import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/screening_session_panel.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('duration formatting handles minutes, hours and a backwards clock', () {
    expect(formatScreeningDuration(const Duration(seconds: 65)), '01:05');
    expect(formatScreeningDuration(const Duration(hours: 2, seconds: 3)),
        '02:00:03');
    final start = DateTime.utc(2026, 10, 15);
    final timing =
        ScreeningTiming(id: '1', diseaseCode: 'rop', startedAt: start);
    expect(timing.finish(start.subtract(const Duration(seconds: 1))).duration,
        Duration.zero);
  });

  test('disease counts come from unique catalog entries, not selection', () {
    expect(
        availableDiseaseCount,
        stwModuleDefinitions
            .where((d) => d.implemented)
            .map((d) => d.id)
            .toSet()
            .length);
    expect(listedConditionCount,
        stwModuleDefinitions.map((d) => d.id).toSet().length);
    // Triage runs before the modules and is not counted as one.
    expect(availableDiseaseCount, 8);
    expect(listedConditionCount, 13);
  });

  group('persistent screening timings', () {
    late Directory directory;
    late OfflineQueue queue;
    late ScreeningSyncRepository repo;
    late DateTime now;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('stw_timings_');
      final suffix = DateTime.now().microsecondsSinceEpoch;
      queue = OfflineQueue(
          sessionBoxName: 'timing_session_$suffix',
          queueBoxName: 'timing_queue_$suffix',
          apiClient: ApiClient(baseUrl: '', apiKey: ''));
      await queue.initialize(customPath: directory.path);
      now = DateTime.utc(2026, 10, 15, 10);
      repo = ScreeningSyncRepository(queue: queue, now: () => now);
    });

    tearDown(() async {
      repo.dispose();
      await queue.dispose();
      await directory.delete(recursive: true);
    });

    test('event timestamps ignore queue delay and completion is frozen',
        () async {
      final start = now;
      final starting = repo.startDiseaseScreening('rop');
      now = now.add(const Duration(seconds: 15));
      await starting;
      expect(repo.timings.single.startedAt, start);
      final completing = repo.completeScreening('rop');
      now = now.add(const Duration(minutes: 5));
      await completing;
      expect(repo.timings.single.duration, const Duration(seconds: 15));
      await repo.recordMcqAttempt(
          diseaseCode: 'rop',
          questionId: 'q1',
          selectedOption: 'a',
          isCorrect: true);
      await repo.completeScreening('rop');
      expect(repo.timings.single.duration, const Duration(seconds: 15));
      expect(queue.getScreeningTimings().single['durationMs'], 15000);
    });

    test(
        'history survives closing, reopening local storage and a fresh session',
        () async {
      final first = await repo.startDiseaseScreening('rop');
      now = now.add(const Duration(seconds: 91));
      await repo.completeScreening('rop');
      await repo.endAssessmentSession();
      expect(repo.activeTimings({'rop'}), isEmpty);
      repo.dispose();
      await queue.dispose();
      await queue.initialize(customPath: directory.path);
      repo = ScreeningSyncRepository(queue: queue, now: () => now);
      expect(repo.timings.single.id, first);
      expect(repo.timings.single.duration, const Duration(seconds: 91));
      await repo.startAssessmentSession({'rop'});
      final second = await repo.startDiseaseScreening('rop');
      expect(second, isNot(first));
      expect(repo.activeTimings({'rop'}).single.isRunning, isTrue);
      expect(repo.timings.where((t) => t.isCompleted).single.id, first);
      now = now.add(const Duration(seconds: 5));
      await repo.endAssessmentSession();
      expect(repo.timings.where((t) => t.id == second).single.abandonedAt, now);
      expect(repo.timings.where((t) => t.isCompleted).length, 1);
    });

    test('multiple selected diseases retain their individual timings',
        () async {
      await repo.startAssessmentSession({'rop', 'kmc'});
      await repo.startDiseaseScreening('rop');
      now = now.add(const Duration(seconds: 2));
      await repo.startDiseaseScreening('kmc');
      now = now.add(const Duration(seconds: 10));
      await repo.completeScreening('rop');
      expect(queue.isSessionClosed, isFalse);
      now = now.add(const Duration(seconds: 8));
      await repo.completeScreening('kmc');
      expect(queue.isSessionClosed, isTrue);
      expect(repo.activeTimings({'rop'}).single.duration,
          const Duration(seconds: 12));
      expect(repo.activeTimings({'kmc'}).single.duration,
          const Duration(seconds: 18));
    });

    test('actual assessment entry and summary drive the timer automatically',
        () async {
      final container = ProviderContainer(overrides: [
        screeningSyncRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(assessmentProvider.notifier);
      controller.start({NeonatalCondition.triage}, forceReset: true);
      await repo.startDiseaseScreening('triage'); // Serial barrier only.
      expect(repo.timings.single.isRunning, isTrue);
      now = now.add(const Duration(seconds: 42));
      for (var i = 0;
          i < 15 && !container.read(assessmentProvider).isComplete;
          i++) {
        controller.answer(triageHypoglycemiaSymptomsKey, false);
        controller.confirmPage(); // Optional measurements, no observed signs.
      }
      expect(container.read(assessmentProvider).isComplete, isTrue);
      await repo.ensureSession(); // Wait for automatically queued completion.
      expect(repo.timings.single.duration, const Duration(seconds: 42));
      expect(controller.back(), isTrue);
      now = now.add(const Duration(minutes: 2));
      controller.confirmPage();
      await repo.ensureSession();
      expect(repo.timings.single.duration, const Duration(seconds: 42));
    });
  });

  testWidgets(
      'all available workflows keep the timer and global count without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final disease in conditionDefinitions.where((d) => d.implemented)) {
      final repo = ScreeningSyncRepository(
          queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')));
      final container = ProviderContainer(overrides: [
        screeningSyncRepositoryProvider.overrideWithValue(repo),
      ]);
      container
          .read(assessmentProvider.notifier)
          .start({disease.id}, forceReset: true);
      await repo.startDiseaseScreening(diseaseCodeOf(disease.id));
      for (final size in [const Size(360, 640), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: WorkflowScreen())));
        await tester.pumpAndSettle();
        expect(find.text('Screening time'), findsOneWidget);
        expect(find.text('$availableDiseaseCount diseases available'),
            findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '${disease.id} at $size');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      repo.dispose();
    }
  });

  testWidgets(
      'timer ticks, stops at completion and renders narrow and landscape',
      (tester) async {
    var now = DateTime.utc(2026, 10, 15, 10);
    final repo = ScreeningSyncRepository(
        queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')),
        now: () => now);
    addTearDown(repo.dispose);
    await repo.startDiseaseScreening('respiratory_distress');
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          screeningSyncRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: Column(children: [
            ScreeningSessionPanel(diseaseCodes: {'respiratory_distress'}),
            ScreeningHistoryCard(),
          ]),
        )))));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:09'), findsOneWidget);
    await repo.completeScreening('respiratory_distress');
    await tester.pumpAndSettle();
    expect(find.text('Time taken: 00:09'), findsOneWidget);
    now = now.add(const Duration(minutes: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Time taken: 00:09'), findsOneWidget);
    await tester.tap(find.text('Previous screenings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Started:'), findsOneWidget);
    expect(find.textContaining('Completed:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
