import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';

import 'test_helpers.dart';

Future<void> _openCaseEntry(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  await goToHome(tester);
  await tapVisible(tester, find.byKey(const ValueKey('open-case-history')));
  expect(find.text('Case history'), findsOneWidget);
}

Future<void> _analyse(WidgetTester tester, String text) async {
  // Structured input is the default; free text is the alternative.
  await tapVisible(tester, find.text('Type or dictate'));
  await tester.enterText(find.byKey(const ValueKey('case-text')), text);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const ValueKey('case-analyse')));
  expect(find.text('We understood'), findsOneWidget);
}

/// Confirms the remaining pages as the clinician would, answering only
/// the questions in [answers] that each page asks.
Future<void> _finish(WidgetTester tester, Map<String, Object?> answers) async {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(WorkflowScreen)));
  final n = container.read(assessmentProvider.notifier);
  final engine = container.read(assessmentEngineProvider);
  for (var i = 0; i < 20; i++) {
    final s = container.read(assessmentProvider);
    final group = s.currentGroup;
    if (group == null) break;
    for (final rq in engine.pageQuestions(s.context, group)) {
      if (answers.containsKey(rq.id) &&
          !s.context.answers.containsKey(rq.question.variable)) {
        n.answer(rq.id, answers[rq.id]);
      }
    }
    n.confirmPage();
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
      'case → review → pre-filled workflow → combined RD + Jaundice summary',
      (tester) async {
    await _openCaseEntry(tester);
    await _analyse(tester,
        'Baby, 36 wk, BW 2.4 kg, day 3. RR 70/min. Jaundice up to palms and soles.');

    // Every value is shown for confirmation, with the detected STWs.
    expect(find.text('Gestational age'), findsOneWidget);
    expect(find.text('Respiratory rate · STW Respiratory Distress'),
        findsOneWidget);
    expect(find.text('Kramer zone 5 (Palms and soles)'), findsOneWidget);
    expect(find.text('Not recognised: ignored'), findsNothing);
    for (final (key, selected) in [
      ('respiratoryDistress', true),
      ('jaundice', true),
      ('triage', false),
    ]) {
      expect(
          tester
              .widget<FilterChip>(find.byKey(ValueKey('case-topic-$key')))
              .selected,
          selected,
          reason: key);
    }

    await tapVisible(tester, find.byKey(const ValueKey('case-start')));

    // First page: shared baby details, pre-filled but not yet confirmed.
    expect(find.text('Baby details'), findsOneWidget);
    expect(
        find.text('Answered once and used by: STW Respiratory Distress · '
            'STW Jaundice'),
        findsOneWidget);
    expect(find.text('36'), findsWidgets);
    expect(find.text('2400'), findsWidgets);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    expect(find.text('70'), findsWidgets);

    await _finish(tester, {
      for (final i in SasItem.values) rdSasKey(i): 1,
      rdInitialSpo2Key: 90,
      rdReassessNowKey: false,
      jaundiceBefore24hKey: false,
      jaundiceCutoffResultKey: 'pending',
    });

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.byKey(const ValueKey('immediate-actions')), findsOneWidget);
    expect(find.text('Serious jaundice'), findsWidgets);
    expect(find.text('Start Intensive Phototherapy'), findsWidgets);
    expect(find.text('Respiratory distress criteria met'), findsWidgets);
    expect(find.text('STW Respiratory Distress'), findsWidgets);
    expect(find.text('STW Jaundice'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GA 33 wk with jaundice: not covered by the ≥35 wk STW',
      (tester) async {
    await _openCaseEntry(tester);
    await _analyse(tester, '33 wk, 1.9 kg, jaundice up to chest');
    await tapVisible(tester, find.byKey(const ValueKey('case-start')));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('Not covered by this STW (infants ≥35 weeks only)'),
        findsOneWidget);
    expect(find.text('Start Intensive Phototherapy'), findsNothing);
    // One STW: no cross-STW strip.
    expect(find.byKey(const ValueKey('immediate-actions')), findsNothing);
  });

  testWidgets('unrecognised text is listed and a topic can be removed',
      (tester) async {
    await _openCaseEntry(tester);
    await _analyse(tester, '38 wk, cord clamped late, grunting, jaundice face');
    expect(find.text('Not recognised: ignored'), findsOneWidget);
    expect(find.text('cord clamped late'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('case-topic-jaundice')));
    await tapVisible(tester, find.byKey(const ValueKey('case-start')));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorkflowScreen)));
    expect(
        container.read(assessmentProvider).context.selected.map((c) => c.name),
        ['respiratoryDistress']);
  });

  group('structured input (no narrative typed)', () {
    Future<void> enter(WidgetTester tester, String field, String value) async {
      final f = find.byKey(ValueKey('cf-$field'));
      await tester.ensureVisible(f);
      await tester.enterText(f, value);
      await tester.pumpAndSettle();
    }

    Future<void> fillExample(WidgetTester tester) async {
      expect(
          find.byKey(const ValueKey('cs-Basic information')), findsOneWidget);
      await tapVisible(tester, find.text('Known'));
      await enter(tester, 'gaWeeks', '36');
      await enter(tester, 'birthWeightKg', '2.4');
      await enter(tester, 'age', '3');
      await tapVisible(
          tester,
          find.descendant(
              of: find.byKey(const ValueKey('cf-ageUnit')),
              matching: find.text('days')));
      await tapVisible(
          tester, find.byKey(const ValueKey('cs-Respiratory assessment')));
      await enter(tester, 'rr', '70');
      await tapVisible(
          tester, find.byKey(const ValueKey('cs-Jaundice assessment')));
      await tapVisible(tester, find.text('Yes').first);
      await tapVisible(tester, find.byKey(const ValueKey('cf-kramer')));
      await tapVisible(
          tester, find.text('5 · Palms and soles (≈>15 to 20 mg/dL)').last);
    }

    testWidgets('select → summary → edit → Analyse Case → guided plan',
        (tester) async {
      await _openCaseEntry(tester);
      await fillExample(tester);
      await tapVisible(
          tester, find.byKey(const ValueKey('case-review-structured')));

      expect(find.byKey(const ValueKey('case-summary')), findsOneWidget);
      for (final (label, value) in [
        ('Gestational age: ', '36 weeks'),
        ('Birth weight: ', '2.4 kg'),
        ('Age: ', '3 days'),
        ('Respiratory rate: ', '70 breaths/min'),
        ('Jaundice: ', 'Present'),
        ('Extent: ', 'Zone 5: Palms and soles'),
      ]) {
        expect(find.textContaining('$label$value', findRichText: true),
            findsOneWidget,
            reason: label);
      }

      // Edit: an invalid birth weight is reported, not accepted.
      await tapVisible(
          tester, find.byKey(const ValueKey('case-edit-Basic information')));
      await enter(tester, 'birthWeightKg', '99');
      await tapVisible(
          tester, find.byKey(const ValueKey('case-review-structured')));
      expect(
          find.text('Check the birth weight: enter 0.3–6 kg.'), findsOneWidget);
      expect(find.byKey(const ValueKey('case-summary')), findsNothing);
      await enter(tester, 'birthWeightKg', '2.5');
      await tapVisible(
          tester, find.byKey(const ValueKey('case-review-structured')));
      expect(find.textContaining('Birth weight: 2.5 kg', findRichText: true),
          findsOneWidget);

      await tapVisible(
          tester, find.byKey(const ValueKey('case-analyse-structured')));
      expect(find.text('We understood'), findsOneWidget);
      for (final key in ['respiratoryDistress', 'jaundice']) {
        expect(
            tester
                .widget<FilterChip>(find.byKey(ValueKey('case-topic-$key')))
                .selected,
            isTrue,
            reason: key);
      }
      expect(find.byKey(const ValueKey('case-pdf-jaundice')), findsOneWidget);
      expect(find.text('Entered as 2.5 kg'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('case-start')));
      expect(find.text('Baby details'), findsOneWidget);
      expect(find.text('2500'), findsWidgets);
    });

    testWidgets('unknown jaundice is flagged; switching modes keeps entries',
        (tester) async {
      await _openCaseEntry(tester);
      await tapVisible(tester, find.text('Known'));
      await enter(tester, 'gaWeeks', '37');
      await tapVisible(
          tester, find.byKey(const ValueKey('cs-Jaundice assessment')));
      await tapVisible(tester, find.text('Unknown').first);

      await tapVisible(tester, find.text('Type or dictate'));
      expect(find.byKey(const ValueKey('case-text')), findsOneWidget);
      await tapVisible(tester, find.text('Select findings'));
      expect(find.text('37'), findsOneWidget);

      await tapVisible(
          tester, find.byKey(const ValueKey('case-review-structured')));
      await tapVisible(
          tester, find.byKey(const ValueKey('case-analyse-structured')));
      expect(find.byKey(const ValueKey('case-flags')), findsOneWidget);
      expect(find.textContaining('Jaundice not assessed'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Start guided plan'))
              .onPressed,
          isNull);
    });
  });

  testWidgets('structured form fits a 360 px phone with every section open',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    await goToHome(tester);
    await tapVisible(tester, find.byKey(const ValueKey('open-case-history')));
    await tapVisible(tester, find.text('Known'));
    for (final s in [
      'Temperature',
      'Respiratory assessment',
      'Jaundice assessment',
      'Other findings',
    ]) {
      await tapVisible(tester, find.byKey(ValueKey('cs-$s')));
    }
    await tapVisible(tester, find.text('Yes').first);
    await tapVisible(tester, find.text('Present (select below)'));
    expect(tester.takeException(), isNull);
  });
}
