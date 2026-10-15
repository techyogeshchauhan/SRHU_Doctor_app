import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/kmc/domain/kmc_workflow.dart';

void main() {
  const engine = AssessmentEngine();
  final today = DateTime(2026, 10, 14);

  ClinicalAssessmentContext evaluate(
    Map<String, Object?> answers, {
    Set<String> completed = const {},
  }) =>
      engine.evaluate(
        selected: const {NeonatalCondition.kmc},
        answers: answers,
        completed: completed,
        today: today,
      );

  test('unknown GA and BW >=2500 asks for clinician preterm assessment', () {
    const completedBabyDetails = {gaKnownKey, birthWeightKey};
    final context = evaluate(
      {gaKnownKey: false, birthWeightKey: 2500},
      completed: completedBabyDetails,
    );

    final question = engine
        .applicableQuestions(context)
        .singleWhere((q) => q.id == kmcPretermAssessmentKey);
    expect(question.question.question,
        'Has the clinician assessed the baby as preterm?');
    expect(question.question.options.map((o) => o.value), [true, false]);
    expect(engine.isRequired(question, context), isTrue);
    expect(engine.nextGroup(context), 'kmc_preterm_assessment');
    expect(context.valueOf(kmcEligibilityKey), isNull);
    expect(context.findings.map((f) => f.id),
        isNot(contains('kmc.eligibility.undetermined')));
  });

  test('clinician confirms preterm and existing KMC workflow continues', () {
    const completedBabyDetails = {gaKnownKey, birthWeightKey};
    final context = evaluate(
      {
        gaKnownKey: false,
        birthWeightKey: 2500,
        kmcPretermAssessmentKey: true,
      },
      completed: {...completedBabyDetails, kmcPretermAssessmentKey},
    );

    expect(context.valueOf(kmcEligibilityKey), 'eligible');
    expect(context.findings.map((f) => f.id), contains('kmc.eligibility.met'));
    expect(context.findings.map((f) => f.id),
        isNot(contains('kmc.eligibility.undetermined')));
    expect(engine.nextGroup(context), 'kmc_exclusions');
  });

  test('clinician assesses not preterm without an undetermined result', () {
    const completedBabyDetails = {gaKnownKey, birthWeightKey};
    final context = evaluate(
      {
        gaKnownKey: false,
        birthWeightKey: 2500,
        kmcPretermAssessmentKey: false,
      },
      completed: {...completedBabyDetails, kmcPretermAssessmentKey},
    );

    expect(context.valueOf(kmcEligibilityKey), 'notEligible');
    expect(
        context.findings.map((f) => f.id), contains('kmc.eligibility.notMet'));
    expect(context.findings.map((f) => f.id),
        isNot(contains('kmc.eligibility.undetermined')));
  });

  test('known preterm GA remains eligible without asking again', () {
    final context = evaluate({
      gaKnownKey: true,
      gaWeeksKey: 36,
      birthWeightKey: 2700,
    });

    expect(context.valueOf(kmcEligibilityKey), 'eligible');
    expect(
      engine.applicableQuestions(context).map((q) => q.id),
      isNot(contains(kmcPretermAssessmentKey)),
    );
  });

  test('unknown GA and BW <2500 remains eligible without prompt', () {
    final context = evaluate({
      gaKnownKey: false,
      birthWeightKey: 2499,
    });

    expect(context.valueOf(kmcEligibilityKey), 'eligible');
    expect(
      engine.applicableQuestions(context).map((q) => q.id),
      isNot(contains(kmcPretermAssessmentKey)),
    );
  });
}
