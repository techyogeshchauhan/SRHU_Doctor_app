import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/disease_selection/ui/disease_selection_screen.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/assessment_map_screen.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

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

/// Confirms the Triage page, then the examination page (nothing ticked).
Future<void> _toResults(WidgetTester tester) async {
  await _continuePage(tester);
  expect(find.text('Examination: Look / Listen / Feel'), findsOneWidget);
  await _continuePage(tester);
}

/// Types [text] into the field of Triage question [id].
Future<void> _enter(WidgetTester tester, String id, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(id)),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Landing -> the single Triage page.
Future<ProviderContainer> _openTriage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Continue'));
  return ProviderScope.containerOf(
    tester.element(find.text('Clinical Assessment').first),
  );
}

void main() {
  group('Automated triage classification', () {
    testWidgets(
        'HR 210 classifies EMERGENCY without a prompt; one Continue opens '
        'the Emergency Treatment dashboard', (tester) async {
      final container = await _openTriage(tester);
      expect(container.read(assessmentProvider).currentGroup,
          triageAssessmentGroup);
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsNothing);

      await _enter(tester, triageHeartRateKey, '210');
      // Zero-click: the category is shown while typing.
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
      expect(
          container.read(assessmentProvider).context.valueOf(triageCategoryKey),
          triageEmergency);
      await _enter(tester, triageWeightKey, '2.5');
      await tapVisible(tester, find.text('Term (T)'));

      await _toResults(tester);
      // Baby details come from the Triage answers.
      expect(find.text('GA Term · Weight 2.5 kg'), findsOneWidget);
      expect(find.textContaining('GA — · BW —'), findsNothing);
      final s = container.read(assessmentProvider);
      expect(s.isComplete, isTrue);
      expect(find.textContaining('Select the triage category'), findsNothing);
      expect(find.text('Emergency Treatment'), findsOneWidget);
      expect(find.byKey(const ValueKey('triage-treatment-dashboard')),
          findsOneWidget);
      for (final id in ['temperature', 'airway', 'breathing', 'circulation']) {
        expect(find.byKey(ValueKey('triage-card-$id')), findsOneWidget,
            reason: id);
      }
      // HR >200/min: the Temperature card (hyperthermia); Circulation no
      // longer lists persistent HR.
      expect(find.byKey(const ValueKey('triage-card-temperature-flagged')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('triage-card-circulation-flagged')),
          findsNothing);
      expect(s.context.findings.map((f) => f.id),
          containsAll(['triage.classification', 'triage.emergencyActions']));
      expect(find.byKey(const ValueKey('next-step')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'RBS 35: no Hypoglycemia card on the dashboard; the treatment is in '
        'the summary', (tester) async {
      final container = await _openTriage(tester);
      await _enter(tester, triageBloodGlucoseKey, '35');
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
      // Shown inline on the same page, no extra screen.
      expect(
          find.textContaining('Is the neonate symptomatic?'), findsOneWidget);
      final no = find.descendant(
        of: find.byKey(const ValueKey(triageHypoglycemiaSymptomsKey)),
        matching: find.text('No'),
      );
      await tapVisible(tester, no);
      await _toResults(tester);

      expect(find.byKey(const ValueKey('triage-treatment-dashboard')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('triage-card-hypoglycemia')), findsNothing);
      expect(find.byKey(const ValueKey('triage-card-hypoglycemia-flagged')),
          findsNothing);
      expect(find.byKey(const ValueKey('triage-card-shock')), findsNothing);
      expect(
          container.read(assessmentProvider).context.findings.map((f) => f.id),
          contains('triage.hypoglycemia.feeding'));
    });

    testWidgets('the Shock sign flags Circulation and links the Shock box',
        (tester) async {
      await _openTriage(tester);
      // The removed checklists are not on the page.
      for (final removed in [
        'Perfusion / shock signs (tick all that apply)',
        'Priority signs (tick all that apply)',
        'Non-urgent signs (tick all that apply)',
        'Specific management findings (tick all that apply)',
      ]) {
        expect(find.textContaining(removed), findsNothing, reason: removed);
      }
      await tapVisible(tester, find.textContaining('Shock (cold peripheries'));
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
      await _toResults(tester);
      expect(find.byKey(const ValueKey('triage-card-shock')), findsNothing);
      expect(find.byKey(const ValueKey('triage-card-circulation-flagged')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('triage-link-circulation-triage_shock')),
          findsOneWidget);
    });

    testWidgets('fast-track skips only the history', (tester) async {
      final container = await _openTriage(tester);
      const history = [
        triageMaternalRisksKey,
        triageRhStatusKey,
        triageAntenatalSteroidsKey,
        triageMaternalHistoryKey,
        triageNewbornRisksKey,
        triageNewbornHistoryKey,
      ];
      for (final id in history) {
        expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
      }
      await tapVisible(tester, find.text('Foul-smelling liquor'));
      await _enter(tester, triageHeartRateKey, '210');

      final toggle =
          find.text('Baby is sick – proceed directly to examination');
      await tapVisible(tester, toggle);
      for (final id in history) {
        expect(find.byKey(ValueKey(id)), findsNothing, reason: id);
      }
      // Measurements and emergency signs stay; the HR still classifies.
      for (final id in const [
        triageWeightKey,
        triageHeartRateKey,
        triageRespiratoryRateKey,
        triageEmergencySignsKey,
      ]) {
        expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
      }
      final answers = container.read(assessmentProvider).context.answers;
      expect(answers[triageHeartRateKey], 210);
      expect(answers.containsKey(triageMaternalRisksKey), isFalse);
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);

      // The examination still follows.
      await _toResults(tester);
      expect(find.byKey(const ValueKey('triage-treatment-dashboard')),
          findsOneWidget);
    });

    testWidgets('fast-track switched off again restores every question',
        (tester) async {
      await _openTriage(tester);
      final toggle =
          find.text('Baby is sick – proceed directly to examination');
      await tapVisible(tester, toggle);
      await tapVisible(tester, toggle);
      for (final id in const [
        triageMaternalRisksKey,
        triageRhStatusKey,
        triageAntenatalSteroidsKey,
        triageMaternalHistoryKey,
        triageNewbornRisksKey,
        triageNewbornHistoryKey,
        triageWeightKey,
        triageGestationKey,
        triageTemperatureKey,
        triageHeartRateKey,
        triageRespiratoryRateKey,
        triageSpo2Key,
        triageBloodGlucoseKey,
        triageEmergencySignsKey,
      ]) {
        expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
      }
    });

    testWidgets(
        'results: summary at the top, no Topics assessed, compact map link',
        (tester) async {
      await _openTriage(tester);
      await _enter(tester, triageHeartRateKey, '210');
      await _toResults(tester);

      final summary = find.text('Clinical Assessment Summary');
      expect(summary, findsOneWidget);
      expect(
          tester.getRect(summary).bottom,
          lessThan(tester
              .getRect(find.byKey(const ValueKey('triage-treatment-dashboard')))
              .top));
      expect(find.text('Topics assessed'), findsNothing);
      expect(find.textContaining('Questions answered:'), findsNothing);
      // The map is a small link beside the heading, not a full-width button.
      final map = find.byKey(const ValueKey('open-assessment-map'));
      expect(map, findsOneWidget);
      expect(
          find.text('Assessment map: how your answers led here'), findsNothing);
      expect(tester.getRect(map).height, lessThan(44));
      expect(tester.getRect(map).center.dy,
          closeTo(tester.getRect(summary).center.dy, 12));
      expect(find.text('DOs'), findsNothing);
      expect(find.text("DON'Ts"), findsNothing);
      expect(find.text('Key performance indicators (KPIs)'), findsNothing);
      await tapVisible(tester, map);
      expect(find.byType(AssessmentMapScreen), findsOneWidget);
    });

    testWidgets('RR 70 classifies PRIORITY and points to the RD STW',
        (tester) async {
      final container = await _openTriage(tester);
      await _enter(tester, triageRespiratoryRateKey, '70');
      expect(find.byKey(const ValueKey('triage-category-priority')),
          findsOneWidget);
      await _toResults(tester);
      expect(container.read(assessmentProvider).isComplete, isTrue);
      expect(
          find.text(
              'Respiratory distress: follow the Respiratory Distress STW'),
          findsOneWidget);
      expect(find.text('Select Respiratory Distress as the next STW.'),
          findsOneWidget);
      // Priority shows the flagged cards; both link the RD STW.
      expect(find.byKey(const ValueKey('triage-card-breathing-flagged')),
          findsOneWidget);
      expect(
          find.byKey(
              const ValueKey('triage-link-respiratory-rd_immediate_actions')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'history and examination suggest STWs; the suggested STW opens '
        'pre-filled', (tester) async {
      final container = await _openTriage(tester);
      await tapVisible(tester, find.text('Gestational diabetes mellitus'));
      await _continuePage(tester);
      // Page 2: examination.
      expect(find.text('Examination: Look / Listen / Feel'), findsOneWidget);
      expect(find.byKey(const ValueKey(triageExamLookKey)), findsOneWidget);
      await tapVisible(tester, find.text('Capillary refill time (CRT) >3 s'));
      await _continuePage(tester);
      expect(container.read(assessmentProvider).isComplete, isTrue);

      final card = find.byKey(const ValueKey('suggested-stws'));
      expect(card, findsOneWidget);
      expect(
          find.descendant(
              of: card,
              matching: find.text('Capillary refill time (CRT) >3 s')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('suggested-stw-sepsis')), findsOneWidget);
      expect(find.byKey(const ValueKey('suggested-stw-hypoglycemia')),
          findsOneWidget);
      // At the top: right under the summary heading, before Baby details.
      final heading = tester.getRect(find.text('Clinical Assessment Summary'));
      expect(tester.getRect(card).top, greaterThan(heading.bottom));
      expect(tester.getRect(card).bottom,
          lessThan(tester.getRect(find.text('Baby details')).top));

      await tapVisible(
          tester, find.byKey(const ValueKey('open-suggested-stws')));
      expect(find.text('Select the Next STW'), findsOneWidget);
      // Suggested first and pre-ticked, with the reason.
      final first = tester.widget<DiseaseCard>(find.byType(DiseaseCard).first);
      expect(first.suggestion, startsWith('Suggested: '));
      for (final c in ['hypoglycemia', 'sepsis']) {
        expect(
            tester
                .widget<Checkbox>(find.byKey(ValueKey('next-stw-checkbox-$c')))
                .value,
            isTrue,
            reason: c);
      }
      expect(
          tester
              .widget<Checkbox>(
                  find.byKey(const ValueKey('next-stw-checkbox-rop')))
              .value,
          isFalse);

      await tapVisible(
          tester, find.byKey(const ValueKey('continue-selected-stws')));
      await tapVisible(
          tester, find.byKey(const ValueKey('selected-stw-hypoglycemia')));
      final hypo = container.read(assessmentProvider);
      expect(hypo.context.selected, {NeonatalCondition.hypoglycemia});
      // Pre-filled, not confirmed: the clinician still reviews every page.
      expect(hypo.context.answers[hypoRiskKey], {'idm'});
      expect(hypo.context.completedQuestions, isEmpty);
    });

    testWidgets('the timer is kept from data entry to the dashboard',
        (tester) async {
      final container = await _openTriage(tester);
      final repo = container.read(screeningSyncRepositoryProvider);
      final started = repo.activeTimings({'triage'}).single.startedAt;
      expect(
          find.byKey(const ValueKey('screening-elapsed-time')), findsOneWidget);

      await _enter(tester, triageHeartRateKey, '210');
      await _toResults(tester);

      expect(
          find.byKey(const ValueKey('screening-elapsed-time')), findsOneWidget);
      final timing = repo.activeTimings({'triage'}).single;
      expect(timing.startedAt, started);
      expect(timing.isCompleted, isTrue);
    });
  });

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

      // The summary is at the top; the instruction follows the results.
      final instruction = find.text(nextStepInstruction);
      expect(instruction, findsOneWidget);
      expect(tester.getRect(find.text('Clinical Assessment Summary')).bottom,
          lessThan(tester.getRect(instruction).top));
      await tapVisible(tester, find.byKey(const ValueKey('next-step')));

      expect(find.text('Select the Next STW'), findsOneWidget);
      final remaining = [
        for (final d in conditionDefinitions)
          if (d.implemented && d.id != NeonatalCondition.triage) d.id,
      ];
      expect(remaining, hasLength(9));
      expect(remaining, [
        NeonatalCondition.fluidsAndFeeds,
        NeonatalCondition.hypoglycemia,
        NeonatalCondition.respiratoryDistress,
        NeonatalCondition.hie,
        NeonatalCondition.sepsis,
        NeonatalCondition.jaundice,
        NeonatalCondition.kmc,
        NeonatalCondition.ancs,
        NeonatalCondition.rop,
      ]);
      expect(
          tester
              .widgetList<DiseaseCard>(find.byType(DiseaseCard))
              .map((card) => card.title),
          [
            'Feeding and Nutrition in Neonates',
            'Neonatal Hypoglycemia',
            'Respiratory Distress in Neonates',
            'Post Asphyxia',
            'Sepsis in Neonates',
            'Neonatal Jaundice',
            'Kangaroo Mother Care',
            'Antenatal Corticosteroids for Preterm Birth',
            'Retinopathy of Prematurity (ROP)',
          ]);
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
    await _enter(tester, triageWeightKey, '2.5');
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
