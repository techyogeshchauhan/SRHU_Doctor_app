import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_content.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_rules.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart';

const jaundice = NeonatalCondition.jaundice;

Map<String, Object?> base({
  int ga = 38,
  int age = 72,
  String kramer = 'zone2',
  bool before24h = false,
  Set<Object> abe = const {},
  Set<Object> posture = const {},
  String? cutoff,
}) =>
    {
      gaKnownKey: true,
      gaWeeksKey: ga,
      jaundiceAgeHoursKey: age,
      if (age >= 24) jaundiceBefore24hKey: before24h,
      jaundiceKramerKey: kramer,
      jaundiceAbeKey: abe,
      jaundicePostureKey: posture,
      if (cutoff != null) jaundiceCutoffResultKey: cutoff,
    };

ClinicalFinding finding(Walk w, String id) =>
    w.ctx.findings.firstWhere((f) => f.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registered, available and linked to its PDF', () {
    expect(definitionOf(jaundice).implemented, isTrue);
    expect(workflowFor(jaundice), same(jaundiceWorkflow));
    expect(stwPdfFor(jaundice)?.asset, jaundicePdfAsset);
    expect(stwPdfForDocument(jaundiceStwDocument)?.asset, jaundicePdfAsset);
  });

  test('every source cites a printed box of the July 2020 PDF', () {
    final raw =
        jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List;
    final regions = {for (final r in raw) r['id'] as String: r};
    for (final s in [
      ...jaundiceWorkflow.rules.map((r) => r.source),
      for (final u in jaundiceWorkflow.uses)
        if (u.question.id.startsWith('jaundice_')) ...u.question.sources,
    ]) {
      expect(s.document, jaundiceStwDocument);
      expect(s.version, 'July 2020');
      final region = regions[s.pdfRegionId];
      expect(region, isNotNull, reason: s.section);
      expect(region['document'], 'Neonatal Jaundice.pdf');
      expect(region['title'], s.section);
      expect((region['segments'] as List).map((g) => g['text']),
          jaundiceEvidence[s.pdfRegionId]);
    }
  });

  group('page flow', () {
    test('baby → signs → risk factors; TSB page only when needed', () {
      final w = walk({jaundice}, base());
      expect(w.pages, ['baby', 'jaundice_signs', 'jaundice_risk']);
      expect(findingIds(w.ctx), contains(jaundiceNoTsbId));
      expect(w.asked, isNot(contains(jaundiceCutoffResultKey)));
    });

    test('GA <35 weeks: not covered, no jaundice questions or advice', () {
      final w = walk({jaundice}, base(ga: 33, kramer: 'zone5'));
      expect(w.pages, ['baby']);
      expect(findingIds(w.ctx), {jaundiceNotCoveredId});
      expect(finding(w, jaundiceNotCoveredId).why, ['GA 33 weeks']);
    });

    test('GA uncertain: clinician assessment of ≥35 weeks decides', () {
      final no = walk({jaundice}, {gaKnownKey: false, jaundiceGa35Key: false});
      expect(findingIds(no.ctx), {jaundiceNotCoveredId});
      final yes = walk({
        jaundice
      }, {
        ...base(kramer: 'zone1'),
        gaKnownKey: false,
        jaundiceGa35Key: true,
      });
      expect(yes.asked, contains(jaundiceKramerKey));
      expect(findingIds(yes.ctx), contains(jaundiceNoTsbId));
    });

    test('"visible in first 24 hrs" asked only beyond 24 hrs', () {
      expect(walk({jaundice}, base(age: 12)).asked,
          isNot(contains(jaundiceBefore24hKey)));
      expect(walk({jaundice}, base(age: 30)).asked,
          contains(jaundiceBefore24hKey));
    });

    test('at/above cut-off adds the optional repeat-TSB page', () {
      final w = walk({jaundice}, base(kramer: 'zone4', cutoff: 'pt'));
      expect(w.pages.last, 'jaundice_review');
      expect(
          w.asked, containsAll([jaundiceRepeatTsbKey, jaundiceCutoffValueKey]));
    });
  });

  group('serious jaundice → start intensive phototherapy', () {
    for (final (label, answers) in [
      ('visible in first 24 hrs', base(age: 20, kramer: 'zone1')),
      (
        'visible before 24 hrs, seen later',
        base(age: 50, kramer: 'zone1', before24h: true)
      ),
      ('yellow palms and soles', base(kramer: 'zone5')),
      ('ABE sign', base(kramer: 'zone2', abe: {AbeSign.lethargy.name})),
      ('posturing', base(kramer: 'zone2', posture: {PostureSign.arching.name})),
    ]) {
      test(label, () {
        final w =
            walk({jaundice}, {...answers, jaundiceCutoffResultKey: 'pending'});
        expect(findingIds(w.ctx),
            containsAll([jaundiceSeriousId, jaundiceStartPtId]));
        expect(finding(w, jaundiceStartPtId).level, FindingLevel.urgent);
        expect(finding(w, jaundiceStartPtId).actions, [
          'Document serum bilirubin simultaneously',
          'Prepare for exchange blood transfusion (EBT) if signs of ABE are present',
        ]);
        expect(w.pages, contains('jaundice_tsb'));
        expect(findingIds(w.ctx), isNot(contains(jaundiceNoTsbId)));
      });
    }

    test('ABE signs → prepare for EBT with volume from birth weight', () {
      final w = walk({
        jaundice
      }, {
        ...base(kramer: 'zone4', abe: {AbeSign.poorSuck.name}),
        birthWeightKey: 2400,
        jaundiceCutoffResultKey: 'pending',
      });
      final ebt = finding(w, jaundiceEbtId);
      expect(ebt.level, FindingLevel.urgent);
      expect(ebt.actions.last,
          'Exchange volume: 2 × 80-100 mL/kg × 2.4 kg = 384-480 mL');
      expect(ebt.source.needsClinicalReview, isTrue);
    });

    test('no EBT finding without ABE signs or an EBT-level TSB', () {
      final w = walk({jaundice}, base(kramer: 'zone5', cutoff: 'pt'));
      expect(findingIds(w.ctx), isNot(contains(jaundiceEbtId)));
      expect(
          findingIds(
              walk({jaundice}, base(kramer: 'zone5', cutoff: 'ebt')).ctx),
          contains(jaundiceEbtId));
    });
  });

  group('not serious', () {
    test('zone 3+ needs TSB; reasons listed', () {
      final w = walk({jaundice}, base(kramer: 'zone3', cutoff: 'pending'));
      expect(findingIds(w.ctx), contains(jaundiceNeedsTsbId));
      expect(findingIds(w.ctx), isNot(contains(jaundiceSeriousId)));
      expect(finding(w, jaundiceNeedsTsbId).why,
          ['Kramer zone 3 (Lower abdomen and thighs): approx 12 to 14 mg/dL']);
      expect(findingIds(w.ctx), contains(jaundiceTsbAwaitedId));
    });

    test('unsure / TcB >12 / near cut-off need TSB', () {
      for (final extra in <Map<String, Object?>>[
        {jaundiceKramerKey: kramerUnsure},
        {jaundiceTcbKey: 12.5},
        {jaundiceNearCutoffKey: true},
      ]) {
        final w = walk({
          jaundice
        }, {
          ...base(kramer: 'zone1'),
          ...extra,
          jaundiceCutoffResultKey: 'below'
        });
        expect(findingIds(w.ctx), contains(jaundiceNeedsTsbId),
            reason: '$extra');
      }
    });

    test('no TSB needed → visual assessment / TcB every 12-24 hrs', () {
      final w = walk({jaundice}, base(kramer: 'zone2'));
      expect(finding(w, jaundiceNoTsbId).actions.first,
          'Continue visual assessment/TcB (if available) every 12 to 24 hrs till discharge');
      expect(
          findingIds(w.ctx),
          containsAll(
              ['jaundice.discharge', 'jaundice.dos', 'jaundice.donts']));
    });
  });

  group('TSB against the unit chart (no cut-off computed by the app)', () {
    test('below cut-off → stop phototherapy, continue visual assessment', () {
      final w = walk({jaundice}, base(kramer: 'zone5', cutoff: 'below'));
      expect(
          finding(w, jaundiceBelowCutoffId).actions.first, 'Stop phototherapy');
    });

    test('at/above cut-off → continue phototherapy, investigations', () {
      final w = walk({jaundice}, base(kramer: 'zone4', cutoff: 'pt'));
      expect(finding(w, jaundiceAboveCutoffId).actions,
          ['Continue phototherapy/prepare for EBT and determine the cause']);
      expect(finding(w, jaundiceInvestigationsId).actions,
          jaundiceEvidence['jaundice_investigation']);
      expect(
          findingIds(w.ctx),
          containsAll(
              ['jaundice.optimalPhototherapy', 'jaundice.stopCriteria']));
    });

    test('repeat TSB: stop criteria met / not met', () {
      Walk withRepeat(num tsb, [num? cutoff]) => walk({
            jaundice
          }, {
            ...base(kramer: 'zone4', cutoff: 'pt'),
            jaundiceRepeatTsbKey: tsb,
            if (cutoff != null) jaundiceCutoffValueKey: cutoff,
          });
      expect(findingIds(withRepeat(12.5).ctx), contains(jaundiceStopMetId));
      expect(findingIds(withRepeat(14).ctx), contains(jaundiceStopNotMetId));
      expect(findingIds(withRepeat(14, 16).ctx), contains(jaundiceStopMetId));
      expect(
          finding(withRepeat(12.5), jaundiceStopMetId)
              .source
              .needsClinicalReview,
          isTrue);
    });
  });

  test('risk factors are recorded, not used to invent a pathway', () {
    final w = walk({
      jaundice
    }, {
      ...base(),
      jaundiceRiskKey: {
        JaundiceRisk.bloodGroup.name,
        JaundiceRisk.sibling.name
      },
    });
    expect(finding(w, 'jaundice.riskFactors').actions, [
      'Previous sibling requiring treatment for jaundice',
      'Blood group incompatibility (ABO/Rh)',
    ]);
    expect(findingIds(w.ctx), contains(jaundiceNoTsbId));
  });

  test('RD + Jaundice share baby details, asked once', () {
    final w = walk({
      rd,
      jaundice
    }, {
      ...base(ga: 36, kramer: 'zone5', cutoff: 'pending'),
      'rd_rr': 70,
    });
    expect(w.pages.where((p) => p == 'baby'), hasLength(1));
    expect(w.asked.where((q) => q == gaWeeksKey), hasLength(1));
    expect(findingIds(w.ctx), containsAll(['rd.present', jaundiceSeriousId]));
  });

  test('immediate actions: level ≥ action across STWs, most urgent first', () {
    final w = walk({
      rd,
      jaundice
    }, {
      ...base(ga: 36, kramer: 'zone5', cutoff: 'pending'),
      'rd_rr': 70,
    });
    final summary = CombinedAssessmentSummary.from(w.ctx);
    final actions = summary.immediateActions;
    expect(summary.showImmediateActions, isTrue);
    expect(actions.every((a) => a.$2.level.index >= FindingLevel.action.index),
        isTrue);
    for (var i = 1; i < actions.length; i++) {
      expect(actions[i - 1].$2.level.index,
          greaterThanOrEqualTo(actions[i].$2.level.index));
    }
    expect(actions.first.$2.id, jaundiceSeriousId);
    expect(actions.map((a) => a.$1.topic).toSet(), {rd, jaundice});
    expect(summary.toPlainText(), contains('IMMEDIATE ACTIONS'));
    // A single STW keeps its existing summary.
    expect(
        CombinedAssessmentSummary.from(
                walk({jaundice}, base(kramer: 'zone5')).ctx)
            .showImmediateActions,
        isFalse);
  });
}
