import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/case_entry/domain/case_parser.dart';
import 'package:neonatal_stw/features/case_entry/domain/structured_case.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_workflow.dart';
import 'package:neonatal_stw/features/post_asphyxia/domain/post_asphyxia_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/sepsis/domain/sepsis_workflow.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

import 'assessment_test_utils.dart';

const jaundice = NeonatalCondition.jaundice;

StructuredCase example() => StructuredCase(
      gaStatus: GaStatus.known,
      gaWeeks: '36',
      birthWeightKg: '2.4',
      age: '3',
      ageUnit: AgeUnit.days,
      rr: '70',
      jaundice: YesNoUnknown.yes,
      kramer: 'zone5',
    );

void main() {
  group('worked example without typing a narrative', () {
    test('summary shows the values as entered', () {
      expect([
        for (final (_, l, v) in example().summary()) '$l: $v'
      ], [
        'Gestational age: 36 weeks',
        'Birth weight: 2.4 kg',
        'Age: 3 days',
        'Respiratory rate: 70 breaths/min',
        'Respiratory signs: Not assessed',
        'Jaundice: Present',
        'Extent: Zone 5: Palms and soles',
      ]);
    });

    test('analysis finds RD and Jaundice with the existing rules', () {
      final c = example().toParsedCase();
      expect(c.topics, {rd, jaundice});
      expect(
          c.answers,
          {
            gaKnownKey: true,
            gaWeeksKey: 36,
            birthWeightKey: 2400,
            rdRrKey: 70,
            jaundiceAgeHoursKey: 72,
            jaundiceBefore24hKey: null,
            jaundiceKramerKey: 'zone5',
            jaundiceRiskKey: {'gestationBelow38'},
          }..remove(jaundiceBefore24hKey));
      expect(c.items.singleWhere((i) => i.key == birthWeightKey).note,
          'Entered as 2.4 kg');
      expect(c.items.singleWhere((i) => i.key == jaundiceAgeHoursKey).note,
          contains('check the age in hours'));

      // The engine keeps every value; findings come from the STW rules.
      final ctx = evalCtx(c.topics, c.answers);
      for (final e in c.answers.entries) {
        expect(ctx.answers[e.key], e.value, reason: e.key);
      }
      expect(ctx.completedQuestions, isEmpty);
      expect(findingIds(ctx), containsAll(['rd.present', jaundiceSeriousId]));
    });
  });

  group('validation: invalid values are reported, never accepted', () {
    test('birth weight 99 kg and non-numbers', () {
      expect(StructuredCase(birthWeightKg: '99').validate(),
          {CaseField.birthWeightKg: 'Check the birth weight: enter 0.3–6 kg.'});
      expect(StructuredCase(birthWeightKg: 'abc').validate(),
          {CaseField.birthWeightKg: 'Enter the birth weight as a number.'});
      expect(StructuredCase(birthWeightKg: '2,4').validate(), isEmpty);
    });

    test('GA: required once marked known, 22–44 weeks, 0–6 days', () {
      expect(StructuredCase(gaStatus: GaStatus.known).validate(),
          contains(CaseField.gaWeeks));
      expect(StructuredCase(gaStatus: GaStatus.known, gaWeeks: '50').validate(),
          {CaseField.gaWeeks: 'Check the gestational age: enter 22–44 weeks.'});
      expect(
          StructuredCase(gaStatus: GaStatus.known, gaWeeks: '36.5')
              .validate()[CaseField.gaWeeks],
          contains('whole number'));
      expect(
          StructuredCase(gaStatus: GaStatus.known, gaWeeks: '36', gaDays: '9')
              .validate(),
          contains(CaseField.gaDays));
      expect(
          StructuredCase(gaStatus: GaStatus.notRecorded).validate(), isEmpty);
    });

    test('age limits follow the unit; RR, temperature, bilirubin, BG', () {
      expect(StructuredCase(age: '800').validate(), contains(CaseField.age));
      expect(StructuredCase(age: '40', ageUnit: AgeUnit.days).validate(),
          contains(CaseField.age));
      expect(StructuredCase(rr: '200').validate(), contains(CaseField.rr));
      expect(StructuredCase(temperature: '98.6').validate(),
          contains(CaseField.temperature));
      expect(
          StructuredCase(
                  temperature: '98.6',
                  temperatureUnit: TemperatureUnit.fahrenheit)
              .validate(),
          isEmpty);
      expect(StructuredCase(bg: '900').validate(), contains(CaseField.bg));
      // Bilirubin is checked only while jaundice is recorded as present.
      expect(StructuredCase(tcb: '55').validate(), isEmpty);
      expect(StructuredCase(jaundice: YesNoUnknown.yes, tcb: '55').validate(),
          contains(CaseField.tcb));
    });

    test('an empty form has no errors and no topics', () {
      final c = StructuredCase();
      expect(c.validate(), isEmpty);
      expect(c.toParsedCase().topics, isEmpty);
    });
  });

  group('temperature is recorded, not classified', () {
    test('°F is converted with a note; no topic is selected', () {
      final c = StructuredCase(
              temperature: '95', temperatureUnit: TemperatureUnit.fahrenheit)
          .toParsedCase();
      expect(c.topics, isEmpty);
      final t = c.items.singleWhere((i) => i.key == triageTemperatureKey);
      expect(t.value, 35.0);
      expect(t.note, 'Entered as 95 °F, converted to °C');
      expect(c.notes, contains(contains('not classified')));
    });

    test('it reaches only Triage, and only when Triage is selected', () {
      final c = StructuredCase(temperature: '35', rr: '70').toParsedCase();
      expect(c.topics, {rd});
      expect(evalCtx(c.topics, c.answers).answers,
          isNot(contains(triageTemperatureKey)));
      expect(
          evalCtx({...c.topics, NeonatalCondition.triage}, c.answers)
              .answers[triageTemperatureKey],
          35.0);
    });
  });

  group('missing, unknown and conflicting information is flagged', () {
    test('jaundice unknown: flagged, Jaundice STW not selected', () {
      final c = StructuredCase(jaundice: YesNoUnknown.unknown).toParsedCase();
      expect(c.topics, isEmpty);
      expect(c.flags.single, contains('Jaundice not assessed'));
    });

    test('jaundice absent selects nothing', () {
      final c = StructuredCase(jaundice: YesNoUnknown.no).toParsedCase();
      expect(c.topics, isEmpty);
      expect(c.flags, isEmpty);
    });

    test('jaundice present without extent, GA or exact age', () {
      final c = StructuredCase(
              jaundice: YesNoUnknown.yes, age: '0', ageUnit: AgeUnit.days)
          .toParsedCase();
      expect(c.topics, {jaundice});
      expect(c.answers, isNot(contains(jaundiceAgeHoursKey)));
      expect(c.flags, [
        contains('Age 0 days'),
        contains('Jaundice extent not recorded'),
        contains('Gestational age not recorded'),
      ]);
    });

    test('"none of these" with RR ≥60 explains that RR is itself a sign', () {
      final c =
          StructuredCase(rr: '72', rdStatus: SignsStatus.none).toParsedCase();
      expect(c.topics, {rd});
      expect(c.answers[rdSignsKey], <Object>{});
      expect(c.notes.single, contains('RR 72/min is itself an RD sign'));
    });

    test('GA uncertain pre-fills "GA uncertain"', () {
      final c =
          StructuredCase(gaStatus: GaStatus.uncertain, rr: '65').toParsedCase();
      expect(c.answers[gaKnownKey], false);
      expect(c.answers, isNot(contains(gaWeeksKey)));
    });

    test('"visible in first 24 hrs" only for babies 24 h or older', () {
      StructuredCase j(String age) => StructuredCase(
          jaundice: YesNoUnknown.yes,
          kramer: 'zone1',
          age: age,
          before24h: YesNoUnknown.yes);
      expect(j('10').asksBefore24h, isFalse);
      expect(j('10').toParsedCase().answers,
          isNot(contains(jaundiceBefore24hKey)));
      expect(j('30').toParsedCase().answers[jaundiceBefore24hKey], isTrue);
    });
  });

  test('one case can select several STWs, from existing STW options only', () {
    final c = StructuredCase(
      gaStatus: GaStatus.known,
      gaWeeks: '34',
      birthWeightKg: '1.9',
      age: '20',
      bg: '38',
      hypoRisks: {'preterm'},
      sepsisYellow: {'lethargy'},
      paRisk: {'resuscitation'},
      rdStatus: SignsStatus.present,
      rdSigns: {'grunting'},
    ).toParsedCase();
    expect(c.topics, {
      rd,
      sepsis,
      NeonatalCondition.hypoglycemia,
      NeonatalCondition.hie,
    });
    expect(c.answers[hypoBgKey], 38);
    expect(c.answers[hypoRiskKey], {'preterm'});
    expect(c.answers[sepsisStageKey], 'initial');
    expect(c.answers[sepsisAgeKey], 20);
    expect(c.answers[sepsisBwKey], 1900);
    expect(c.answers[qPaRisk.id], {'resuscitation'});
    final ctx = evalCtx(c.topics, c.answers);
    // No selected STW asks the shared birth weight here (RD with GA known;
    // Sepsis has its own field): the engine drops it and the analysis screen
    // says so. Every other value is kept.
    expect(ctx.answers, isNot(contains(birthWeightKey)));
    for (final e in c.answers.entries) {
      if (e.key == birthWeightKey) continue;
      expect(ctx.answers[e.key], e.value, reason: e.key);
    }
  });

  test('text and form input share one builder', () {
    final fromText = parseCase('36 wk, 2.4 kg, 72 hrs, RR 70/min, jaundice '
        'palms & soles');
    final fromForm = (example()
          ..age = '72'
          ..ageUnit = AgeUnit.hours)
        .toParsedCase();
    expect(fromForm.topics, fromText.topics);
    expect(fromForm.answers, fromText.answers);
  });
}
