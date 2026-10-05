import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';

import 'assessment_test_utils.dart';

Map<String, Object?> sas(int grade, {bool repeat = false}) => {
      for (final i in SasItem.values)
        (repeat ? rdReSasKey(i) : rdSasKey(i)): grade,
    };

Map<String, Object?> rdBase({
  Set<Object> signs = const {'grunting'},
  int ga = 30,
  int sasGrade = 1,
  bool reassess = false,
}) =>
    {
      rdSignsKey: signs,
      gaKnownKey: true,
      gaWeeksKey: ga,
      ...sas(sasGrade),
      rdReassessNowKey: reassess,
    };

ClinicalFinding finding(Walk w, String id) =>
    w.ctx.findings.firstWhere((f) => f.id == id);

void main() {
  group('RD criteria (STW §1.1: ANY ONE)', () {
    test('positive: one sign → RD present, RD questions follow', () {
      final w = walk({rd}, rdBase());
      expect(findingIds(w.ctx), contains(rdPresentId));
      expect(findingIds(w.ctx), isNot(contains(rdNotMetId)));
      expect(w.pages.first, 'rd_signs');
      expect(w.asked, containsAll([gaWeeksKey, rdSasKey(SasItem.grunt)]));
    });

    test('negative: no sign → criteria not met, nothing else asked', () {
      final w = walk({rd}, {});
      expect(findingIds(w.ctx), {rdNotMetId});
      expect(w.asked, [rdRrKey, rdSignsKey]);
      expect(finding(w, rdNotMetId).category, FindingCategory.notMet);
    });

    test('measured RR >60 counts as the sign; RR ≤60 overrides a tick', () {
      expect(findingIds(evalCtx({rd}, {rdRrKey: 72})), contains(rdPresentId));
      final ctx = evalCtx({
        rd
      }, {
        rdRrKey: 50,
        rdSignsKey: <Object>{RdSign.rrAbove60.name},
      });
      expect(findingIds(ctx), contains(rdNotMetId));
    });

    test('the rule agrees with meetsRdCriteria for every sign', () {
      for (final s in RdSign.values) {
        final ctx = evalCtx({
          rd
        }, {
          rdSignsKey: <Object>{s.name}
        });
        expect(ctx.hasFinding(rdPresentId), meetsRdCriteria({s}),
            reason: s.name);
      }
    });
  });

  group('GA and SAS branches (STW §1.4–1.5)', () {
    test('GA ≤34 → START CPAP + caffeine', () {
      final w = walk({rd}, rdBase(ga: 30));
      final plan = finding(w, rdInitialPlanId);
      expect(plan.title, 'START CPAP');
      expect(plan.actions, contains(CaffeineAdvice.indicated.text));
      expect(plan.category, FindingCategory.pathway);
    });

    test('GA >34, SAS ≤3 → mild, nasal-prong oxygen', () {
      final w = walk({rd}, rdBase(ga: 37, sasGrade: 0));
      expect(finding(w, rdSeverityId).title, 'Mild RD (SAS 0)');
      expect(
          finding(w, rdInitialPlanId).title, 'Nasal-prong oxygen 0.5–1 L/min');
      expect(finding(w, rdAvoidId).actions,
          contains(startsWith('Do not perform routine CBC')));
    });

    test('GA >34, SAS ≥4 → moderate–severe, START CPAP', () {
      final w = walk({rd}, rdBase(ga: 37, sasGrade: 1));
      expect(finding(w, rdSeverityId).title, 'Moderate–severe RD (SAS 5)');
      expect(finding(w, rdInitialPlanId).title, 'START CPAP');
    });

    test('GA uncertain → birth weight asked; ≤1800 g surrogate → CPAP', () {
      final w = walk({
        rd
      }, {
        rdSignsKey: <Object>{'grunting'},
        gaKnownKey: false,
        birthWeightKey: 1500,
        ...sas(0),
        rdReassessNowKey: false,
      });
      expect(w.asked, contains(birthWeightKey));
      expect(w.asked, isNot(contains(gaWeeksKey)));
      final plan = finding(w, rdInitialPlanId);
      expect(plan.title, 'START CPAP');
      expect(plan.actions, contains(CaffeineAdvice.confirmGa.text));
    });

    test('GA known → birth weight not asked for RD', () {
      expect(walk({rd}, rdBase()).asked, isNot(contains(birthWeightKey)));
    });

    test('IV fluid indication from clinician findings', () {
      final w = walk({
        rd
      }, {
        ...rdBase(),
        rdIvFlagsKey: <Object>{'apnea'},
      });
      expect(finding(w, rdIvFluidsId).why, ['Recurrent apnea']);
    });

    test('plan matches initialPlan() exactly', () {
      final w = walk({rd}, rdBase(ga: 37, sasGrade: 0));
      final direct = initialPlan(
        signs: {RdSign.grunting},
        gestation: const Gestation(gaWeeks: 37),
        sas: SasScore.of(),
      ).plan!;
      expect(finding(w, rdInitialPlanId).why, direct.why);
      expect(finding(w, rdAvoidId).actions, direct.avoid);
    });
  });

  group('reassessment (STW §1.7–1.10)', () {
    test('not recorded → no reassessment questions asked', () {
      final w = walk({rd}, rdBase(reassess: false));
      expect(w.asked, isNot(contains(rdSupportKey)));
      expect(
          w.ctx.findings.where((f) => f.id.startsWith('rd.reassess')), isEmpty);
    });

    Map<String, Object?> re({
      String support = 'cpap',
      int peep = 5,
      int fio2 = 21,
      int spo2 = 93,
      int reGrade = 1,
      bool comfortable = false,
      Set<Object> warnings = const {},
      int ga = 30,
    }) =>
        {
          ...rdBase(ga: ga, reassess: true),
          rdSupportKey: support,
          rdPeepKey: peep,
          rdFio2Key: fio2,
          rdSpo2Key: spo2,
          rdComfortableKey: comfortable,
          ...sas(reGrade, repeat: true),
          rdWarningsKey: warnings,
        };

    test('reassessment questions asked when recorded', () {
      final w = walk({rd}, re());
      expect(w.pages,
          containsAllInOrder(['rd_support', 'rd_resas', 'rd_warnings']));
    });

    test('CPAP failure → urgent referral', () {
      final w = walk({rd}, re(warnings: {'hypoxemia'}, spo2: 88));
      final f = finding(w, rdReassessId(ReassessStatus.cpapFailure));
      expect(f.category, FindingCategory.referral);
      expect(f.level, FindingLevel.urgent);
      expect(f.title, 'CPAP FAILURE — refer urgently');
    });

    test('surfactant: GA <34, CPAP, PEEP >6 and FiO₂ >0.30', () {
      final w = walk({rd}, re(peep: 7, fio2: 35));
      final f = finding(w, rdReassessId(ReassessStatus.surfactant));
      expect(f.category, FindingCategory.treatment);
      expect(f.title, 'SURFACTANT indicated');
    });

    test('no surfactant at FiO₂ 0.30 (must be >0.30)', () {
      final w = walk({rd}, re(peep: 7, fio2: 30, reGrade: 0));
      expect(findingIds(w.ctx),
          isNot(contains(rdReassessId(ReassessStatus.surfactant))));
    });

    test('not improving: SpO₂ <91% → optimise CPAP', () {
      final w = walk({rd}, re(spo2: 88));
      expect(finding(w, rdReassessId(ReassessStatus.notImproving)).title,
          'NOT IMPROVING — optimise CPAP');
    });

    test('improving: SAS down, SpO₂ in range, comfortable → wean', () {
      final w = walk({rd}, re(reGrade: 0, comfortable: true));
      final f = finding(w, rdReassessId(ReassessStatus.improving));
      expect(f.title, 'IMPROVING — wean support');
      expect(f.level, FindingLevel.ok);
    });

    test('CPAP-only warning option is dropped on nasal-prong O₂', () {
      final w = walk({rd}, re(support: 'nasalO2', warnings: {'hypoxemia'}));
      expect(w.ctx.answers[rdWarningsKey], <Object>{});
      expect(w.asked, isNot(contains(rdPeepKey)));
      expect(findingIds(w.ctx),
          isNot(contains(rdReassessId(ReassessStatus.cpapFailure))));
    });

    test('recording a reassessment keeps the SAS trend and re-asks', () {
      final w = walk({rd}, re(reGrade: 0, comfortable: true));
      final next =
          recordRdReassessment(w.ctx.answers, w.ctx.completedQuestions)!;
      expect(next.answers[rdSasHistoryKey], [0]);
      expect(next.answers.containsKey(rdSpo2Key), isFalse);
      expect(next.answers[rdSupportKey], 'cpap');
      final ctx = engine.evaluate(
        selected: {rd},
        answers: next.answers,
        completed: next.completed,
        today: testToday,
      );
      expect(ctx.valueOf(rdPrevSasTotalKey), 0);
      expect(engine.nextGroup(ctx), 'rd_support');
    });
  });
}
