import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';
import 'package:neonatal_stw/features/chatbot/domain/understanding/query_analyzer.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_map.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_region.dart';
import 'package:neonatal_stw/features/post_asphyxia/domain/post_asphyxia_content.dart';
import 'package:neonatal_stw/features/post_asphyxia/domain/post_asphyxia_rules.dart';
import 'package:neonatal_stw/features/post_asphyxia/domain/post_asphyxia_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';
import 'assessment_test_utils.dart';

const post = NeonatalCondition.hie;
Map<String, Object?> input(
        {String stage = 'moderate',
        String stability = 'stable',
        String seizures = 'no',
        String worsening = 'no',
        num? ga = 36,
        String hypoxia = 'yes'}) =>
    {
      paStability: stability,
      paSeizures: seizures,
      paWorsening: worsening,
      paStage: stage,
      paGa: ga,
      paAcuteHypoxia: hypoxia,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('replace existing slot without changing ordinal or persisted code',
      () async {
    expect(NeonatalCondition.values, hasLength(14));
    expect(post.index, 10);
    expect(post.name, 'hie');
    expect(diseaseCodeOf(post), 'hie');
    expect(conditionDefinitions[5].id, post);
    expect(definitionOf(post).title, 'STW Post Asphyxia');
    expect(workflowFor(post), same(postAsphyxiaWorkflow));
    expect(stwPdfFor(post)?.asset, postAsphyxiaPdfAsset);
    expect(stwPdfForDocument(postAsphyxiaStwDocument)?.asset,
        postAsphyxiaPdfAsset);
    expect(stwPdfForDocument('Post Asphyxia 16-10-26.pdf')?.asset,
        postAsphyxiaPdfAsset);
    expect(
        topicOfDocument('Post Asphyxia 16-10-26.pdf'), StwTopic.postAsphyxia);
    for (final source in [
      postAsphyxiaWorkflow.source,
      ...postAsphyxiaWorkflow.rules.map((r) => r.source),
      ...postAsphyxiaWorkflow.uses.expand((u) => u.question.sources)
    ]) {
      expect(source.document, postAsphyxiaStwDocument);
      expect(source.version, 'August 2026');
      expect((await stwRegionTarget(source.pdfRegionId!))?.document,
          'Post Asphyxia 16-10-26.pdf');
    }
  });
  test('no clinical defaults or automatic stage from observed domains', () {
    for (var i = 0; i < paDomains.length; i++) {
      final (_, title, cells) = paDomains[i];
      final excerpt = postAsphyxiaEvidence['post_asphyxia_sarnat']![i];
      expect(excerpt, startsWith('$title:'));
      for (var j = 0; j < cells.length; j++) {
        expect(excerpt,
            contains('${['MILD', 'MODERATE', 'SEVERE'][j]}: ${cells[j]}'));
      }
    }
    final empty = evalCtx({post}, {});
    expect(engine.canConfirm(empty, 'pa_initial'), isFalse);
    final assessed = evalCtx({
      post
    }, {
      ...input(),
      paStage: null,
      for (final (key, _, _) in paDomains) 'post_asphyxia_domain_$key': 'severe'
    });
    expect(assessed.valueOf(paStage), isNull);
    expect(engine.canConfirm(assessed, 'pa_sarnat'), isFalse);
    expect(assessed.hasFinding('post_asphyxia.potentialCooling'), isFalse);
    expect(assessed.hasFinding('post_asphyxia.normal'), isFalse);
  });
  test(
      'all clinical stage / stability / seizures branches execute to completion',
      () {
    for (final stage in ['normal', 'mild', 'moderate', 'severe', 'unknown']) {
      for (final stability in ['stable', 'unstable', 'unknown']) {
        for (final seizures in ['no', 'yes', 'unknown']) {
          final ctx = walk({post},
                  input(stage: stage, stability: stability, seizures: seizures))
              .ctx;
          expect(engine.nextGroup(ctx), isNull);
          expect(
              ctx.hasFinding('post_asphyxia.urgent'),
              stability == 'unstable' ||
                  stage == 'moderate' ||
                  stage == 'severe');
          expect(ctx.hasFinding('post_asphyxia.normal'),
              stability == 'stable' && stage == 'normal' && seizures == 'no');
          expect(ctx.hasFinding('post_asphyxia.mild'),
              stability == 'stable' && stage == 'mild');
          expect(ctx.hasFinding('post_asphyxia.seizures'), seizures == 'yes');
          expect(
              ctx.hasFinding('post_asphyxia.review'),
              stage == 'unknown' ||
                  stability == 'unknown' ||
                  seizures == 'unknown');
        }
      }
    }
  });
  test('high-risk boundaries and blood gas timing have no inferred negatives',
      () {
    expect(hasPostAsphyxiaHighRisk(), isFalse);
    for (final apgar in [4, 5, 6]) {
      expect(hasPostAsphyxiaHighRisk(apgar10: apgar), apgar <= 5);
    }
    expect(hasPostAsphyxiaHighRisk(ppv10: true), isTrue);
    for (final timing in <String?>[
      null,
      'unknown',
      'later',
      'cord',
      'within1h'
    ]) {
      for (final ph in [7.09, 7.1, 7.11]) {
        for (final bd in [11.9, 12, 12.1]) {
          expect(
              hasPostAsphyxiaHighRisk(
                  sampleTiming: timing, ph: ph, baseDeficit: bd),
              (timing == 'cord' || timing == 'within1h') &&
                  (ph <= 7.1 || bd >= 12));
        }
      }
    }
    final ctx = walk({
      post
    }, {
      ...input(),
      'post_asphyxia_sample': 'later',
      'post_asphyxia_ph': 7.0
    }).ctx;
    expect(ctx.hasFinding('post_asphyxia.high_risk'), isFalse);
  });
  test(
      'potential TH candidates require all three criteria and never final eligibility',
      () {
    for (final ga in <num?>[null, 35.99, 36, 40]) {
      for (final stage in ['normal', 'mild', 'moderate', 'severe', 'unknown']) {
        for (final hypoxia in ['no', 'yes', 'unknown']) {
          final expected = ga != null &&
              ga >= 36 &&
              ['moderate', 'severe'].contains(stage) &&
              hypoxia == 'yes';
          expect(
              isPotentialCoolingCandidate(
                  gaWeeks: ga, stage: stage, acuteHypoxia: hypoxia),
              expected);
          final ctx =
              walk({post}, input(ga: ga, stage: stage, hypoxia: hypoxia)).ctx;
          expect(ctx.hasFinding('post_asphyxia.potentialCooling'), expected);
          expect(
              ctx.findings.where((f) => f.category.name == 'notMet'), isEmpty);
          final guidance =
              ctx.findings.firstWhere((f) => f.id == 'post_asphyxia.cooling');
          expect(
              guidance.actions, postAsphyxiaEvidence['post_asphyxia_cooling']);
        }
      }
    }
  });
  test('complete emergency doses and monitoring qualifiers equal source cards',
      () {
    final ctx = walk({post}, input(seizures: 'yes', worsening: 'yes')).ctx;
    expect(CombinedAssessmentSummary.from(ctx).subjects.single.line,
        contains('GA at birth: 36 weeks'));
    for (final suffix in [
      'seizures',
      'urgent',
      'cooling',
      'oxygen',
      'perfusion',
      'neurological',
      'temperature',
      'glucose',
      'fluids',
      'feeding',
      'discharge',
      'dos',
      'donts',
      'kpis',
      'key_message'
    ]) {
      expect(
          ctx.findings
              .firstWhere((f) => f.id == 'post_asphyxia.$suffix')
              .actions,
          postAsphyxiaEvidence['post_asphyxia_$suffix']);
    }
    expect(
        walk({post}, input(stage: 'mild', worsening: 'yes'))
            .ctx
            .hasFinding('post_asphyxia.worsening'),
        isTrue);
    expect(
        walk({post}, input(stage: 'normal', worsening: 'yes'))
            .ctx
            .hasFinding('post_asphyxia.review'),
        isTrue);
    expect(postAsphyxiaEvidence['post_asphyxia_seizures']!.join(' '),
        contains('20 mg/kg IV over 15 min'));
    expect(postAsphyxiaEvidence['post_asphyxia_high_risk']!.single,
        contains('pH ≤7.1 or base deficit ≥12 mmol/L'));
    expect(postAsphyxiaEvidence['post_asphyxia_glucose']!.single,
        contains('50–125 mg/dL'));
    expect(postAsphyxiaEvidence['post_asphyxia_cooling']!.first,
        contains('GA ≥36 weeks'));
  });
  test('all source cards, KG nodes and quoted referral preserve source meaning',
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
    final graph = StwMapData.fromJson(jsonDecode(
        File('assets/knowledge_graph/stw_map.json').readAsStringSync()));
    final map = buildStwMap(regions: regions, data: graph);
    final root = map.roots.singleWhere((r) => r.topic == post);
    expect(root.label, 'STW Post Asphyxia');
    for (final card
        in raw.where((r) => (r['id'] as String).startsWith('post_asphyxia_'))) {
      expect(postAsphyxiaEvidence[card['id']],
          (card['segments'] as List).map((s) => s['text']));
      expect(map.box(card['id']), isNotNull);
    }
    final link = graph.links
        .singleWhere((l) => l.id == 'post_asphyxia_seizures_referral');
    expect(link.to, NeonatalCondition.seizures);
    expect(link.approved, isFalse);
    expect(link.quote, 'Refer to Seizures STW');
  });
  test(
      'chatbot returns complete PDF cards and keeps shared words in this topic',
      () async {
    final raw =
        jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List;
    final answerer = StwAnswerer(Bm25Retriever(
        initialChunks: raw.map((r) => StwChunk.fromJson(r)).toList()));
    for (final (query, suffix) in [
      ('Therapeutic hypothermia criteria for HIE', 'cooling'),
      ('Therapeutic hypothermia management for HIE', 'cooling'),
      ('Hypoxic ischemic encephalopathy oxygen monitoring', 'oxygen'),
      ('Hypoxic ischaemic encephalopathy oxygen monitoring', 'oxygen'),
      ('Post Asphyxia seizure treatment', 'seizures'),
      ('Post Asphyxia blood glucose monitoring', 'glucose'),
      ('Post Asphyxia oxygen target', 'oxygen'),
      ('Post Asphyxia feeding safety', 'feeding'),
      ('Post Asphyxia Modified Sarnat staging', 'sarnat'),
      ('Post Asphyxia discharge and hearing follow-up', 'discharge'),
      ('Post Asphyxia high-risk Apgar and pH features', 'high_risk'),
      ('Post Asphyxia mild HIE management', 'mild'),
      ('Post Asphyxia severe HIE management', 'urgent'),
      ('Post Asphyxia normal examination', 'normal'),
      ('Post Asphyxia temperature monitoring', 'temperature'),
      ('HIE blood pressure monitoring frequency', 'perfusion'),
      ('HIE prophylactic phenobarbitone dose', 'donts'),
      ('HIE seizure prophylaxis', 'donts'),
      ('HIE initially normal examination exclude HIE?', 'serial'),
    ]) {
      final a = await answerer.answer(query);
      expect(a.analysis.topics, {StwTopic.postAsphyxia}, reason: query);
      expect(a.kind, AnswerKind.answer, reason: query);
      expect(a.region?.chunkId, 'post_asphyxia_$suffix', reason: query);
      expect(a.lines.map((l) => l.text),
          postAsphyxiaEvidence['post_asphyxia_$suffix']);
    }
    for (final q in [
      'HIE cooling duration protocol',
      'HIE complete NNF criteria',
      'HIE repeat phenobarbitone dose',
      'HIE next phenobarbitone dose',
      'HIE rewarming rate',
      'Post Asphyxia IV glucose dose',
      'HIE refractory seizure treatment',
      'Therapeutic hypothermia management in adults',
      'Neonatal hypothermia management'
    ]) {
      expect((await answerer.answer(q)).kind, AnswerKind.notCovered, reason: q);
    }
    final mixed = await answerer.answer('HIE Sarnat mixed domains staging');
    expect(mixed.region?.chunkId, 'post_asphyxia_sarnat');
    expect(mixed.caseSummary?.reviewNote,
        contains('No overall stage has been inferred'));
    expect((await answerer.answer('BG 18 with seizures')).region?.chunkId,
        'hypo_symptomatic_branch');
  });
}
