import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

import 'test_helpers.dart';

Future<void> _continuePage(WidgetTester tester) =>
    tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

/// Landing -> Triage, then confirms every Triage page with blank
/// measurements, no signs and an asymptomatic neonate.
Future<ProviderContainer> _completeTriage(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Continue'));
  final container = ProviderScope.containerOf(
    tester.element(find.text('Clinical Assessment').first),
  );
  expect(container.read(assessmentProvider).context.selected,
      {NeonatalCondition.triage});

  for (var i = 0;
      i < 6 && container.read(assessmentProvider).currentGroup != null;
      i++) {
    if (find
        .textContaining('Is the neonate symptomatic?')
        .evaluate()
        .isNotEmpty) {
      await tapVisible(tester, find.text('No'));
    }
    await _continuePage(tester);
  }
  expect(container.read(assessmentProvider).isComplete, isTrue);
  return container;
}

void main() {
  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets(
        'Next Step after Triage results opens a page of the remaining STWs '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = await _completeTriage(tester);

      // Results are shown with a Next Step button; no list on the summary.
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-stw-sepsis')), findsNothing);

      // The instruction sits above the summary.
      final instruction = find.text(nextStepInstruction);
      expect(instruction, findsOneWidget);
      expect(
          tester.getRect(instruction).bottom,
          lessThan(
              tester.getRect(find.text('Clinical Assessment Summary')).top));
      await tapVisible(tester, find.byKey(const ValueKey('next-step')));

      expect(find.text('Select the Next STW'), findsOneWidget);
      final remaining = [
        for (final d in conditionDefinitions)
          if (d.implemented && d.id != NeonatalCondition.triage) d.id,
      ];
      expect(remaining, hasLength(6));
      for (final c in remaining) {
        expect(find.byKey(ValueKey('next-stw-${c.name}')), findsOneWidget,
            reason: c.name);
        expect(
            tester
                .widget<Checkbox>(
                    find.byKey(ValueKey('next-stw-checkbox-${c.name}')))
                .value,
            isFalse);
      }
      expect(find.byType(Checkbox), findsNWidgets(remaining.length));
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('continue-selected-stws')))
              .onPressed,
          isNull);
      expect(find.byKey(const ValueKey('next-stw-triage')), findsNothing);

      // Nothing is launched automatically.
      expect(container.read(assessmentProvider).context.selected,
          {NeonatalCondition.triage});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'Continue shows a single selected STW; only clicking it starts screening',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(
        tester, find.byKey(const ValueKey('next-stw-checkbox-sepsis')));

    expect(find.text('Select the Next STW'), findsOneWidget);
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.triage});
    await tapVisible(
        tester, find.byKey(const ValueKey('continue-selected-stws')));

    expect(find.text('Selected STW Diseases'), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-stw-sepsis')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-stw-kmc')), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.triage});
    expect(container.read(assessmentProvider).isComplete, isTrue);
    await tapVisible(tester, find.byKey(const ValueKey('selected-stw-sepsis')));

    final s = container.read(assessmentProvider);
    expect(s.context.selected, {NeonatalCondition.sepsis});
    expect(s.currentGroup, isNotNull);
    expect(s.context.answers, isEmpty);
    expect(find.text('Select the Next STW'), findsNothing);
    expect(find.text('Sepsis STW PDF'), findsOneWidget);
  });

  testWidgets('deselecting all modules disables Continue and keeps Triage',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    final checkbox = find.byKey(const ValueKey('next-stw-checkbox-sepsis'));
    await tapVisible(tester, checkbox);
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    await tapVisible(tester, checkbox);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    final continueButton = find.byKey(const ValueKey('continue-selected-stws'));
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    await tapVisible(tester, continueButton);
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.triage});
    expect(container.read(assessmentProvider).isComplete, isTrue);
    expect(find.text('Select the Next STW'), findsOneWidget);
  });

  testWidgets('Back from selected diseases preserves the checkbox selection',
      (tester) async {
    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(
        tester, find.byKey(const ValueKey('next-stw-checkbox-sepsis')));
    final triage = container.read(assessmentProvider);
    await tapVisible(
        tester, find.byKey(const ValueKey('continue-selected-stws')));
    await tapVisible(tester, find.byTooltip('Back to STW selection'));

    expect(find.text('Select the Next STW'), findsOneWidget);
    expect(
        tester
            .widget<Checkbox>(
                find.byKey(const ValueKey('next-stw-checkbox-sepsis')))
            .value,
        isTrue);
    expect(container.read(assessmentProvider), same(triage));
  });

  testWidgets(
      'unfinished screening returns to selected diseases without completion',
      (tester) async {
    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(tester, find.byKey(const ValueKey('next-stw-sepsis')));
    await tapVisible(tester, find.byKey(const ValueKey('next-stw-kmc')));
    await tapVisible(
        tester, find.byKey(const ValueKey('continue-selected-stws')));
    await tapVisible(tester, find.byKey(const ValueKey('selected-stw-sepsis')));
    await tapVisible(tester, find.text('Initial assessment'));
    await _continuePage(tester);
    final inProgress = container.read(assessmentProvider);
    expect(inProgress.isComplete, isFalse);

    await tapVisible(
        tester, find.byKey(const ValueKey('return-selected-stws')));
    expect(find.text('Progress will be reset'), findsOneWidget);
    await tapVisible(tester, find.text('Stay'));
    expect(container.read(assessmentProvider), same(inProgress));

    await tapVisible(
        tester, find.byKey(const ValueKey('return-selected-stws')));
    await tapVisible(tester, find.text('Leave & Reset'));
    expect(find.text('Selected STW Diseases'), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-stw-sepsis')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-stw-kmc')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-stw-sepsis')), findsNothing);
    expect(find.byKey(const ValueKey('selected-stw-rop')), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('selected-stw-kmc')));
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.kmc});
    expect(container.read(assessmentProvider).context.answers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets(
        'Selected STWs screen individually and return to the same list '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = await _completeTriage(tester);
      await tapVisible(tester, find.byKey(const ValueKey('next-step')));
      // Cards toggle selection too, without starting an assessment.
      await tapVisible(tester, find.byKey(const ValueKey('next-stw-sepsis')));
      await tapVisible(tester, find.byKey(const ValueKey('next-stw-kmc')));
      await tapVisible(tester, find.byKey(const ValueKey('next-stw-rop')));
      // A checked then unchecked module must not enter the assessment.
      await tapVisible(
          tester, find.byKey(const ValueKey('next-stw-checkbox-rop')));
      expect(container.read(assessmentProvider).context.selected,
          {NeonatalCondition.triage});
      await tapVisible(
          tester, find.byKey(const ValueKey('continue-selected-stws')));

      const selected = {NeonatalCondition.kmc, NeonatalCondition.sepsis};
      expect(find.text('Selected STW Diseases'), findsOneWidget);
      for (final condition in stwModuleDefinitions) {
        expect(find.byKey(ValueKey('selected-stw-${condition.id.name}')),
            selected.contains(condition.id) ? findsOneWidget : findsNothing);
      }
      expect(find.byType(Checkbox), findsNothing);
      expect(container.read(assessmentProvider).context.selected,
          {NeonatalCondition.triage});

      // Choose Sepsis first, then KMC. Neither starts automatically.
      final completedModules = <NeonatalCondition>{};
      for (final condition in [
        NeonatalCondition.sepsis,
        NeonatalCondition.kmc
      ]) {
        await tapVisible(
            tester, find.byKey(ValueKey('selected-stw-${condition.name}')));
        expect(
            container.read(assessmentProvider).context.selected, {condition});
        expect(container.read(assessmentProvider).context.answers, isEmpty);
        final engine = container.read(assessmentEngineProvider);
        for (var i = 0;
            i < 8 && !container.read(assessmentProvider).isComplete;
            i++) {
          final state = container.read(assessmentProvider);
          for (final question
              in engine.pageQuestions(state.context, state.currentGroup!)) {
            expect(question.topics, {condition});
          }
          if (state.currentGroup == 'baby') {
            await tapVisible(tester, find.text('GA uncertain'));
            await tester.enterText(find.byType(TextField), '2000');
            await tester.pumpAndSettle();
          } else if (state.currentGroup == 'sepsis_stage') {
            await tapVisible(tester, find.text('Initial assessment'));
          }
          await _continuePage(tester);
        }

        final completed = container.read(assessmentProvider);
        expect(completed.isComplete, isTrue);
        expect(completed.context.selected, {condition});
        expect(completed.context.findings.map((f) => f.topic).toSet(),
            {condition});
        expect(find.text('Clinical Assessment Summary'), findsOneWidget);
        await tapVisible(
            tester, find.byKey(const ValueKey('return-selected-stws')));
        completedModules.add(condition);
        expect(find.text('Selected STW Diseases'), findsOneWidget);
        for (final selectedCondition in selected) {
          expect(find.byKey(ValueKey('selected-stw-${selectedCondition.name}')),
              findsOneWidget);
          expect(
              find.byKey(ValueKey('completed-stw-${selectedCondition.name}')),
              completedModules.contains(selectedCondition)
                  ? findsOneWidget
                  : findsNothing);
        }
        expect(find.byKey(const ValueKey('selected-stw-rop')), findsNothing);
        // Returning to the list does not start the next screening.
        expect(container.read(assessmentProvider), same(completed));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back from the Next STW page returns to the Triage results',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(
        tester, find.byKey(const ValueKey('next-stw-checkbox-sepsis')));
    await tapVisible(tester, find.byTooltip('Back to results'));

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.triage});
    expect(container.read(assessmentProvider).isComplete, isTrue);
  });

  testWidgets('Next Step is not shown before Triage results', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Continue'));
    expect(find.byKey(const ValueKey('next-step')), findsNothing);
    expect(find.text(nextStepInstruction), findsNothing);
  });

  testWidgets('Back on the first Triage page returns to condition selection',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Continue'));
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Back'));

    // The existing leave confirmation is shown before leaving Triage.
    expect(find.text('Progress will be reset'), findsOneWidget);
    await tapVisible(tester, find.text('Leave & Reset'));

    expect(find.text('Select any condition.'), findsOneWidget);
  });

  testWidgets('Start Triage on the module list starts a new Triage',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    await goToHome(tester);

    // Triage is not a module in the list, but has its own entry point.
    expect(find.text('STW Triage'), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('start-triage')));

    final container = ProviderScope.containerOf(
      tester.element(find.text('Clinical Assessment').first),
    );
    final s = container.read(assessmentProvider);
    expect(s.context.selected, {NeonatalCondition.triage});
    expect(s.currentGroup, isNotNull);
    expect(s.context.answers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Restart Triage from another STW returns to a new Triage',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(tester, find.byKey(const ValueKey('next-stw-sepsis')));
    await tapVisible(
        tester, find.byKey(const ValueKey('continue-selected-stws')));
    await tapVisible(tester, find.byKey(const ValueKey('selected-stw-sepsis')));
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.sepsis});

    await tapVisible(tester, find.byTooltip('More options'));
    await tapVisible(tester, find.byKey(const ValueKey('menu-restart-triage')));
    if (find.text('Progress will be reset').evaluate().isNotEmpty) {
      await tapVisible(tester, find.text('Leave & Reset'));
    }

    final s = container.read(assessmentProvider);
    expect(s.context.selected, {NeonatalCondition.triage});
    expect(s.currentGroup, isNotNull);
    expect(s.context.answers, isEmpty);
    expect(find.byKey(const ValueKey('next-step')), findsNothing);
  });

  testWidgets('Restart Triage asks first and Stay keeps the Triage results',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byTooltip('More options'));
    await tapVisible(tester, find.byKey(const ValueKey('menu-restart-triage')));

    expect(find.text('Progress will be reset'), findsOneWidget);
    await tapVisible(tester, find.text('Stay'));

    expect(container.read(assessmentProvider).isComplete, isTrue);
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
  });
}
