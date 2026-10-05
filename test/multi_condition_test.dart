import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';

import 'assessment_test_utils.dart';

final answers = <String, Object?>{
  gaKnownKey: true,
  gaWeeksKey: 32,
  birthWeightKey: 1600,
  dobKey: testToday.subtract(const Duration(days: 5)),
  rdSignsKey: <Object>{'retractions'},
  for (final i in SasItem.values) rdSasKey(i): 1,
  rdReassessNowKey: false,
  ropFollowUpAssuredKey: 'yes',
  ropExamDoneKey: false,
};

void main() {
  test('shared GA/BW are resolved once and used by both workflows', () {
    final resolved = engine.resolve({rd, rop});
    for (final id in [gaKnownKey, gaWeeksKey, birthWeightKey]) {
      final matches = resolved.where((q) => q.id == id).toList();
      expect(matches, hasLength(1), reason: id);
      expect(matches.single.topics, {rd, rop}, reason: id);
    }
  });

  test('RD + ROP: GA asked once, first; both pathways consume it', () {
    final w = walk({rd, rop}, answers);
    expect(w.pages.first, 'baby');
    expect(w.asked.where((id) => id == gaWeeksKey), hasLength(1));
    expect(w.asked.where((id) => id == birthWeightKey), hasLength(1));

    // GA 32 → RD: CPAP + caffeine (<34); ROP: eligible (<34).
    final ids = findingIds(w.ctx);
    expect(ids, containsAll([rdPresentId, rdInitialPlanId, ropEligibleId]));
    final plan = w.ctx.findings.firstWhere((f) => f.id == rdInitialPlanId);
    expect(plan.actions, contains(CaffeineAdvice.indicated.text));
    expect(w.ctx.findingsFor(rd).every((f) => f.id.startsWith('rd.')), isTrue);
    expect(
        w.ctx.findingsFor(rop).every((f) => f.id.startsWith('rop.')), isTrue);
  });

  test('independent findings: RD not met while ROP is eligible', () {
    final w = walk({rd, rop}, {...answers, rdSignsKey: <Object>{}});
    expect(findingIds(w.ctx), contains(rdNotMetId));
    expect(findingIds(w.ctx), contains(ropEligibleId));
    expect(w.asked, isNot(contains(rdSasKey(SasItem.grunt))));
  });

  test('deselecting ROP removes its questions, answers and findings', () {
    final both = walk({rd, rop}, answers).ctx;
    final rdOnly = engine.evaluate(
      selected: {rd},
      answers: both.answers,
      completed: both.completedQuestions,
      today: testToday,
    );
    expect(rdOnly.findingsFor(rop), isEmpty);
    expect(rdOnly.answers.containsKey(dobKey), isFalse);
    expect(rdOnly.answers.containsKey(ropExamDoneKey), isFalse);
    expect(rdOnly.answers[gaWeeksKey], 32);
    expect(rdOnly.completedQuestions, contains(gaWeeksKey));
    expect(rdOnly.completedQuestions, isNot(contains(dobKey)));
    expect(engine.nextGroup(rdOnly), isNull);
  });

  test('combined summary lists both topics and avoids diagnosis wording', () {
    final w = walk({rd, rop, sepsis}, answers);
    final s = CombinedAssessmentSummary.from(w.ctx);
    expect(s.selectedTitles, ['Respiratory Distress', 'Sepsis', 'ROP']);
    expect(s.topics.map((t) => t.available), [true, false, true]);
    final text = s.toPlainText();
    expect(text, contains('Baby: GA 32+0 wk · BW 1600 g'));
    expect(text,
        contains('[Assessment finding] Respiratory distress criteria met'));
    expect(text, contains('[Screening] Screening eligible — SCREEN FOR ROP'));
    expect(text, contains(pendingStwMessage));
    expect(text, contains('ROP SCREENING SUMMARY'));
    expect(text,
        contains('Source: ICMR/DHR STW "Retinopathy of Prematurity (ROP)"'));
    // Topics are "assessed", never labelled as diagnoses. (STW action text
    // may still say e.g. "within 30 min of diagnosis/admission".)
    expect(text, isNot(contains('Diagnosis')));
    expect(text, isNot(contains('diagnosed')));
    expect(text, contains('Topics assessed:'));
    expect(text, endsWith(combinedSummaryAdvisory));
  });

  test('pending topics add no questions and no findings', () {
    final w = walk({sepsis, NeonatalCondition.jaundice}, {});
    expect(w.pages, isEmpty);
    expect(w.ctx.findings, isEmpty);
  });

  test('every rule and question carries an STW source', () {
    for (final wf in [rdWorkflow, ropWorkflow]) {
      for (final rule in wf.rules) {
        expect(rule.source.isClinical, isTrue, reason: rule.id);
        expect(rule.source.section, isNotEmpty, reason: rule.id);
      }
      for (final u in wf.uses) {
        expect(u.question.sources, isNotEmpty, reason: u.question.id);
      }
    }
  });
}
