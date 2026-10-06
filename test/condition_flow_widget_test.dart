import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/widgets/back_to_home_button.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

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
  testWidgets(
      'selection lists all 14 conditions uniformly with ROP and RD at top, live counter, 2 selectable and 12 disabled',
      (tester) async {
    await _pumpToSelection(tester);

    // 1. Header shows 'Based on ICMR / DHR Standard Treatment Workflows' below logo
    expect(
      find.text('Based on ICMR / DHR Standard Treatment Workflows'),
      findsOneWidget,
    );

    // 2. Main Heading as specified
    expect(
      find.text('Triage: Based on history and clinical examination'),
      findsOneWidget,
    );
    expect(find.text('Select any condition.'), findsOneWidget);

    // 3. No bulky 'Selected' label or full text line
    expect(find.textContaining('Selected:'), findsNothing);
    // When nothing selected, count is hidden
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);

    // 4. Exactly 14 checkboxes for all 14 conditions in a single view
    expect(find.byType(Checkbox), findsNWidgets(14));

    // 5. Active conditions are at the top
    final ropFinder = find.text('STW ROP');
    final rdFinder = find.text('STW Respiratory Distress');
    expect(ropFinder, findsOneWidget);
    expect(rdFinder, findsOneWidget);

    // 6. Uniform status badges: 2 available, 12 awaiting STW
    expect(find.text('Available'), findsNWidgets(2));
    expect(find.text('Awaiting STW'), findsNWidgets(12));

    // Verify all 14 condition titles are present
    for (final d in conditionDefinitions) {
      expect(find.text(d.title), findsOneWidget);
    }

    // 7. Inactive condition (e.g. Sepsis) cannot be selected
    await tester.tap(find.text('STW Sepsis'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected:'), findsNothing);
    expect(find.text('1'), findsNothing);

    // 8. Active condition (Respiratory Distress) toggles selection -> count 1 appears in badge
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    expect(find.textContaining('Selected:'), findsNothing);
    expect(find.text('1'), findsOneWidget);

    // 9. Active condition (ROP) toggles selection -> count 2 appears in badge
    await tapVisible(tester, find.text('STW ROP'));
    expect(find.textContaining('Selected:'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    // 10. Toggling ROP again deselects it -> count 1
    await tapVisible(tester, find.text('STW ROP'));
    expect(find.textContaining('Selected:'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      'Condition Selection -> Next Page displays only the selected condition (e.g. RD only) with single-line card and Reference button',
      (tester) async {
    await _pumpToSelection(tester);

    // Select only Respiratory Distress
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    expect(find.text('1'), findsOneWidget);

    // Tap Continue to proceed to next page
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

    // Next page header keeps ONLY the ICMR logo (no 'Based on ICMR / DHR...' text)
    expect(
      find.textContaining('Based on ICMR / DHR Standard Treatment Workflow'),
      findsNothing,
    );

    // Next page displays ONLY Respiratory Distress
    expect(find.text('Available Clinical Workflows'), findsOneWidget);
    expect(find.text('Respiratory Distress in Neonates'), findsOneWidget);
    expect(find.text('Retinopathy of Prematurity'), findsNothing);
    expect(find.text('Combined Assessment (RD + ROP)'), findsNothing);
    expect(find.text('Reference'), findsOneWidget);

    // Tapping Reference button directly opens Respiratory Distress PDF
    await tapVisible(tester, find.text('Reference'));
    expect(find.text('Respiratory Distress in Neonates'), findsWidgets);
    expect(find.byType(BackToHomeButton), findsOneWidget);
  });

  testWidgets(
      'Condition Selection with both conditions displays both, each with its own Reference button',
      (tester) async {
    await _pumpToSelection(tester);

    // Select both Respiratory Distress and ROP
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    await tapVisible(tester, find.text('STW ROP'));
    expect(find.text('2'), findsOneWidget);

    // Tap Continue to proceed to next page
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

    // Next page displays both conditions properly without Combined Assessment
    expect(find.text('Available Clinical Workflows'), findsOneWidget);
    expect(find.text('Retinopathy of Prematurity'), findsOneWidget);
    expect(find.text('Respiratory Distress in Neonates'), findsOneWidget);
    expect(find.text('Combined Assessment (RD + ROP)'), findsNothing);
    expect(find.text('Reference'), findsNWidgets(2));

    // Tap ROP Reference button (first Reference button) opens ROP PDF
    await tapVisible(tester, find.text('Reference').first);
    expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);
    expect(find.byType(BackToHomeButton), findsOneWidget);
  });

  testWidgets(
      'Back to Home button navigates back to 14 conditions screen from Disease Selection',
      (tester) async {
    await _pumpToSelection(tester);

    // Select a condition and navigate to disease selection
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);
    expect(find.text('Available Clinical Workflows'), findsOneWidget);

    // Tap "Back to Home"
    expect(find.byType(BackToHomeButton), findsWidgets);
    await tapVisible(tester, find.byType(BackToHomeButton).first);

    // Back to main condition selection list with selection intact
    expect(
      find.text('Triage: Based on history and clinical examination'),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Selected:'), findsNothing);
  });

  testWidgets(
      'Clicking a selectable disease card starts screening process with Back to Home button',
      (tester) async {
    await _pumpToSelection(tester);

    // Select RD and navigate to disease selection
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);

    // Click Respiratory Distress card
    await tapVisible(tester, find.text('Respiratory Distress in Neonates'));

    // Screening process starts per existing workflow
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    expect(find.byType(BackToHomeButton), findsOneWidget);

    // Tap Back to Home returns to main condition selection
    await tapVisible(tester, find.byType(BackToHomeButton));
    expect(
      find.text('Triage: Based on history and clinical examination'),
      findsOneWidget,
    );
  });

  testWidgets(
      'PDF Reference button on condition tile opens PDF viewer with Back to Home',
      (tester) async {
    await _pumpToSelection(tester);

    // Tap Reference button for ROP (first active condition at top)
    await tapVisible(tester, find.text('Reference').first);

    // Opens PDF viewer screen
    expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);
    expect(find.byType(BackToHomeButton), findsOneWidget);

    // Back to Home button returns to condition selection
    await tapVisible(tester, find.byType(BackToHomeButton));
    expect(
      find.text('Triage: Based on history and clinical examination'),
      findsOneWidget,
    );
  });
}
