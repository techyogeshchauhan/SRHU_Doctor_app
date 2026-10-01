import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/rop/domain/rop_rules.dart';

void main() {
  group('eligibility', () {
    test('GA 33 → eligible', () {
      expect(ropEligibility(gaWeeks: 33, birthWeightG: 2100).eligible, isTrue);
    });

    test('BW 1900 g at term → eligible', () {
      expect(ropEligibility(gaWeeks: 38, birthWeightG: 1900).eligible, isTrue);
    });

    test('GA 35 + BW 2100 g, no risk factors → not eligible', () {
      expect(ropEligibility(gaWeeks: 35, birthWeightG: 2100).eligible, isFalse);
    });

    test('GA 35 + sepsis → eligible', () {
      final e = ropEligibility(
          gaWeeks: 35, birthWeightG: 2100, risks: {RopRiskFactor.sepsis});
      expect(e.eligible, isTrue);
      expect(e.reasons.single, contains('sepsis'));
    });

    test('GA 37 + risk factor → not eligible (risk factors only for 34–36)', () {
      expect(
          ropEligibility(
              gaWeeks: 37,
              birthWeightG: 2500,
              risks: {RopRiskFactor.transfusion}).eligible,
          isFalse);
    });

    test('nothing entered → null', () {
      expect(ropEligibility().eligible, isNull);
    });
  });

  group('first-screen timing', () {
    final dob = DateTime(2026, 9, 1);

    test('GA 27 → due by day 21', () {
      final t = firstScreenTiming(
          dob: dob, today: DateTime(2026, 9, 5), gaWeeks: 27, birthWeightG: 900);
      expect(t.earlyWindow, isTrue);
      expect(t.dueBy, DateTime(2026, 9, 22));
      expect(t.windowStart, DateTime(2026, 9, 15));
      expect(t.status, FirstScreenStatus.notYetDue);
    });

    test('BW 1100 g at GA 30 → early window', () {
      expect(usesEarlyWindow(gaWeeks: 30, birthWeightG: 1100), isTrue);
    });

    test('GA 32 → due by day 28, not yet due before dueBy', () {
      final t = firstScreenTiming(
          dob: dob,
          today: DateTime(2026, 9, 24),
          gaWeeks: 32,
          birthWeightG: 1600);
      expect(t.dueBy, DateTime(2026, 9, 29));
      expect(t.status, FirstScreenStatus.notYetDue);
      expect(t.postnatalAgeDays, 23);
    });

    test('past due → overdue', () {
      final t = firstScreenTiming(
          dob: dob, today: DateTime(2026, 10, 5), gaWeeks: 32);
      expect(t.status, FirstScreenStatus.overdue);
    });

    test('PMA and 65-week date', () {
      expect(
          pmaDays(
              gaWeeks: 28, gaDays: 3, dob: dob, onDate: DateTime(2026, 9, 15)),
          28 * 7 + 3 + 14);
      expect(formatWeeksDays(28 * 7 + 3 + 14), '30+3 wk');
      final d = dateAtPma(gaWeeks: 28, gaDays: 0, dob: dob, targetWeeks: 65);
      expect(daysBetween(dob, d), (65 - 28) * 7);
    });
  });

  group('treatment indications', () {
    test('Zone I stage 1 + plus → treat', () {
      expect(
          eyeIndication(
                  const EyeFindings(zone: RopZone.i, stage: 1, plus: true))
              .action,
          EyeAction.treat);
    });

    test('Zone I stage 3 without plus → treat', () {
      expect(eyeIndication(const EyeFindings(zone: RopZone.i, stage: 3)).action,
          EyeAction.treat);
    });

    test('Zone I stage 2 without plus → observe within 1 week', () {
      final r = eyeIndication(const EyeFindings(zone: RopZone.i, stage: 2));
      expect(r.action, EyeAction.observe);
      expect(r.followUp, contains('within 1 week'));
    });

    test('Zone II stage 2 without plus → no treatment', () {
      final r = eyeIndication(const EyeFindings(zone: RopZone.ii, stage: 2));
      expect(r.action, EyeAction.observe);
      expect(r.followUp, contains('1–3 weeks'));
    });

    test('Zone II stage 3 + plus → treat', () {
      expect(
          eyeIndication(
                  const EyeFindings(zone: RopZone.ii, stage: 3, plus: true))
              .action,
          EyeAction.treat);
    });

    test('Zone II stage 1 + plus → observe', () {
      expect(
          eyeIndication(
                  const EyeFindings(zone: RopZone.ii, stage: 1, plus: true))
              .action,
          EyeAction.observe);
    });

    test('Zone III stage 3 + plus → observe', () {
      expect(
          eyeIndication(
                  const EyeFindings(zone: RopZone.iii, stage: 3, plus: true))
              .action,
          EyeAction.observe);
    });

    test('stage 4 → surgery referral', () {
      expect(
          eyeIndication(const EyeFindings(zone: RopZone.ii, stage: 4)).action,
          EyeAction.surgeryReferral);
    });

    test('A-ROP → urgent even without zone/stage', () {
      expect(eyeIndication(const EyeFindings(aRop: true)).action,
          EyeAction.urgentTreatment);
    });

    test('reactivation after anti-VEGF stage 2 → treat', () {
      expect(
          eyeIndication(const EyeFindings(
            zone: RopZone.ii,
            stage: 2,
            priorAntiVegf: true,
            reactivationOrPar: true,
          )).action,
          EyeAction.treat);
    });

    test('fully vascularised → may stop', () {
      expect(
          eyeIndication(const EyeFindings(
                  status: RetinaStatus.fullyVascularised))
              .action,
          EyeAction.mayStop);
    });

    test('regressed after anti-VEGF before 65 wk PMA → continue follow-up', () {
      final r = eyeIndication(
        const EyeFindings(
            zone: RopZone.ii,
            stage: 0,
            status: RetinaStatus.regressed,
            priorAntiVegf: true),
        pmaWeeks: 50,
      );
      expect(r.action, EyeAction.observe);
      expect(r.why.first, contains('65 weeks'));
    });

    test('regressed after anti-VEGF at 66 wk PMA → may stop', () {
      expect(
          eyeIndication(
            const EyeFindings(
                status: RetinaStatus.regressed, priorAntiVegf: true),
            pmaWeeks: 66,
          ).action,
          EyeAction.mayStop);
    });
  });

  group('next exam and summary', () {
    test('summary flags a missing follow-up plan', () {
      final s = buildRopSummary(
        babyLine: 'GA 30+0 wk, BW 1300 g',
        eligibility: ropEligibility(gaWeeks: 30, birthWeightG: 1300),
      );
      expect(s, contains('Eligible for screening: YES'));
      expect(s, contains('NOT DOCUMENTED'));
    });

    test('summary includes date and place when given', () {
      final s = buildRopSummary(
        babyLine: 'GA 30+0 wk',
        eligibility: ropEligibility(gaWeeks: 30),
        nextExamDate: DateTime(2026, 10, 15),
        nextExamPlace: 'District Hospital SNCU',
        familyCounselled: true,
      );
      expect(s, contains('15/10/2026 at District Hospital SNCU'));
      expect(s, contains('risk of vision loss: Yes'));
    });
  });
}
