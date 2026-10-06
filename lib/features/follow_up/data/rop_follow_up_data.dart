import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';

/// Authoritative ROP Follow-up Assessment Questions (MCQs and Case Scenarios).
/// Sourced directly from ICMR / DHR ROP STW Training & Evaluation Guidelines.
const List<FollowUpQuestion> ropFollowUpMcqs = [
  FollowUpQuestion(
    id: 'rop_mcq_1',
    disease: NeonatalCondition.rop,
    category: 'ROP Prevention & KPIs',
    questionType: QuestionType.mcq,
    question:
        'Which of the following is the appropriate Key Performance Indicator (KPI) for monitoring the quality of ROP prevention and management practices in an SNCU?',
    options: [
      'Number of babies referred to an ophthalmologist',
      'Percentage of eligible preterm/LBW babies receiving at least one ROP eye examination',
      'Total number of babies receiving oxygen therapy',
      'Percentage of babies discharged without oxygen requirement',
    ],
    correctAnswerIndex: 1,
    explanation:
        'Percentage of eligible preterm/LBW babies receiving at least one ROP eye examination is the designated Key Performance Indicator (KPI) for monitoring the quality of ROP prevention and management practices in an SNCU.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_2',
    disease: NeonatalCondition.rop,
    category: 'Prevention Measures',
    questionType: QuestionType.mcq,
    question:
        'All of the following measures are important for prevention of ROP EXCEPT:',
    options: [
      'Maintaining appropriate oxygen saturation and avoiding unnecessary oxygen exposure',
      'Early and appropriate treatment of neonatal sepsis',
      'Ensuring mother\'s own milk and appropriate weight gain',
      'Liberal blood transfusion for anaemia',
    ],
    correctAnswerIndex: 3,
    explanation:
        'Liberal blood transfusion for anaemia increases the risk of ROP. A restrictive transfusion policy, optimal oxygen saturation control, early sepsis treatment, and mother\'s own milk are key preventive strategies.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_3',
    disease: NeonatalCondition.rop,
    category: 'Screening Arrangements',
    questionType: QuestionType.mcq,
    question:
        'Which of the following is the preferred method for arranging ROP screening?',
    options: [
      'Referral of all infants to a tertiary eye hospital after discharge',
      'On-site screening in SNCU/NICU by an ROP-trained ophthalmologist or tele-screening team with appropriate monitoring',
      'Screening only when visual symptoms develop',
      'Screening only for infants requiring oxygen therapy',
    ],
    correctAnswerIndex: 1,
    explanation:
        'On-site screening in SNCU/NICU by an ROP-trained ophthalmologist or tele-screening team with appropriate cardiorespiratory monitoring is the preferred method to prevent delays and missed cases.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_4',
    disease: NeonatalCondition.rop,
    category: 'Preparation Before Screening',
    questionType: QuestionType.mcq,
    question: 'Before ROP screening, feeds should generally be withheld for:',
    options: [
      '30 minutes',
      '1 hour',
      '3 hours',
      '6 hours',
    ],
    correctAnswerIndex: 1,
    explanation:
        'Before ROP screening, feeds should generally be withheld for 1 hour to prevent regurgitation and aspiration during eye examination.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_5',
    disease: NeonatalCondition.rop,
    category: 'Eligibility Criteria',
    questionType: QuestionType.mcq,
    question:
        'Which babies should be screened for ROP based on gestation age and birth weight criteria in India?',
    options: [
      '<30 wks gestation and/or <1500g birth weight',
      '<32 wks gestation and/or <1500g birth weight',
      '<34 wks gestation and/or <2000g birth weight',
      '<34 wks gestation and/or <1500g birth weight',
    ],
    correctAnswerIndex: 2,
    explanation:
        'In India, preterm infants born at <34 weeks gestation and/or <2000g birth weight (or larger preterm infants with an unstable clinical course) should be screened for ROP per national STW guidelines.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_6',
    disease: NeonatalCondition.rop,
    category: 'Timing of First Screening',
    questionType: QuestionType.mcq,
    question:
        'When should the first ROP screening be done for a baby born at 27 weeks gestation age and 1100g birth weight?',
    options: [
      '2–3 weeks after birth',
      '4 weeks after birth',
      '6 weeks after birth',
      'At birth',
    ],
    correctAnswerIndex: 0,
    explanation:
        'For extremely preterm infants born at <28 weeks gestation, the first ROP screening should be performed earlier, at 2–3 weeks after birth.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_7',
    disease: NeonatalCondition.rop,
    category: 'ROP Treatment',
    questionType: QuestionType.mcq,
    question:
        'Which of the following statements is TRUE regarding ROP treatment?',
    options: [
      'Non-dilating pupil is a good sign.',
      'ROP in Zone I requires Anti-VEGF therapy.',
      'ROP treatments can be safely performed 1 week after diagnosis.',
      'Anti-VEGF treated eyes have low risk of disease reactivation.',
    ],
    correctAnswerIndex: 1,
    explanation:
        'ROP in Zone I (especially Aggressive ROP) is preferentially treated with intravitreal Anti-VEGF therapy. Treatment must be performed within 48–72 hours of diagnosis (not delayed by 1 week), non-dilating pupil indicates iris engorgement/rigidity (poor sign/plus disease sign), and anti-VEGF treated eyes have a significant risk of late reactivation requiring prolonged surveillance.',
  ),
  FollowUpQuestion(
    id: 'rop_mcq_8',
    disease: NeonatalCondition.rop,
    category: 'Management of Stage 1 ROP',
    questionType: QuestionType.mcq,
    question:
        'A 28 weeks 950 g infant undergoes ROP screening and is diagnosed with Zone II stage 1 ROP without plus. What is the most appropriate management?',
    options: [
      'Observe and repeat examination after 2 weeks',
      'Observe and repeat examination after 4 days',
      'Observe, monitor weight gain, encourage KMC, breastfeeding and repeat examination after 2 weeks',
      'Treat with laser photocoagulation within 48–72 hours',
    ],
    correctAnswerIndex: 2,
    explanation:
        'Zone II Stage 1 ROP without plus disease is immature, early disease that does not require immediate intervention. The infant should be observed, weight gain monitored, KMC and breastfeeding encouraged, with repeat examination after 2 weeks.',
  ),
];

