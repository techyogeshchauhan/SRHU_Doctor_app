/// Verbatim text of the ICMR/DHR STW "Antenatal Corticosteroids for Preterm
/// Birth" (August 2026; assets/pdfs/
/// Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf, single page).
///
/// Copied from the PDF text layer; only the "ﬁ" ligature is written as "fi".
/// Do not reword: see CLINICAL_REVIEW.md for open questions on the wording.
library;

import '../../../content/stw_content.dart';

const ancsPdfAsset =
    'assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf';
const ancsPdfFile = 'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf';
const ancsPdfTitle = 'Antenatal Corticosteroids for Preterm Birth';

// INTRODUCTION
const ancsIntroduction =
    'Antenatal corticosteroid (ACS) therapy is one of the most cost-effective '
    'interventions for improving outcomes of preterm birth. When given to '
    'women with a high likelihood of preterm birth, it reduces neonatal '
    'mortality, incidence and severity of respiratory distress syndrome, and '
    'intraventricular haemorrhage';

// WHEN TO GIVE
const ancsWhenToGive =
    'Pregnant women at 24+0 to 33+6 weeks of gestation with a high '
    'likelihood of preterm birth within the next 7 days';

// ELIGIBILITY CRITERIA
const ancsEligibilityHeading =
    'GIVE ACS WHEN ALL CONDITIONS ARE MET IN WOMEN AT 24+0 TO 33+6 WEEKS OF '
    'GESTATION:';
const ancsCriterion1 =
    '1. High likelihood of preterm birth within the next 7 days due to any one:';
const ancsCauseSpontaneousLabour =
    'Spontaneous preterm labour: regular contractions with cervical change '
    'consider (dilatation or effacement)';
const ancsCausePprom = 'PPROM without clinical infection';
const ancsCauseAph = 'Antepartum Hemorrhage';
const ancsCausePreEclampsia = 'Severe pre-eclampsia/eclampsia';
const ancsCausePlanned = 'Planned preterm birth for maternal/fetal indication';
const ancsCriterion2 =
    '2. Gestational age assessed accurately, preferably by early USG';
const ancsCriterion3 =
    '3. No clinical chorioamnionitis or systemic maternal infection';
const ancsCriterion4 =
    '4. Adequate childbirth care is available at the facility or at the '
    'referral facility';
const ancsCriterion5 =
    '5. Adequate preterm newborn care be ensured(including CPAP) at the '
    'facility or the receiving facility';
const ancsImportant =
    'IMPORTANT: Start ACS promptly once eligibility criteria are met, even if '
    'the full course may not be completed before birth';

// DRUG & DOSE
const ancsDrugDose =
    'DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES';
const ancsDexaPreferred =
    'Dexamethasone is preferred: it is effective, low-cost, widely available '
    'and more heat-stable';
const ancsBetaNote =
    'Betamethasone regimen (12 mg every 24 hours x 2 doses) requires an '
    'appropriate acetate + phosphate preparation, which is not available in '
    'India. Betamethasone phosphate alone is shorter acting than '
    'dexamethasone';

// WHEN NOT TO GIVE
const ancsNotGiveInfection =
    'Clinical chorioamnionitis or systemic maternal infection';
const ancsNotGiveUnlikely = 'Preterm birth within next 7 days is unlikely';
const ancsNotGiveRoutine34 = 'Routine use at ≥34 weeks';
const ancsNotGiveMoreThanOneRepeat = 'More than one repeat course';

// SPECIAL SITUATIONS
const ancsSpecialDoNotWithhold =
    'When otherwise eligible, do not withhold ACS because of: multiple '
    'pregnancy, fetal growth restriction, hypertensive disorders, or diabetes '
    'in pregnancy';
const ancsSpecialDiabetes =
    'In diabetes: monitor and optimize maternal glucose control';

// WHEN TO GIVE REPEAT COURSE
/// The PDF line ends with a stray fragment ("; neuro-developmental"), kept
/// in [ancsRepeatHeadingAsPrinted]; see CLINICAL_REVIEW.md.
const ancsRepeatHeadingAsPrinted =
    'Give ONE repeat course only if ALL criteria are met; neuro-developmental';
const ancsRepeatHeading = 'Give ONE repeat course only if ALL criteria are met';
const ancsRepeatGa = 'GA 24+0 to 33+6 weeks';
const ancsRepeatLikelihood =
    'High likelihood of preterm birth within the next 7 days';
const ancsRepeatSevenDays =
    'The previous ACS course was started ≥7 days earlier';
const ancsRepeatNoMore = 'Do NOT give more than one repeat course';
const ancsRepeatHarm =
    '(More than one repeat course may cause fetal harm, and is not '
    'recommended)';

// DOCUMENTATION
const ancsDocument =
    'Document: gestational age, indication, drug/dose, date and time, '
    'initial/repeat course, next dose due';
const ancsRecordIn = 'Record in: case sheet, MCP card, and referral slip';

// REFERRAL/TRANSFER
const ancsReferral =
    'Pregnant women with likelihood of early preterm birth should be referred '
    'to a facility (in-utero transfer) with at least level II care (CPAP) for '
    'preterm infants';
const ancsLevelOne =
    'Level I facilities can give the first dose of ACS before referral, '
    'provided the pregnant woman meets the eligibility criteria, but '
    'referral/transfer should not be delayed  to complete the course';

