import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/core/widgets/sync_status_indicator.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/audit_log_repository.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/triage/domain/triage_decision.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

/// Captures what the assessment sends for sync instead of queueing it.
class _RecordingRepo extends ScreeningSyncRepository {
  _RecordingRepo()
      : super(queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')));

  final responses = <String, Object?>{};
  final decisions = <String, Map<String, Object?>>{};

  @override
  Future<String> startAssessmentSession(Set<String> diseaseCodes) async => 's';

  @override
  Future<String> startDiseaseScreening(String diseaseCode) async => 'x';

  @override
  Future<void> recordResponse({
    required String diseaseCode,
    required String questionId,
    required Object? value,
  }) async =>
      responses[questionId] = value;

  @override
  Future<void> recordFindings({
    required String diseaseCode,
    required List<ClinicalFinding> findings,
  }) async {}

  @override
  Future<void> recordDecision({
    required String diseaseCode,
    required Map<String, Object?> decision,
  }) async =>
      decisions[diseaseCode] = decision;

  @override
  Future<void> completeScreening(String diseaseCode) async {}
}

class _RecordingAudit extends AuditLog {
  _RecordingAudit()
      : super(queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')));

  final events = <(String, Map<String, Object?>)>[];

  @override
  void log(String type, [Map<String, Object?> data = const {}]) =>
      events.add((type, data));
}

void main() {
  late _RecordingRepo repo;
  late _RecordingAudit audit;
  late ProviderContainer container;

  setUp(() {
    repo = _RecordingRepo();
    audit = _RecordingAudit();
    container = ProviderContainer(overrides: [
      screeningSyncRepositoryProvider.overrideWithValue(repo),
      auditLogProvider.overrideWithValue(audit),
    ]);
    container
        .read(assessmentProvider.notifier)
        .start({NeonatalCondition.triage}, forceReset: true);
  });
  tearDown(() => container.dispose());

  AssessmentController controller() =>
      container.read(assessmentProvider.notifier);

  test('completing Triage records the structured decision', () {
    controller()
      ..answer(triageWeightKey, 2500)
      ..answer(triageGestationKey, triageTerm)
      ..answer(triageHeartRateKey, 210)
      ..answer(triageEmergencySignsKey, <Object>{'shock'})
      ..confirmPage();
    expect(container.read(assessmentProvider).isComplete, isTrue);

    final d = repo.decisions['triage']!;
    expect(d['topic'], 'triage');
    expect(d['category'], 'EMERGENCY');
    expect(d['triggers'], containsAll(['HR 210/min (>200/min)']));
    expect((d['flags'] as Map)['shock'], isTrue);
    final cards = (d['flaggedCards'] as List).cast<Map>();
    expect(cards.map((c) => c['id']), containsAll(['circulation', 'shock']));
    final dose = (d['computedDoses'] as List).cast<Map>().single;
    expect(dose['drug'], 'Normal saline');
    expect(dose['volumeMl'], 25);
    expect(dose['rate'], 'Term: give the NS bolus over 15–20 min.');
    expect(
        (d['stwLinks'] as List).cast<Map>().map((l) => l['regionId']),
        contains('triage_shock'));
    expect((d['findings'] as List).cast<Map>().map((f) => f['id']),
        contains('triage.classification'));
  });

  test('free-text history is never synced; only whether it was provided', () {
    controller().answer(triageMaternalHistoryKey, 'Mother: Sunita, PROM 20 h');
    expect(repo.responses[triageMaternalHistoryKey], isNull);
    expect(repo.responses.containsKey(triageMaternalHistoryKey), isFalse);
    expect(repo.responses['${triageMaternalHistoryKey}_provided'], isTrue);
    expect(
        repo.responses.values.whereType<String>().any((v) => v.contains('Sunita')),
        isFalse);

    controller().answer(triageMaternalHistoryKey, null);
    expect(repo.responses['${triageMaternalHistoryKey}_provided'], isFalse);

    controller()
      ..answer(triageMaternalHistoryKey, 'Sunita')
      ..answer(triageHeartRateKey, 150)
      ..confirmPage();
    final baseline = repo.decisions['triage']!['baseline'] as Map;
    expect(baseline['maternalHistoryProvided'], isTrue);
    expect(baseline['newbornHistoryProvided'], isFalse);
    expect('${repo.decisions['triage']}'.contains('Sunita'), isFalse);
  });

  test('page changes go to the audit trail', () {
    controller()
      ..answer(triageHeartRateKey, 210)
      ..confirmPage()
      ..back();
    expect(
        audit.events.map((e) => e.$1), containsAllInOrder(['page_confirmed', 'page_back']));
    final confirmed = audit.events.firstWhere((e) => e.$1 == 'page_confirmed');
    expect(confirmed.$2, {'group': triageAssessmentGroup, 'next': 'results'});
  });

  test('a Triage with no sign is recorded as NO_SIGNS without doses', () {
    final ctx = const AssessmentEngine().evaluate(
      selected: {NeonatalCondition.triage},
      answers: {triageWeightKey: 2500},
      today: DateTime(2026, 10, 17),
    );
    final d = triageDecisionRecord(ctx);
    expect(d['category'], 'NO_SIGNS');
    expect(d['triggers'], isEmpty);
    expect(d['flaggedCards'], isEmpty);
    expect(d['computedDoses'], isEmpty);
  });

  test('IV dextrose dose is recorded only when the STW indicates it', () {
    Map<String, Object?> decision(Map<String, Object?> answers) =>
        triageDecisionRecord(const AssessmentEngine().evaluate(
          selected: {NeonatalCondition.triage},
          answers: {triageWeightKey: 3000, ...answers},
          today: DateTime(2026, 10, 17),
        ));
    expect(
        decision({
          triageBloodGlucoseKey: 35,
          triageHypoglycemiaSymptomsKey: false,
        })['computedDoses'],
        isEmpty);
    final dose = (decision({triageBloodGlucoseKey: 15})['computedDoses']
            as List)
        .cast<Map>()
        .single;
    expect(dose['drug'], '10% dextrose');
    expect(dose['volumeMl'], 6);
  });

  group('sync status indicator', () {
    Future<void> pump(WidgetTester tester, SyncStatus s) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith((_) => Stream.value(s)),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [SyncStatusIndicator()]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('all synced shows cloud done', (tester) async {
      await pump(tester,
          const SyncStatus(pending: 0, failed: 0, phase: SyncPhase.idle));
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      expect(find.byTooltip('All records synced'), findsOneWidget);
    });

    testWidgets('offline with pending records shows the count', (tester) async {
      await pump(
          tester,
          SyncStatus(
            pending: 7,
            failed: 0,
            phase: SyncPhase.waitingToRetry,
            nextRetryAt: DateTime(2026, 10, 17, 10, 30),
          ));
      expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(
          find.byTooltip('7 records waiting to sync (offline; retrying at 10:30)'),
          findsOneWidget);
    });

    testWidgets('syncing shows cloud sync; tap opens details', (tester) async {
      await pump(tester,
          const SyncStatus(pending: 2, failed: 1, phase: SyncPhase.syncing));
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sync-status-indicator')));
      await tester.pumpAndSettle();
      expect(find.text('Data sync'), findsOneWidget);
      expect(
          find.text('Syncing 2 records… · 1 record rejected by the server, '
              'kept on this device'),
          findsOneWidget);
    });
  });
}
