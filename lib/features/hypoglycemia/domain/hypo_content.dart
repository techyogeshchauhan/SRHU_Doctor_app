/// Verbatim text of the ICMR/DHR STW "Neonatal Hypoglycemia" (ICD-11
/// KB60.4, August 2026; assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf,
/// single page).
///
/// Copied from the PDF text layer; only the "ﬁ" ligature is written as "fi".
/// The flowchart has hidden duplicate text objects behind some boxes (e.g.
/// "Increase GIR @ 2 mg/kg/min till max GIR 12 mg/kg/min"); the visible box
/// text is used. Do not reword: see CLINICAL_REVIEW.md.
library;

import '../../../content/stw_content.dart';
import '../../ancs/domain/ancs_content.dart' show stwPortalDisclaimer;

const hypoPdfAsset = 'assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf';
const hypoPdfFile = 'Neonatal_Hypoglycemia_8th_Oct.pdf';
const hypoPdfTitle = 'Neonatal Hypoglycemia';

// WHOM TO SCREEN FOR HYPOGLYCEMIA
const hypoRiskPreterm = 'Preterm infants (<37 weeks’ gestation)';
const hypoRiskLbw = 'Low-birth-weight infants (<2500 g)';
const hypoRiskSga =
    'Small-for-gestational-age (SGA) infants: birth weight <10th percentile '
    'as per INTERGROWTH-21st standards';
const hypoRiskLga =
    'Large-for-gestational-age (LGA) infants: birth weight >90th percentile '
    'as per INTERGROWTH-21st standards';
const hypoRiskIdm = 'Infants of diabetic mothers (IDM)';
const hypoRiskBetaBlockers = 'Neonates born to mothers receiving beta-blockers';
const hypoRiskSick =
    'Sick neonates, including those with sepsis, shock, birth asphyxia, '
    'respiratory distress, polycythaemia, on IV fluids';
const hypoRiskExchange = 'Neonates following exchange transfusion';
const hypoRoutineNotRequired =
    'Routine blood glucose monitoring is not required in healthy term AGA '
    'neonates';

// SCHEDULE OF BLOOD GLUCOSE MONITORING
const hypoScheduleAtRisk = 'At-risk infants: 1, 2, 6, 12, 24, 48, 72 hours';
const hypoScheduleIdm =
    '*in IDM, monitoring can be stopped between 24-36 hours provided feeding '
    'is established';
const hypoScheduleIv = 'Infants on IV fluids: Every 6-8 hours';
const hypoSchedulePreFeed = 'BG should be measured pre-feeding';

// HOW TO MONITOR BLOOD GLUCOSE (BG)
const hypoMonitorGlucometer = 'Measure BG using a point-of-care glucometer';
const hypoMonitorLab = 'Low value (<45 mg/dL): send a blood sample to the lab';
const hypoMonitorNoDelay = 'DO NOT delay treatment for lab confirmation';

// Flowchart entry box
const hypoEntry = 'BLOOD GLUCOSE <45 mg/dL';

// LOOK FOR THE FOLLOWING SYMPTOMS AND SIGNS
const hypoSymptomStupor = 'Stupor, lethargy, limpness';
const hypoSymptomJitter = 'Jitteriness, tremors, convulsions';
const hypoSymptomCyanosis = 'Episodes of cyanosis, apnoea or tachypnoea';
const hypoSymptomCry = 'Weak or high-pitched cry';
const hypoSymptomFeed = 'Unable to feed';

// ASYMPTOMATIC & BG ≥25 mg/dL
const hypoAsymptomaticTitle = 'ASYMPTOMATIC & BG ≥25 mg/dL';
const hypoSupervisedFeeding = 'Immediate supervised feeding';
const hypoFeedHow =
    'Breastfeeding or a measured volume of expressed breastmilk (Formula '
    'milk if EBM not available) by paladai or gavage';