/// The 8 authoritative ROP Case Scenarios from ICMR / DHR STW.
const List<FollowUpQuestion> ropFollowUpCaseScenarios = [
  FollowUpQuestion(
    id: 'rop_case_1',
    disease: NeonatalCondition.rop,
    category: 'Oxygen Titration & Respiratory Support',
    questionType: QuestionType.caseScenario,
    scenario:
        'A preterm 32 weeks, 1.5 kg male baby at 48 hours of life, delivered by LSCS, is receiving CPAP with pressure of 5 cm H₂O and FiO₂ of 40%. His SpO₂ is persistently 97–98%. His respiratory rate is 65/minute with minimal chest indrawing, no grunting and no nasal flaring.',
    question:
        'What is the most appropriate action for managing the respiratory support?',
    options: [
      'Gradually reduce oxygen (FiO₂) while continuing monitoring for respiratory distress and saturation',
      'Increase CPAP pressure to 7 cm H₂O and maintain FiO₂ at 40%',
      'Maintain FiO₂ at 40% as SpO₂ is within normal limits',
      'Discontinue CPAP immediately and transition to room air',
    ],
    correctAnswerIndex: 0,
    explanation:
        'Gradually reduce oxygen (FiO₂) while continuing monitoring for respiratory distress and saturation. Target saturation in preterms receiving supplemental oxygen is 91–95%; persistent hyperoxia (97–98%) significantly elevates the risk of severe ROP.',
  ),
  FollowUpQuestion(
    id: 'rop_case_2',
    disease: NeonatalCondition.rop,
    category: 'Quality & KPI Calculation',
    questionType: QuestionType.caseScenario,
    scenario:
        'An SNCU admitted 20 babies during the month who were eligible for ROP screening. On reviewing the records, it was found that 16 babies received their first ROP screening on time, while 4 babies were screened late.',
    question:
        'What was the KPI for timely first ROP screening in this SNCU?',
    options: [
      '80% (16 ÷ 20 × 100)',
      '20% (4 ÷ 20 × 100)',
      '75% (15 ÷ 20 × 100)',
      '85% (17 ÷ 20 × 100)',
    ],
    correctAnswerIndex: 0,
    explanation:
        'Timely first ROP screening = (Number of eligible babies screened on time ÷ Total number of eligible babies) × 100 = (16 ÷ 20) × 100 = 80%.',
  ),
  FollowUpQuestion(
    id: 'rop_case_3',
    disease: NeonatalCondition.rop,
    category: 'Screening Arrangements in SNCU',
    questionType: QuestionType.caseScenario,
    scenario:
        'A district SNCU does not have an ROP-trained ophthalmologist available on-site. The medical officer is planning how to ensure timely ROP screening for eligible preterm infants.',
    question:
        'What should be the most appropriate arrangement for ROP screening?',
    options: [
      'Arrange scheduled specialist visits, safe referral to designated center, or tele-screening where available',
      'Advise parents to consult a local clinic after 6 months of age',
      'Discharge infants without screening and advise return only if visual defects appear',
      'Delay screening until an ophthalmologist is permanently posted at the district hospital',
    ],
    correctAnswerIndex: 0,
    explanation:
        'If on-site screening is unavailable, the SNCU should arrange scheduled specialist visits or ensure safe referral to the nearest designated ROP screening center. Tele-screening may also be used where available.',
  ),
  FollowUpQuestion(
    id: 'rop_case_4',
    disease: NeonatalCondition.rop,
    category: 'Pre-Screening Preparation & Analgesia',
    questionType: QuestionType.caseScenario,
    scenario:
        'A 30 wks, 1400 g infant is scheduled for ROP screening. During preparation, the nurse asks what measures should be taken immediately before the examination to improve comfort and safety.',
    question: 'What preparation should be done before ROP screening?',
    options: [
      'Withhold feeds for 1 hour; dilate pupils (phenylephrine 2.5% + tropicamide 0.5–0.8%); swaddle; proparacaine drops; EBM/oral 25% dextrose; monitor temp & SpO₂',
      'Feed immediately before exam to prevent crying, and avoid eye drops',
      'Administer general anesthesia and dilate pupils with atropine 1%',
      'Fast for 6 hours without swaddling or analgesia',
    ],
    correctAnswerIndex: 0,
    explanation:
        'The infant should have feeds withheld for 1 hour before screening; pupils dilated with phenylephrine 2.5% and tropicamide 0.5–0.8% eye drops; be swaddled; receive proparacaine eye drops; receive EBM/oral 25% dextrose for analgesia; and have temperature and SpO₂ monitored.',
  ),
  FollowUpQuestion(
    id: 'rop_case_5',
    disease: NeonatalCondition.rop,
    category: 'Post-Anti-VEGF Surveillance',
    questionType: QuestionType.caseScenario,
    scenario:
        'A 28 wk gestation and 900g birth weight baby is diagnosed with aggressive ROP in both eyes and is given intravitreal injection of Ranibizumab in both eyes at 34 weeks PMA. He has been followed up till 10 weeks, and there are no signs of reactivation, but there is persistent avascular retina in zone 2. No further vascular growth is observed.',
    question: 'Should the child be exited from the screening program?',
    options: [
      'No. Regular follow-up must continue at least until 65 weeks PMA due to risk of late reactivation or persistent avascular retina needing laser',
      'Yes. The child can be safely discharged as there is no reactivation at 10 weeks',
      'Yes. Anti-VEGF provides permanent complete cure without follow-up',
      'No. Schedule immediate bilateral vitrectomy',
    ],
    correctAnswerIndex: 0,
    explanation:
        'Babies injected with anti-VEGF drugs like Ranibizumab need longer regular follow-up at least until 65wks PMA, as it can lead to late reactivation of disease or persistent avascular retina, which may need laser treatment.',
  ),
  FollowUpQuestion(
    id: 'rop_case_6',
    disease: NeonatalCondition.rop,
    category: 'Screening Timing Guidelines',
    questionType: QuestionType.caseScenario,
    scenario:
        'A baby born at 32 weeks gestation and 1800 g birth weight was referred to an ophthalmologist for ROP screening after one week of birth. The ophthalmologist did not examine this baby and advised that he needs to be screened at a later date.',
    question:
        'Why did the ophthalmologist advise screening at a later date?',
    options: [
      'As per ROP screening guidelines (32 weeks / 1800 g), first ROP screening should be done at 4 weeks postnatal age',
      'The baby is too healthy and does not meet screening criteria',
      'Eye examination should only occur after 40 weeks PMA',
      'Screening requires prior blood transfusion',
    ],
    correctAnswerIndex: 0,
    explanation:
        'As per the current ROP screening guidelines, based on gestation age and birth weight criteria, this baby should undergo the first ROP screening at 4 weeks postnatal age.',
  ),
  FollowUpQuestion(
    id: 'rop_case_7',
    disease: NeonatalCondition.rop,
    category: 'Transfer Care & Missed Screening',
    questionType: QuestionType.caseScenario,
    scenario:
        'A male preterm infant born at GA 30 weeks, BW 1300 gms, previously admitted to one SNCU due to respiratory distress syndrome and early onset neonatal sepsis, was later transferred to another SNCU closer to his home at 3 weeks of life. He is now brought by his parents at 5 months of age to the ophthalmology department with complaints that the child was not recognising faces or following light. Ocular examination reveals bilateral white reflex, and ultrasonography reveals retinal detachments in both eyes.',
    question:
        'What is the likely diagnosis and possible reasons for the condition?',
    options: [
      'Stage 5 ROP due to failure to identify screening eligibility, lack of documented screening plan at transfer, and failure to counsel parents',
      'Bilateral retinoblastoma unrelated to premature birth',
      'Congenital cataract with secondary glaucoma',
      'Cortical visual impairment from hypoxic ischemic encephalopathy',
    ],
    correctAnswerIndex: 0,
    explanation:
        'The baby is likely to have stage 5 ROP. This baby was never screened for ROP and this could be because of failure to identify the infant as “eligible for screening”, lack of a documented ROP screening plan at the time of back referral and failure to inform parents about the importance of eye exam.',
  ),
  FollowUpQuestion(
    id: 'rop_case_8',
    disease: NeonatalCondition.rop,
    category: 'Aggressive ROP & Discharge Counseling',
    questionType: QuestionType.caseScenario,
    scenario:
        'A 28-week, 1000 gm infant is diagnosed with bilateral Zone I Aggressive ROP at 35 weeks PMA inside the NICU.',
    question:
        'What is the likely treatment and what are the checklists at the time of discharge from NICU?',
    options: [
      'Intravitreal Anti-VEGF; discharge summary mentioning ROP diagnosis, date and type of injection; counseling parents on essential follow-up for reactivation',
      'Oral corticosteroids and routine discharge without ophthalmology notes',
      'Cryotherapy only, with standard non-ROP discharge instructions',
      'Observation without intervention until 40 weeks PMA',
    ],
    correctAnswerIndex: 0,
    explanation:
        'Aggressive ROP in zone 1 is treated with Intravitreal Anti-VEGF drugs. Discharge should mention about the ROP diagnosis, date and type of injection given and parents should be informed about the need for regular follow ups for reactivation.',
  ),
];
