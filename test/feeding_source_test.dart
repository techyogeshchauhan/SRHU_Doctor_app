import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';
import 'package:neonatal_stw/features/chatbot/domain/understanding/query_analyzer.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/feeding/domain/feeding_content.dart';
import 'package:neonatal_stw/features/feeding/domain/feeding_rules.dart';
import 'package:neonatal_stw/features/feeding/domain/feeding_workflow.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_map.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_region.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart';

const feeding = NeonatalCondition.fluidsAndFeeds;
Map<String, Object?> input(
        {int? ga = 34,
        int bw = 1500,
        bool? aedf = false,
        Set<Object> signs = const {},
        num? pma = 34,
        bool full = true,
        bool support = false}) =>
    {
      gaKnownKey: ga != null,
      gaWeeksKey: ga,
      birthWeightKey: bw,
      feedingSignsKey: signs,
      feedingDayKey: 1,
      feedingAedfKey: aedf,
      feedingPmaKey: pma,
      feedingToleranceKey: false,
      feedingFullKey: full,
      feedingSupportKey: support,
      feedingPoorGainKey: false,
      feedingVolumeKey: 240,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a stable baby can confirm an empty contraindication checklist', () {
    final ctx = evalCtx({feeding}, {});
    expect(engine.nextGroup(ctx), 'feeding_stability');
    expect(engine.canConfirm(ctx, 'feeding_stability'), isTrue);
    final confirmed = engine.confirmPage(ctx, 'feeding_stability');
    final next =
        evalCtx({feeding}, confirmed.answers, completed: confirmed.completed);
    expect(next.valueOf(feedingStableKey), isTrue);
    expect(engine.nextGroup(next), 'baby');
  });
  test('only the existing position 3 slot is activated; all citations resolve',
      () async {
    expect(conditionDefinitions, hasLength(14));
    expect(conditionDefinitions[2].id, feeding);
    expect(conditionDefinitions[2].title, 'STW Fluids & Feeds');
    expect(definitionOf(feeding).implemented, isTrue);
    expect(stwPdfFor(feeding)?.asset, feedingPdfAsset);
    expect(stwPdfForDocument('Feeding_Nutrition Final 22 Oct 26.pdf')?.asset,
        feedingPdfAsset);
    expect(topicOfDocument('Feeding_Nutrition Final 22 Oct 26.pdf'),
        StwTopic.feeding);
    final sourceCards =
        jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List;
    for (final card in sourceCards
        .where((r) => (r['id'] as String).startsWith('feeding_'))) {
      expect(feedingEvidence[card['id']],
          (card['segments'] as List).map((s) => s['text']));
      expect(feedingHeadings[card['id']], card['title']);
    }
    for (final s in [
      feedingWorkflow.source,
      ...feedingWorkflow.rules.map((r) => r.source),
      ...feedingWorkflow.uses.expand((u) => u.question.sources)
    ]) {
      expect(s.document, feedingStwDocument);
      expect(s.version, 'October 2026');
      final target = await stwRegionTarget(s.pdfRegionId!);
      expect(target, isNotNull, reason: s.citation);
      expect(target!.document, 'Feeding_Nutrition Final 22 Oct 26.pdf');
    }
  });

  test('all enteral start boundaries, explicit BW override and missing inputs',
      () {
    for (final ga in <num?>[null, 27.99, 28, 32, 34, 34 + 6 / 7, 35, 40]) {
      for (final bw in <num?>[null, 999, 1000, 1499, 2500]) {
        for (final aedf in <bool?>[null, false, true]) {
          final expected = (bw != null && bw < 1000) || (ga != null && ga < 28)
              ? FeedingStart.verySmall
              : ga == null || bw == null
                  ? null
                  : ga >= 35
                      ? FeedingStart.standard
                      : aedf == null
                          ? null
                          : aedf
                              ? FeedingStart.aedf
                              : FeedingStart.standard;
          expect(feedingStart(birthGaWeeks: ga, birthWeightG: bw, aedf: aedf),
              expected,
              reason: '$ga / $bw / $aedf');
        }
      }
    }
  });

  test(
      'D1–D7 values are exact; no admission-day substitution or D8 extrapolation',
      () {
    for (var d = 1; d <= 7; d++) {
      expect(
          feedingFluidGuide(dayOfLife: d, birthGaWeeks: 28, birthWeightG: 1000),
          ['60', '80', '100', '120', '140', '150', '150–160'][d - 1]);
      for (final (ga, bw) in [(27, 1000), (35, 999)]) {
        expect(
            feedingFluidGuide(dayOfLife: d, birthGaWeeks: ga, birthWeightG: bw),
            ['80', '90', '100', '120', '140', '150', '150–160'][d - 1]);
      }
    }
    for (final day in <int?>[null, 0, 8, 28]) {
      expect(
          feedingFluidGuide(
              dayOfLife: day, birthGaWeeks: 28, birthWeightG: 1000),
          isNull);
    }
    expect(feedingFluidGuide(dayOfLife: 1, birthWeightG: 1000), isNull);
    expect(feedingFluidGuide(dayOfLife: 1, birthWeightG: 999), '80');
  });

  test('each contraindication suppresses enteral plans and drops stale inputs',
      () {
    for (final option in qFeedingSigns.options) {
      final w = walk({feeding}, input(signs: {option.value}));
      expect(engine.nextGroup(w.ctx), isNull);
      expect(w.ctx.hasFinding('feeding.unstable'), isTrue);
      expect(w.ctx.valueOf(feedingStartKey), isNull);
      expect(w.ctx.valueOf(feedingThreeHourlyKey), isFalse);
      for (final id in [
        'standard',
        'aedf',
        'small',
        'milk',
        'route',
        'volume',
        'iron',
        'vitamin_d'
      ]) {
        expect(w.ctx.hasFinding('feeding.$id'), isFalse, reason: option.label);
      }
      expect(w.ctx.answers.containsKey(feedingVolumeKey), isFalse);
      expect(w.ctx.answers.containsKey(feedingAedfKey), isFalse);
      expect(
          w.ctx.findings.firstWhere((f) => f.id == 'feeding.unstable').actions,
          feedingEvidence['feeding_unstable']);
    }
  });

  test('stable assessment chooses only the matching printed starting column',
      () {
    for (final (ga, bw, aedf, id) in [
      (34, 1000, false, 'standard'),
      (35, 1000, true, 'standard'),
      (34, 1000, true, 'aedf'),
      (27, 1000, false, 'small'),
      (35, 999, true, 'small')
    ]) {
      final w = walk({feeding}, input(ga: ga, bw: bw, aedf: aedf));
      expect(engine.nextGroup(w.ctx), isNull);
      for (final column in ['standard', 'aedf', 'small']) {
        expect(w.ctx.hasFinding('feeding.$column'), column == id);
      }
      final plan = w.ctx.findings
          .firstWhere((f) => f.id == 'feeding.$id')
          .actions
          .join(' ');
      expect(plan, contains('Start volume:'));
      expect(plan, contains('Advance daily as tolerated:'));
      expect(
          plan,
          contains(
              'Start once clinically stable, with reassuring abdominal assessment'));
      expect(plan, contains('If BW <1000 g'));
    }
    expect(
        walk({feeding}, input(ga: null, bw: 1500))
            .ctx
            .hasFinding('feeding.planUnknown'),
        isTrue);
    expect(
        walk({feeding}, input(ga: 34, aedf: null))
            .ctx
            .hasFinding('feeding.planUnknown'),
        isTrue);
  });

  test(
      'route follows current maturity and oral tolerance, never birth GA surrogate',
      () {
    for (final (pma, expected) in [
      (31.99, 'Orogastric'),
      (32, 'Spoon/paladai'),
      (33.99, 'Spoon/paladai'),
      (34, 'Direct breastfeeding')
    ]) {
      final ctx = walk({feeding}, input(ga: 27, pma: pma)).ctx;
      expect(
          ctx.findings
              .firstWhere((f) => f.id == 'feeding.routeGuide')
              .actions
              .first,
          contains(expected));
    }
    final ctx =
        walk({feeding}, {...input(pma: 36), feedingToleranceKey: true}).ctx;
    expect(
        ctx.findings
            .firstWhere((f) => f.id == 'feeding.routeGuide')
            .actions
            .single,
        contains('Use OG feeds'));
    expect(
        walk({feeding}, input(pma: null)).ctx.hasFinding('feeding.routeGuide'),
        isFalse);
  });

  test(
      '3-hourly is considered only with all four printed conditions; exact per-feed arithmetic',
      () {
    for (final pma in <num?>[null, 32, 32.01, 34]) {
      for (final stable in [false, true]) {
        for (final full in [false, true]) {
          for (final off in [false, true]) {
            expect(
                canConsiderThreeHourly(
                    pmaWeeks: pma,
                    stable: stable,
                    fullFeeds: full,
                    offRespiratorySupport: off),
                pma != null && pma > 32 && stable && full && off);
          }
        }
      }
    }
    final yes = walk({feeding}, input())
        .ctx
        .findings
        .firstWhere((f) => f.id == 'feeding.volume')
        .actions;
    expect(yes.first, contains('20.0 mL per feed'));
    expect(yes.last, contains('May consider 3-hourly'));
    expect(yes.last, contains('30.0 mL per feed'));
    final no = walk({feeding}, input(pma: 32))
        .ctx
        .findings
        .firstWhere((f) => f.id == 'feeding.volume')
        .actions;
    expect(no, hasLength(1));
  });

  test(
      'supplements retain eligibility, timing, shortfall and no duplicated dose',
      () {
    final ctx = walk({feeding}, input()).ctx;
    for (final id in ['iron', 'vitamin_d', 'minerals', 'supplement_review']) {
      expect(ctx.findings.firstWhere((f) => f.id == 'feeding.$id').actions,
          feedingEvidence['feeding_$id']);
    }
    final iron = feedingEvidence['feeding_iron']!.join();
    expect(
        iron, contains('Start at 2 weeks of age once feeds are established'));
    final minerals = feedingEvidence['feeding_minerals']!.join();
    expect(minerals, contains('total intake targets'));
    expect(minerals, contains('Supplement the shortfall'));
    expect(
        ctx.findings.firstWhere((f) => f.id == 'feeding.key_message').actions, [
      'EARLY BREASTMILK FEEDING AND RAPID ADVANCEMENT IMPROVE SURVIVAL AND GROWTH'
    ]);
    expect(ctx.hasFinding('feeding.poor_gain'), isFalse);
    expect(
        walk({feeding}, {...input(), feedingPoorGainKey: true})
            .ctx
            .hasFinding('feeding.poor_gain'),
        isTrue);
  });

  test('Knowledge Graph/STW Map has all source boxes, findings and own PDF',
      () {
    final raw =
        jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List;
    final regions = {
      for (final r in raw)
        r['id'] as String: StwRegionInfo(
            id: r['id'],
            document: r['document'],
            page: r['page'],
            text: r['text'])
    };
    final map = buildStwMap(
        regions: regions,
        data: StwMapData.fromJson(jsonDecode(
            File('assets/knowledge_graph/stw_map.json').readAsStringSync())));
    expect(map.root(feeding)!.pending, isFalse);
    expect(map.topicOfFile('Feeding_Nutrition Final 22 Oct 26.pdf'), feeding);
    final boxes = map.boxes.where((b) => b.topic == feeding).toList();
    expect(boxes, hasLength(25));
    for (final id in feedingEvidence.keys) {
      expect(map.box(id), isNotNull);
      expect(map.box(id)!.source!.document, feedingStwDocument);
    }
    for (final rule in feedingWorkflow.rules) {
      expect(map.box(rule.source.pdfRegionId!), isNotNull);
    }
  });

  test(
      'chatbot uses complete Feeding source cards and abstains from absent recommendations',
      () async {
    final chunks =
        (jsonDecode(File('assets/regions/regions.json').readAsStringSync())
                as List)
            .map((r) => StwChunk.fromJson(r))
            .toList();
    final bot = StwAnswerer(Bm25Retriever(initialChunks: chunks));
    for (final (q, id) in [
      ('What is the milk source for feeding and nutrition?', 'milk'),
      ('Feeding colostrum care frequency?', 'milk'),
      ('Feeding route at PMA 32 weeks?', 'route'),
      ('Daily total fluid guide day of life 1?', 'fluids'),
      ('Feeding and nutrition iron dose?', 'iron'),
      ('Feeding vitamin D dose?', 'vitamin_d'),
      ('Feeding calcium phosphorus dose?', 'minerals'),
      ('Feeding zinc eligibility?', 'supplement_review'),
      ('Feeding frequency 3-hourly?', 'plan_notes'),
      ('Feeding gastric residual monitoring?', 'monitoring'),
      ('Feeding poor weight gain?', 'poor_gain'),
      ('Feeding nutrition KPIs?', 'kpis'),
      ('Feeding start GA 35 weeks birth weight 900 g?', 'small'),
    ]) {
      final a = await bot.answer(q);
      expect(a.kind, AnswerKind.answer, reason: q);
      expect(a.region?.chunkId, 'feeding_$id', reason: q);
      expect(a.lines.map((s) => s.text), feedingEvidence['feeding_$id'],
          reason: q);
    }
    for (final q in [
      'Feeding zinc dose?',
      'Daily fluid guide day 8?',
      'Feeding formula brand?'
    ]) {
      expect((await bot.answer(q)).kind, AnswerKind.notCovered, reason: q);
    }
    expect((await bot.answer('Feeding start GA 32 weeks?')).kind,
        AnswerKind.clarify);
  });
}
