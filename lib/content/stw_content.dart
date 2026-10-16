/// Static text and metadata reproduced from the bundled STW documents.
library;

class RefSection {
  const RefSection(this.title, this.lines, {this.isDont = false});
  final String title;
  final List<String> lines;
  final bool isDont;
}

class RelatedLink {
  const RelatedLink(this.title, [this.url]);
  final String title;

  /// The PDF shows these as QR codes (not machine-readable in the source).
  /// Fill in once the URLs are confirmed.
  final String? url;
}

/// An STW whose PDF is bundled with the app. App text (not from the
/// STWs): titles, ICD-11 codes and dates as printed on each PDF.
class BundledStw {
  const BundledStw(this.title, this.code, this.version, this.appliesTo);
  final String title;

  /// ICD code printed on the PDF; null when the PDF gives none.
  final String? code;
  final String version;

  /// Who the workflow assesses.
  final String appliesTo;
}

const bundledStws = [
  BundledStw('Sepsis in Neonates', 'ICD-10-P36', 'August 2026', 'newborn'),
  BundledStw('Respiratory Distress in Neonates', 'ICD-11 KB23', 'August 2026',
      'newborn'),
  BundledStw('Retinopathy of Prematurity (ROP)', 'ICD-11 9B71.3', 'August 2026',
      'newborn'),
  BundledStw('Antenatal Corticosteroids for Preterm Birth', null, 'August 2026',
      'pregnant woman at risk of preterm birth'),
  BundledStw(
      'Neonatal Hypoglycemia', 'ICD-11 KB60.4', 'August 2026', 'newborn'),
  BundledStw('Neonatal Emergency Triage Assessment and Management', null,
      'July 2020', 'newborn'),
  BundledStw('Kangaroo Mother Care', null, 'August 2026',
      'preterm or low-birth-weight infant'),
];

/// App text shown under [stwDisclaimer].
const stwDisclaimerNote =
    'Each of these STWs carries this disclaimer. The Antenatal '
    'Corticosteroids for Preterm Birth and Neonatal Hypoglycemia STWs direct '
    'readers to the DHR portal (stw.icmr.org.in) for more information. The '
    'app follows the STW PDFs as published; open them under References.';

const stwDisclaimer =
    'This STW has been prepared by national experts of India with feasibility '
    'considerations for various levels of healthcare system in the country. '
    'These broad guidelines are advisory, and are based on expert opinions and '
    'available scientific evidence. There may be variations in the management '
    'of an individual patient based on his/her specific condition, as decided '
    'by the treating physician. There will be no indemnity for direct or '
    'indirect consequences. Kindly visit the website of DHR for more '
    'information (stw.icmr.org.in). © Department of Health Research, Ministry '
    'of Health & Family Welfare, Government of India.';

// ---------------------------------------------------------------------------
// Respiratory distress
// ---------------------------------------------------------------------------

const rdImmediateActions = [
    "Apnoea/gasping, poor effort or shock: Stabilize immediately; ventilate when indicated",
    "Maintain TABC; provide warmth; admit to SNCU/NICU",
    "Attach pulse oximeter; monitor HR, RR, SpO₂ and CRT; assess SAS",
    "Feed when stable: breastfeed if mild RD; OG feeds when appropriate on CPAP; decompress stomach",
    "Withhold feeds; give IV fluids for severe RD, recurrent apnoea, poor perfusion or abdominal concerns",
];

