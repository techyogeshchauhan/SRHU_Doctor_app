import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_content.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/data/ancs_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/data/disease_follow_up_registry.dart';
import 'package:neonatal_stw/features/follow_up/data/hypo_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/domain/follow_up_models.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_content.dart';

String correct(List<FollowUpQuestion> qs, String id) =>
    qs.singleWhere((q) => q.id == id).correctAnswer;

void main() {
  final packages = {
    NeonatalCondition.ancs: (
      'ancs_',
      'Antenatal Corticosteroids for Preterm Birth',
      ancsFollowUpMcqs,
      ancsFollowUpCaseScenarios,
    ),
    NeonatalCondition.hypoglycemia: (
      'hypo_',
      'Neonatal Hypoglycemia',
      hypoFollowUpMcqs,
      hypoFollowUpCaseScenarios,
    ),
  };

  for (final MapEntry(key: c, value: (prefix, doc, mcqs, cases))
      in packages.entries) {
    test('${c.name}: 8 MCQs + 6 cases, well-formed, each citing the STW', () {
      expect(mcqs, hasLength(8));
      expect(cases, hasLength(6));
      final all = [...mcqs, ...cases];
      expect(all.map((q) => q.id).toSet(), hasLength(all.length));
      for (final q in all) {
        expect(q.id, startsWith(prefix));
        expect(q.disease, c);
        expect(q.options, hasLength(4), reason: q.id);
        expect(q.options.toSet(), hasLength(4), reason: q.id);
        expect(q.correctAnswerIndex, inInclusiveRange(0, 3), reason: q.id);
        expect(q.explanation, isNotEmpty, reason: q.id);
        expect(q.stwReference, contains('ICMR/DHR STW "$doc"'), reason: q.id);
      }
      for (final q in mcqs) {
        expect(q.questionType, QuestionType.mcq);
      }
      for (final q in cases) {
        expect(q.questionType, QuestionType.caseScenario);
        expect(q.scenario, isNotEmpty, reason: q.id);
      }
      expect(hasFollowUpForCondition(c), isTrue);
    });
  }

  test('ANCS answers match the STW wording', () {
    expect(correct(ancsFollowUpMcqs, 'ancs_mcq_1'), '24+0 to 33+6 weeks');
    expect(correct(ancsFollowUpMcqs, 'ancs_mcq_2'),
        'Dexamethasone sodium phosphate 6 mg IM every 12 hours x 4 doses');
    expect(correct(ancsFollowUpMcqs, 'ancs_mcq_3'),
        'It is effective, low-cost, widely available and more heat-stable');
    expect(ancsDexaPreferred, contains('effective, low-cost, widely available '
        'and more heat-stable'));
    expect(correct(ancsFollowUpMcqs, 'ancs_mcq_5'), ancsNotGiveInfection);
    expect(correct(ancsFollowUpMcqs, 'ancs_mcq_8'), '≥80%');
  });

  test('Hypoglycemia answers match the STW wording', () {
    expect(correct(hypoFollowUpMcqs, 'hypo_mcq_1'), hypoEntry);
    expect(correct(hypoFollowUpMcqs, 'hypo_mcq_3'),
        '1, 2, 6, 12, 24, 48, 72 hours');
    expect(hypoBolus,
        contains('2 ml/kg of 10% of dextrose slowly over 1 minute'));
    expect(correct(hypoFollowUpMcqs, 'hypo_mcq_5'), '6 mg/kg/min');
    expect(correct(hypoFollowUpMcqs, 'hypo_mcq_7'), hypoHydrocortisone);
    expect(correct(hypoFollowUpMcqs, 'hypo_mcq_8'), '> 12.5-15% dextrose');
  });

  test('controller loads the package and labels it', () {
    final controller = FollowUpController();
    controller.initForCondition(NeonatalCondition.ancs);
    expect(controller.state.mcqs, same(ancsFollowUpMcqs));
    expect(controller.state.shortName, 'ANCS');
    controller.initForCondition(NeonatalCondition.hypoglycemia);
    expect(controller.state.caseScenarios, same(hypoFollowUpCaseScenarios));
    expect(controller.state.shortName, 'Hypoglycemia');
    // ROP keeps its existing labels.
    controller.initForCondition(NeonatalCondition.rop);
    expect(controller.state.shortName, 'ROP');
    expect(hasFollowUpForCondition(NeonatalCondition.respiratoryDistress),
        isFalse);
  });
}
