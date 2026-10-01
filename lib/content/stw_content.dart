/// Static text reproduced from the two STW documents (Aug 2026).
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
  'Assess and stabilize TABC (temperature, airway, breathing, circulation)',
  'Admit to SNCU/NICU',
  'Provide thermal care',
  'Attach pulse oximeter',
  'Monitor HR, RR, SpO₂ and CRT; grade severity using SAS',
  'Feed enterally if stable: direct breastfeed if mild distress; '
      'gastric-tube feeds if moderate distress, or on CPAP',
  'IV fluids if severe distress, recurrent apnea, poor perfusion, '
      'or abdominal signs',
];

const rdReference = [
  RefSection('DOs', [
    'Assess severity using SAS and monitor SpO₂ continuously.',
    'Maintain SpO₂ 91%–95%.',
    'Start CPAP within 30 minutes.',
    'Administer surfactant within 2 hours.',
  ]),
  RefSection('DON’Ts', [
    'DO NOT give unmonitored supplemental oxygen.',
    'DO NOT perform routine CBC, CRP, Chest X-ray or blood gas in '
        'uncomplicated mild RD.',
    'DO NOT give IV fluids, antibiotics, or blood products routinely.',
    'DO NOT delay mechanical ventilation or referral in case of CPAP failure.',
  ], isDont: true),
  RefSection('Algorithm summary', [
    'GA ≤34 weeks, any RD → START CPAP 5–6 cm H₂O; blended O₂, titrate FiO₂ '
        'to SpO₂ 91–95%. Caffeine citrate if <34 weeks on respiratory support.',
    'GA >34 weeks, moderate–severe RD (SAS ≥4) → START CPAP.',
    'GA >34 weeks, mild RD (SAS ≤3) → nasal-prong oxygen 0.5–1 L/min, '
        'titrate to SpO₂ 91–95%.',
    'If GA is uncertain, BW ≤1800 g may be used as an operational surrogate.',
    'Reassess frequently: clinical status, SAS, SpO₂, FiO₂ requirement.',
    'Surfactant: <34 weeks on CPAP needing PEEP >6 cm H₂O AND FiO₂ >0.30 '
        'to keep SpO₂ 91–95%.',
    'Improving → wean FiO₂ first to 0.21, then reduce CPAP in 1 cm H₂O steps '
        'to 4–5 cm H₂O and stop when stable; monitor SpO₂ for 24 h after.',
    'Not improving → optimise CPAP: PEEP stepwise up to 7–8 cm H₂O, titrate '
        'FiO₂, look for/treat cause, consider surfactant.',
    'CPAP failure (persistent hypoxemia/high FiO₂, recurrent apnea, shock or '
        'fatigue) → refer urgently.',
  ]),
  RefSection('Key performance indicators (target >90%)', [
    'Timely CPAP initiation (%) = neonates ≤34 weeks with RD started on CPAP '
        'within 30 min of diagnosis or admission ÷ neonates ≤34 weeks '
        'diagnosed with RD × 100.',
    'SpO₂ target compliance (%) = neonates on supplemental O₂ or CPAP with '
        'continuous pulse oximetry and SpO₂ in target range ÷ neonates '
        'receiving supplemental O₂ or CPAP × 100.',
  ]),
  RefSection('Abbreviations', [
    'BW: Birth Weight · CRT: Capillary Refill Time · CPAP: Continuous '
        'Positive Airway Pressure · GA: Gestational Age · IV: Intravenous · '
        'SpO₂: Peripheral Oxygen Saturation · RD: Respiratory Distress · '
        'FiO₂: Fraction of Inspired Oxygen · RR: Respiratory Rate · '
        'PEEP: Positive End-Expiratory Pressure · SAS: Silverman-Andersen Score',
  ]),
  RefSection('References', [
    'Oxygen therapy in neonates, and Surfactant Replacement therapy in '
        'neonates. Evidence-based Clinical Practice Guidelines. National '
        'Neonatology Forum India. www.nnfi.org/cpg',
  ]),
];

const rdRelatedLinks = [
  RelatedLink('How to set up a bubble CPAP'),
  RelatedLink('How to connect a ventilator CPAP'),
  RelatedLink('How to fix binasal prongs'),
  RelatedLink('Silverman-Andersen scoring'),
  RelatedLink('Surfactant administration'),
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
  RefSection('DON’Ts', [
    'DO NOT discharge/transfer an at-risk neonate without a documented ROP '
        'follow-up plan.',
    'DO NOT delay referral/treatment when indicated.',
    'DO NOT stop ROP follow-up without advice of ROP-trained ophthalmologist.',
  ], isDont: true),
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
