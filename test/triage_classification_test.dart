import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/triage/domain/triage_treatment.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

const _engine = AssessmentEngine();
final _today = DateTime(2026, 10, 17);

ClinicalAssessmentContext _eval(Map<String, Object?> answers) =>
    _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: answers,
      today: _today,
    );

Object? _category(Map<String, Object?> answers) =>
    _eval(answers).valueOf(triageCategoryKey);

TriageProtocolCard _card(ClinicalAssessmentContext ctx, String id) =>
    triageTreatmentCards(ctx).singleWhere((c) => c.id == id);

Set<String> _applicable(ClinicalAssessmentContext ctx) =>
    {for (final rq in _engine.applicableQuestions(ctx)) rq.id};

const _history = {
  triageMaternalRisksKey,
  triageRhStatusKey,
  triageAntenatalSteroidsKey,
  triageMaternalHistoryKey,
  triageNewbornRisksKey,
  triageNewbornHistoryKey,
};

/// Triage page questions shown by default (the symptomatic question
/// depends on the RBS).
const _page1 = {
  triageFastTrackKey,
  ..._history,
  triageWeightKey,
  triageGestationKey,
  triageTemperatureKey,
  triageHeartRateKey,
  triageRespiratoryRateKey,
  triageSpo2Key,
  triageBloodGlucoseKey,
  triageEmergencySignsKey,
};

const _page2 = {
  triageExamLookKey,
  triageExamListenKey,
  triageAirEntryKey,
  triageExamFeelKey,
  triageFontanelleKey,
  triageToneKey,
};

