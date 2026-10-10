import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_rules.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/condition_expr.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/stw_section_regions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_rules.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/cond_introspection.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/explained_values.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/kg_graph.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/kg_value_format.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/reasoning.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart';

const hypo = NeonatalCondition.hypoglycemia;
const ancs = NeonatalCondition.ancs;

/// GA 32 wk preterm with RD (SAS 5), ROP screening due, BG 40 asymptomatic.
final babyAnswers = <String, Object?>{
  gaKnownKey: true,
  gaWeeksKey: 32,
  birthWeightKey: 1600,
  dobKey: testToday.subtract(const Duration(days: 5)),
  rdSignsKey: <Object>{'retractions'},
  for (final i in SasItem.values) rdSasKey(i): 1,
  rdReassessNowKey: false,
  ropFollowUpAssuredKey: 'yes',
  ropExamDoneKey: false,
  hypoRiskKey: <Object>{HypoRisk.preterm.name},
  hypoBgKey: 40,
  hypoSymptomsKey: <Object>{},
};

final ancsAnswers = <String, Object?>{
  ancsGaWeeksKey: 30,
  ancsGaDaysKey: 2,
  ancsCausesKey: <Object>{AncsCause.pprom.name},
  ancsGaAccurateKey: true,
  ancsInfectionKey: false,
  ancsChildbirthCareKey: true,
  ancsNewbornCareKey: true,
  ancsPreviousCourseKey: AncsPreviousCourse.none.name,
  ancsLevel2Key: true,
};

ClinicalAssessmentContext babyCtx() => walk({rd, rop, hypo}, babyAnswers).ctx;

/// Box ids of `assets/regions/regions.json` with their PDF file name.
final Map<String, String> regionDocs = {
  for (final r in jsonDecode(
    File('assets/regions/regions.json').readAsStringSync(),
  ) as List)
    (r as Map<String, dynamic>)['id'] as String: r['document'] as String,
};

/// The source opens a box that exists, in the PDF of its own STW.
void expectHighlightable(SourceReference s, String reason) {
  final pdf = stwPdfForDocument(s.document);
  expect(pdf, isNotNull, reason: '$reason: no bundled PDF for ${s.document}');
  final rid = s.pdfRegionId;
  expect(rid, isNotNull, reason: '$reason: no PDF box for "${s.section}"');
  expect(regionDocs.keys, contains(rid), reason: '$reason: unknown box $rid');
  expect(
    pdf!.asset.endsWith('/${regionDocs[rid]}'),
    isTrue,
    reason: '$reason: box $rid is in ${regionDocs[rid]}, not ${pdf.asset}',
  );
}

ReasonNode tree(ClinicalAssessmentContext ctx, String findingId) =>
    ReasoningBuilder(ctx)
        .explain(ctx.findings.singleWhere((f) => f.id == findingId));

