import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/follow_up/data/rop_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/domain/follow_up_models.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/follow_up/ui/follow_up_screen.dart';

void main() {
  group('ROP Follow-up Data Integrity', () {
    test('contains exactly 8 ROP MCQs with valid properties', () {
      expect(ropFollowUpMcqs.length, 8);
      for (final mcq in ropFollowUpMcqs) {
        expect(mcq.question.isNotEmpty, true);
        expect(mcq.options.length, 4,
            reason: '${mcq.id} must have exactly 4 options');
        expect(mcq.correctAnswerIndex, inInclusiveRange(0, 3));
        expect(mcq.correctAnswer.isNotEmpty, true);
        expect(mcq.explanation.isNotEmpty, true);
        expect(mcq.category.isNotEmpty, true);
        expect(mcq.questionType, QuestionType.mcq);
      }
    });

    test('contains exactly 8 ROP Case Scenarios with valid properties', () {
      expect(ropFollowUpCaseScenarios.length, 8);
      for (final cs in ropFollowUpCaseScenarios) {
        expect(cs.scenario, isNotNull);
        expect(cs.scenario!.isNotEmpty, true);
        expect(cs.question.isNotEmpty, true);
        expect(cs.options.length, 4,
            reason: '${cs.id} must have exactly 4 options');
        expect(cs.correctAnswerIndex, inInclusiveRange(0, 3));
        expect(cs.correctAnswer.isNotEmpty, true);
        expect(cs.explanation.isNotEmpty, true);
        expect(cs.category.isNotEmpty, true);
        expect(cs.questionType, QuestionType.caseScenario);
      }
    });

    test('verifies authoritative answers for key MCQs', () {
      // Q1: KPI -> B (index 1)
      expect(ropFollowUpMcqs[0].correctAnswerIndex, 1);
      // Q2: Prevention EXCEPT -> D (index 3)
      expect(ropFollowUpMcqs[1].correctAnswerIndex, 3);
      // Q3: Preferred screening method -> B (index 1)
      expect(ropFollowUpMcqs[2].correctAnswerIndex, 1);
      // Q4: Withhold feeds -> 1 hour -> B (index 1)
      expect(ropFollowUpMcqs[3].correctAnswerIndex, 1);
      // Q5: Eligibility in India -> <34 wks and/or <2000g -> C (index 2)
      expect(ropFollowUpMcqs[4].correctAnswerIndex, 2);
      // Q6: First screening 27 wks & 1100g -> 2-3 wks -> A (index 0)
      expect(ropFollowUpMcqs[5].correctAnswerIndex, 0);
      // Q7: Treatment statement -> Zone I requires Anti-VEGF -> B (index 1)
      expect(ropFollowUpMcqs[6].correctAnswerIndex, 1);
      // Q8: Zone II stage 1 without plus -> Observe, KMC, repeat 2 wks -> C (index 2)
      expect(ropFollowUpMcqs[7].correctAnswerIndex, 2);
    });
  });

  group('FollowUpController State Machine', () {
    test('initial state begins at intro stage', () {
      final controller = FollowUpController();
      expect(controller.state.stage, FollowUpStage.intro);
      expect(controller.state.currentMcqIndex, 0);
      expect(controller.state.mcqAnswers.isEmpty, true);
      expect(controller.state.currentCaseIndex, 0);
      expect(controller.state.caseAnswers.isEmpty, true);
    });

    test('navigates through MCQs, preserves selections, and calculates score', () {
      final controller = FollowUpController();
      controller.startAssessment();
      expect(controller.state.stage, FollowUpStage.mcqs);
      expect(controller.state.currentMcqIndex, 0);

      // Select answer for Q1: option B (index 1 = correct)
      controller.selectMcqOption(1);
      expect(controller.state.selectedMcqOption, 1);

      // Advance to Q2
      controller.nextMcq();
      expect(controller.state.currentMcqIndex, 1);

      // Select answer for Q2: option D (index 3 = correct)
      controller.selectMcqOption(3);
      expect(controller.state.selectedMcqOption, 3);

      // Go back to Q1 and verify selection is preserved
      controller.previousMcq();
      expect(controller.state.currentMcqIndex, 0);
      expect(controller.state.selectedMcqOption, 1);

      // Answer rest of MCQs
      for (int i = 0; i < controller.state.mcqs.length; i++) {
        controller.goToMcq(i);
        controller.selectMcqOption(controller.state.mcqs[i].correctAnswerIndex);
      }

      // Submit MCQs
      controller.submitMcqs();
      expect(controller.state.stage, FollowUpStage.mcqResult);
      expect(controller.state.mcqCorrectCount, 8);
      expect(controller.state.mcqIncorrectCount, 0);
      expect(controller.state.mcqPercentage, 100.0);
    });

    test('navigates through Case Scenarios and calculates final summary', () {
      final controller = FollowUpController();
      controller.startAssessment();

      // Submit MCQs with 1 incorrect
      for (int i = 0; i < controller.state.mcqs.length; i++) {
        controller.goToMcq(i);
        // Make Q1 incorrect (index 0 instead of 1)
        controller.selectMcqOption(i == 0 ? 0 : controller.state.mcqs[i].correctAnswerIndex);
      }
      controller.submitMcqs();
      expect(controller.state.mcqCorrectCount, 7);
      expect(controller.state.mcqIncorrectCount, 1);

      // Proceed to Case Scenarios
      controller.proceedToCaseScenarios();
      expect(controller.state.stage, FollowUpStage.caseScenarios);
      expect(controller.state.currentCaseIndex, 0);

      // Answer all 8 Case Scenarios correctly
      for (int i = 0; i < controller.state.caseScenarios.length; i++) {
        controller.goToCase(i);
        controller.selectCaseOption(controller.state.caseScenarios[i].correctAnswerIndex);
      }
      expect(controller.state.isLastCase, true);

      // Submit Case Scenarios
      controller.submitCaseScenarios();
      expect(controller.state.stage, FollowUpStage.finalSummary);
      expect(controller.state.caseCorrectCount, 8);
      expect(controller.state.totalCorrectCount, 15);
      expect(controller.state.totalQuestionsCount, 16);
      expect(controller.state.totalPercentage, (15 / 16) * 100);

      // Reset
      controller.reset();
      expect(controller.state.stage, FollowUpStage.intro);
      expect(controller.state.mcqAnswers.isEmpty, true);
    });
  });

  group('FollowUpScreen Widget Tests', () {
    testWidgets('renders intro stage and transitions to MCQs upon tapping start',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FollowUpScreen(),
          ),
        ),
      );

      // Expect Intro header and start button
      expect(find.textContaining('Follow-up Assessment: Retinopathy of Prematurity'),
          findsOneWidget);
      expect(find.text('Start ROP MCQs (8 Questions)'), findsOneWidget);

      // Tap Start ROP MCQs
      await tester.tap(find.text('Start ROP MCQs (8 Questions)'));
      await tester.pumpAndSettle();

      // Expect MCQ 1 screen
      expect(find.text('MCQ 1 OF 8'), findsOneWidget);
      expect(find.textContaining('Key Performance Indicator (KPI)'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('allows selecting an option, navigating next, and submitting MCQs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FollowUpScreen(),
          ),
        ),
      );

      // Start MCQs
      container.read(followUpProvider.notifier).startAssessment();
      await tester.pumpAndSettle();

      expect(find.text('MCQ 1 OF 8'), findsOneWidget);

      // Tap option B
      await tester.tap(find.textContaining('Percentage of eligible preterm/LBW babies'));
      await tester.pumpAndSettle();

      // Verify controller state updated
      expect(container.read(followUpProvider).selectedMcqOption, 1);

      // Jump to last question (MCQ 8)
      container.read(followUpProvider.notifier).goToMcq(7);
      await tester.pumpAndSettle();

      expect(find.text('MCQ 8 OF 8'), findsOneWidget);
      expect(find.text('Submit Assessment'), findsOneWidget);

      // Tap option C on Q8
      await tester.tap(find.textContaining('Observe, monitor weight gain, encourage KMC'));
      await tester.pumpAndSettle();

      // Tap Submit Assessment
      await tester.tap(find.text('Submit Assessment'));
      await tester.pumpAndSettle();

      // Verify we are on MCQ Result screen
      expect(find.textContaining('Results'), findsWidgets);
      expect(find.text('Proceed to Case Scenarios (8 Cases)'), findsWidgets);
    });
  });
}
