import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/data/ancs_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/data/hypo_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/data/rop_follow_up_data.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/bubble_graph.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_map.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_region.dart';

final regions = <String, StwRegionInfo>{
  for (final r in jsonDecode(
    File('assets/regions/regions.json').readAsStringSync(),
  ) as List)
    (r as Map<String, dynamic>)['id'] as String: StwRegionInfo(
      id: r['id'] as String,
      document: r['document'] as String,
      page: r['page'] as int? ?? 1,
      text: readableStwText(r['text'] as String),
    ),
};

final data = StwMapData.fromJson(
  jsonDecode(File('assets/knowledge_graph/stw_map.json').readAsStringSync())
      as Map<String, dynamic>,
);

final map = buildStwMap(regions: regions, data: data);

void main() {
  group('stw_map.json is verbatim from the STW PDFs', () {
    test('every box has a heading printed in that box', () {
      expect(data.headings.keys.toSet(), regions.keys.toSet());
      for (final MapEntry(:key, :value) in data.headings.entries) {
        expect(flatStwText(regions[key]!.text), contains(value), reason: key);
      }
    });

    test('context lines are printed in the same PDF', () {
      for (final MapEntry(:key, :value) in data.contexts.entries) {
        final doc = regions[key]!.document;
        for (final line in value) {
          expect(
            regions.values.any(
                (r) => r.document == doc && flatStwText(r.text).contains(line)),
            isTrue,
            reason: '$key: $line',
          );
        }
      }
    });

    test('every link quotes its own box and points to another STW', () {
      expect(data.links, isNotEmpty);
      final raw = (jsonDecode(
              File('assets/knowledge_graph/stw_map.json').readAsStringSync())
          as Map)['links'] as List;
      expect(data.links, hasLength(raw.length), reason: 'unknown topic');
      for (final l in data.links) {
        expect(regions.keys, contains(l.from), reason: l.id);
        expect(flatStwText(regions[l.from]!.text), contains(l.quote),
            reason: l.id);
        expect(map.topicOfBox(l.from), isNot(l.to), reason: l.id);
      }
    });
  });

  group('the map covers the workflows', () {
    test('one root per available STW, then linked pending topics', () {
      final available = [
        for (final c in NeonatalCondition.values)
          if (workflowFor(c) is StwWorkflow) c,
      ];
      expect(map.roots.take(available.length).map((r) => r.topic), available);
      for (final r in map.roots.skip(available.length)) {
        expect(r.pending, isTrue);
        expect(r.children, isNotEmpty, reason: '${r.topic} has no links');
        expect(r.children.every((c) => c.kind == MapKind.link), isTrue);
      }
      expect(map.root(NeonatalCondition.sepsis)?.pending, isTrue);
    });

    test('every PDF box appears once, under its own STW', () {
      expect(map.boxes.map((b) => b.boxId).toSet(), regions.keys.toSet());
      for (final b in map.boxes) {
        final root = map.root(b.topic!)!;
        expect(root.children.where((c) => c.id == b.id), hasLength(1));
      }
    });

    test('every rule is shown under the box it cites', () {
      for (final c in NeonatalCondition.values) {
        if (workflowFor(c) case final StwWorkflow w) {
          for (final rule in w.rules) {
            final box = map.box(rule.source.pdfRegionId!)!;
            final shown = box.children.any((n) =>
                n.id == 'finding:${rule.id}' ||
                n.rules.any((r) => r.$1 == rule.id));
            expect(shown, isTrue, reason: rule.id);
          }
        }
      }
    });

    test('a shared question bridges the STWs that ask it', () {
      final rdBox = map.box('rd_algorithm_overview')!;
      final ropBox = map.box('rop_whom_to_screen')!;
      for (final box in [rdBox, ropBox]) {
        final ga =
            box.children.singleWhere((n) => n.question?.id == gaWeeksKey);
        expect(ga.topics, {
          NeonatalCondition.respiratoryDistress,
          NeonatalCondition.rop,
        });
      }
    });

    test('fixed-title findings use the rule wording', () {
      final box = map.box('hypo_how_to_monitor')!;
      expect(box.children.map((n) => n.label),
          contains('BLOOD GLUCOSE <45 mg/dL'));
    });
  });

  group('bubble view', () {
    final g = buildBubbleGraph(map);

    test('one hub per map root, with the same children', () {
      expect(g.hubs.map((h) => h.node.id), map.roots.map((r) => r.id));
      final hypo = g.hubOf(NeonatalCondition.hypoglycemia)!;
      expect(
          hypo.children.map((c) => c.id), contains('box:hypo_whom_to_screen'));
      final box = g.box('hypo_whom_to_screen')!;
      expect(box.children.map((c) => c.edgeLabel).toSet(),
          containsAll(['asks', 'produces', 'mentions']));
    });

    test('edges between STWs come from the links and shared answers', () {
      bool has(String from, String to, String label) => g.hubEdges
          .any((e) => e.from == from && e.to == to && e.label == label);
      expect(has('hub:respiratoryDistress', 'hub:sepsis', 'refers to'), isTrue);
      expect(has('hub:rop', 'hub:ancs', 'mentions'), isTrue);
      expect(
          has('hub:respiratoryDistress', 'hub:rop', 'shares answers'), isTrue);
      for (final e in g.hubEdges) {
        expect(g.byId(e.from), isNotNull, reason: e.from);
        expect(g.byId(e.to), isNotNull, reason: e.to);
        if (e.label != 'shares answers') expect(e.draft, isTrue);
      }
    });
  });

  group('finding a box', () {
    test('search matches headings, box text and questions', () {
      expect(map.search('surfactant').map((n) => n.boxId),
          contains('rd_surfactant_indication'));
      expect(map.search('blood glucose').any((n) => n.kind == MapKind.question),
          isTrue);
      expect(map.search('   '), isEmpty);
    });

    test('every MCQ reference resolves to a box of its STW', () {
      final refs = {
        for (final q in [
          ...ancsFollowUpMcqs,
          ...ancsFollowUpCaseScenarios,
          ...hypoFollowUpMcqs,
          ...hypoFollowUpCaseScenarios,
          ...ropFollowUpMcqs,
          ...ropFollowUpCaseScenarios,
        ])
          if (q.stwReference != null) q.stwReference!: q.disease,
      };
      expect(refs, isNotEmpty);
      for (final MapEntry(key: ref, value: topic) in refs.entries) {
        final box = map.resolveReference(ref);
        expect(box, isNotNull, reason: ref);
        expect(map.topicOfBox(box!), topic, reason: ref);
      }
      expect(
        map.resolveReference(
            'ICMR/DHR STW "Antenatal Corticosteroids for Preterm Birth" '
            '(August 2026), WHEN TO GIVE REPEAT COURSE'),
        'ancs_repeat_course',
      );
    });
  });
}
