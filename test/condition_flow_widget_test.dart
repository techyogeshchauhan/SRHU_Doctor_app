import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/core/widgets/back_to_home_button.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/disease_selection/ui/disease_selection_screen.dart';

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
  await goToHome(tester);
}

void main() {
  testWidgets(
      'selection lists all 13 modules in standard order, with 9 selectable and 4 disabled',
      (tester) async {
    await _pumpToSelection(tester);

    // 1. Header shows 'Based on ICMR / DHR Standard Treatment Workflows' below logo
    expect(
      find.text('Based on ICMR / DHR Standard Treatment Workflows'),
      findsOneWidget,
    );

    // 2. Main Heading as specified
    expect(find.text('Triaging'), findsOneWidget);
    expect(
      find.text('Based on History and Clinical Examination.'),
      findsOneWidget,
    );
    expect(find.text('Select any condition.'), findsOneWidget);

    // 3. No bulky 'Selected' label or full text line
    expect(find.textContaining('Selected:'), findsNothing);
    // When nothing selected, count is hidden
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);

    // 4. Exactly 13 checkboxes: every STW module, but not Triage
    expect(find.byType(Checkbox), findsNWidgets(13));
    expect(find.text('STW Triage'), findsNothing);
    expect(find.byKey(const ValueKey('condition-index-triage')), findsNothing);
    final displayed = stwModuleDefinitions;
    for (final (index, disease) in displayed.indexed) {
      expect(
          tester
              .widget<Text>(
                  find.byKey(ValueKey('condition-index-${disease.id.name}')))
              .data,
          '${index + 1}.');
    }

    // 5. Existing active conditions remain available.
    final ropFinder = find.text('STW ROP');
    final rdFinder = find.text('STW Respiratory Distress');
    expect(ropFinder, findsOneWidget);
    expect(rdFinder, findsOneWidget);

    // 6. Uniform status badges: 9 available, 4 awaiting STW
    expect(find.text('Available'), findsNWidgets(9));
    expect(find.text('Awaiting STW'), findsNWidgets(4));

    // Verify all 13 module titles are present
    for (final d in stwModuleDefinitions) {
      expect(find.text(d.title), findsOneWidget);
    }

    // 7. Inactive condition (e.g. Seizures) cannot be selected
    await tester.tap(find.text('STW Seizures'), warnIfMissed: false);
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
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);

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
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('disease-card-index-1')))
            .data,
        '1.');
    expect(find.byKey(const ValueKey('disease-card-index-2')), findsNothing);

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
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);

    // Next page displays both conditions properly without Combined Assessment
    expect(find.text('Available Clinical Workflows'), findsOneWidget);
    expect(find.text('Retinopathy of Prematurity'), findsOneWidget);
    expect(find.text('Respiratory Distress in Neonates'), findsOneWidget);
    expect(find.text('Combined Assessment (RD + ROP)'), findsNothing);
    expect(find.text('Reference'), findsNWidgets(2));
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('disease-card-index-1')))
            .data,
        '1.');
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('disease-card-index-2')))
            .data,
        '2.');

    // The ROP card follows RD and keeps its own PDF reference.
    final ropCard =
        find.widgetWithText(DiseaseCard, 'Retinopathy of Prematurity');
    await tapVisible(
        tester, find.descendant(of: ropCard, matching: find.text('Reference')));
    expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);
    expect(find.byType(BackToHomeButton), findsOneWidget);
  });

  testWidgets(
      'Back to Home button navigates back to 14 conditions screen from Disease Selection',
      (tester) async {
    await _pumpToSelection(tester);

    // Select a condition and navigate to disease selection
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);
    expect(find.text('Available Clinical Workflows'), findsOneWidget);

    // Tap "Back to Home"
    expect(find.byType(BackToHomeButton), findsWidgets);
    await tapVisible(tester, find.byType(BackToHomeButton).first);

    // Back to main condition selection list with selection intact
    expect(find.text('Triaging'), findsOneWidget);
    expect(
      find.text('Based on History and Clinical Examination.'),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Selected:'), findsNothing);
  });

  testWidgets(
      'all available disease cards are consecutively numbered on narrow screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: AppTheme.light(), home: const DiseaseSelectionScreen())));
      await tester.pumpAndSettle();
      for (var number = 1; number <= availableDiseaseCount; number++) {
        expect(
            tester
                .widget<Text>(
                    find.byKey(ValueKey('disease-card-index-$number')))
                .data,
            '$number.');
      }
      // Triage runs before the modules, so it has no card here.
      expect(
          find.byKey(
              ValueKey('disease-card-index-${availableDiseaseCount + 1}')),
          findsNothing);
      expect(find.text('Neonatal Emergency Triage Assessment and Management'),
          findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Clicking a selectable disease card starts screening process, and Back to Selection returns to selected diseases',
      (tester) async {
    await _pumpToSelection(tester);

    // Select both RD and ROP, navigate to disease selection
    await tapVisible(tester, find.text('STW Respiratory Distress'));
    await tapVisible(tester, find.text('STW ROP'));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);

    // On Available Clinical Workflows page
    expect(find.text('Available Clinical Workflows'), findsOneWidget);

    // Click Respiratory Distress card to open disease details
    await tapVisible(tester, find.text('Respiratory Distress in Neonates'));

    // Screening process starts
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    expect(find.text('Back to Selection'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap "Back to Selection" returns directly to Available Clinical Workflows
    await tapVisible(tester, find.text('Back to Selection'));
    expect(find.text('Available Clinical Workflows'), findsOneWidget);
    expect(find.text('Retinopathy of Prematurity'), findsOneWidget);
    expect(find.text('Respiratory Distress in Neonates'), findsOneWidget);
  });

  testWidgets(
      'PDF Reference button on condition tile opens PDF viewer with Back to Home',
      (tester) async {
    await _pumpToSelection(tester);

    // Tap Reference button for ROP (first active condition at top; the
    // Triage card above the list has its own Reference button)
    final ropTile =
        find.ancestor(of: find.text('STW ROP'), matching: find.byType(InkWell));
    await tapVisible(tester,
        find.descendant(of: ropTile.first, matching: find.text('Reference')));

    // Opens PDF viewer screen
    expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);
    expect(find.byType(BackToHomeButton), findsOneWidget);

    // Back to Home button returns to condition selection
    await tapVisible(tester, find.byType(BackToHomeButton));
    expect(find.text('Triaging'), findsOneWidget);
    expect(
      find.text('Based on History and Clinical Examination.'),
      findsOneWidget,
    );
  });
}
