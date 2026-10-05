import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/rop/domain/rop_rules.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';

import 'assessment_test_utils.dart';

Map<String, Object?> ropBase({
  int ga = 30,
  int? bw,
  int dobDaysAgo = 10,
  String followUp = 'yes',
  bool examDone = false,
}) =>
    {
      gaKnownKey: true,
      gaWeeksKey: ga,
      if (bw != null) birthWeightKey: bw,
      dobKey: testToday.subtract(Duration(days: dobDaysAgo)),
      ropFollowUpAssuredKey: followUp,
      ropExamDoneKey: examDone,
    };

Map<String, Object?> eye(
  RopEye e, {
  String zone = 'ii',
  int stage = 1,
  String vascular = 'noPlus',
  bool arop = false,
  String? status,
}) =>
    {
      e.key('zone'): zone,
      e.key('stage'): stage,
      e.key('vascular'): vascular,
      e.key('arop'): arop,
      if (status != null) e.key('status'): status,
    };

ClinicalFinding finding(Walk w, String id) =>
    w.ctx.findings.firstWhere((f) => f.id == id);

void main() {
  group('eligibility (STW §2.1)', () {
    test('GA <34 → screening eligible, screening questions follow', () {
      final w = walk({rop}, ropBase(ga: 30));
      expect(finding(w, ropEligibleId).category, FindingCategory.screening);
      expect(w.asked, containsAll([dobKey, ropExamDoneKey]));
      expect(w.asked, isNot(contains(ropRisksKey)));
    });

    test('not eligible → no ROP screening/finding questions', () {
      final w = walk({
        rop
      }, {
        gaKnownKey: true,
        gaWeeksKey: 37,
        birthWeightKey: 2500,
      });
      expect(findingIds(w.ctx), {ropNotEligibleId});
      expect(w.pages.toSet(), {'baby'});
      expect(w.asked, isNot(contains(ropExamDoneKey)));
      expect(w.asked, isNot(contains(RopEye.right.key('zone'))));
    });

    test('BW <2000 g alone makes the baby eligible', () {
      final w = walk({rop}, {...ropBase(ga: 37, bw: 1900)});
      expect(findingIds(w.ctx), contains(ropEligibleId));
    });

    test('GA 34–36: risk factor question asked; a risk factor → eligible', () {
      final none = walk({
        rop
      }, {
        gaKnownKey: true,
        gaWeeksKey: 35,
        birthWeightKey: 2200,
      });
      expect(none.asked, contains(ropRisksKey));
      expect(findingIds(none.ctx), contains(ropNotEligibleId));

      final withRisk = walk({
        rop
      }, {
        ...ropBase(ga: 35, bw: 2200),
        ropRisksKey: <Object>{RopRiskFactor.sepsis.name},
      });
      expect(findingIds(withRisk.ctx), contains(ropEligibleId));
    });

    test('risk-factor visibility matches riskFactorsRelevant() for GA 22–44',
        () {
      for (var ga = 22; ga <= 44; ga++) {
        final ctx = evalCtx({rop}, {gaKnownKey: true, gaWeeksKey: ga});
        expect(
            applicableIds(ctx).contains(ropRisksKey), riskFactorsRelevant(ga),
            reason: 'GA $ga');
      }
    });

    test('eligibility matches ropEligibility() for a grid of GA/BW', () {
      for (final ga in [26, 33, 34, 36, 37]) {
        for (final bw in [1100, 1999, 2000, 2600]) {
          final ctx = evalCtx({
            rop
          }, {
            gaKnownKey: true,
            gaWeeksKey: ga,
            birthWeightKey: bw,
          });
          final expected =
              ropEligibility(gaWeeks: ga, birthWeightG: bw).eligible;
          expect(ctx.hasFinding(ropEligibleId), expected == true,
              reason: 'GA $ga BW $bw');
        }
      }
    });
  });

  group('timing (STW §2.2)', () {
    test('first screen not yet due → due date shown', () {
      final w = walk({rop}, ropBase(ga: 30, dobDaysAgo: 10));
      final due = testToday.add(const Duration(days: 18));
      expect(
          finding(w, ropDueId).title, 'First screen due by ${formatDmy(due)}');
    });

    test('GA <28 → 2–3 week window; overdue after day 21', () {
      final w = walk({rop}, ropBase(ga: 26, dobDaysAgo: 25));
      final f = finding(w, ropOverdueId);
      expect(f.level, FindingLevel.urgent);
      expect(f.why.first, contains('2–3 weeks'));
    });

    test('follow-up uncertain → screen before discharge', () {
      final w = walk({rop}, ropBase(followUp: 'uncertain'));
      expect(findingIds(w.ctx), contains(ropScreenBeforeDischargeId));
    });

    test('exam not done → eye questions skipped, follow-up plan required', () {
      final w = walk({rop}, ropBase());
      expect(w.asked, isNot(contains(RopEye.right.key('zone'))));
      expect(finding(w, ropFollowUpMissingId).level, FindingLevel.urgent);
    });
  });

  group('findings and treatment (STW §2.6–2.8)', () {
    Map<String, Object?> exam(Map<String, Object?> right,
            [Map<String, Object?>? left]) =>
        {
          ...ropBase(examDone: true),
          ropExamDateKey: testToday,
          ...right,
          if (left == null) ropLeftSameKey: true else ...left,
        };

    test('Zone II stage 3 + plus → treatment criteria met', () {
      final w = walk({rop},
          exam(eye(RopEye.right, zone: 'ii', stage: 3, vascular: 'plus')));
      expect(finding(w, RopEye.right.findingId).category,
          FindingCategory.treatment);
      expect(finding(w, RopEye.left.findingId).title,
          'Left eye (OS): Treatment-requiring ROP');
      expect(finding(w, ropTreatUrgentlyId).title,
          'Treat urgently — within 48–72 h of decision');
      // Timing is no longer relevant once examined.
      expect(findingIds(w.ctx), isNot(contains(ropDueId)));
    });

    test('left eye questions skipped when same as right', () {
      final w = walk({rop}, exam(eye(RopEye.right)));
      expect(w.asked, isNot(contains(RopEye.left.key('zone'))));
    });

    test('A-ROP → urgent treatment without zone/stage', () {
      final w = walk({rop}, exam({RopEye.right.key('arop'): true}));
      final f = finding(w, RopEye.right.findingId);
      expect(f.level, FindingLevel.urgent);
      expect(f.title, contains('Aggressive ROP'));
    });

    test('stage 4 → referral for vitreo-retinal surgery', () {
      final w = walk({rop}, exam(eye(RopEye.right, stage: 4)));
      expect(finding(w, RopEye.right.findingId).category,
          FindingCategory.referral);
    });

    test('Zone II stage 1 → no treatment, continue screening', () {
      final w = walk({rop}, exam(eye(RopEye.right)));
      final f = finding(w, RopEye.right.findingId);
      expect(f.category, FindingCategory.followUp);
      expect(findingIds(w.ctx), isNot(contains(ropTreatUrgentlyId)));
    });

    test('both eyes fully vascularised → may stop; no plan-missing alarm', () {
      final w = walk(
          {rop},
          exam({
            RopEye.right.key('status'): RetinaStatus.fullyVascularised.name,
          }));
      expect(finding(w, RopEye.right.findingId).title,
          contains('Screening may stop'));
      expect(findingIds(w.ctx), isNot(contains(ropFollowUpMissingId)));
    });

    test('documented follow-up → next exam finding and discharge card', () {
      final next = testToday.add(const Duration(days: 14));
      final w = walk({
        rop
      }, {
        ...exam(eye(RopEye.right)),
        ropNextExamDateKey: next,
        ropNextExamPlaceKey: 'District hospital',
        ropCounselledKey: true,
      });
      expect(findingIds(w.ctx), isNot(contains(ropFollowUpMissingId)));
      expect(findingIds(w.ctx), isNot(contains(ropCounselId)));
      expect(finding(w, ropNextExamId).title,
          'Next ROP examination: ${formatDmy(next)} at District hospital');
      expect(
          w.ctx.valueOf(ropSummaryTextKey),
          contains(
              'NEXT ROP EXAMINATION: ${formatDmy(next)} at District hospital'));
    });
  });
}
