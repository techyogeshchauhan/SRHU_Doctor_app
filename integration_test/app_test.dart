/// On-device end-to-end tests: the real app on a phone (or emulator), driven
/// through its screens. Covers the landing page, condition selection, every
/// available STW from first page to summary, Triage scenarios and the hand-off
/// to the next STW, follow-up MCQs, the offline chat assistant, the PDF viewer
/// and the STW map.
///
/// Run (uses the local dev API so nothing reaches production):
///   flutter test integration_test/app_test.dart -d DEVICE_ID \
///       --dart-define-from-file=dev.env
///
/// Any Flutter error on the device (exception, layout overflow) fails the
/// test that caused it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/local/release_notes_store.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/assessment_summary.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/feeding/domain/feeding_workflow.dart';
import 'package:neonatal_stw/features/follow_up/domain/follow_up_models.dart'
    show FollowUpStage;
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_rules.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_rules.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_workflow.dart';
import 'package:neonatal_stw/features/kmc/domain/kmc_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';
import 'package:neonatal_stw/features/sepsis/domain/sepsis_workflow.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

// ---------------------------------------------------------------- helpers

/// pumpAndSettle that tolerates endless animations (spinners, the
/// screening clock).
Future<void> settle(WidgetTester t, [int seconds = 6]) async {
  try {
    await t.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, Duration(seconds: seconds));
  } catch (_) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

/// Scrolls [f] into view, then taps it like a user.
Future<void> tapOn(WidgetTester t, Finder f) async {
  expect(f, findsWidgets, reason: 'nothing to tap: $f');
  try {
    await t.ensureVisible(f.first);
  } catch (_) {}
  await settle(t);
  await t.tap(f.first);
  await settle(t);
}

/// Types [text] into the field of question [id].
Future<void> enter(WidgetTester t, String id, String text) async {
  final field = find.descendant(
      of: find.byKey(ValueKey(id)), matching: find.byType(TextField));
  await t.ensureVisible(field);
  await t.enterText(field, text);
  await settle(t);
}

var _storageReady = false;

/// Opens local storage as `main()` does, once per run. Real I/O must run
/// outside the test's fake clock, hence [WidgetTester.runAsync].
Future<void> ensureStorage(WidgetTester t) async {
  if (_storageReady) return;
  await t.runAsync(() async {
    await OfflineQueue.instance.initialize();
    await ReleaseNotesStore.instance.open();
  });
  _storageReady = true;
}

/// Launches the app as `main()` does and returns its provider container.
Future<ProviderContainer> launch(WidgetTester t) async {
  await ensureStorage(t);
  await t.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await settle(t);
  // "What's New" and similar dialogs open just after the first frame.
  await t.pump(const Duration(seconds: 2));
  await settle(t);
  for (final label in ['Got it', 'OK', 'Close']) {
    for (final type in [TextButton, FilledButton]) {
      final b = find.widgetWithText(type, label);
      if (b.evaluate().isNotEmpty) await tapOn(t, b);
    }
  }
  return ProviderScope.containerOf(t.element(find.byType(Navigator).first));
}

GoRouter router(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Navigator).first));

/// Answer for [q] that passes validation. [variant] 0 picks the first
/// option / "yes", 1 the last option / "no", reaching other branches.
Object? sampleAnswer(ClinicalQuestion q, int variant, DateTime today) {
  final opts = q.options;
  return switch (q.type) {
    QuestionType.singleChoice =>
      opts.isEmpty ? null : (variant == 0 ? opts.first : opts.last).value,
    QuestionType.multipleChoice => opts.isEmpty || variant == 1
        ? <Object>{}
        : {for (final o in opts.take(2)) o.value},
    QuestionType.numeric => (q.min ?? 0) +
        (((q.max ?? ((q.min ?? 0) + 100)) - (q.min ?? 0)) *
                (variant == 0 ? 0.15 : 0.6))
            .round(),
    QuestionType.decimal => (q.min ?? 0) +
        ((q.max ?? ((q.min ?? 0) + 100)) - (q.min ?? 0)) *
            (variant == 0 ? 0.15 : 0.6),
    QuestionType.text => 'Device test note',
    QuestionType.date => today.subtract(const Duration(days: 3)),
    QuestionType.boolean => variant == 0,
  };
}

/// Home -> select [c] -> Continue -> open it from the selected list.
Future<void> openStw(WidgetTester t, NeonatalCondition c) async {
  router(t).go('/home');
  await settle(t);
  await tapOn(t, find.text(definitionOf(c).title));
  await tapOn(t, find.widgetWithText(FilledButton, 'Continue'));
  await tapOn(t, find.byKey(const ValueKey('disease-card-index-1')));
  expect(find.text('Clinical Assessment'), findsWidgets);
}