const rdReference = [
  RefSection("DOs", [
    "Assess severity using SAS; monitor SpO₂ continuously",
    "Maintain SpO₂ 91–95%",
    "Start CPAP within 30 min of identification of indication",
    "Give early rescue surfactant promptly when indicated",
]),
  RefSection("DON’Ts", [
    "Do NOT give unmonitored supplemental oxygen",
    "Do NOT order routine CBC/CRP, chest X-ray or blood gas in uncomplicated mild RD",
    "Do NOT give IV fluids, antibiotics or blood products routinely",
    "Do NOT delay ventilation or referral when CPAP fails",
], isDont: true),
  RefSection("ALGORITHM", [
    "ASSESS GESTATIONAL AGE (GA)* + SILVERMAN–ANDERSEN SCORE (SAS)",
    "*If GA is uncertain, BW ≤1800 g may be used as an operational surrogate",
    "GA ≤34 weeks Any respiratory distress",
    "GA >34 weeks Moderate–severe RD (SAS ≥4)",
    "GA >34 weeks Mild RD (SAS ≤3)",
]),
  RefSection("START CPAP", [
    "CPAP 5–6 cm H₂O; blended oxygen; titrate FiO₂ to SpO₂ 91–95%",
    "Caffeine citrate for babies <34 weeks requiring respiratory support, as per protocol",
]),
  RefSection("NASAL PRONGS OXYGEN", [
    "If SpO₂ <91%: 0.5–1 L/min; Titrate to SpO₂ 91–95%",
]),
  RefSection("MONITORING", [
    "Monitor SpO₂ continuously while on oxygen/CPAP",
    "Reassess clinical status, SAS and FiO₂ requirement within 15–30 min of starting/changing support",
    "Reassess at least 1 hourly while on respiratory support; immediately if any worsening",
]),
  RefSection("IMPROVING", [
    "Decreasing SAS; SpO₂ 91–95% on stable/reducing support; Comfortable breathing",
]),
  RefSection("NOT IMPROVING / WORSENING", [
    "Persisting/increasing SAS",
    "SpO₂ <91% or rising oxygen need",
    "Recurrent apnoea/bradycardia",
    "Consider sepsis (Refer to sepsis STW)",
]),
  RefSection("EARLY RESCUE SURFACTANT", [
    "Suspected worsening RDS in a preterm neonate <34 weeks, AND FiO₂ >0.30 on CPAP ≥6 cm H₂O to maintain SpO₂ 91–95%",
    "Give promptly when indicated—before established CPAP failure",
]),
  RefSection("WEAN WHEN STABLE", [
    "Comfortable breathing; no significant apnoea; low oxygen requirement",
    "Reduce FiO₂, then CPAP as per protocol",
    "Trial off when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25",
    "Monitor SpO₂ for 24 h after stopping",
]),
  RefSection("OPTIMIZE RESPIRATORY SUPPORT", [
    "If on Nasal Prongs oxygen, rising oxygen need or distress: Start CPAP",
    "Check prongs, circuit and delivered pressure",
    "Increase CPAP up to 7–8 cm H₂O; Titrate FiO₂",
    "Exclude pneumothorax (Transillumination, X-ray)",
    "Consider surfactant",
]),
  RefSection("CPAP FAILURE — ESCALATE PROMPTLY", [
    "Persistent hypoxaemia/rising FiO₂ despite optimized CPAP, recurrent apnoea, shock or fatigue",
    "Escalate support; intubate/ventilate when indicated; stabilize and refer urgently",
]),
  RefSection("KEY PERFORMANCE INDICATORS (KPIs)", [
    "Timely CPAP initiation (%)\nEligible neonates with RD started on CPAP within 30 min of identification\n÷ All neonates with RD meeting the STW criteria for CPAP\n× 100\nTarget >90%",
    "Continuous pulse-oximetry coverage (%)\nNeonates receiving oxygen or CPAP with documented continuous pulse oximetry\n÷ All neonates receiving oxygen or CPAP\n× 100\nTarget >90%",
]),
  RefSection("ABBREVIATIONS", [
    "BW: Birth weight",
    "CPAP: Continuous positive airway pressure",
    "CRT: Capillary refill time",
    "GA: Gestational age",
    "FiO₂: Fraction of inspired oxygen",
    "PEEP: Positive end-expiratory pressure",
    "RD: Respiratory distress",
    "RR: Respiratory rate",
    "SAS: Silverman–Andersen score",
    "SpO₂: Peripheral oxygen saturation",
    "TABC: Temperature, airway, breathing, circulation",
]),
  RefSection("REFERENCES", [
    "1. National Neonatology Forum India. Oxygen Therapy in Neonates; Surfactant Replacement Therapy in Neonates. Evidence-based Clinical Practice Guidelines. nnfi.org/cpg.php",
    "2. Sweet DG et al. European Consensus Guidelines on the Management of Respiratory Distress Syndrome: 2022 Update. Neonatology. 2023;120:3–23.",
]),
];

const rdRelatedLinks = [
  RelatedLink("Bubble CPAP setup"),
  RelatedLink("Fixing binasal prongs"),
  RelatedLink("SAS scoring"),
  RelatedLink("Surfactant administration"),
];

// ---------------------------------------------------------------------------
// ROP
// ---------------------------------------------------------------------------

const ropIntro =
    'ROP is a potentially blinding retinal vascular disorder of preterm '
    'infants. Severe disease may cause retinal detachment and irreversible '
    'vision loss. Optimal quality neonatal care, timely screening and prompt '
    'treatment can prevent most ROP-related blindness.';

const ropArrangeScreening = [
  'Preferred: on-site screening in SNCU/NICU by an ROP-trained '
      'ophthalmologist/tele-screening team with appropriate monitoring.',
  'If unavailable: arrange scheduled specialist visits, or safe referral to '
      'the nearest designated ROP screening centre.',
];

const ropPrepareChecklist = [
  'Withhold feeds 1 hour before screening',
  'Dilate pupils: phenylephrine 2.5% + tropicamide 0.5–0.8% eye drops '
      '(2–3 times at 10 min interval)',
  'Swaddle; proparacaine eye drops; EBM/oral 25% dextrose for analgesia',
  'Maintain temperature and monitor SpO₂',
];

