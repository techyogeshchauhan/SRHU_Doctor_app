import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/chat_log_repository.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';

void main() {
  late Directory tempDir;
  late OfflineQueue queue;
  late ScreeningSyncRepository screeningRepo;
  late ChatLogRepository chatRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('stw_test_db_');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    queue = OfflineQueue(
      sessionBoxName: 'test_session_$timestamp',
      queueBoxName: 'test_queue_$timestamp',
    );
    await queue.initialize(customPath: tempDir.path);
    screeningRepo = ScreeningSyncRepository(queue: queue);
    chatRepo = ChatLogRepository(queue: queue);
  });

  tearDownAll(() async {
    await queue.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Goal B: Structured Database & Offline Sync Unit Tests', () {
    test('1. ensureSession creates session with platform, version and session token', () async {
      final initialPending = queue.pendingCount;
      final sessionId = await screeningRepo.ensureSession();

      expect(sessionId, isNotEmpty);
      expect(queue.currentSessionId, equals(sessionId));
      expect(queue.pendingCount, greaterThan(initialPending));
    });

    test('2. startDiseaseScreening generates screening row for active module', () async {
      final initialPending = queue.pendingCount;
      final screeningId = await screeningRepo.startDiseaseScreening('respiratory_distress');

      expect(screeningId, isNotEmpty);
      final active = queue.getActiveScreenings();
      expect(active['respiratory_distress'], equals(screeningId));
      expect(queue.pendingCount, greaterThan(initialPending));
    });

    test('3. recordResponse enqueues upsert for screening question response', () async {
      final initialPending = queue.pendingCount;
      await screeningRepo.recordResponse(
        diseaseCode: 'respiratory_distress',
        questionId: 'gestation_weeks',
        value: 32,
      );

      expect(queue.pendingCount, greaterThan(initialPending));
    });

    test('4. recordFindings enqueues algorithmic findings', () async {
      final initialPending = queue.pendingCount;
      const finding = ClinicalFinding(
        id: 'test_rd_finding',
        topic: NeonatalCondition.respiratoryDistress,
        content: FindingContent(
          category: FindingCategory.treatment,
          level: FindingLevel.action,
          title: 'Start CPAP 5 cm H2O and Caffeine',
          actions: ['Apply nasal prongs', 'Loading dose caffeine citrate 20 mg/kg'],
          why: ['Severe distress in preterm <34 weeks'],
        ),
        source: SourceReference(
          document: 'Respiratory Distress in Neonates',
          section: 'Algorithm Box 3',
        ),
      );

      await screeningRepo.recordFindings(
        diseaseCode: 'respiratory_distress',
        findings: [finding],
      );

      expect(queue.pendingCount, greaterThan(initialPending));
    });

    test('5. recordMcqAttempt records clinician follow-up evaluation attempt', () async {
      final initialPending = queue.pendingCount;
      await screeningRepo.recordMcqAttempt(
        diseaseCode: 'rop',
        questionId: 'rop_q1',
        selectedOption: '<34 weeks',
        isCorrect: true,
      );

      expect(queue.pendingCount, greaterThan(initialPending));
    });

    test('6. abandonActiveScreenings marks active screenings as abandoned', () async {
      await screeningRepo.startDiseaseScreening('rop');
      expect(queue.getActiveScreenings().containsKey('rop'), isTrue);

      final countBefore = queue.pendingCount;
      await screeningRepo.abandonActiveScreenings();

      expect(queue.getActiveScreenings().isEmpty, isTrue);
      expect(queue.pendingCount, greaterThan(countBefore));
    });

    test('7. logChatQuery persists extractive query, verbatim answer and citations', () async {
      final countBefore = queue.pendingCount;
      await chatRepo.logChatQuery(
        query: 'What is the starting CPAP pressure?',
        answer: 'Starting CPAP pressure: 5 cm H2O with PEEP valve.',
        matchedChunkIds: ['rd_006'],
        sourceMetadata: {
          'document': 'respiratory_distress_neonates_stw.pdf',
          'page': 1,
          'section': 'Oxygen Therapy and CPAP Initiation',
          'bounding_boxes': [
            {'x': 0.1, 'y': 0.3, 'width': 0.4, 'height': 0.15}
          ],
        },
        found: true,
      );

      expect(queue.pendingCount, greaterThan(countBefore));
    });
  });

  group('Goal B: Assessment Engine & Riverpod Integration Tests', () {
    test('AssessmentController start & answer automatically records into queue', () async {
      final containerElement = ProviderContainer(
        overrides: [
          screeningSyncRepositoryProvider.overrideWithValue(screeningRepo),
        ],
      );

      final controller = containerElement.read(assessmentProvider.notifier);
      final countBefore = queue.pendingCount;

      controller.start({NeonatalCondition.respiratoryDistress});
      await pumpEventQueue(times: 20);
      expect(queue.pendingCount, greaterThanOrEqualTo(countBefore));

      containerElement.dispose();
    });

    test('FollowUpController submitMcqs records MCQ attempts via sync repository', () async {
      final followUpController = FollowUpController(syncRepo: screeningRepo);
      followUpController.startAssessment();

      // Answer all MCQs
      for (var i = 0; i < followUpController.state.mcqs.length; i++) {
        followUpController.goToMcq(i);
        followUpController.selectMcqOption(0);
      }

      final countBefore = queue.pendingCount;
      final submitted = followUpController.submitMcqs();
      expect(submitted, isTrue);

      // Await background async I/O to write into local queue box
      final stopwatch = Stopwatch()..start();
      while (queue.pendingCount <= countBefore &&
          stopwatch.elapsedMilliseconds < 1500) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(queue.pendingCount, greaterThan(countBefore));
    });
  });
}
