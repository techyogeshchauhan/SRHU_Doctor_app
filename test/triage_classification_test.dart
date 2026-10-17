import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
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
        expect(
            ctx.findings.where((f) => f.id == 'triage.emergencyActions'),
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
    expect(
        questions.where((q) => q.question.question.contains('category')),
        isEmpty);
  });

  test('without emergency triggers Priority comes from temperature or weight',
      () {
    expect(_category({triageWeightKey: 1500}), triagePriority);
    expect(_category({triageTemperatureKey: 36.0}), triagePriority);
    expect(_category({triageWeightKey: 2500, triageTemperatureKey: 36.8}),
        isNull);
    expect(_category({}), isNull);
  });

  test('only history, vitals and emergency signs are asked', () {
    final ids = {
      for (final rq in _engine.resolve({NeonatalCondition.triage})) rq.id,
    };
    expect(ids, {
      triageFastTrackKey,
      triageMaternalHistoryKey,
      triageNewbornHistoryKey,
      triageWeightKey,
      triageGestationKey,
      triageTemperatureKey,
      triageHeartRateKey,
      triageSpo2Key,
      triageBloodGlucoseKey,
      triageHypoglycemiaSymptomsKey,
      triageEmergencySignsKey,
    });
    for (final removed in [
      'triage_perfusion_signs',
      'triage_priority_signs',
      'triage_nonurgent_signs',
      'triage_specific_findings',
    ]) {
      expect(triageGroups.single.questionOrder, isNot(contains(removed)));
    }
  });

  test('confirmed with no trigger: no category, no invented label', () {
    final r = _engine.confirmPage(_eval({triageWeightKey: 2500}),
        triageAssessmentGroup);
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

  test('Triage is a single page that goes straight to the results', () {
    final first = _eval({});
    final group = _engine.nextGroup(first);
    expect(group, triageAssessmentGroup);
    final r = _engine.confirmPage(
        _eval({triageHeartRateKey: 210}), triageAssessmentGroup);
    final done = _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: r.answers,
      completed: r.completed,
      today: _today,
    );
    expect(_engine.nextGroup(done), isNull);
    expect(done.valueOf(triageCategoryKey), triageEmergency);
  });

  test('fast-track hides the maternal and newborn history', () {
    expect(_applicable(_eval({})),
        containsAll([triageMaternalHistoryKey, triageNewbornHistoryKey]));
    final sick = _applicable(_eval({triageFastTrackKey: true}));
    expect(sick, isNot(contains(triageMaternalHistoryKey)));
    expect(sick, isNot(contains(triageNewbornHistoryKey)));
    expect(sick, contains(triageHeartRateKey));
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
    expect(card.links.map((l) => l.stw), contains(NeonatalCondition.hypoglycemia));
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
    expect(ctx.findings.map((f) => f.id),
        containsAll(['triage.hypoglycemia.feeding', 'triage.glucoseEmergencyTrigger']));
    expect(ctx.findings.map((f) => f.id),
        isNot(contains('triage.hypoglycemia.iv')));
    final trigger =
        ctx.findings.singleWhere((f) => f.id == 'triage.glucoseEmergencyTrigger');
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
      for (final r in jsonDecode(
              File('assets/regions/regions.json').readAsStringSync()) as List)
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
}