void main() {
  group('Every STW source points at its box in the PDF', () {
    test('questions and rules of all available workflows', () {
      for (final c in NeonatalCondition.values) {
        if (workflowFor(c) case final StwWorkflow w) {
          final sources = [
            for (final u in w.uses)
              for (final s in u.question.sources) (u.question.id, s),
            for (final r in w.rules) (r.id, r.source),
          ];
          for (final (id, s) in sources) {
            if (!s.isClinical) continue;
            if (sectionsOutsideStwPdf.contains('${s.document}|${s.section}')) {
              continue;
            }
            expectHighlightable(s, id);
          }
        }
      }
    });

    test('values shown as their own step', () {
      for (final MapEntry(:key, :value) in explainedValues.entries) {
        expectHighlightable(value.source, key);
      }
    });

    test('the section table only names existing boxes', () {
      for (final MapEntry(:key, :value) in stwSectionRegions.entries) {
        expect(regionDocs.keys, contains(value), reason: key);
      }
    });
  });

  group('Cond introspection', () {
    test('collects keys, finding ids and leaves through AND/OR/NOT', () {
      final c = AllOf([
        const Var('a').ge(1),
        AnyOf([const Var('b').eq(true), const HasFinding('x.y')]),
        Not(AllOf([const Var('c').exists(), const HasFinding('z')])),
      ]);
      expect(c.variableKeys, {'a', 'b', 'c'});
      expect(c.findingIds, {'x.y', 'z'});
      expect(c.leafComparisons.map((l) => l.key), ['a', 'b', 'c']);
    });
  });

  group('Why a finding appeared', () {
    test('START CPAP: earlier finding, then the answers its rule used', () {
      final t = tree(babyCtx(), rdInitialPlanId);
      expect(t.kind, ReasonKind.finding);
      expect(t.label, 'START CPAP');
      expect(t.source!.pdfRegionId, 'rd_algorithm_overview');

      // Findings first, then computed values, then answers.
      expect(t.children.first.id, 'finding:$rdPresentId');
      final kinds = t.children.map((c) => c.kind.index).toList();
      expect(kinds, [...kinds]..sort());

      final ga = t.descendants.firstWhere((n) => n.id == 'answer:$gaWeeksKey');
      expect(ga.value, '32 weeks');
      expect(ga.topics, {rd, rop}, reason: 'GA is shared by RD and ROP');
      expect(ga.source!.document, rdStwDocument,
          reason: 'under an RD finding, GA cites the RD STW');
    });

    test('computed values use the STW wording', () {
      final signs = tree(babyCtx(), rdPresentId)
          .children
          .singleWhere((c) => c.id == 'value:$rdSignsEffectiveKey');
      expect(signs.value, 'Chest retractions');
      expect(signs.check, 'includes Chest retractions');
    });

    test('a shared answer cites the STW of the finding it explains', () {
      final ctx = babyCtx();
      final ga = tree(ctx, ropEligibleId)
          .descendants
          .firstWhere((n) => n.id == 'answer:$gaWeeksKey');
      expect(ga.source!.document, ropStwDocument);
      expect(ga.source!.pdfRegionId, 'rop_whom_to_screen');
    });

    test('SAS items sit under the SAS total, not repeated beside it', () {
      final t = tree(babyCtx(), rdSeverityId);
      final total =
          t.descendants.firstWhere((c) => c.id == 'value:$rdSasScoreKey');
      expect(total.value, '5');
      expect(
          total.children.map((c) => c.id),
          containsAll(
              [for (final i in SasItem.values) 'answer:${rdSasKey(i)}']));
      expect(
        t.children.where((c) => c.id.startsWith('answer:rd_sas_')),
        isEmpty,
      );
    });

    test('START CPAP reads as STW steps, not loose answers', () {
      final t = tree(babyCtx(), rdInitialPlanId);
      expect(t.children.map((c) => c.label), [
        'Respiratory distress criteria met',
        'Gestation group',
        'SAS total',
        'Other findings (tick all that apply)',
      ]);
      final group = t.children.singleWhere((c) => c.label == 'Gestation group');
      expect(group.value, 'GA ≤34 weeks');
      expect(group.source!.pdfRegionId, 'rd_algorithm_overview');
      expect(group.children.map((c) => c.id),
          containsAll(['answer:$gaKnownKey', 'answer:$gaWeeksKey']));
    });

    test('a threshold the rule checks directly is shown on the answer', () {
      final t = tree(babyCtx(), hypoLowId);
      final bg = t.children.singleWhere((c) => c.id == 'answer:$hypoBgKey');
      expect(bg.value, '40 mg/dL');
      expect(bg.check, '< 45 mg/dL');
      expect(bg.source!.pdfRegionId, isNotNull);
    });

    test('shared answers list the findings of each topic', () {
      final ctx = babyCtx();
      final shared = ReasoningBuilder(ctx).sharedAnswers();
      final ga = shared.singleWhere(
          (s) => s.answers.any((a) => a.id == 'answer:$gaWeeksKey'));
      expect(ga.answers.map((a) => a.id), contains('answer:$gaKnownKey'));
      expect(ga.topics, {rd, rop});
      expect(ga.findings.map((f) => f.id),
          containsAll([rdInitialPlanId, ropEligibleId]));
    });
  });

  group('Every finding is explained only from the workflow, with sources', () {
    final cases = <String, (Set<NeonatalCondition>, Map<String, Object?>)>{
      'RD + ROP + Hypo': ({rd, rop, hypo}, babyAnswers),
      'ANCS eligible': ({ancs}, ancsAnswers),
      'Hypo symptomatic on IV': (
        {hypo},
        {
          hypoRiskKey: <Object>{HypoRisk.preterm.name},
          hypoBgKey: 30,
          hypoSymptomsKey: <Object>{HypoSymptom.jitteriness.name},
          hypoIvNowKey: true,
          hypoGirKey: 6,
          hypoIvBgKey: 40,
        }
      ),
      'RD not met': ({rd}, {...babyAnswers, rdSignsKey: <Object>{}}),
      'RD reassessment': (
        {rd},
        {
          ...babyAnswers,
          rdReassessNowKey: true,
          rdSupportKey: 'cpap',
          rdPeepKey: 7,
          rdFio2Key: 40,
          rdSpo2Key: 90,
          for (final i in SasItem.values) rdReSasKey(i): 1,
        }
      ),
    };
    for (final MapEntry(key: name, value: (topics, answers)) in cases.entries) {
      test(name, () {
        final ctx = walk(topics, answers).ctx;
        expect(ctx.findings, isNotEmpty);
        final allowedLabels = {
          for (final f in ctx.findings) f.title,
          for (final rq in engine.resolve(ctx.selected)) rq.question.question,
          for (final v in explainedValues.values) v.label,
          'Date of this assessment',
        };
        for (final t in ReasoningBuilder(ctx).explainAll()) {
          final f = t.finding!;
          expect(t.label, f.title);
          expect(
            t.descendants.any((n) => n.kind == ReasonKind.answer),
            isTrue,
            reason: '${f.id} has no answer behind it',
          );
          for (final n in [t, ...t.descendants]) {
            expect(allowedLabels, contains(n.label),
                reason: 'label not from the workflow: ${n.label}');
            final ids = n.children.map((c) => c.id).toList();
            expect(ids.toSet(), hasLength(ids.length),
                reason: 'duplicate steps under ${n.id}');
            if (n.kind != ReasonKind.answer) {
              expectHighlightable(n.source!, '${f.id} › ${n.id}');
            } else if (n.source != null &&
                !sectionsOutsideStwPdf
                    .contains('${n.source!.document}|${n.source!.section}')) {
              expectHighlightable(n.source!, '${f.id} › ${n.id}');
            }
          }
        }
      });
    }
  });

  group('Node graph of one finding', () {
    FocusGraph graphOf(ClinicalAssessmentContext ctx, String id) {
      final trees = ReasoningBuilder(ctx).explainAll();
      return focusGraphOf(trees.singleWhere((t) => t.finding!.id == id), trees);
    }

    test('rule node: the checks it made, from the rule itself', () {
      final g = graphOf(babyCtx(), hypoLowId);
      expect(g.rule.kind, KgKind.rule);
      expect(g.rule.label, g.clinicalFinding.source.section);
      expect(g.rule.checks.single.label, 'Blood glucose (BG)');
      expect(g.rule.checks.single.value, '40 mg/dL');
      expect(g.rule.checks.single.threshold, '< 45 mg/dL');
      expect(g.stwBox!.source!.pdfRegionId, 'hypo_how_to_monitor');
    });

    test('a finding lists the findings its rule leads to', () {
      final g = graphOf(babyCtx(), rdPresentId);
      expect(g.leadsTo.map((i) => i.id),
          containsAll(['finding:$rdInitialPlanId', 'finding:$rdImmediateId']));
      expect(graphOf(babyCtx(), rdInitialPlanId).leadsTo.map((i) => i.id),
          isNot(contains('finding:$rdPresentId')));
    });

    test('nodes come only from the reasoning tree', () {
      final ctx = babyCtx();
      final trees = ReasoningBuilder(ctx).explainAll();
      for (final t in trees) {
        final g = focusGraphOf(t, trees);
        expect(g.finding.label, t.label);
        expect(g.rule.basedOn.map((i) => i.id), t.children.map((c) => c.id));
        expect(g.rule.source, g.clinicalFinding.source);
      }
    });

    test('GA leads to findings of both topics', () {
      final using = findingsUsing(ReasoningBuilder(babyCtx()).explainAll());
      expect(
          using['answer:$gaWeeksKey']!.map((f) => f.topic).toSet(), {rd, rop});
    });
  });

  group('Value text', () {
    test('identifiers read as words; no text for engine objects', () {
      expect(humanizeIdentifier('notYetDue'), 'not yet due');
      expect(humanizeIdentifier('BG <45'), 'BG <45');
      expect(formatKgValue(true), 'Yes');
      expect(formatKgValue(Object()), isNull);
    });

    test('yes/no checks are not repeated as a rule check', () {
      expect(describeCheck(const Compare('x', CmpOp.eq, true)), isNull);
      expect(describeCheck(const Compare('x', CmpOp.ge, 4)), '≥ 4');
    });
  });
}