void main() {
  group('every single emergency trigger classifies EMERGENCY', () {
    final triggers = <String, Map<String, Object?>>{
      'HR 210': {triageHeartRateKey: 210},
      'apnea': {
        triageEmergencySignsKey: <Object>{'apnea'}
      },
      'central cyanosis': {
        triageEmergencySignsKey: <Object>{'centralCyanosis'}
      },
      'SpO2 88': {triageSpo2Key: 88},
      'seizures': {
        triageEmergencySignsKey: <Object>{'convulsionsComa'}
      },
      'shock': {
        triageEmergencySignsKey: <Object>{'shock'}
      },
      'RBS 35': {triageBloodGlucoseKey: 35},
      'RBS 38': {triageBloodGlucoseKey: 38},
      'temperature 35.0': {triageTemperatureKey: 35.0},
    };
    for (final MapEntry(key: name, value: answers) in triggers.entries) {
      test(name, () {
        final ctx = _eval(answers);
        expect(ctx.valueOf(triageCategoryKey), triageEmergency);
        expect(triageReasonsFor(ctx), isNotEmpty);
        expect(ctx.findings.where((f) => f.id == 'triage.emergencyActions'),
            hasLength(1));
      });
    }
  });

  test('values at the thresholds do not trigger EMERGENCY', () {
    expect(_category({triageHeartRateKey: 200}), isNull);
    expect(_category({triageSpo2Key: 91}), isNull);
    expect(_category({triageBloodGlucoseKey: 45}), isNull);
  });

  test('emergency with priority signs is EMERGENCY, never a choice', () {
    final ctx = _eval({
      triageHeartRateKey: 210,
      triageWeightKey: 1500,
      triageTemperatureKey: 36.0,
    });
    expect(ctx.valueOf(triageCategoryKey), triageEmergency);
    expect(ctx.valueOf(triageMatchedCategoriesKey),
        {triageEmergency, triagePriority});
    // No category question exists at all.
    final questions = _engine.resolve({NeonatalCondition.triage});
    expect(questions.where((q) => q.id == 'triage_category'), isEmpty);
    expect(questions.where((q) => q.question.question.contains('category')),
        isEmpty);
  });

  test('without emergency triggers Priority comes from temperature or weight',
      () {
    expect(_category({triageWeightKey: 1500}), triagePriority);
    expect(_category({triageTemperatureKey: 36.0}), triagePriority);
    expect(
        _category({triageWeightKey: 2500, triageTemperatureKey: 36.8}), isNull);
    expect(_category({}), isNull);
  });

  test('history, vitals, emergency signs and the examination are asked', () {
    final ids = {
      for (final rq in _engine.resolve({NeonatalCondition.triage})) rq.id,
    };
    expect(ids, {..._page1, triageHypoglycemiaSymptomsKey, ..._page2});
    for (final removed in [
      'triage_perfusion_signs',
      'triage_priority_signs',
      'triage_nonurgent_signs',
      'triage_specific_findings',
    ]) {
      for (final g in triageGroups) {
        expect(g.questionOrder, isNot(contains(removed)));
      }
    }
  });

  test('confirmed with no trigger: no category, no invented label', () {
    final r = _engine.confirmPage(
        _eval({triageWeightKey: 2500}), triageAssessmentGroup);
    final done = _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: r.answers,
      completed: r.completed,
      today: _today,
    );
    expect(done.valueOf(triageCategoryKey), isNull);
    expect(done.findings.map((f) => f.id),
        contains('triage.classificationUndetermined'));
  });

  test('Triage page, then the examination page, then the results', () {
    expect(_engine.nextGroup(_eval({})), triageAssessmentGroup);
    var r = _engine.confirmPage(
        _eval({triageHeartRateKey: 210}), triageAssessmentGroup);
    var ctx = _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: r.answers,
      completed: r.completed,
      today: _today,
    );
    expect(_engine.nextGroup(ctx), triageExaminationGroup);
    expect(ctx.valueOf(triageCategoryKey), triageEmergency);
    r = _engine.confirmPage(ctx, triageExaminationGroup);
    ctx = _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: r.answers,
      completed: r.completed,
      today: _today,
    );
    expect(_engine.nextGroup(ctx), isNull);
    // Nothing ticked is recorded as none.
    expect(ctx.answers[triageExamLookKey], <Object>{});
    expect(ctx.valueOf(triageCategoryKey), triageEmergency);
  });

  test('fast-track shows only emergency signs before examination', () {
    final all = {..._page1, ..._page2};
    expect(_applicable(_eval({})), all);
    expect(_applicable(_eval({triageFastTrackKey: true})),
        {triageFastTrackKey, triageEmergencySignsKey, ..._page2});
  });

  test('fast-track drops history, measurements and dependent symptoms', () {
    final answers = <String, Object?>{
      triageMaternalRisksKey: <Object>{'foulLiquor'},
      triageRhStatusKey: 'negative',
      triageAntenatalSteroidsKey: 'complete',
      triageMaternalHistoryKey: 'maternal fever',
      triageNewbornRisksKey: <Object>{'delayedCry'},
      triageNewbornHistoryKey: 'not feeding',
      triageWeightKey: 1500,
      triageGestationKey: triagePreterm,
      triageTemperatureKey: 35.0,
      triageHeartRateKey: 210,
      triageRespiratoryRateKey: 70,
      triageSpo2Key: 85,
      triageBloodGlucoseKey: 35,
      triageHypoglycemiaSymptomsKey: true,
      triageExamLookKey: <Object>{'jaundice'},
    };
    final sick = _eval({...answers, triageFastTrackKey: true});
    expect(sick.answers.keys, {triageFastTrackKey, triageExamLookKey});
    expect(sick.valueOf(triageCategoryKey), isNull);
    expect(sick.valueOf(triageHypoglycemiaKey), isFalse);
    expect(sick.valueOf(triageTachypneaKey), isFalse);
    expect([for (final s in triageStwSuggestions(sick)) s.stw],
        [NeonatalCondition.jaundice]);
  });

  test('fast-track emergency signs continue through examination to results',
      () {
    var ctx = _eval({
      triageFastTrackKey: true,
      triageEmergencySignsKey: <Object>{'shock'},
    });
    expect(_engine.nextGroup(ctx), triageAssessmentGroup);
    expect(_engine.pageQuestions(ctx, triageAssessmentGroup).map((q) => q.id),
        [triageFastTrackKey, triageEmergencySignsKey]);
    for (final group in [triageAssessmentGroup, triageExaminationGroup]) {
      expect(_engine.canConfirm(ctx, group), isTrue);
      final r = _engine.confirmPage(ctx, group);
      ctx = _engine.evaluate(
        selected: ctx.selected,
        answers: r.answers,
        completed: r.completed,
        today: _today,
      );
      expect(_engine.nextGroup(ctx),
          group == triageAssessmentGroup ? triageExaminationGroup : null);
      expect(ctx.valueOf(triageCategoryKey), triageEmergency);
      expect(_card(ctx, 'circulation').flagged, isTrue);
    }
  });

  test('fast-track off: every question is asked as before', () {
    expect(
      _applicable(_eval({triageFastTrackKey: false})),
      _applicable(_eval({})),
    );
  });

  test('the symptomatic question applies only when 20 <= RBS < 45', () {
    for (final (bg, shown) in [
      (null, false),
      (15, false),
      (20, true),
      (35, true),
      (44, true),
      (45, false),
      (80, false),
    ]) {
      expect(
          _applicable(_eval({triageBloodGlucoseKey: bg}))
              .contains(triageHypoglycemiaSymptomsKey),
          shown,
          reason: 'RBS $bg');
    }
  });

  test('RBS 35 flags the Hypoglycemia card with direct STW links', () {
    final ctx = _eval({triageBloodGlucoseKey: 35});
    final card = _card(ctx, 'hypoglycemia');
    expect(card.flagged, isTrue);
    expect(card.links.map((l) => l.regionId), contains('triage_hypoglycemia'));
    expect(
        card.links.map((l) => l.stw), contains(NeonatalCondition.hypoglycemia));
    expect(_card(ctx, 'shock').flagged, isFalse);
  });

  test('RBS 35 asymptomatic: feeding branch, not IV dextrose (STW)', () {
    final ctx = _eval({
      triageBloodGlucoseKey: 35,
      triageHypoglycemiaSymptomsKey: false,
    });
    final card = _card(ctx, 'hypoglycemia');
    final applies = card.actions.where((a) => a.applies).map((a) => a.text);
    expect(applies.single, contains('supervised breastfeeding'));
    expect(
        ctx.findings.map((f) => f.id),
        containsAll(
            ['triage.hypoglycemia.feeding', 'triage.glucoseEmergencyTrigger']));
    expect(ctx.findings.map((f) => f.id),
        isNot(contains('triage.hypoglycemia.iv')));
    final trigger = ctx.findings
        .singleWhere((f) => f.id == 'triage.glucoseEmergencyTrigger');
    expect(trigger.source.needsClinicalReview, isTrue);
  });

  test('RBS 35 symptomatic or RBS <20: IV dextrose with the bolus volume', () {
    for (final answers in [
      {triageBloodGlucoseKey: 35, triageHypoglycemiaSymptomsKey: true},
      {triageBloodGlucoseKey: 15},
    ]) {
      final ctx = _eval({...answers, triageWeightKey: 2500});
      final card = _card(ctx, 'hypoglycemia');
      final applies =
          card.actions.where((a) => a.applies).map((a) => a.text).join('\n');
      expect(applies, contains('10% dextrose IV'));
      expect(applies, contains('= 5 mL of 10% dextrose'));
      expect(card.links.map((l) => l.regionId),
          contains('hypo_symptomatic_branch'));
      expect(ctx.findings.map((f) => f.id), contains('triage.hypoglycemia.iv'));
    }
  });

  test('the Shock emergency sign highlights the Shock -> Bolus pathway', () {
    for (final sign in ['shock']) {
      final ctx = _eval({
        triageEmergencySignsKey: <Object>{sign},
        triageGestationKey: triagePreterm,
        triageWeightKey: 2000,
      });
      final shock = _card(ctx, 'shock');
      expect(shock.flagged, isTrue, reason: sign);
      expect(shock.links.single.regionId, 'triage_shock');
      final applies = shock.actions.where((a) => a.applies).map((a) => a.text);
      expect(applies, contains('Preterm: give the NS bolus over 30–60 min.'));
      expect(applies.join(), contains('= 20 mL of NS'));
      expect(_card(ctx, 'circulation').flagged, isTrue);
      expect(ctx.findings.map((f) => f.id), contains('triage.shock'));
    }
  });

  test('apnea flags Airway, Breathing and Respiratory distress', () {
    final ctx = _eval({
      triageEmergencySignsKey: <Object>{'apnea'}
    });
    for (final id in ['airway', 'breathing', 'respiratory']) {
      expect(_card(ctx, id).flagged, isTrue, reason: id);
    }
    expect(_card(ctx, 'respiratory').links.map((l) => l.regionId),
        contains('rd_immediate_actions'));
    expect(_card(ctx, 'shock').flagged, isFalse);
  });

  test('every card link points at an existing box of its STW', () {
    final regions = {
      for (final r
          in jsonDecode(File('assets/regions/regions.json').readAsStringSync())
              as List)
        (r as Map)['id'] as String,
    };
    final ctx = _eval({
      triageBloodGlucoseKey: 15,
      triageEmergencySignsKey: <Object>{'shock'},
    });
    for (final card in triageTreatmentCards(ctx)) {
      expect(card.links, isNotEmpty, reason: card.id);
      for (final link in card.links) {
        final prefix = switch (link.stw) {
          NeonatalCondition.triage => 'triage_',
          NeonatalCondition.hypoglycemia => 'hypo_',
          NeonatalCondition.respiratoryDistress => 'rd_',
          _ => '?',
        };
        expect(link.regionId, startsWith(prefix), reason: card.id);
        expect(regions, contains(link.regionId), reason: card.id);
      }
    }
  });

  test('Baby details show the Triage gestation and weight', () {
    String line(Map<String, Object?> answers) {
      final subjects = CombinedAssessmentSummary.from(_eval(answers)).subjects;
      expect(subjects, hasLength(1));
      expect(subjects.single.label, 'Baby');
      return subjects.single.line;
    }

    expect(line({}), 'GA — · Weight —');
    expect(line({triageGestationKey: triageTerm, triageWeightKey: 2500}),
        'GA Term · Weight 2.5 kg');
    expect(line({triageGestationKey: triagePreterm, triageWeightKey: 1250}),
        'GA Preterm · Weight 1.25 kg');
    expect(
        CombinedAssessmentSummary.from(_eval({triageWeightKey: 2500}))
            .toPlainText(),
        contains('Baby: GA — · Weight 2.5 kg'));
  });

  group('respiratory rate', () {
    Set<String> findingIds(ClinicalAssessmentContext ctx) =>
        {for (final f in ctx.findings) f.id};

    test('RR >=60/min without retractions or grunt classifies PRIORITY', () {
      final ctx = _eval({triageRespiratoryRateKey: 70});
      expect(ctx.valueOf(triageTachypneaKey), isTrue);
      expect(ctx.valueOf(triageCategoryKey), triagePriority);
      expect(triageReasonsFor(ctx), [
        'RR 70/min (≥60/min): tachypnea without retractions or grunt',
      ]);
    });

    test('the threshold is the RD STW value: 60/min', () {
      expect(_eval({triageRespiratoryRateKey: 59}).valueOf(triageCategoryKey),
          isNull);
      expect(_eval({triageRespiratoryRateKey: 60}).valueOf(triageCategoryKey),
          triagePriority);
    });

    test('abnormal RR directs to the Respiratory Distress STW', () {
      final ctx = _eval({triageRespiratoryRateKey: 72});
      final f = ctx.findings
          .singleWhere((f) => f.id == 'triage.respiratoryDistressStw');
      expect(f.source.document, rdStwDocument);
      expect(f.source.pdfRegionId, 'rd_diagnostic_criteria');
      expect(f.content.why, ['RR 72/min (≥60/min)']);
      expect(f.content.actions,
          contains('Select Respiratory Distress as the next STW.'));
      for (final id in ['breathing', 'respiratory']) {
        final card = _card(ctx, id);
        expect(card.flaggedBecause, contains('RR 72/min (≥60/min)'));
        expect(card.links.map((l) => l.stw),
            contains(NeonatalCondition.respiratoryDistress));
      }
    });

    test('with retractions or grunt it is the Emergency sign instead', () {
      final ctx = _eval({
        triageRespiratoryRateKey: 70,
        triageEmergencySignsKey: <Object>{'respiratoryDistress'},
      });
      expect(ctx.valueOf(triageCategoryKey), triageEmergency);
      expect(ctx.valueOf(triagePriorityReasonsKey), isEmpty);
      expect(findingIds(ctx), contains('triage.respiratoryDistressStw'));
    });

    test('the respiratory distress sign alone also directs to the RD STW', () {
      final ctx = _eval({
        triageEmergencySignsKey: <Object>{'respiratoryDistress'},
      });
      expect(findingIds(ctx), contains('triage.respiratoryDistressStw'));
    });

    test('normal or blank RR: no tachypnea, no RD finding', () {
      for (final answers in [
        <String, Object?>{},
        {triageRespiratoryRateKey: 45},
      ]) {
        final ctx = _eval(answers);
        expect(ctx.valueOf(triageTachypneaKey), isFalse);
        expect(
            findingIds(ctx), isNot(contains('triage.respiratoryDistressStw')));
        expect(_card(ctx, 'breathing').flagged, isFalse);
      }
    });
  });

  test("DOs, DON'Ts and KPIs are not part of the Triage results", () {
    final r = _engine.confirmPage(
        _eval({triageHeartRateKey: 210}), triageAssessmentGroup);
    final done = _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: r.answers,
      completed: r.completed,
      today: _today,
    );
    final ids = {for (final f in done.findings) f.id};
    expect(
        ids,
        isNot(anyOf(contains('triage.dos'), contains('triage.donts'),
            contains('triage.kpis'))));
    // The other results are still given.
    expect(
        ids,
        containsAll([
          'triage.initialChecks',
          'triage.followSpecific',
          'triage.persistentTachycardia'
        ]));
  });

  test('Circulation no longer lists persistent HR >200/min', () {
    final ctx = _eval({triageHeartRateKey: 210});
    final circulation = _card(ctx, 'circulation');
    expect(circulation.flagged, isFalse);
    expect(circulation.actions.map((a) => a.text).join(),
        isNot(contains('Persistent HR')));
    // Still covered by the Temperature card and the summary finding.
    expect(_card(ctx, 'temperature').flagged, isTrue);
    expect(ctx.findings.map((f) => f.id),
        contains('triage.persistentTachycardia'));
  });
}
