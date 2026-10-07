import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/utils/condition_exit_dialog.dart';
import 'package:neonatal_stw/core/widgets/back_to_home_button.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/data/disease_follow_up_registry.dart';

import 'test_helpers.dart';

Future<void> _pumpToSelection(
  WidgetTester tester, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  if (find.text('Continue').evaluate().isNotEmpty) {
    await tapVisible(tester, find.text('Continue'));
  }
}

void main() {
  group('Disease-specific MCQ & Section 6 Reset Rules', () {
    test('Disease follow up registry returns package only for ROP and not RD', () {
      expect(hasFollowUpForCondition(NeonatalCondition.rop), isTrue);
      expect(getFollowUpPackage(NeonatalCondition.rop), isNotNull);

      expect(hasFollowUpForCondition(NeonatalCondition.respiratoryDistress), isFalse);
      expect(getFollowUpPackage(NeonatalCondition.respiratoryDistress), isNull);
    });

    testWidgets(
        'When no data has been entered yet, tapping Back to Selection or Home skips dialog and navigates directly',
        (tester) async {
      await _pumpToSelection(tester);

      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

      // Open Respiratory Distress screening
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // 1. No data entered yet: tap Back to Selection -> skips dialog, returns to disease selection directly
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Available Clinical Workflows'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsNothing);

      // 2. Open screening again, tap Home button in header -> skips dialog, returns to 14 conditions directly
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);
      await tapVisible(tester, find.byType(BackToHomeButton));
      expect(find.text('TRIGIN'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsNothing);
    });

    testWidgets(
        'Mid-screening: when progress exists, tapping Back to Selection shows confirmation dialog with Stay and Leave & Reset',
        (tester) async {
      await _pumpToSelection(tester);

      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

      // Open Respiratory Distress screening
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Tick Grunting -> now progress exists mid-screening
      await tapVisible(tester, find.text('Grunting'));

      // Tap Back to Selection -> confirmation dialog must appear
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Leave & Reset'), findsOneWidget);

      // Tap Stay -> dialog closes, user remains on screening with Grunting still ticked
      await tapVisible(tester, find.text('Stay'));
      expect(find.text(conditionExitAlertMessage), findsNothing);
      expect(find.text('Signs of respiratory distress'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Checkbox && w.value == true), findsOneWidget);

      // Tap Back to Selection again, then tap Leave & Reset
      await tapVisible(tester, find.text('Back to Selection'));
      await tapVisible(tester, find.text('Leave & Reset'));

      // Returns to Available Clinical Workflows, and data is cleared
      expect(find.text('Available Clinical Workflows'), findsOneWidget);

      // Reopening condition starts fresh with clean state
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Checkbox && w.value == true), findsNothing);
    });

    testWidgets(
        'Mid-screening: when progress exists, tapping Home in header shows confirmation dialog and Leave & Reset returns to Home',
        (tester) async {
      await _pumpToSelection(tester);

      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

      // Open Respiratory Distress screening
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));

      // Tick Grunting -> progress exists
      await tapVisible(tester, find.text('Grunting'));

      // Tap Home in header -> confirmation dialog must appear
      await tapVisible(tester, find.byType(BackToHomeButton));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Tap Stay -> remains on screening
      await tapVisible(tester, find.text('Stay'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Tap Home in header again -> tap Leave & Reset
      await tapVisible(tester, find.byType(BackToHomeButton));
      await tapVisible(tester, find.text('Leave & Reset'));

      // Returns to main condition selection page
      expect(find.text('TRIGIN'), findsOneWidget);
    });

    testWidgets(
        'After screening completion: shows summary without ROP MCQs, and Back to Selection prompts confirmation',
        (tester) async {
      await _pumpToSelection(tester);

      // Select Respiratory Distress & ROP
      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(tester, find.text('STW ROP'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

      expect(find.text('Available Clinical Workflows'), findsOneWidget);

      // Open Respiratory Distress screening
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));

      // Advance with no signs -> RD criteria not met -> completes immediately to summary
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

      // Reached Clinical Assessment Summary for Respiratory Distress
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);

      // Verify that ROP MCQs and button are NOT shown
      expect(find.text('ROP Knowledge Check & Follow-up Questions'), findsNothing);
      expect(find.text('Follow-up Assessment'), findsNothing);
      expect(
        find.textContaining('currently under preparation'),
        findsOneWidget,
      );

      // Completed screening has progress -> Back to Selection prompts confirmation
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Tap Stay -> stays on Clinical Assessment Summary
      await tapVisible(tester, find.text('Stay'));
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);

      // Tap Back to Selection again, then tap Leave & Reset
      await tapVisible(tester, find.text('Back to Selection'));
      await tapVisible(tester, find.text('Leave & Reset'));

      // Returns to Available Clinical Workflows
      expect(find.text('Available Clinical Workflows'), findsOneWidget);
    });

    testWidgets(
        'Normal Back and Continue within the same screening preserves answers without dialog',
        (tester) async {
      await _pumpToSelection(tester);

      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Tick Grunting
      await tapVisible(tester, find.text('Grunting'));

      // Advance to next step (Baby details)
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(find.text('Baby details'), findsOneWidget);

      // Tap Back in bottom bar -> no dialog, stays in flow, preserves Grunting
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Back'));
      expect(find.text(conditionExitAlertMessage), findsNothing);
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Grunting checkbox is still checked
      expect(
        find.byWidgetPredicate((w) => w is Checkbox && w.value == true),
        findsOneWidget,
      );

      // Continue to Baby details again
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(find.text('Baby details'), findsOneWidget);
    });

    testWidgets(
        'Mid-assessment: answering an MCQ and tapping Back to Selection or Home prompts confirmation, and Leave & Reset resets data',
        (tester) async {
      await _pumpToSelection(tester);

      // Open follow-up assessment module
      await openStandaloneModule(tester, '/follow-up-assessment');
      expect(find.text('Start ROP MCQs (8 Questions)'), findsOneWidget);

      // Start MCQs
      await tapVisible(tester, find.text('Start ROP MCQs (8 Questions)'));
      expect(find.text('MCQ 1 OF 8'), findsOneWidget);

      // Select an option mid-assessment
      await tapVisible(
          tester, find.textContaining('Percentage of eligible preterm'));

      // 1. Mid-assessment: Tap Back to Selection in bottom bar -> dialog appears
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Tap Stay -> remains on Question 1
      await tapVisible(tester, find.text('Stay'));
      expect(find.text('MCQ 1 OF 8'), findsOneWidget);

      // 2. Mid-assessment: Tap Home icon in header -> dialog appears
      await tapVisible(tester, find.byType(BackToHomeButton));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Tap Leave & Reset -> clears data and navigates to Home (condition selection)
      await tapVisible(tester, find.text('Leave & Reset'));
      expect(find.text('TRIGIN'), findsOneWidget);
    });

    testWidgets(
        'Leaving after completion: when follow-up assessment is complete, tapping Back to Selection prompts confirmation',
        (tester) async {
      await _pumpToSelection(tester);

      await openStandaloneModule(tester, '/follow-up-assessment');
      await tapVisible(tester, find.text('Start ROP MCQs (8 Questions)'));

      // Select answer on Q1
      await tapVisible(
          tester, find.textContaining('Percentage of eligible preterm'));

      // Jump to last question (MCQ 8) via pill button
      await tapVisible(tester, find.widgetWithText(InkWell, '8'));
      expect(find.text('MCQ 8 OF 8'), findsOneWidget);

      // Select answer on Q8 and submit
      await tapVisible(tester,
          find.textContaining('Observe, monitor weight gain, encourage KMC'));
      await tapVisible(tester, find.text('Submit Assessment'));

      // Reached MCQ Result Summary (completion)
      expect(find.text('Proceed to Case Scenarios (8 Cases)'), findsWidgets);

      // Tapping Back to Selection prompts confirmation
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Stay keeps results
      await tapVisible(tester, find.text('Stay'));
      expect(find.text('Proceed to Case Scenarios (8 Cases)'), findsWidgets);

      // Leave & Reset clears all data and navigates to Available Clinical Workflows
      await tapVisible(tester, find.text('Back to Selection'));
      await tapVisible(tester, find.text('Leave & Reset'));
      expect(find.text('Available Clinical Workflows'), findsOneWidget);
    });

    testWidgets(
        'ROP screening completion: result page stays without auto-redirect, Next opens MCQs, Back returns to result page',
        (tester) async {
      await _pumpToSelection(tester);

      // Select STW ROP
      await tapVisible(tester, find.text('STW ROP'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);

      expect(find.text('Available Clinical Workflows'), findsOneWidget);

      // Open ROP screening
      await tapVisible(tester, find.text('Retinopathy of Prematurity'));
      expect(find.text('Baby details'), findsOneWidget);

      // Select GA known and enter 37 weeks, BW 2500 g -> Not eligible
      await tapVisible(tester, find.text('GA known'));
      await tester.enterText(
          find.widgetWithText(TextField, 'Gestational age (completed weeks) *'),
          '37');
      await tester.enterText(
          find.widgetWithText(TextField, 'Birth weight'), '2500');
      await tester.pumpAndSettle();

      // Tap Continue to complete screening
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

      // 1. Result page appears and stays
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(
          find.text('Not eligible per STW screening criteria'), findsOneWidget);

      // 2. Wait 10 seconds: NO redirect happens
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.text('MCQ 1 OF 8'), findsNothing);

      // 3. Bottom bar has "Next: MCQs" button
      expect(find.text('Next: MCQs'), findsOneWidget);

      // 4. Tap Next: the MCQs open
      await tapVisible(tester, find.text('Next: MCQs'));
      expect(find.text('MCQ 1 OF 8'), findsOneWidget);

      // 5. From the MCQs, tap Back: you return to the result page and do not get pushed forward again
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Back'));
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(
          find.text('Not eligible per STW screening criteria'), findsOneWidget);

      // Wait 10 seconds: stays on result page
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.text('MCQ 1 OF 8'), findsNothing);

      // Verify rebuild does not trigger navigation
      tester.binding.scheduleFrame();
      await tester.pumpAndSettle();
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.text('MCQ 1 OF 8'), findsNothing);

      // Verify screen rotation (portrait to landscape) does not trigger navigation
      tester.view.physicalSize = const Size(915, 412);
      await tester.pumpAndSettle();
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.text('MCQ 1 OF 8'), findsNothing);

      // Rotate back to portrait
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.text('MCQ 1 OF 8'), findsNothing);

      // 6. Back to Selection still prompts confirmation dialog
      await tapVisible(tester, find.text('Back to Selection'));
      expect(find.text('Progress will be reset'), findsOneWidget);
      expect(find.text(conditionExitAlertMessage), findsOneWidget);

      // Tap Stay -> stays on result page
      await tapVisible(tester, find.text('Stay'));
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);

      // Tap Leave & Reset -> clears data and navigates to Available Clinical Workflows
      await tapVisible(tester, find.text('Back to Selection'));
      await tapVisible(tester, find.text('Leave & Reset'));
      expect(find.text('Available Clinical Workflows'), findsOneWidget);
    });
  });
}
