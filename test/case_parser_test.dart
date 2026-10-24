import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/case_entry/domain/case_parser.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';

import 'assessment_test_utils.dart';

const jaundice = NeonatalCondition.jaundice;
const hypo = NeonatalCondition.hypoglycemia;

void main() {
  group('worked example', () {
    for (final text in [
      '36 wk, 2.4 kg, day 3, RR 70/min, jaundice palms & soles',
      'Baby, 36 wk, BW 2.4 kg, day 3. RR 70/min. Jaundice up to palms and '
          'soles.',
    ]) {
      test(text, () {
        final c = parseCase(text);
        expect(c.topics, {rd, jaundice});
        expect(c.answers, {
          gaKnownKey: true,
          gaWeeksKey: 36,
          birthWeightKey: 2400,
          rdRrKey: 70,
          jaundiceAgeHoursKey: 72,
          jaundiceKramerKey: 'zone5',
          jaundiceRiskKey: {'gestationBelow38'},
        });
        expect(c.unrecognised, isEmpty);
        expect(c.topicReasons[rd], 'RR 70/min (≥60)');
        expect(c.topicReasons[jaundice], 'Kramer zone 5');
        final age = c.items.singleWhere((i) => i.key == jaundiceAgeHoursKey);
        expect(age.note, contains('check the age in hours'));
        expect(c.items.singleWhere((i) => i.key == birthWeightKey).note,
            'Converted from kg');
      });
    }

    test('pre-filled answers keep every value the engine accepts', () {
      final c =
          parseCase('36 wk, 2.4 kg, day 3, RR 70/min, jaundice palms & soles');
      final ctx = evalCtx(c.topics, c.answers);
      for (final e in c.answers.entries) {
        expect(ctx.answers[e.key], e.value, reason: e.key);
      }
      expect(findingIds(ctx), containsAll(['rd.present', jaundiceSeriousId]));
      // Nothing is confirmed: every page is still shown.
      expect(ctx.completedQuestions, isEmpty);
    });
  });

  test('kg → g; grams kept; implausible weights ignored', () {
    expect(parseCase('BW 1.85 kg').answers[birthWeightKey], 1850);
    expect(parseCase('birth weight 2400 g').answers[birthWeightKey], 2400);
    expect(parseCase('2400g').answers[birthWeightKey], 2400);
    expect(parseCase('weight 9 kg').answers, isNot(contains(birthWeightKey)));
    expect(parseCase('current weight 2.2 kg').answers,
        isNot(contains(birthWeightKey)));
  });

  test('Hinglish: piliya haath pair tak → jaundice, zone 5 with a note', () {
    final c = parseCase('piliya haath pair tak, 38 hafte');
    expect(c.topics, {jaundice});
    expect(c.answers[jaundiceKramerKey], 'zone5');
    expect(c.answers[gaWeeksKey], 38);
    expect(c.items.singleWhere((i) => i.key == jaundiceKramerKey).note,
        contains('change to zone 4'));
    expect(
        parseCase('peela chehra, piliya').answers[jaundiceKramerKey], 'zone1');
  });

  group('negation does not trigger a topic', () {
    test('no jaundice', () {
      final c = parseCase('37 wk, no jaundice');
      expect(c.topics, isEmpty);
      expect(c.notes, contains('Noted as absent: no jaundice'));
      expect(c.unrecognised, isEmpty);
    });
    test('RR normal, no grunting or retractions', () {
      final c = parseCase('RR normal, no grunting or retractions');
      expect(c.topics, isEmpty);
      expect(c.answers, isEmpty);
      expect(c.unrecognised, isEmpty);
    });
    test('RR below 60 alone does not select RD', () {
      final c = parseCase('RR 48/min');
      expect(c.topics, isEmpty);
      expect(c.answers[rdRrKey], 48);
    });
    test('grunting present but no flaring', () {
      final c = parseCase('grunting present but no flaring');
      expect(c.topics, {rd});
      expect(c.answers[rdSignsKey], {'grunting'});
    });
  });

  test('missing values give no answer', () {
    final c = parseCase('jaundice');
    expect(c.topics, {jaundice});
    expect(c.answers, isEmpty);
    expect(parseCase('').isEmpty, isTrue);
  });

  test('day 1 is not converted (could be under or over 24 h)', () {
    final c = parseCase('day 1, jaundice face');
    expect(c.answers, isNot(contains(jaundiceAgeHoursKey)));
    expect(c.flags, [
      contains('Enter the age in hours'),
      contains('Gestational age not recorded'),
    ]);
    expect(parseCase('20 hrs old, jaundice face').answers[jaundiceAgeHoursKey],
        20);
    expect(parseCase('jaundice in first 24 hrs').answers,
        isNot(contains(jaundiceAgeHoursKey)));
  });

  test('unrecognised parts are listed, never silently used', () {
    final c =
        parseCase('38 wk, mother O positive, jaundice chest, cord clamped');
    expect(c.unrecognised, ['mother O positive', 'cord clamped']);
    expect(c.answers[jaundiceKramerKey], 'zone2');
  });

  test('ABE signs and bilirubin values fill jaundice answers', () {
    final c = parseCase(
        '39 wk, 4 days old, jaundice up to legs, lethargic, poor feeding, '
        'arching, TSB 22 mg/dL, TcB 19');
    expect(c.topics, {jaundice});
    expect(c.answers[jaundiceAgeHoursKey], 96);
    expect(c.answers[jaundiceKramerKey], 'zone4');
    expect(c.answers[jaundiceAbeKey], {'lethargy', 'poorSuck'});
    expect(c.answers[jaundicePostureKey], {'arching'});
    expect(c.answers[jaundiceTsbKey], 22);
    expect(c.answers[jaundiceTcbKey], 19);
    // TSB in mg/dL is not read as a blood glucose.
    expect(c.answers, isNot(contains(hypoBgKey)));
  });

  test('BG selects hypoglycemia; extent words bind to jaundice, not RD', () {
    final c = parseCase('35 wk, BG 38 mg/dl, chest retractions, jaundice face');
    expect(c.topics, {rd, hypo, jaundice});
    expect(c.answers[hypoBgKey], 38);
    expect(c.answers[rdSignsKey], {'retractions'});
    expect(c.answers[jaundiceKramerKey], 'zone1');
  });

  test('explicit sepsis / asphyxia mentions select their STW', () {
    expect(parseCase('suspected sepsis, 37 wk').topics,
        {NeonatalCondition.sepsis});
    expect(parseCase('birth asphyxia').topics, {NeonatalCondition.hie});
    expect(parseCase('no sepsis').topics, isEmpty);
  });
}
