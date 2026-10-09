/// Decision logic of the ICMR/DHR STW "Neonatal Hypoglycemia" (ICD-11
/// KB60.4, August 2026) flowchart. Pure Dart, deterministic.
///
/// Every threshold comes from the PDF; nothing is inferred. Readings that
/// need clinician sign-off are listed in CLINICAL_REVIEW.md.
library;

import 'hypo_content.dart';

/// Flowchart entry box: BLOOD GLUCOSE <45 mg/dL.
const hypoThresholdMgDl = 45;

/// SYMPTOMATIC OR BG < 25 mg/dL / ASYMPTOMATIC & BG ≥25 mg/dL.
const hypoSevereThresholdMgDl = 25;

/// SYMPTOMATIC OR BG < 25 mg/dL: GIR of 6 mg/kg/min.
const hypoStartGir = 6;

/// Increase GIR by 2 mg/kg/min (maximum 12 mg/kg/min).
const hypoGirStep = 2;
const hypoMaxGir = 12;

/// Stop IV fluids when euglycemic on GIR 4 mg/kg/min and tolerating
/// adequate enteral feeds.
const hypoStopGir = 4;

/// IV bolus: 2 ml/kg of 10% of dextrose.
const hypoBolusMlPerKg = 2;

/// WHOM TO SCREEN FOR HYPOGLYCEMIA.
enum HypoRisk {
  preterm(hypoRiskPreterm),
  lowBirthWeight(hypoRiskLbw),
  sga(hypoRiskSga),
  lga(hypoRiskLga),
  idm(hypoRiskIdm),
  betaBlockers(hypoRiskBetaBlockers),
  sick(hypoRiskSick),
  exchangeTransfusion(hypoRiskExchange);

  const HypoRisk(this.label);
  final String label;
}

/// LOOK FOR THE FOLLOWING SYMPTOMS AND SIGNS.
enum HypoSymptom {
  stupor(hypoSymptomStupor),
  jitteriness(hypoSymptomJitter),
  cyanosis(hypoSymptomCyanosis),
  cry(hypoSymptomCry),
  unableToFeed(hypoSymptomFeed);

  const HypoSymptom(this.label);
  final String label;
}

enum HypoBranch {
  /// BG ≥45 mg/dL: the flowchart (entry BLOOD GLUCOSE <45 mg/dL) is not
  /// entered.
  notTriggered,

  /// ASYMPTOMATIC & BG ≥25 mg/dL.
  supervisedFeeding,

  /// SYMPTOMATIC OR BG < 25 mg/dL.
  ivGlucose,
}

/// Branch for a first BG value; null until BG (and, when <45, the symptom
/// check) is recorded.
HypoBranch? hypoBranch(int? bg, Set<HypoSymptom>? symptoms) {
  if (bg == null) return null;
  if (bg >= hypoThresholdMgDl) return HypoBranch.notTriggered;
  if (symptoms == null) return null;
  if (symptoms.isNotEmpty || bg < hypoSevereThresholdMgDl) {
    return HypoBranch.ivGlucose;
  }
  return HypoBranch.supervisedFeeding;
}

enum HypoRecheckOutcome {
  /// If BG ≥ 45 mg/dL: continue feeds; BG monitoring 6 hourly for 24 hours.
  continueFeeds,

  /// Start IV glucose infusion if: BG < 45 mg/dL OR symptoms develop.
  startIvInfusion,
}

/// RE-CHECK BG AFTER 1 HOUR (supervised-feeding branch).
HypoRecheckOutcome? hypoRecheckOutcome(int? bg, bool? symptomsDeveloped) {
  if (bg == null) return null;
  return bg < hypoThresholdMgDl || symptomsDeveloped == true
      ? HypoRecheckOutcome.startIvInfusion
      : HypoRecheckOutcome.continueFeeds;
}

enum HypoIvOutcome {
  /// BG < 45 mg/dL: increase GIR by 2 mg/kg/min.
  increaseGir,

  /// BG < 45 mg/dL with GIR already at the 12 mg/kg/min maximum.
  maxGirReached,

  /// BG ≥ 45 mg/dL, not yet euglycemic for 24 hours on IV fluids.
  awaitEuglycemia24h,

  /// Euglycemic for 24 hours, GIR above 4: reduce GIR by 2 every 6 hours.
  wean,

  /// Euglycemic on GIR 4 mg/kg/min and tolerating adequate enteral feeds.
  stopIv,

  /// Euglycemic on GIR 4 but not tolerating adequate enteral feeds.
  stopCriteriaNotMet,

  /// Euglycemic on a GIR below 4: not addressed by the STW.
  girBelowStw,
}

/// Outcome of a BG re-check while on IV glucose; null until GIR and BG are
/// recorded.
HypoIvOutcome? hypoIvOutcome({
  int? gir,
  int? bg,
  bool? euglycemic24h,
  bool? toleratingFeeds,
}) {
  if (gir == null || bg == null) return null;
  if (bg < hypoThresholdMgDl) {
    return gir >= hypoMaxGir
        ? HypoIvOutcome.maxGirReached
        : HypoIvOutcome.increaseGir;
  }
  if (euglycemic24h != true) return HypoIvOutcome.awaitEuglycemia24h;
  if (gir > hypoStopGir) return HypoIvOutcome.wean;
  if (gir < hypoStopGir) return HypoIvOutcome.girBelowStw;
  return toleratingFeeds == true
      ? HypoIvOutcome.stopIv
      : HypoIvOutcome.stopCriteriaNotMet;
}

/// GIR after "Increase GIR by 2 mg/kg/min (maximum 12 mg/kg/min)".
int hypoIncreasedGir(int current) {
  final next = current + hypoGirStep;
  return next > hypoMaxGir ? hypoMaxGir : next;
}

/// Exact decimal for [thousandths] / 1000, without rounding (e.g. 2500 →
/// "2.5", 2468 → "2.468", 3000 → "3").
String _thousandths(int thousandths) {
  final whole = thousandths ~/ 1000;
  final frac = (thousandths % 1000).toString().padLeft(3, '0');
  final trimmed = frac.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}

/// Bolus volume as the straight multiplication of the STW per-kg value
/// (2 ml/kg) by the weight, with the formula shown. Exact; not rounded.
String hypoBolusVolumeText(int weightG) {
  final kg = _thousandths(weightG);
  final ml = _thousandths(hypoBolusMlPerKg * weightG);
  return 'Bolus volume = $hypoBolusMlPerKg ml/kg × $kg kg = $ml ml of 10% '
      'dextrose (straight multiplication of the STW per-kg value; verify '
      'before giving)';
}