const hypoRecheck1h = 'RE-CHECK BG AFTER 1 HOUR';
const hypoRecheckOkTitle = 'If BG ≥ 45 mg/dL';
const hypoContinueFeeds = 'Continue feeds';
const hypoContinueMonitoring = 'Continue BG monitoring 6 hourly for 24 hours';
const hypoStartIvIf = 'Start IV glucose infusion if:';
const hypoStartIvIfBg = 'BG < 45 mg/dL OR';
const hypoStartIvIfSymptoms = 'Symptoms develop';

// SYMPTOMATIC OR BG < 25 mg/dL
const hypoSymptomaticTitle = 'SYMPTOMATIC OR BG < 25 mg/dL';
const hypoBolus = 'IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute';
const hypoStartInfusion =
    'Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 '
    'mg/kg/min';

// After IV glucose
const hypoRecheck30 =
    'Re-check BG every 30 min until 2 consecutive values are ≥45 mg/dL, then '
    'every 6 h';
const hypoIncreaseGir = 'Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)';
const hypoPersistentRefractory =
    'Persistent (GIR requirement >3-7 days) or Refractory (GIR > 10-12 '
    'mg/kg/min for 24 hours) hypoglycemia';
const hypoPersistent = 'Persistent (GIR requirement >3-7 days)';
const hypoRefractory = 'Refractory (GIR > 10-12 mg/kg/min for 24 hours)';
const hypoConsiderRefer =
    'Consider ENDOCRINE/ METABOLIC disorders & REFER to higher centre';
const hypoEuglycemic24h = 'Euglycemic for 24 hours on IV fluids';
const hypoReduceGir = 'Reduce GIR by 2 mg/ kg/min every 6 hours';
const hypoIncreaseOralFeeds = 'Increase oral feeds';
const hypoMonitor6h = 'Monitor BG every 6 hours';
const hypoStopIv =
    'Stop IV fluids when euglycemic on GIR 4 mg/ kg/min and tolerating '
    'adequate enteral feeds';

// DRUGS FOR REFRACTORY HYPOGLYCEMIA
const hypoDrugsTitle = 'DRUGS FOR REFRACTORY HYPOGLYCEMIA';
const hypoHydrocortisone =
    'Hydrocortisone: 5 mg/kg/day IV in two divided doses';
const hypoAdditionalDrugs =
    'Additional drugs should be administered at a tertiary care hospital with '
    'workup for underlying causes';

// PREVENTION OF HYPOGLYCEMIA
const hypoPrevention = [
  'Support mother for early initiation and regular breastfeeding',
  'Maintain normothermia',
  'Do not feed dextrose solutions as a substitute for breastmilk',
];

// PRACTICAL POINTS
const hypoPracticalPoints = [
  'Avoid > 12.5-15% dextrose infusion through a peripheral vein',
  'Maintain patency of IV cannula',
  'Use a syringe/infusion pump to deliver glucose',
  'Avoid frequent dextrose boluses',
  'Always search for an underlying cause – polycythemia, sepsis, meningitis, '
      'hypothermia, IUGR',
];

// DO's / DON'Ts
const hypoDos = [
  'Monitor BG in all; as per protocol',
  'Support early and frequent breastfeeding',
  'Treat symptomatic hypoglycemia immediately',
];
const hypoDonts = [
  'Do NOT substitute dextrose solutions for breastmilk',
  'Do NOT separate a stable mother-infant dyad solely for glucose monitoring',
  'Do NOT give antibiotics for hypoglycemia unless sepsis is suspected',
];

// KEY PERFORMANCE INDICATORS (KPIs)
const hypoKpis = [
  'Blood glucose screening coverage = At-risk neonates monitored for BG as '
      'per protocol × 100 / Total at-risk neonates eligible for BG '
      'monitoring (Target ≥90%)',
  'Timely BG re-check after treatment = Hypoglycemic episodes with repeat BG '
      'within prescribed interval × 100 / No. of hypoglycemic episodes '
      'treated (Target ≥90%)',
];

const hypoNeuroFollowUp =
    'NEONATES WITH SYMPTOMATIC, SEVERE, RECURRENT OR PERSISTENT HYPOGLYCEMIA '
    'SHOULD RECEIVE STRUCTURED NEURODEVELOPMENTAL FOLLOW-UP';