const ropHowToScreenChecklist = [
  'Strict hand hygiene and asepsis',
  'Examine both eyes by indirect ophthalmoscopy (20D/28D lens); '
      'speculum/scleral indentation as required',
  'Wide-field retinal imaging/tele-screening where available',
  'Monitor for apnea, bradycardia, desaturation and feed intolerance',
  'Document ROP findings and the date/place of the next examination',
];

const ropTreatmentOptions = [
  'Laser photocoagulation and/or intravitreal anti-VEGF injection, as '
      'decided by the ROP specialist based on zone and disease '
      'characteristics.',
  'Vitreo-retinal surgery for advanced ROP.',
  'Treatment-requiring ROP should be treated urgently, preferably within '
      '48–72 hours of the decision to treat.',
];

const ropReference = [
  RefSection('Whom to screen (any ONE)', [
    'Gestation <34 weeks',
    'Birth weight <2000 g',
    'Gestation 34–36 weeks with specified risk factors* or an unstable '
        'clinical course',
    '*Significant cardiorespiratory support, prolonged/poorly controlled '
        'oxygen therapy, significant anemia, blood transfusion, sepsis, poor '
        'postnatal weight gain',
  ]),
  RefSection('When to screen', [
    'First screen by 4 weeks postnatal age.',
    'By 2–3 weeks postnatal age if GA <28 weeks or BW <1200 g.',
    'If already overdue, screen ASAP.',
    'If follow-up uncertain, screen before discharge even if not due.',
    'Repeat as advised by ROP-trained ophthalmologist, usually every 1–3 '
        'weeks; posterior/progressive disease or suspected A-ROP may need '
        'review within 1 week or sooner.',
  ]),
  RefSection('How to arrange screening', ropArrangeScreening),
  RefSection('Prepare to screen', ropPrepareChecklist),
  RefSection('How to screen', ropHowToScreenChecklist),
  RefSection('Treatment indications', [
    'Zone I: any stage with plus disease, or stage 3 without plus.',
    'Zone II: stage 2–3 with plus disease.',
    'Aggressive ROP (A-ROP): urgent treatment.',
    'Reactivation/significant PAR after anti-VEGF; stage 2–3; stage 4–5.',
    'Advanced ROP (stage 4–5): requires referral for surgery.',
  ]),
  RefSection('Treatment options', ropTreatmentOptions),
  RefSection('When to stop screening', [
    'Stop only when advised by ROP-trained ophthalmologist (retina fully '
        'vascularised, or ROP fully regressed).',
    'After anti-VEGF, prolonged follow-up at least until 65 weeks PMA is '
        'required because of the risk of late reactivation and PAR.',
  ]),
  RefSection('Prevention', [
    'Antenatal corticosteroids for fetal lung maturation.',
    'Safe oxygen therapy: air-oxygen blenders and continuous pulse oximetry; '
        'target SpO₂ 91–95%.',
    'Prevent and promptly treat sepsis.',
    'Ensure mother’s own milk, optimal nutrition and adequate postnatal '
        'growth.',
    'Avoid unnecessary blood transfusions.',
  ]),
  RefSection('DOs', [
    'Ensure timely ROP screening and follow-up.',
    'Document the date and place of next screening in discharge card.',
    'Counsel the family regarding need for follow-up and risk of vision loss '
        'if screening is delayed.',
  ]),
  RefSection(
      'DON’Ts',
      [
        'DO NOT discharge/transfer an at-risk neonate without a documented ROP '
            'follow-up plan.',
        'DO NOT delay referral/treatment when indicated.',
        'DO NOT stop ROP follow-up without advice of ROP-trained ophthalmologist.',
      ],
      isDont: true),
  RefSection('Key performance indicators (target 95–100%)', [
    'ROP screening coverage (%) = eligible infants who received at least one '
        'ROP eye examination ÷ total eligible infants × 100.',
    'Timely first ROP screening (%) = eligible infants screened within the '
        'recommended first-screen window ÷ eligible infants due for first '
        'screening × 100.',
  ]),
  RefSection('Abbreviations', [
    'A-ROP: Aggressive ROP · BW: Birth weight · EBM: Expressed Breastmilk · '
        'GA: Gestational Age · PAR: Persistent Avascular Retina · '
        'PMA: Postmenstrual Age · ROP: Retinopathy of Prematurity · '
        'VEGF: Vascular Endothelial Growth Factor',
  ]),
  RefSection('References', [
    'MoHFW, Government of India. Guidelines for Universal Eye Screening in '
        'Newborns Including Retinopathy of Prematurity. RBSK. nhm.gov.in',
    'National Neonatology Forum of India. Screening and Management of '
        'Retinopathy of Prematurity: Clinical Practice Guideline. '
        'nnfi.org/cpg.php',
  ]),
];

const ropRelatedLinks = [
  RelatedLink('ROP classification'),
  RelatedLink('ROP record form'),
  RelatedLink('Information for parents and FAQs'),
  RelatedLink('Preterm care package'),
];
