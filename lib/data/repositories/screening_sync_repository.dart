import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/clinical_workflow/domain/clinical_finding.dart';
import '../../features/clinical_workflow/domain/clinical_question.dart';
import '../../features/condition_selection/domain/neonatal_condition.dart';
import '../local/offline_queue.dart';

/// Maps [NeonatalCondition] enum values to standardized database codes.
String diseaseCodeOf(NeonatalCondition c) {
  switch (c) {
    case NeonatalCondition.respiratoryDistress:
      return 'respiratory_distress';
    case NeonatalCondition.rop:
      return 'rop';
    case NeonatalCondition.thermalCare:
      return 'thermal_care';
    case NeonatalCondition.fluidsAndFeeds:
      return 'fluids_and_feeds';
    case NeonatalCondition.dischargeAndFollowUp:
      return 'discharge_and_follow_up';
    default:
      return c.name;
  }
}


/// Question types never sent to the server: dates (date of birth, exam
/// dates) and free text (facility name, SNCU/CR number) can identify a baby.
bool isSyncableQuestion(ClinicalQuestion q) =>
    q.type != QuestionType.date && q.type != QuestionType.text;

/// Repository for syncing clinical sessions, screenings, question responses,
/// clinical findings, and MCQ attempts via the offline-first queue.
///
/// Operations run one at a time, in call order, so concurrent callers cannot
/// create duplicate sessions/screenings and a screening is always queued
/// before anything that refers to it.
class ScreeningSyncRepository {
  ScreeningSyncRepository({OfflineQueue? queue})
      : _queue = queue ?? OfflineQueue.instance;

  final OfflineQueue _queue;

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  /// Ensures an active de-identified clinical session exists.
  Future<String> ensureSession({String? facilityName}) =>
      _serial(() => _ensureSession(facilityName: facilityName));

  Future<String> _ensureSession({String? facilityName}) async {
    var sessionId = _queue.currentSessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }

    sessionId = _queue.generateUuid();
    final token = _queue.getOrCreateSessionToken();
    final now = DateTime.now().toUtc().toIso8601String();

    await _queue.setSessionId(sessionId);
    await _queue.enqueue(
      table: 'clinical_sessions',
      action: 'upsert',
      payload: {
        'id': sessionId,
        'session_token': token,
        'clinician_id': 'anon_${token.substring(0, 8)}',
        'facility_name': facilityName,
        'platform': _detectPlatform(),
        'app_version': '0.1.0+1',
        'status': 'in_progress',
        'created_at': now,
        'updated_at': now,
      },
    );

    return sessionId;
  }

  /// Starts or gets an existing screening ID for a specific disease code.
  Future<String> startDiseaseScreening(String diseaseCode) =>
      _serial(() => _screeningFor(diseaseCode));

  Future<String> _screeningFor(String diseaseCode) async {
    final active = _queue.getActiveScreenings();
    if (active.containsKey(diseaseCode)) {
      return active[diseaseCode]!;
    }

    final sessionId = await _ensureSession();
    final screeningId = _queue.generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();

    await _queue.setActiveScreening(diseaseCode, screeningId);
    await _queue.enqueue(
      table: 'disease_screenings',
      action: 'upsert',
      payload: {
        'id': screeningId,
        'session_id': sessionId,
        'disease_code': diseaseCode,
        'progress_state': 'in_progress',
        'is_eligible': null,
        'started_at': now,
      },
    );

    return screeningId;
  }

  /// Upserts an answer to a question in an active disease screening. A null
  /// [value] records that the answer was cleared. Callers must not pass
  /// answers to questions failing [isSyncableQuestion].
  Future<void> recordResponse({
    required String diseaseCode,
    required String questionId,
    required Object? value,
  }) =>
      _serial(() async {
        final screeningId = await _screeningFor(diseaseCode);
        final now = DateTime.now().toUtc().toIso8601String();

        await _queue.enqueue(
          table: 'screening_responses',
          action: 'upsert',
          customId: '${screeningId}_$questionId',
          payload: {
            'screening_id': screeningId,
            'question_id': questionId,
            'response_data': {'value': storable(value)},
            'answered_at': now,
          },
        );
      });

  /// Records the screening's current findings, replacing any recorded
  /// earlier (e.g. when the clinician goes Back and completes again).
  Future<void> recordFindings({
    required String diseaseCode,
    required List<ClinicalFinding> findings,
  }) =>
      _serial(() async {
        final screeningId = await _screeningFor(diseaseCode);
        final now = DateTime.now().toUtc().toIso8601String();

        await _queue.enqueue(
          table: 'screening_findings',
          action: 'replace',
          customId: '${screeningId}_findings',
          payload: {
            'screening_id': screeningId,
            'findings': [
              for (final f in findings)
                {
                  'type': f.category.name,
                  'title': f.title,
                  'severity': f.level.name,
                  'recommendations': {
                    'actions': f.actions,
                    'why': f.why,
                  },
                  'stwReference': f.source.citation,
                  'generatedAt': now,
                },
            ],
          },
        );
      });

  /// Marks a disease screening as completed.
  Future<void> completeScreening(String diseaseCode) => _serial(() async {
        final active = _queue.getActiveScreenings();
        final screeningId = active[diseaseCode];
        if (screeningId == null) return;

        final now = DateTime.now().toUtc().toIso8601String();
        await _queue.markScreeningCompleted(diseaseCode);
        await _queue.enqueue(
          table: 'disease_screenings',
          action: 'patch_status',
          payload: {
            'id': screeningId,
            'progress_state': 'completed',
            'completed_at': now,
          },
        );
      });

  /// Records an attempt at an MCQ or clinical case scenario question.
  Future<void> recordMcqAttempt({
    required String diseaseCode,
    required String questionId,
    required String selectedOption,
    required bool isCorrect,
  }) =>
      _serial(() async {
        final screeningId = await _screeningFor(diseaseCode);
        final now = DateTime.now().toUtc().toIso8601String();

        await _queue.enqueue(
          table: 'mcq_attempts',
          action: 'insert',
          payload: {
            'id': _queue.generateUuid(),
            'screening_id': screeningId,
            'question_id': questionId,
            'selected_option': selectedOption,
            'is_correct': isCorrect,
            'answered_at': now,
          },
        );
      });

  /// Closes the active screenings so the next assessment starts new ones.
  /// Screenings not yet completed are marked 'abandoned'; completed ones
  /// keep their status. Called on Home / Exit reset and when an assessment
  /// is restarted.
  Future<void> abandonActiveScreenings() => _serial(() async {
        final active = _queue.getActiveScreenings();
        final completed = _queue.getCompletedScreenings();
        for (final entry in active.entries) {
          if (completed.contains(entry.key)) continue;
          await _queue.enqueue(
            table: 'disease_screenings',
            action: 'patch_status',
            payload: {
              'id': entry.value,
              'progress_state': 'abandoned',
            },
          );
        }
        await _queue.clearActiveScreenings();
      });
}

/// Global provider for [ScreeningSyncRepository].
final screeningSyncRepositoryProvider =
    Provider<ScreeningSyncRepository>((ref) {
  return ScreeningSyncRepository();
});