const hypoAbbreviations = [
  'AGA: Appropriate for Gestational Age',
  'BG: Blood Glucose',
  'EBM: Expressed Breastmilk',
  'GIR: Glucose Infusion Rate',
  'IDM: Infant of Diabetic Mother',
  'IV: Intravenous',
  'IUGR: Intrauterine Growth Restriction',
];

const hypoReferences = [
  '1. Committee on Fetus and Newborn, Adamkin DH. Postnatal glucose '
      'homeostasis in late-preterm and term infants. Pediatrics 2011; '
      '127:575.',
  '2. Cornblath M, Hawdon JM, Williams AF, et al. Controversies regarding '
      'definition of neonatal hypoglycemia: Suggested operational '
      'thresholds. Pediatrics 2000;105(5):1141–5.',
  '3. Management of Neonatal Hypoglycemia. 25 November 2023. New Delhi: '
      'National Neonatology Forum of India; 2023 (NNF/2023/CPG/ 2023.5.0) '
      'Accessed from: https://app.magicapp.org/#/guideline/6893',
];

/// Reference screen: every box of the STW, in PDF order.
const hypoReference = [
  RefSection('WHOM TO SCREEN FOR HYPOGLYCEMIA', [
    hypoRiskPreterm,
    hypoRiskLbw,
    hypoRiskSga,
    hypoRiskLga,
    hypoRiskIdm,
    hypoRiskBetaBlockers,
    hypoRiskSick,
    hypoRiskExchange,
    hypoRoutineNotRequired,
  ]),
  RefSection('SCHEDULE OF BLOOD GLUCOSE MONITORING', [
    hypoScheduleAtRisk,
    hypoScheduleIdm,
    hypoScheduleIv,
    hypoSchedulePreFeed,
  ]),
  RefSection('HOW TO MONITOR BLOOD GLUCOSE (BG)', [
    hypoMonitorGlucometer,
    hypoMonitorLab,
    hypoMonitorNoDelay,
  ]),
  RefSection('LOOK FOR THE FOLLOWING SYMPTOMS AND SIGNS', [
    hypoSymptomStupor,
    hypoSymptomJitter,
    hypoSymptomCyanosis,
    hypoSymptomCry,
    hypoSymptomFeed,
  ]),
  RefSection(hypoAsymptomaticTitle, [
    hypoSupervisedFeeding,
    hypoFeedHow,
    hypoRecheck1h,
    '$hypoRecheckOkTitle: $hypoContinueFeeds; $hypoContinueMonitoring',
    '$hypoStartIvIf $hypoStartIvIfBg $hypoStartIvIfSymptoms',
  ]),
  RefSection(hypoSymptomaticTitle, [hypoBolus, hypoStartInfusion]),
  RefSection('AFTER STARTING IV GLUCOSE', [
    hypoRecheck30,
    'BG < 45 mg/dL: $hypoIncreaseGir',
    '$hypoPersistentRefractory: $hypoConsiderRefer',
    'BG ≥ 45 mg/dL: $hypoEuglycemic24h',
    '$hypoReduceGir; $hypoIncreaseOralFeeds; $hypoMonitor6h',
    hypoStopIv,
  ]),
  RefSection(hypoDrugsTitle, [hypoHydrocortisone, hypoAdditionalDrugs]),
  RefSection('PREVENTION OF HYPOGLYCEMIA', hypoPrevention),
  RefSection('PRACTICAL POINTS', hypoPracticalPoints),
  RefSection('DO’s', hypoDos),
  RefSection('DON’Ts', hypoDonts, isDont: true),
  RefSection('KEY PERFORMANCE INDICATORS (KPIs)', hypoKpis),
  RefSection('FOLLOW-UP', [hypoNeuroFollowUp]),
  RefSection('ABBREVIATIONS', hypoAbbreviations),
  RefSection('REFERENCES', hypoReferences),
  RefSection('DISCLAIMER (FROM THE STW)', [stwPortalDisclaimer]),
];

/// QR codes in the PDF; their content is not reproduced (see the PDF).
const hypoRelatedLinks = [
  RelatedLink('GIR calculations'),
  RelatedLink('Heel Prick for BG estimation'),
];
