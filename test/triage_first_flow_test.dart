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
    if (find.textContaining('Is the neonate symptomatic?').evaluate().isNotEmpty) {
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
      expect(tester.getRect(instruction).bottom,
          lessThan(tester.getRect(find.text('Clinical Assessment Summary')).top));
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
      }
      expect(find.byKey(const ValueKey('next-stw-triage')), findsNothing);

      // Nothing is launched automatically.
      expect(container.read(assessmentProvider).context.selected,
          {NeonatalCondition.triage});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting the next STW opens its existing workflow',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(
        tester, find.byKey(const ValueKey('next-stw-sepsis')));

    final s = container.read(assessmentProvider);
    expect(s.context.selected, {NeonatalCondition.sepsis});
    expect(s.currentGroup, isNotNull);
    expect(s.context.answers, isEmpty);
    expect(find.text('Select the Next STW'), findsNothing);
    expect(find.text('Sepsis STW PDF'), findsOneWidget);
  });

  testWidgets('Back from the Next STW page returns to the Triage results',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await _completeTriage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('next-step')));
    await tapVisible(tester, find.byTooltip('Back to results'));

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(container.read(assessmentProvider).context.selected,
        {NeonatalCondition.triage});
    expect(container.read(assessmentProvider).isComplete, isTrue);
  });

  testWidgets('Next Step is not shown before Triage results',
      (tester) async {
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
}
