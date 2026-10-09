import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_content.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_rules.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';

import 'assessment_test_utils.dart';

const hypo = NeonatalCondition.hypoglycemia;

Map<String, Object?> firstBg(int bg, {Set<Object> symptoms = const {}}) => {
      hypoRiskKey: <Object>{HypoRisk.preterm.name},
      hypoBgKey: bg,
      hypoSymptomsKey: <Object>{...symptoms},
    };

Set<String> findingsOf(Map<String, Object?> answers) =>
    findingIds(walk({hypo}, answers).ctx);

/// Symptomatic baby on IV glucose with a re-check being recorded.
Map<String, Object?> onIv({
  required int gir,
  required int bg,
  bool? euglycemic,
  bool? feeds,
  Set<Object>? persistent,
}) =>
    {
      ...firstBg(30, symptoms: {HypoSymptom.jitteriness.name}),
      hypoIvNowKey: true,
      hypoGirKey: gir,
      hypoIvBgKey: bg,
      if (euglycemic != null) hypoEuglycemicKey: euglycemic,
      if (feeds != null) hypoToleratingFeedsKey: feeds,
      if (persistent != null) hypoPersistentKey: persistent,
    };

void main() {
  group('BG and symptom boundaries (flowchart)', () {
    test('BG 45 → flowchart not triggered; no symptom question', () {
      final w = walk({hypo}, firstBg(45));
      expect(w.ctx.valueOf(hypoBranchKey), HypoBranch.notTriggered.name);
      expect(w.asked, isNot(contains(hypoSymptomsKey)));
      expect(findingIds(w.ctx), contains(hypoNotTriggeredId));
      expect(findingIds(w.ctx), isNot(contains(hypoLowId)));
    });

    test('BG 44, asymptomatic → supervised feeding, re-check after 1 hour',
        () {
      final w = walk({hypo}, firstBg(44));
      expect(w.ctx.valueOf(hypoBranchKey), HypoBranch.supervisedFeeding.name);
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoFeedingId);
      expect(f.title, 'ASYMPTOMATIC & BG ≥25 mg/dL');
      expect(f.actions, [hypoSupervisedFeeding, hypoFeedHow, hypoRecheck1h]);
      expect(findingIds(w.ctx), contains(hypoLowId));
    });

    test('BG 44 with a symptom → IV bolus + GIR 6', () {
      final w = walk({hypo},
          firstBg(44, symptoms: {HypoSymptom.unableToFeed.name}));
      expect(w.ctx.valueOf(hypoBranchKey), HypoBranch.ivGlucose.name);
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoIvGlucoseId);
      expect(f.actions, [hypoBolus, hypoStartInfusion, hypoRecheck30]);
      expect(f.why, ['Symptom: Unable to feed']);
    });

    test('BG 25, asymptomatic → supervised feeding (≥25)', () {
      expect(walk({hypo}, firstBg(25)).ctx.valueOf(hypoBranchKey),
          HypoBranch.supervisedFeeding.name);
    });

    test('BG 25 with a symptom → IV glucose', () {
      expect(
        walk({hypo}, firstBg(25, symptoms: {HypoSymptom.stupor.name}))
            .ctx
            .valueOf(hypoBranchKey),
        HypoBranch.ivGlucose.name,
      );
    });

    test('BG 24, asymptomatic → IV glucose (< 25)', () {
      final w = walk({hypo}, firstBg(24));
      expect(w.ctx.valueOf(hypoBranchKey), HypoBranch.ivGlucose.name);
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoIvGlucoseId);
      expect(f.why, ['BG 24 mg/dL (< 25 mg/dL)']);
    });

    test('BG 24 with a symptom → IV glucose', () {
      expect(
        walk({hypo}, firstBg(24, symptoms: {HypoSymptom.cry.name}))
            .ctx
            .valueOf(hypoBranchKey),
        HypoBranch.ivGlucose.name,
      );
    });

    test('BG <45: lab sample, do not delay treatment', () {
      final w = walk({hypo}, firstBg(30));
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoLowId);
      expect(f.title, 'BLOOD GLUCOSE <45 mg/dL');
      expect(f.actions, [hypoMonitorLab, hypoMonitorNoDelay]);
    });
  });

  group('whom to screen and schedule', () {
    test('at-risk infant gets the schedule; IDM note only for IDM', () {
      final w = walk({hypo}, {hypoRiskKey: <Object>{HypoRisk.idm.name}});
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoAtRiskId);
      expect(f.actions, [
        hypoScheduleAtRisk,
        hypoScheduleIdm,
        hypoScheduleIv,
        hypoSchedulePreFeed,
        hypoMonitorGlucometer,
      ]);
      final other = walk({hypo}, {hypoRiskKey: <Object>{HypoRisk.lga.name}})
          .ctx
          .findings
          .singleWhere((f) => f.id == hypoAtRiskId);
      expect(other.actions, isNot(contains(hypoScheduleIdm)));
    });

    test('no risk factor → routine monitoring not required (flagged)', () {
      final w = walk({hypo}, {hypoRiskKey: <Object>{}});
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoNoRiskId);
      expect(f.actions, [hypoRoutineNotRequired]);
      expect(f.source.needsClinicalReview, isTrue);
    });

    test('no BG entered → only the screening finding, no flowchart', () {
      final w = walk({hypo}, {hypoRiskKey: <Object>{HypoRisk.preterm.name}});
      expect(w.ctx.valueOf(hypoBranchKey), isNull);
      expect(findingIds(w.ctx), {hypoAtRiskId});
    });
  });

  group('1-hour re-check (supervised-feeding branch)', () {
    Map<String, Object?> recheck(int bg, {bool symptoms = false}) => {
          ...firstBg(30),
          hypoRecheckNowKey: true,
          hypoRecheckBgKey: bg,
          hypoSymptomsDevelopedKey: symptoms,
        };

    test('BG 45 at 1 hour → continue feeds and 6-hourly BG for 24 hours', () {
      final w = walk({hypo}, recheck(45));
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoRecheckOkId);
      expect(f.actions, [hypoContinueFeeds, hypoContinueMonitoring]);
      expect(w.ctx.valueOf(hypoOnIvKey), isFalse);
    });

    test('BG 44 at 1 hour → start IV glucose infusion (no bolus/GIR stated)',
        () {
      final w = walk({hypo}, recheck(44));
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoRecheckIvId);
      expect(f.title, 'Start IV glucose infusion');
      expect(f.actions, [hypoRecheck30]);
      expect(f.source.needsClinicalReview, isTrue);
      expect(findingIds(w.ctx), isNot(contains(hypoIvGlucoseId)));
      expect(w.ctx.valueOf(hypoOnIvKey), isTrue);
    });

    test('symptoms develop with BG 50 → start IV glucose infusion', () {
      final w = walk({hypo}, recheck(50, symptoms: true));
      expect(findingIds(w.ctx),
          containsAll([hypoRecheckIvId, hypoNeuroFollowUpId]));
    });

    test('not recorded now → plan only, no IV page', () {
      final w = walk({hypo}, {...firstBg(30), hypoRecheckNowKey: false});
      expect(w.pages, ['hypo_screen', 'hypo_bg', 'hypo_recheck']);
    });
  });

  group('on IV glucose', () {
    test('BG <45 → increase GIR by 2', () {
      final w = walk({hypo}, onIv(gir: 6, bg: 40));
      expect(w.ctx.valueOf(hypoNextGirKey), 8);
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoIncreaseGirId);
      expect(f.actions, [hypoIncreaseGir, 'GIR 6 → 8 mg/kg/min', hypoRecheck30]);
    });

    test('GIR is capped at 12', () {
      expect(hypoIncreasedGir(10), 12);
      expect(hypoIncreasedGir(11), 12);
      expect(walk({hypo}, onIv(gir: 10, bg: 40)).ctx.valueOf(hypoNextGirKey),
          12);
      final atMax = walk({hypo}, onIv(gir: 12, bg: 40));
      expect(atMax.ctx.valueOf(hypoIvOutcomeKey),
          HypoIvOutcome.maxGirReached.name);
      expect(findingIds(atMax.ctx), contains(hypoMaxGirId));
      expect(findingIds(atMax.ctx), isNot(contains(hypoIncreaseGirId)));
    });

    test('GIR above 12 is flagged', () {
      expect(findingsOf(onIv(gir: 14, bg: 40)), contains(hypoGirAboveMaxId));
    });

    test('persistent or refractory → refer + hydrocortisone box', () {
      for (final tick in ['persistent', 'refractory']) {
        final w = walk({hypo}, onIv(gir: 12, bg: 40, persistent: {tick}));
        expect(findingIds(w.ctx), containsAll([hypoReferId, hypoDrugsId]),
            reason: tick);
        final drugs = w.ctx.findings.singleWhere((f) => f.id == hypoDrugsId);
        expect(drugs.actions, [hypoHydrocortisone, hypoAdditionalDrugs]);
      }
    });

    test('BG ≥45, not yet euglycemic 24 h → keep re-checking, then wean', () {
      final w = walk({hypo}, onIv(gir: 8, bg: 45));
      expect(w.ctx.valueOf(hypoIvOutcomeKey),
          HypoIvOutcome.awaitEuglycemia24h.name);
      expect(w.asked, isNot(contains(hypoPersistentKey)));
    });

    test('euglycemic 24 h on GIR 8 → reduce GIR by 2 every 6 hours', () {
      final w = walk({hypo}, onIv(gir: 8, bg: 60, euglycemic: true));
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoWeanId);
      expect(f.actions,
          [hypoReduceGir, hypoIncreaseOralFeeds, hypoMonitor6h, hypoStopIv]);
    });

    test('stop IV: euglycemic on GIR 4 AND tolerating enteral feeds', () {
      expect(
        walk({hypo}, onIv(gir: 4, bg: 60, euglycemic: true, feeds: true))
            .ctx
            .valueOf(hypoIvOutcomeKey),
        HypoIvOutcome.stopIv.name,
      );
      expect(findingsOf(onIv(gir: 4, bg: 60, euglycemic: true, feeds: true)),
          contains(hypoStopIvId));
      // Not tolerating feeds → not yet.
      expect(findingsOf(onIv(gir: 4, bg: 60, euglycemic: true, feeds: false)),
          contains(hypoStopNotYetId));
      // GIR 6 even with feeds → wean, not stop.
      expect(
        walk({hypo}, onIv(gir: 6, bg: 60, euglycemic: true, feeds: true))
            .ctx
            .valueOf(hypoIvOutcomeKey),
        HypoIvOutcome.wean.name,
      );
      // Not euglycemic for 24 h → no stop.
      expect(findingsOf(onIv(gir: 4, bg: 60, euglycemic: false)),
          isNot(contains(hypoStopIvId)));
    });

    test('GIR below 4 is not addressed by the STW (flagged, no stop)', () {
      final ids = findingsOf(onIv(gir: 2, bg: 60, euglycemic: true, feeds: true));
      expect(ids, contains(hypoGirBelowId));
      expect(ids, isNot(contains(hypoStopIvId)));
    });

    test('practical points shown once IV glucose is started', () {
      expect(findingsOf(firstBg(20)), contains(hypoPracticalId));
      expect(findingsOf(firstBg(30)), isNot(contains(hypoPracticalId)));
    });
  });

  group('bolus volume (2 ml/kg × weight)', () {
    test('formula shown; exact, not rounded', () {
      expect(hypoBolusVolumeText(1250),
          startsWith('Bolus volume = 2 ml/kg × 1.25 kg = 2.5 ml'));
      expect(hypoBolusVolumeText(1234),
          startsWith('Bolus volume = 2 ml/kg × 1.234 kg = 2.468 ml'));
      expect(hypoBolusVolumeText(3000),
          startsWith('Bolus volume = 2 ml/kg × 3 kg = 6 ml'));
    });

    test('only on the IV branch and only when a weight is entered', () {
      final w = walk({hypo}, {...firstBg(20), hypoWeightKey: 1500});
      final f = w.ctx.findings.singleWhere((f) => f.id == hypoBolusVolumeId);
      expect(f.actions.single, startsWith('Bolus volume = 2 ml/kg × 1.5 kg = 3 ml'));
      expect(f.source.needsClinicalReview, isTrue);
      expect(findingsOf(firstBg(20)), isNot(contains(hypoBolusVolumeId)));
      expect(findingsOf({...firstBg(30), hypoWeightKey: 1500}),
          isNot(contains(hypoBolusVolumeId)));
      expect(walk({hypo}, firstBg(45)).asked, isNot(contains(hypoWeightKey)));
      // Asked on the BG page, so that page is shown only once.
      expect(walk({hypo}, firstBg(20)).pages.where((p) => p == 'hypo_bg'),
          hasLength(1));
    });
  });

  group('follow-up, de-identification and summary', () {
    test('symptomatic hypoglycemia → structured neurodevelopmental follow-up',
        () {
      expect(findingsOf(firstBg(30, symptoms: {HypoSymptom.cyanosis.name})),
          contains(hypoNeuroFollowUpId));
      expect(findingsOf(firstBg(30)), isNot(contains(hypoNeuroFollowUpId)));
      expect(findingsOf(onIv(gir: 12, bg: 40, persistent: {'persistent'})),
          contains(hypoNeuroFollowUpId));
    });

    test('no identifier, date or free-text question; all answers syncable',
        () {
      for (final u in hypoWorkflow.uses) {
        expect(isSyncableQuestion(u.question), isTrue, reason: u.question.id);
      }
    });

    test('summary describes the neonate by BG; source cited', () {
      final s = CombinedAssessmentSummary.from(walk({hypo}, firstBg(30)).ctx);
      final text = s.toPlainText();
      expect(text, contains('Neonate: BG 30 mg/dL'));
      expect(text, isNot(contains('Baby:')));
      expect(text, contains('Source: ICMR/DHR STW "Neonatal Hypoglycemia"'));
    });

    test('every rule and question carries an STW source; rules point at a '
        'PDF region', () {
      for (final rule in hypoWorkflow.rules) {
        expect(rule.source.isClinical, isTrue, reason: rule.id);
        expect(rule.source.regionId, isNotNull, reason: rule.id);
      }
      for (final u in hypoWorkflow.uses) {
        expect(u.question.sources, isNotEmpty, reason: u.question.id);
      }
    });
  });
}