// DOs / DONTs
const ancsDos = [
  'Confirm accurate GA and that preterm birth is likely within next 7 days',
  'Start ACS promptly once eligibility criteria are  met',
  'Monitor maternal glucose closely in women with diabetes',
  'Document dose timing and arrange in-utero transfer when higher-level care '
      'is required',
];
const ancsDonts = [
  'Do NOT give ACS when preterm birth is unlikely within next 7 days',
  'Do NOT delay an indicated birth or referral to complete the ACS course',
  'Do NOT give ACS in clinical chorioamnionitis or systemic maternal '
      'infection',
  'Do NOT routinely use ACS at ≥34+0 weeks or give more than one repeat '
      'course',
];

// KEY PERFORMANCE INDICATORS (KPIs)
const ancsKpis = [
  'ACS coverage = Women at 24+0–33+6 weeks identified with high likelihood '
      'of preterm birth who received ≥1 ACS dose × 100 / All women at '
      '24+0-33+6 weeks identified with high likelihood of preterm birth '
      '(Target: ≥80%)',
  'Appropriate ACS use = (formula not printed in the STW) (Target: ≥95%)',
];

const ancsKeyMessage =
    'TIMELY ACS IMPROVES PRETERM OUTCOMES — GIVE WHEN ELIGIBILITY CRITERIA '
    'ARE MET AND BIRTH IS LIKELY WITHIN 7 DAYS';

const ancsAbbreviations = [
  'ACS: Antenatal Corticosteroids',
  'GA: Gestational Age',
  'PPROM: Preterm Prelabour Rupture of Membranes',
  'CPAP: Continuous Positive Airway Pressure',
  'MCP: Mother and Child Protection Card',
  'IM: Intramuscular',
  'IVH: Intraventricular Hemorrhage',
  'RDS: Respiratory Distress Syndrome',
  'USG: Ultrasonography',
];

const ancsReferences = [
  'McGoldrick E, et al. Antenatal corticosteroids for accelerating fetal '
      'lung maturation for women at risk of preterm birth. Cochrane Database '
      'Syst Rev. 2020;12:CD004454.',
  'World Health Organization. WHO recommendations on antenatal '
      'corticosteroids for improving preterm birth outcomes. Geneva: WHO; '
      '2022.',
];

/// Disclaimer as printed on the 8th-Oct STWs ("DHR portal").
const stwPortalDisclaimer =
    'This STW has been prepared by national experts of India with '
    'feasibility considerations for various levels of healthcare system in '
    'the country. These broad guidelines are advisory, and are based on '
    'expert opinions and available scientific evidence. There may be '
    'variations in the management of an individual patient based on his/her '
    'specific condition, as decided by the treating physician. There will be '
    'no indemnity for direct or indirect consequences. Kindly visit the DHR '
    'portal for more information (stw.icmr.org.in) © Department of Health '
    'Research, Ministry of Health & Family Welfare, Government of India.';

/// Reference screen: every box of the STW, in PDF order.
const ancsReference = [
  RefSection('INTRODUCTION', [ancsIntroduction]),
  RefSection('WHEN TO GIVE', [ancsWhenToGive]),
  RefSection('ELIGIBILITY CRITERIA', [
    ancsEligibilityHeading,
    ancsCriterion1,
    ancsCauseSpontaneousLabour,
    ancsCausePprom,
    ancsCauseAph,
    ancsCausePreEclampsia,
    ancsCausePlanned,
    ancsCriterion2,
    ancsCriterion3,
    ancsCriterion4,
    ancsCriterion5,
    ancsImportant,
  ]),
  RefSection('DRUG & DOSE', [ancsDrugDose, ancsDexaPreferred, ancsBetaNote]),
  RefSection(
    'WHEN NOT TO GIVE',
    [
      ancsNotGiveInfection,
      ancsNotGiveUnlikely,
      ancsNotGiveRoutine34,
      ancsNotGiveMoreThanOneRepeat,
    ],
    isDont: true,
  ),
  RefSection('SPECIAL SITUATIONS', [ancsSpecialDoNotWithhold, ancsSpecialDiabetes]),
  RefSection('WHEN TO GIVE REPEAT COURSE', [
    ancsRepeatHeadingAsPrinted,
    ancsRepeatGa,
    ancsRepeatLikelihood,
    ancsRepeatSevenDays,
    ancsRepeatNoMore,
    ancsRepeatHarm,
  ]),
  RefSection('DOCUMENTATION', [ancsDocument, ancsRecordIn]),
  RefSection('REFERRAL/TRANSFER', [ancsReferral, ancsLevelOne]),
  RefSection('DOs', ancsDos),
  RefSection('DONTs', ancsDonts, isDont: true),
  RefSection('KEY PERFORMANCE INDICATORS (KPIs)', ancsKpis),
  RefSection('KEY MESSAGE', [ancsKeyMessage]),
  RefSection('ABBREVIATIONS', ancsAbbreviations),
  RefSection('REFERENCES', ancsReferences),
  RefSection('DISCLAIMER (FROM THE STW)', [stwPortalDisclaimer]),
];

/// QR codes in the PDF; their targets are not machine-readable.
const ancsRelatedLinks = [
  RelatedLink('Video on Antenatal Steroids'),
  RelatedLink('Antenatal Steroid Use'),
];
