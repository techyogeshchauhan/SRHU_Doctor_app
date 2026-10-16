import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/domain/understanding/query_analyzer.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/sepsis/domain/sepsis_rules.dart';
import 'package:neonatal_stw/features/sepsis/domain/sepsis_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart';
import 'chatbot_eval/eval_harness.dart';
import 'test_helpers.dart';

Map<String, Object?> initial(
        {num? age = 24,
        num? ga = 34,
        int? bw = 2000,
        Set<Object> red = const {},
        Set<Object> yellow = const {},
        Set<Object> maternal = const {},
        bool maternalRed = false}) =>
    {
      sepsisStageKey: 'initial',
      sepsisAgeKey: age,
      sepsisGaKey: ga,
      sepsisBwKey: bw,
      sepsisRedKey: red,
      sepsisYellowKey: yellow,
      sepsisMaternalKey: maternal,
      sepsisMaternalRedKey: maternalRed,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Sepsis is available and resolves to the supplied source everywhere',
      () {
    expect(definitionOf(sepsis).implemented, isTrue);
    expect(workflowFor(sepsis), isA<StwWorkflow>());
    expect(stwPdfFor(sepsis)?.asset, sepsisPdfAsset);
    expect(stwPdfForDocument('Sepsis_STW_Final_15-10-26.pdf')?.asset,
        sepsisPdfAsset);
    final regions =
        jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List;
    final ids = {for (final r in regions) r['id']};
    for (final s in [
      sepsisWorkflow.source,
      ...sepsisWorkflow.rules.map((r) => r.source),
      ...sepsisWorkflow.uses.expand((u) => u.question.sources)
    ]) {
      if (s.isClinical) {
        expect(ids, contains(s.pdfRegionId), reason: s.citation);
      }
    }
    expect(topicOfDocument('Sepsis_STW_Final_15-10-26.pdf'), StwTopic.sepsis);
  });

  test(
      'all classification boundaries and unknowns follow only printed criteria',
      () {
    for (final red in [0, 1, 2]) {
      for (final yellow in [0, 1, 2, 3]) {
        for (final ga in <num?>[null, 31, 32, 32.01, 33]) {
          for (final bw in <num?>[null, 1499, 1500, 1501]) {
            final c = classifySepsis(
                redFlags: red,
                yellowFlags: yellow,
                gestationWeeks: ga,
                birthWeightG: bw);
            if (red > 0 || yellow >= 2) {
              expect(c, SepsisClassification.highProbability);
            } else if (yellow == 0) {
              expect(c, SepsisClassification.noListedCriterion);
            } else if (ga != null && ga > 32 && bw != null && bw < 1500) {
              expect(c, SepsisClassification.overlap);
            } else if ((ga != null && ga <= 32) || (bw != null && bw < 1500)) {
              expect(c, SepsisClassification.highProbability);
            } else if (ga != null && ga > 32 && bw != null) {
              expect(c, SepsisClassification.observe);
            } else {
              expect(c, SepsisClassification.incomplete);
            }
          }
        }
      }
    }
  });

  test('each red flag triggers treatment, culture and stable-baby LP guidance',
      () {
    for (final o in qSepsisRed.options) {
      final w = walk({sepsis}, initial(red: {o.value}));
      expect(engine.nextGroup(w.ctx), isNull);
      expect(w.ctx.hasFinding('sepsis.high'), isTrue, reason: o.label);
      final actions = w.ctx.findings
          .firstWhere((f) => f.id == 'sepsis.high')
          .actions
          .join(' ');
      expect(actions, contains('as per local/unit policy'));
      expect(actions,
          contains('even if baby has received an antibiotic before admission'));
      expect(actions, contains('when baby is hemodynamically stable'));
    }
  });

  test('maternal risks apply below 72 h and are dropped at 72 h', () {
    for (final age in <num>[0, 71.99, 72, 73]) {
      final w = walk({sepsis},
          initial(age: age, maternal: {'pv', 'rom'}, maternalRed: true));
      expect(w.ctx.hasFinding('sepsis.high'), age < 72);
      expect(w.ctx.answers.containsKey(sepsisMaternalKey), age < 72);
      expect(w.ctx.answers.containsKey(sepsisMaternalRedKey), age < 72);
    }
    final unknown = walk({sepsis},
        initial(age: null, maternal: {'pv', 'rom'}, maternalRed: true));
    expect(unknown.ctx.hasFinding('sepsis.high'), isFalse);
    expect(unknown.ctx.hasFinding('sepsis.ageMissing'), isTrue);
  });

  test(
      'two yellow signs, two maternal risks and a mixed pair each trigger high probability',
      () {
    for (final input in [
      initial(yellow: {'refusal', 'lethargy'}),
      initial(maternal: {'uti', 'diarrhea'}),
      initial(yellow: {'rr'}, maternal: {'fever'})
    ]) {
      expect(walk({sepsis}, input).ctx.hasFinding('sepsis.high'), isTrue);
    }
  });

  test(
      'one yellow flag uses 32-week and 1500-g boundaries, with explicit overlap review',
      () {
    for (final o in qSepsisYellow.options) {
      expect(
          walk({sepsis}, initial(ga: 32, yellow: {o.value}))
              .ctx
              .hasFinding('sepsis.high'),
          isTrue);
      expect(
          walk({sepsis}, initial(ga: 33, bw: 1500, yellow: {o.value}))
              .ctx
              .hasFinding('sepsis.observe'),
          isTrue);
      final overlap =
          walk({sepsis}, initial(ga: 33, bw: 1499, yellow: {o.value}));
      expect(overlap.ctx.hasFinding('sepsis.overlap'), isTrue);
      expect(overlap.ctx.hasFinding('sepsis.overlapObservation'), isTrue);
      expect(
          overlap.ctx.findings
              .firstWhere((f) => f.id == 'sepsis.overlapObservation')
              .source
              .pdfRegionId,
          'sepsis_observation');
      expect(overlap.ctx.hasFinding('sepsis.high'), isFalse);
      expect(overlap.ctx.hasFinding('sepsis.observe'), isFalse);
    }
    expect(
        walk({sepsis}, initial(ga: null, bw: 1499, yellow: {'refusal'}))
            .ctx
            .hasFinding('sepsis.high'),
        isTrue);
    for (final input in [
      initial(ga: null, bw: 1500, yellow: {'refusal'}),
      initial(ga: 33, bw: null, yellow: {'refusal'})
    ]) {
      expect(walk({sepsis}, input).ctx.hasFinding('sepsis.missing'), isTrue);
    }
  });

  test(
      'seizure footnote is urgent even when a single yellow flag does not meet high probability',
      () {
    final c = walk({sepsis}, initial(yellow: {'seizure'})).ctx;
    expect(c.hasFinding('sepsis.seizure'), isTrue);
    expect(c.hasFinding('sepsis.high'), isFalse);
    expect(
        c.findings.firstWhere((f) => f.id == 'sepsis.seizure').actions.join(),
        contains('low threshold'));
  });

  test(
      'complete sign qualifiers remain in questions, without invented neonatal fever cutoff',
      () {
    final labels = qSepsisYellow.options.map((o) => o.label).join(' ');
    expect(labels,
        contains('HR >180 persisting for one hour despite normal temperature'));
    expect(labels, contains('RR >60/min'));
    expect(labels, contains('<36.0°C not corrected by rewarming'));
    expect(labels, isNot(contains('Fever >38')));
    expect(qSepsisMaternal.options.last.label, 'Fever >38°C');
    expect(qSepsisRed.options.last.label, contains('score >5'));
  });

  test(
      'new flag during observation starts antibiotics after culture and indicates LP',
      () {
    for (final newFlag in [true, false]) {
      final c = walk({
        sepsis
      }, {
        ...initial(),
        sepsisStageKey: 'observation',
        sepsisNewFlagKey: newFlag,
        sepsisCulturePositiveKey: false
      }).ctx;
      expect(engine.nextGroup(c), isNull);
      expect(c.hasFinding('sepsis.newFlag'), newFlag);
      expect(c.hasFinding('sepsis.positiveCulture'), isFalse);
      expect(c.hasFinding('sepsis.ongoingObservation'), isTrue);
      if (newFlag) {
        expect(
            c.findings
                .firstWhere((f) => f.id == 'sepsis.newFlag')
                .actions
                .join(' '),
            contains('before starting antibiotics'));
      }
    }
    final c = walk({
      sepsis
    }, {
      ...initial(),
      sepsisStageKey: 'observation',
      sepsisNewFlagKey: false,
      sepsisCulturePositiveKey: true
    }).ctx;
    expect(c.hasFinding('sepsis.positiveCulture'), isTrue);
    expect(c.hasFinding('sepsis.newFlag'), isFalse);
  });

  for (final state in ['disappeared', 'improving', 'worsened']) {
    test('48-hour review: $state resolves only its source branch', () {
      final w =
          walk({sepsis}, {sepsisStageKey: 'review48', sepsisReviewKey: state});
      expect(engine.nextGroup(w.ctx), isNull);
      expect(w.ctx.hasFinding('sepsis.review.$state'), isTrue);
      expect(w.ctx.findings.where((f) => f.id.startsWith('sepsis.review.')),
          hasLength(1));
      expect(w.ctx.answers.containsKey(sepsisRedKey), isFalse);
      expect(w.ctx.hasFinding('sepsis.earlyStop'), isTrue);
      if (state == 'disappeared') {
        expect(
            w.ctx.findings
                .firstWhere((f) => f.id == 'sepsis.review.$state')
                .actions
                .join(),
            contains('sterile after 48 hrs'));
      }
    });
  }

  test(
      'day 5 stop requires all three explicit confirmations; unknown is not normal',
      () {
    for (final well in [true, false, 'unknown']) {
      for (final culture in [true, false, 'unknown']) {
        for (final csf in [true, false, 'unknown']) {
          final w = walk({
            sepsis
          }, {
            sepsisStageKey: 'review5',
            sepsisWellKey: well,
            sepsisSterileKey: culture,
            sepsisCsfNormalKey: csf
          });
          expect(engine.nextGroup(w.ctx), isNull);
          expect(w.ctx.hasFinding('sepsis.day5Stop'),
              well == true && culture == true && csf == true);
        }
      }
    }
  });

  test('all five duration rows preserve the full conditions and durations', () {
    final expected = [
      '5–7 DAYS',
      '5–7 DAYS',
      '7–10 DAYS',
      '10–14 DAYS',
      '21 DAYS'
    ];
    for (final c in SepsisDurationCondition.values) {
      final w = walk(
          {sepsis}, {sepsisStageKey: 'duration', sepsisDurationKey: c.name});
      expect(engine.nextGroup(w.ctx), isNull);
      final rows =
          w.ctx.findings.where((f) => f.id.startsWith('sepsis.duration.'));
      expect(rows, hasLength(1));
      expect(rows.single.actions.single, endsWith(expected[c.index]));
    }
    final unknown = walk({sepsis},
        {sepsisStageKey: 'duration', sepsisDurationKey: 'unconfirmed'}).ctx;
    expect(unknown.hasFinding('sepsis.durationUnknown'), isTrue);
    expect(unknown.findings.where((f) => f.id.startsWith('sepsis.duration.')),
        isEmpty);
  });

  test('changing stage drops obsolete answers and findings', () {
    final old = walk({sepsis}, initial(red: {'shock'})).ctx;
    final c = evalCtx({
      sepsis
    }, {
      ...old.answers,
      sepsisStageKey: 'review5',
      sepsisWellKey: true,
      sepsisSterileKey: true,
      sepsisCsfNormalKey: true
    });
    expect(c.hasFinding('sepsis.high'), isFalse);
    expect(c.answers.containsKey(sepsisRedKey), isFalse);
    expect(c.hasFinding('sepsis.day5Stop'), isTrue);
    expect(evalCtx({}, c.answers).findings, isEmpty);
  });

  group('Sepsis chatbot source fidelity', () {
    late StwAnswerer answerer;
    setUpAll(() {
      answerer = StwAnswerer(Bm25Retriever(
          initialChunks: loadRegions(), initialSynonyms: loadSynonyms()));
    });
    for (final (q, id) in [
      ('What are the red flags for neonatal sepsis?', 'red_flags'),
      ('What are the yellow flags for neonatal sepsis?', 'yellow_signs'),
      ('What are maternal risks for neonatal sepsis?', 'maternal_risks'),
      ('Antibiotics for neonatal sepsis', 'high_probability'),
      ('When should a baby with sepsis be observed?', 'observation'),
      (
        'What if signs of sepsis disappeared at 48 hours?',
        'review_disappeared'
      ),
      ('What if sepsis is improving but still present?', 'review_improving'),
      ('Sepsis worsened after antibiotics', 'review_worsened'),
      ('Sepsis review at 5 days', 'review_day5'),
      ('What is the antibiotic duration for neonatal sepsis?', 'duration'),
      ('Sepsis CSF suggestive of meningitis duration', 'duration'),
      ('What are the sepsis KPIs?', 'kpis'),
      ('What should not be done in sepsis?', 'donts'),
      ('How to prevent neonatal sepsis?', 'prevention'),
      ('Sepsis seizure evaluation', 'seizure'),
      ('When should the first antibiotic dose be given for sepsis?', 'dos'),
      ('Sepsis another yellow sign during observation', 'observation'),
    ]) {
      test(q, () async {
        final a = await answerer.answer(q);
        expect(a.kind, AnswerKind.answer, reason: a.prompt);
        expect(a.region?.chunkId, 'sepsis_$id');
        expect(a.region?.document, 'Sepsis_STW_Final_15-10-26.pdf');
        expect(
            a.lines.map((s) => s.text).toList(),
            a.region!.segments
                .where((s) => !s.header)
                .map((s) => s.text)
                .toList());
        expect(a.lines.every((s) => s.boundingBoxes.isNotEmpty), isTrue);
      });
    }
    test('unsupported doses and procedures never borrow from other STWs',
        () async {
      for (final q in [
        'Ampicillin dose for neonatal sepsis',
        'Gentamicin dose for neonatal sepsis',
        'How to perform lumbar puncture for sepsis?'
      ]) {
        expect((await answerer.answer(q)).kind, AnswerKind.notCovered,
            reason: q);
      }
    });
    test(
        'one-yellow patient case asks for missing values; overlapping case needs clinical review',
        () async {
      final missing = await answerer.answer('Sepsis one yellow flag, 33 weeks');
      expect(missing.kind, AnswerKind.clarify);
      final overlap = await answerer
          .answer('Sepsis one yellow flag, 33 weeks, birth weight 1400 g');
      expect(overlap.kind, AnswerKind.clarify);
      expect(overlap.prompt, contains('both PDF boxes'));
      final high = await answerer.answer('Sepsis two yellow flags');
      expect(high.region?.chunkId, 'sepsis_high_probability');
      for (final ga in ['32+6 weeks', '32.5 weeks', '32 weeks +6 days']) {
        final c = await answerer
            .answer('Sepsis one yellow flag, $ga, birth weight 1.4 kg');
        expect(c.kind, AnswerKind.clarify, reason: ga);
        expect(c.prompt, contains('both PDF boxes'));
      }
      final decimalWeight = await answerer
          .answer('Sepsis one yellow flag, 33 weeks, birth weight 1.5 kg');
      expect(decimalWeight.region?.chunkId, 'sepsis_observation');
    });
  });

  testWidgets(
      'mobile: select Sepsis, assess shock and reach the source-linked summary',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tapVisible(tester, find.text('Continue'));
    }
    await tapVisible(tester, find.text('STW Sepsis'));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);
    await tapVisible(tester, find.text('Sepsis in Neonates'));
    await tapVisible(tester, find.text('Initial assessment'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tapVisible(tester, find.text('Shock'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('HIGH PROBABILITY OF SEPSIS'), findsOneWidget);
    expect(
        find.textContaining(
            'Start empirical antibiotics as per local/unit policy'),
        findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