/// Answers each page as a clinician would — [answers] first, then any
/// required question still empty — and confirms it with the on-screen
/// Continue button, until the summary is shown.
Future<void> walkPages(
  WidgetTester t,
  ProviderContainer c, {
  Map<String, Object?> answers = const {},
  int variant = 0,
}) async {
  final n = c.read(assessmentProvider.notifier);
  final engine = c.read(assessmentEngineProvider);
  final today = c.read(assessmentTodayProvider);
  for (var page = 0; page < 40; page++) {
    final group = c.read(assessmentProvider).currentGroup;
    if (group == null) return;
    for (var pass = 0; pass < 3; pass++) {
      final ctx = c.read(assessmentProvider).context;
      for (final rq in engine.pageQuestions(ctx, group)) {
        final v = rq.question.variable;
        if (answers.containsKey(v) && ctx.answers[v] != answers[v]) {
          n.answer(rq.id, answers[v]);
        }
      }
    }
    for (var k = 0; k < 25; k++) {
      final missing = engine.firstMissingRequired(
          c.read(assessmentProvider).context, group);
      if (missing == null) break;
      n.answer(missing.id, sampleAnswer(missing.question, variant, today));
    }
    await settle(t);
    await tapOn(t, find.widgetWithText(FilledButton, 'Continue'));
    expect(c.read(assessmentProvider).currentGroup, isNot(group),
        reason: 'Continue did not leave page "$group"');
  }
  fail('assessment did not finish within 40 pages');
}

/// Finding ids drawn as cards on the summary.
Set<String> drawnFindings(WidgetTester t) => {
      for (final w in t.widgetList<FindingCard>(
          find.byType(FindingCard, skipOffstage: false)))
        w.finding.id,
    };

/// The summary draws every finding the engine produced.
void expectSummaryShowsFindings(WidgetTester t, ProviderContainer c) {
  final s = c.read(assessmentProvider);
  expect(s.isComplete, isTrue);
  expect(find.text('Clinical Assessment Summary'), findsWidgets);
  final engineIds = {for (final f in s.context.findings) f.id};
  expect(engineIds, isNotEmpty, reason: 'no findings for a completed STW');
  expect(drawnFindings(t), containsAll(engineIds));
}

bool hasFinding(ProviderContainer c, String id) =>
    c.read(assessmentProvider).context.hasFinding(id);

/// Every STW module that can be screened (Triage is tested separately).
final modules = [
  for (final d in stwModuleDefinitions)
    if (d.implemented) d.id,
];

