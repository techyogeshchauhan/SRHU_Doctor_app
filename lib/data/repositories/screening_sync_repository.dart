import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/clinical_workflow/domain/clinical_finding.dart';
import '../../features/clinical_workflow/domain/clinical_question.dart';
import '../../features/condition_selection/domain/neonatal_condition.dart';
import '../local/offline_queue.dart';
import '../models/screening_timing.dart';

export '../models/screening_timing.dart';

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

/// App version recorded with each session (set by scripts/build_*.ps1).
const appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

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
  ScreeningSyncRepository({OfflineQueue? queue, DateTime Function()? now})
      : _queue = queue ?? OfflineQueue.instance,
        _now = now ?? DateTime.now {
    _activeScreenings.addAll(_queue.getActiveScreenings());
    for (final raw in _queue.getScreeningTimings()) {
      final timing = ScreeningTiming.fromJson(raw);
      _timings[timing.id] = timing;
    }
  }

  final OfflineQueue _queue;
  final DateTime Function() _now;
  final Map<String, String> _activeScreenings = {};
  final Map<String, ScreeningTiming> _timings = {};
  final _timingChanges = StreamController<List<ScreeningTiming>>.broadcast();
  DateTime get currentTime => _now().toUtc();
  DateTime _eventTime() =>
      DateTime.fromMillisecondsSinceEpoch(_now().millisecondsSinceEpoch,
          isUtc: true);

  List<ScreeningTiming> get timings =>
      List.unmodifiable(_timings.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  List<ScreeningTiming> activeTimings(Set<String> codes) => [
        for (final code in codes)
          if (_timings[_activeScreenings[code]] case final timing?) timing,
      ];

  Stream<List<ScreeningTiming>> get watchTimings => Stream.multi((controller) {
        final subscription = _timingChanges.stream.listen(controller.add);
        controller.add(timings);
        controller.onCancel = subscription.cancel;
      });

  Future<void> _saveTiming(ScreeningTiming timing) async {
    _timings[timing.id] = timing;
    await _queue.saveScreeningTiming(timing.toJson());
    if (!_timingChanges.isClosed) _timingChanges.add(timings);
  }

  void dispose() => _timingChanges.close();

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

  /// Ensures an active de-identified clinical session exists (e.g. for a
  /// chatbot question asked outside an assessment).
  Future<String> ensureSession({String? facilityName}) =>
      _serial(() => _ensureSession(facilityName: facilityName));

  /// One session per assessment: closes the current session (see
  /// [endAssessmentSession]) and opens a new one for [diseaseCodes]. Called
  /// when an assessment starts or restarts.
  Future<String> startAssessmentSession(Set<String> diseaseCodes) =>
      _serial(() async {
        await _endSession();
        return _ensureSession(selectedConditions: diseaseCodes);
      });

  /// Ends the current session: unfinished screenings are marked abandoned
  /// and the session is closed, 'completed' when every screening in it was
  /// completed, else 'abandoned'. The next screening or chat opens a new
  /// session. Called on Home / Exit reset.
  Future<void> endAssessmentSession() => _serial(_endSession);

  Future<void> _endSession() async {
    final active = _activeScreenings;
    final completed = {
      ..._queue.getCompletedScreenings(),
      for (final t in _timings.values)
        if (t.isCompleted && active[t.diseaseCode] == t.id) t.diseaseCode,
    };
    final allDone = active.keys.every(completed.contains);
    await _abandonActive();
    final sessionId = _queue.currentSessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    if (!_queue.isSessionClosed) {
      await _closeSession(sessionId, allDone ? 'completed' : 'abandoned');
    }
    await _queue.clearSessionId();
  }

  Future<void> _closeSession(String sessionId, String status) async {
    await _queue.enqueue(
      table: 'clinical_sessions',
      action: 'patch',
      payload: {
        'id': sessionId,
        'status': status,
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await _queue.markSessionClosed();
  }

  Future<String> _ensureSession({
    String? facilityName,
    Set<String> selectedConditions = const {},
  }) async {
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
        'app_version': appVersion,
        'selected_conditions': (selectedConditions.toList()..sort()),
        'status': 'in_progress',
        'created_at': now,
        'updated_at': now,
      },
    );

    return sessionId;
  }

  /// Starts or gets an existing screening ID for a specific disease code.
  Future<String> startDiseaseScreening(String diseaseCode) {
    final startedAt = _eventTime();
    return _serial(() => _screeningFor(diseaseCode, startedAt: startedAt));
  }

  Future<String> _screeningFor(String diseaseCode,
      {DateTime? startedAt}) async {
    final active = _activeScreenings;
    if (active.containsKey(diseaseCode)) {
      return active[diseaseCode]!;
    }

    final sessionId = await _ensureSession();
    final screeningId = _queue.generateUuid();
    final start = startedAt ?? _eventTime();
    final now = start.toIso8601String();

    await _queue.setActiveScreening(diseaseCode, screeningId);
    _activeScreenings[diseaseCode] = screeningId;
    await _saveTiming(ScreeningTiming(
        id: screeningId, diseaseCode: diseaseCode, startedAt: start));
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
  Future<void> completeScreening(String diseaseCode) {
    final completedAt = _eventTime();
    return _serial(() async {
      final active = _activeScreenings;
      final screeningId = active[diseaseCode];
      if (screeningId == null) return;

      final timing = _timings[screeningId];
      if (timing?.isCompleted == true) return;
      final finished = timing?.finish(completedAt);
      if (finished != null) await _saveTiming(finished);
      final now = (finished?.completedAt ?? completedAt).toIso8601String();
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

      // Every screening of this assessment done: the session is complete
      // (it stays current, so follow-up MCQs and chats still belong to it).
      final completed = _queue.getCompletedScreenings();
      final sessionId = _queue.currentSessionId;
      if (sessionId != null &&
          !_queue.isSessionClosed &&
          active.keys.every(completed.contains)) {
        await _closeSession(sessionId, 'completed');
      }
    });
  }

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
  Future<void> abandonActiveScreenings() => _serial(_abandonActive);

  Future<void> _abandonActive() async {
    final active = _activeScreenings;
    final completed = {
      ..._queue.getCompletedScreenings(),
      for (final t in _timings.values)
        if (t.isCompleted && active[t.diseaseCode] == t.id) t.diseaseCode,
    };
    for (final entry in active.entries) {
      if (completed.contains(entry.key)) continue;
      final timing = _timings[entry.value];
      if (timing != null && timing.isRunning) {
        await _saveTiming(timing.finish(_eventTime(), abandoned: true));
      }
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
    _activeScreenings.clear();
    if (!_timingChanges.isClosed) _timingChanges.add(timings);
  }
}

/// Global provider for [ScreeningSyncRepository].
final screeningSyncRepositoryProvider =
    Provider<ScreeningSyncRepository>((ref) {
  final repository = ScreeningSyncRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// A separate stream keeps timing updates from rebuilding repository consumers
/// such as the chatbot or the clinical assessment controller.
final screeningTimingsProvider = StreamProvider<List<ScreeningTiming>>(
    (ref) => ref.watch(screeningSyncRepositoryProvider).watchTimings);
