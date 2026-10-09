import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_content.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_rules.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

import 'assessment_test_utils.dart';

const ancs = NeonatalCondition.ancs;

/// Every criterion met, no previous course, facility has level II care.
Map<String, Object?> eligible({int weeks = 30, int days = 2}) => {
      ancsGaWeeksKey: weeks,
      ancsGaDaysKey: days,
      ancsCausesKey: <Object>{AncsCause.pprom.name},
      ancsGaAccurateKey: true,
      ancsInfectionKey: false,
      ancsChildbirthCareKey: true,
      ancsNewbornCareKey: true,
      ancsPreviousCourseKey: AncsPreviousCourse.none.name,
      ancsLevel2Key: true,
    };

String? decision(Map<String, Object?> answers) =>
    walk({ancs}, answers).ctx.valueOf(ancsDecisionKey) as String?;

AncsResult result(Map<String, Object?> answers) =>
    walk({ancs}, answers).ctx.valueOf(ancsResultKey)! as AncsResult;

void main() {
  group('GA window (WHEN TO GIVE / WHEN NOT TO GIVE)', () {
    test('23+6 → outside 24+0–33+6: criteria not met, nothing else asked', () {
      final w = walk({ancs}, eligible(weeks: 23, days: 6));
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.criteriaNotMet.name);
      expect(w.pages, ['ancs_ga']);
      expect(findingIds(w.ctx), contains(ancsNotMetId));
      expect(findingIds(w.ctx), isNot(contains(ancsGiveId)));
    });

    test('24+0 → inside the window: ACS given when all criteria met', () {
      expect(decision(eligible(weeks: 24, days: 0)),
          AncsDecision.giveInitial.name);
    });

    test('33+6 → inside the window', () {
      expect(decision(eligible(weeks: 33, days: 6)),
          AncsDecision.giveInitial.name);
    });

    test('34+0 → Do NOT give: "Routine use at ≥34 weeks"', () {
      final w = walk({ancs}, eligible(weeks: 34, days: 0));
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.doNotGive.name);
      expect(w.pages, ['ancs_ga']);
      final f = w.ctx.findings.singleWhere((f) => f.id == ancsDoNotGiveId);
      expect(f.actions, ['WHEN NOT TO GIVE: $ancsNotGiveRoutine34']);
    });
  });

  group('all five criteria met (ELIGIBILITY CRITERIA)', () {
    test('GIVE ACS with the STW drug & dose, IMPORTANT note and documentation',
        () {
      final w = walk({ancs}, eligible());
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.giveInitial.name);
      final give = w.ctx.findings.singleWhere((f) => f.id == ancsGiveId);
      expect(give.title, 'GIVE ACS');
      expect(give.actions, [
        'DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES',
        'IMPORTANT: Start ACS promptly once eligibility criteria are met, even '
            'if the full course may not be completed before birth',
      ]);
      expect(findingIds(w.ctx),
          containsAll([ancsDrugNoteId, ancsDocumentationId]));
      final drug = w.ctx.findings.singleWhere((f) => f.id == ancsDrugNoteId);
      expect(drug.actions, contains(ancsDexaPreferred));
      expect(drug.actions, contains(ancsBetaNote));
      final doc =
          w.ctx.findings.singleWhere((f) => f.id == ancsDocumentationId);
      expect(doc.actions, [ancsDocument, ancsRecordIn]);
      expect(findingIds(w.ctx), isNot(contains(ancsReferralId)));
    });

    test('pages follow the STW order', () {
      expect(walk({ancs}, eligible()).pages, [
        'ancs_ga',
        'ancs_likelihood',
        'ancs_criteria',
        'ancs_course',
        'ancs_special',
        'ancs_referral',
      ]);
    });

    test('any one listed cause is enough', () {
      for (final c in AncsCause.values) {
        expect(
          decision({...eligible(), ancsCausesKey: <Object>{c.name}}),
          AncsDecision.giveInitial.name,
          reason: c.name,
        );
      }
    });
  });

  group('each single missing criterion', () {
    test('1: no listed cause → Do NOT give (birth unlikely); rest skipped', () {
      final w = walk({ancs}, {...eligible(), ancsCausesKey: <Object>{}});
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.doNotGive.name);
      expect(result({...eligible(), ancsCausesKey: <Object>{}})
          .doNotGiveReasons, [ancsNotGiveUnlikely]);
      expect(w.pages, ['ancs_ga', 'ancs_likelihood']);
    });

    test('2: GA not assessed accurately → criteria not met', () {
      final r = result({...eligible(), ancsGaAccurateKey: false});
      expect(r.decision, AncsDecision.criteriaNotMet);
      expect(r.unmetCriteria, [ancsCriterion2]);
    });

    test('3: chorioamnionitis / systemic infection → Do NOT give', () {
      final r = result({...eligible(), ancsInfectionKey: true});
      expect(r.decision, AncsDecision.doNotGive);
      expect(r.doNotGiveReasons, [ancsNotGiveInfection]);
    });

    test('4: no adequate childbirth care → criteria not met', () {
      final r = result({...eligible(), ancsChildbirthCareKey: false});
      expect(r.decision, AncsDecision.criteriaNotMet);
      expect(r.unmetCriteria, [ancsCriterion4]);
    });

    test('5: no adequate preterm newborn care → criteria not met', () {
      final r = result({...eligible(), ancsNewbornCareKey: false});
      expect(r.decision, AncsDecision.criteriaNotMet);
      expect(r.unmetCriteria, [ancsCriterion5]);
    });

    test('several WHEN NOT TO GIVE reasons are all shown', () {
      final w = walk({ancs}, {
        ...eligible(),
        ancsInfectionKey: true,
        ancsPreviousCourseKey: AncsPreviousCourse.repeatGiven.name,
      });
      final f = w.ctx.findings.singleWhere((f) => f.id == ancsDoNotGiveId);
      expect(f.actions, [
        'WHEN NOT TO GIVE: $ancsNotGiveInfection',
        'WHEN NOT TO GIVE: $ancsNotGiveMoreThanOneRepeat',
      ]);
    });
  });

  group('repeat course (WHEN TO GIVE REPEAT COURSE)', () {
    Map<String, Object?> repeat(int days) => {
          ...eligible(),
          ancsPreviousCourseKey: AncsPreviousCourse.one.name,
          ancsDaysSincePreviousKey: days,
        };

    test('previous course started 6 days earlier → repeat criteria not met',
        () {
      final r = result(repeat(6));
      expect(r.decision, AncsDecision.criteriaNotMet);
      expect(r.unmetCriteria, [ancsRepeatSevenDays]);
    });

    test('previous course started 7 days earlier → GIVE ONE REPEAT COURSE',
        () {
      final w = walk({ancs}, repeat(7));
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.giveRepeat.name);
      final f = w.ctx.findings.singleWhere((f) => f.id == ancsRepeatId);
      expect(f.actions, contains(ancsRepeatNoMore));
      expect(f.actions, contains(ancsRepeatHarm));
      expect(f.source.needsClinicalReview, isTrue);
    });

    test('days question only when one course was given', () {
      expect(walk({ancs}, eligible()).asked,
          isNot(contains(ancsDaysSincePreviousKey)));
      expect(walk({ancs}, repeat(7)).asked, contains(ancsDaysSincePreviousKey));
    });

    test('a repeat course already given → Do NOT give', () {
      final r = result({
        ...eligible(),
        ancsPreviousCourseKey: AncsPreviousCourse.repeatGiven.name,
      });
      expect(r.decision, AncsDecision.doNotGive);
      expect(r.doNotGiveReasons, [ancsNotGiveMoreThanOneRepeat]);
    });
  });

  group('special situations and referral', () {
    test('special situations never withhold ACS; diabetes adds glucose advice',
        () {
      final w = walk({ancs}, {
        ...eligible(),
        ancsSpecialKey: <Object>{
          AncsSpecialSituation.multiplePregnancy.name,
          AncsSpecialSituation.diabetes.name,
        },
      });
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.giveInitial.name);
      final f = w.ctx.findings.singleWhere((f) => f.id == ancsSpecialId);
      expect(f.actions, [
        ancsSpecialDoNotWithhold,
        ancsSpecialDiabetes,
        'Monitor maternal glucose closely in women with diabetes',
      ]);
    });

    test('no special situation → no special finding', () {
      expect(findingIds(walk({ancs}, eligible()).ctx),
          isNot(contains(ancsSpecialId)));
    });

    test('no level II care → in-utero transfer with the level I note', () {
      final w = walk({ancs}, {...eligible(), ancsLevel2Key: false});
      final f = w.ctx.findings.singleWhere((f) => f.id == ancsReferralId);
      expect(f.actions, [ancsReferral, ancsLevelOne]);
      // Referral does not stop ACS.
      expect(w.ctx.valueOf(ancsDecisionKey), AncsDecision.giveInitial.name);
    });
  });

  group('de-identification and summary', () {
    test('no identifier, date or free-text question; all answers syncable',
        () {
      for (final u in ancsWorkflow.uses) {
        final q = u.question;
        expect(isSyncableQuestion(q), isTrue, reason: q.id);
        for (final word in ['name', 'mrn', 'dob', 'phone', 'birth date']) {
          expect(q.id.toLowerCase(), isNot(contains(word)), reason: q.id);
        }
      }
    });

    test('summary describes the pregnant woman, not a baby', () {
      final w = walk({ancs}, eligible());
      final s = CombinedAssessmentSummary.from(w.ctx);
      final text = s.toPlainText();
      expect(text, contains('Pregnant woman: GA 30+2 wk'));
      expect(text, isNot(contains('Baby:')));
      expect(text, contains('[Treatment criteria met] GIVE ACS'));
      expect(text,
          contains('Source: ICMR/DHR STW "Antenatal Corticosteroids for '
              'Preterm Birth" (August 2026)'));
    });

    test('every rule and question carries an STW source; rules point at a '
        'PDF region', () {
      for (final rule in ancsWorkflow.rules) {
        expect(rule.source.isClinical, isTrue, reason: rule.id);
        expect(rule.source.regionId, isNotNull, reason: rule.id);
      }
      for (final u in ancsWorkflow.uses) {
        expect(u.question.sources, isNotEmpty, reason: u.question.id);
      }
    });
  });
}