// ---------------------------------------------------------------- tests

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App shell', () {
    testWidgets('landing page lists the coverage and opens Triage', (t) async {
      final c = await launch(t);
      expect(find.text('STW Neo'), findsOneWidget);
      expect(find.textContaining('9 newborn-care STWs'), findsOneWidget);
      await tapOn(t, find.text('Continue'));
      expect(c.read(assessmentProvider).context.selected,
          {NeonatalCondition.triage});
      expect(find.text('Triage assessment'), findsOneWidget);
    });

    testWidgets('condition list: 9 available, 4 awaiting, correct counts',
        (t) async {
      await launch(t);
      router(t).go('/home');
      await settle(t);
      expect(find.byType(Checkbox), findsNWidgets(13));
      for (final d in stwModuleDefinitions) {
        expect(find.text(d.title), findsOneWidget, reason: d.title);
      }
      await tapOn(t, find.text('STW Sepsis'));
      expect(find.bySemanticsLabel('Continue with 1 condition selected'),
          findsOneWidget);
      await tapOn(t, find.text('STW Jaundice'));
      expect(find.bySemanticsLabel('Continue with 2 conditions selected'),
          findsOneWidget);
      // An STW still awaiting approval cannot be selected.
      await t.tap(find.text('STW Seizures'), warnIfMissed: false);
      await settle(t);
      expect(find.bySemanticsLabel('Continue with 2 conditions selected'),
          findsOneWidget);
    });
  });

  group('Triage', () {
    testWidgets('HR 210 -> EMERGENCY with treatment cards', (t) async {
      final c = await launch(t);
      await tapOn(t, find.text('Continue'));
      await enter(t, triageHeartRateKey, '210');
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
      await walkPages(t, c);
      expect(c.read(assessmentProvider).context.valueOf(triageCategoryKey),
          triageEmergency);
      expect(find.byKey(const ValueKey('triage-treatment-dashboard')),
          findsOneWidget);
    });

    testWidgets('RR 72 -> PRIORITY and RD suggested', (t) async {
      final c = await launch(t);
      await tapOn(t, find.text('Continue'));
      await enter(t, triageRespiratoryRateKey, '72');
      expect(find.byKey(const ValueKey('triage-category-priority')),
          findsOneWidget);
      await walkPages(t, c);
      expect(c.read(assessmentProvider).context.valueOf(triageCategoryKey),
          triagePriority);
      expect(find.byKey(const ValueKey('suggested-stw-respiratoryDistress')),
          findsOneWidget);
    });

    testWidgets('no signs -> neither Emergency nor Priority', (t) async {
      final c = await launch(t);
      await tapOn(t, find.text('Continue'));
      await walkPages(t, c, variant: 1);
      final category =
          c.read(assessmentProvider).context.valueOf(triageCategoryKey);
      expect(category, isNot(anyOf(triageEmergency, triagePriority)));
    });

    testWidgets('"Baby is sick" keeps measurements and the Emergency',
        (t) async {
      final c = await launch(t);
      await tapOn(t, find.text('Continue'));
      await enter(t, triageBloodGlucoseKey, '15');
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
      await tapOn(
          t, find.text('Baby is sick – proceed directly to examination'));
      final answers = c.read(assessmentProvider).context.answers;
      expect(answers[triageBloodGlucoseKey], 15);
      expect(find.byKey(const ValueKey(triageBloodGlucoseKey)), findsOneWidget);
      expect(find.byKey(const ValueKey(triageRhStatusKey)), findsNothing);
      expect(find.byKey(const ValueKey('triage-category-emergency')),
          findsOneWidget);
    });

    testWidgets(
        'Rh-negative + RR 72 -> Next STW pre-selects Jaundice and RD; '
        'RR carried, no blood-group pre-tick', (t) async {
      final c = await launch(t);
      await tapOn(t, find.text('Continue'));
      c.read(assessmentProvider.notifier).answer(triageRhStatusKey, 'negative');
      await enter(t, triageRespiratoryRateKey, '72');
      await walkPages(t, c, variant: 1);
      expect(
          find.byKey(const ValueKey('suggested-stw-jaundice')), findsOneWidget);
      expect(find.textContaining('Maternal Rh status: Negative'), findsWidgets);

      await tapOn(t, find.byKey(const ValueKey('next-step')));
      expect(find.text('Select the Next STW'), findsOneWidget);
      await tapOn(t, find.widgetWithText(FilledButton, 'Continue'));

      // 1. Respiratory Distress: RR 72 carried over.
      await tapOn(t, find.byKey(const ValueKey('disease-card-index-1')));
      expect(c.read(assessmentProvider).context.answers[rdRrKey], 72);
      await tapOn(t, find.text('Return to selected STWs'));
      final leave = find.text('Leave & Reset');
      if (leave.evaluate().isNotEmpty) await tapOn(t, leave);

      // 2. Jaundice: the Rh status must not assert incompatibility.
      await tapOn(t, find.byKey(const ValueKey('disease-card-index-2')));
      final risks = c.read(assessmentProvider).context.answers[jaundiceRiskKey];
      expect(risks is Set && risks.contains(JaundiceRisk.bloodGroup.name),
          isFalse);
    });
  });

  group('Every STW, first page to summary', () {
    for (final m in modules) {
      for (final variant in [0, 1]) {
        testWidgets('${m.name} (answers variant $variant)', (t) async {
          final c = await launch(t);
          await openStw(t, m);
          expect(c.read(assessmentProvider).context.selected, {m});
          await walkPages(t, c, variant: variant);
          expectSummaryShowsFindings(t, c);
        });
      }
    }
  });

  group('Clinical scenarios on the device', () {
    testWidgets('Sepsis: two yellow flags -> high probability, with WHY',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.sepsis);
      await walkPages(t, c, answers: {
        sepsisStageKey: 'initial',
        sepsisRedKey: <Object>{},
        sepsisYellowKey: <Object>{'lethargy', 'intolerance'},
      });
      expect(hasFinding(c, 'sepsis.high'), isTrue);
      expect(find.text('Yellow flag: Lethargy', skipOffstage: false),
          findsOneWidget);
      expect(find.text('Yellow flag: Feed intolerance', skipOffstage: false),
          findsOneWidget);
      expectSummaryShowsFindings(t, c);
    });

    testWidgets('Hypoglycemia: BG 20 -> IV bolus and GIR 6', (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.hypoglycemia);
      await walkPages(t, c, answers: {
        hypoRiskKey: <Object>{HypoRisk.preterm.name},
        hypoBgKey: 20,
        hypoRecheckNowKey: false,
      });
      expect(
          find.textContaining('IV bolus: 2 ml/kg of 10% of dextrose',
              skipOffstage: false),
          findsWidgets);
      expect(find.textContaining('BG 20 mg/dL', skipOffstage: false),
          findsWidgets);
      expectSummaryShowsFindings(t, c);
    });

    testWidgets('Respiratory Distress: grunting + RR 72 -> RD present',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.respiratoryDistress);
      await walkPages(t, c, answers: {
        rdRrKey: 72,
        rdSignsKey: <Object>{RdSign.grunting.name},
      });
      expect(hasFinding(c, 'rd.present'), isTrue);
      expectSummaryShowsFindings(t, c);
    });

    testWidgets('KMC: GA uncertain, 2500 g, preterm assessment -> eligible',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.kmc);
      await walkPages(t, c, answers: {
        gaKnownKey: false,
        birthWeightKey: 2500,
        kmcPretermAssessmentKey: true,
      });
      expect(hasFinding(c, 'kmc.eligibility.met'), isTrue);
      expectSummaryShowsFindings(t, c);
    });

    testWidgets('Feeding: a contraindication -> not stable for feeds',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.fluidsAndFeeds);
      await walkPages(t, c, answers: {
        feedingSignsKey: <Object>{qFeedingSigns.options.first.value},
      });
      expect(hasFinding(c, 'feeding.unstable'), isTrue);
      expectSummaryShowsFindings(t, c);
    });

    testWidgets('a greyed-out Continue names the missing required field',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.jaundice);
      expect(c.read(assessmentProvider).currentGroup, isNotNull);
      await t.tap(find.widgetWithText(FilledButton, 'Continue'),
          warnIfMissed: false);
      await settle(t);
      expect(
          find.text('Answer "Gestational age" to continue.'), findsOneWidget);
      expect(find.text('Required: answer this to continue'), findsOneWidget);
    });
  });

  group('Follow-up, chat, PDF and map', () {
    testWidgets('Hypoglycemia MCQs and case scenarios run to the report',
        (t) async {
      final c = await launch(t);
      await openStw(t, NeonatalCondition.hypoglycemia);
      await walkPages(t, c, answers: {
        hypoRiskKey: <Object>{HypoRisk.preterm.name},
        hypoBgKey: 50,
      });
      await tapOn(t, find.textContaining('Next: MCQs'));
      final f = c.read(followUpProvider.notifier);
      expect(find.textContaining('MCQ 1 OF'), findsOneWidget);
      final mcqs = c.read(followUpProvider).mcqs.length;
      for (var i = 0; i < mcqs; i++) {
        f.selectMcqOption(0);
        await settle(t);
        final last = i == mcqs - 1;
        await tapOn(
            t,
            find.widgetWithText(
                FilledButton, last ? 'Submit Assessment' : 'Next Question'));
        if (!last) {
          expect(find.text('MCQ ${i + 2} OF $mcqs'), findsOneWidget);
          // The new question starts at the top of the page.
          expect(t.getRect(find.text('Question ${i + 2}')).top, greaterThan(0));
        }
      }
      await tapOn(t, find.textContaining('Proceed to Case Scenarios'));
      final cases = c.read(followUpProvider).caseScenarios.length;
      for (var i = 0; i < cases; i++) {
        f.selectCaseOption(0);
        await settle(t);
        await tapOn(
            t,
            find.widgetWithText(FilledButton,
                i == cases - 1 ? 'Submit Case Scenarios' : 'Next Question'));
      }
      expect(c.read(followUpProvider).stage, FollowUpStage.finalSummary);
      expect(find.text('Copy Report', skipOffstage: false), findsOneWidget);
    });

    testWidgets('chat answers offline from the STW and opens the PDF',
        (t) async {
      await launch(t);
      router(t).go('/chat');
      await settle(t);
      expect(find.textContaining('Initial CPAP pressure in preterm'),
          findsOneWidget,
          reason: 'suggestions shown once');
      await t.enterText(
          find.byType(TextField).last, 'IV bolus dose for hypoglycemia');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await settle(t, 10);
      if (find.textContaining('IV bolus: 2 ml/kg').evaluate().isEmpty) {
        await tapOn(t, find.byIcon(Icons.send_rounded));
        await settle(t, 10);
      }
      expect(find.textContaining('IV bolus: 2 ml/kg'), findsWidgets);
      expect(find.text('STW Hypoglycemia · Page 1'), findsWidgets);
      await tapOn(t, find.text('View in PDF'));
      await settle(t, 10);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.byTooltip('Hide Highlight'), findsWidgets);
    });

    testWidgets('STW map opens; a Triage rule on the RD box is labelled Triage',
        (t) async {
      await launch(t);
      router(t).go('/stw-map');
      await settle(t, 10);
      expect(find.text('Graph view'), findsOneWidget);
      await tapOn(t, find.text('Search & list'));
      await t.enterText(find.byType(TextField).first, 'Respiratory distress');
      await settle(t);
      await tapOn(t, find.text('RESPIRATORY DISTRESS'));
      // The box details list is built lazily: scroll to its findings.
      final finding = find
          .text('Respiratory distress: follow the Respiratory Distress STW');
      await t.scrollUntilVisible(finding, 300,
          scrollable: find.byType(Scrollable).last);
      await tapOn(t, finding);
      expect(find.text('STW Triage'), findsWidgets);
    });
  });
}
