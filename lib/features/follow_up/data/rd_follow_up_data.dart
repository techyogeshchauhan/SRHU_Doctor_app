import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';

/// Supplied MCQs RD.docx: Section 1 (Q1–Q10), Section 2 (Q11–Q20).
/// Wording, option order, bold answer keys and explanations are preserved.
/// Case stems are split at the final question sentence for the existing UI.
const _ref = 'ICMR/DHR STW "Respiratory Distress in Neonates" (August 2026)';

const List<FollowUpQuestion> rdFollowUpMcqs = [
  FollowUpQuestion(
    id: 'rd_mcq_1',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Diagnosis",
    questionType: QuestionType.mcq,
    question:
        "Which clinical sign is diagnostic of respiratory distress in a newborn according to the Standard Treatment Workflow (STW)?",
    options: [
      "Heart rate of 160 beats per minute",
      "Respiratory rate of 68 breaths per minute",
      "Capillary refill time >2 seconds",
      "Axillary temperature <36.5°C",
    ],
    correctAnswerIndex: 1,
    explanation:
        "The guidelines define neonatal respiratory distress by the presence of ANY ONE of four criteria: Respiratory rate ≥60/min, chest retractions, nasal flaring, or grunting.",
    stwReference: '$_ref, RESPIRATORY DISTRESS; MCQs RD.docx Section 1 Q1',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_2',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Oxygen target",
    questionType: QuestionType.mcq,
    question:
        "What is the target peripheral oxygen saturation (SpO₂) range for neonates receiving supplemental oxygen or CPAP support?",
    options: [
      "91–94%",
      "90–92%",
      "91–95%",
      "95–97%",
    ],
    correctAnswerIndex: 2,
    explanation:
        "Guidelines mandate using air-oxygen blenders and continuous pulse oximetry to strictly maintain and target SpO₂ between 91–95% for all neonates receiving oxygen or CPAP.",
    stwReference: '$_ref, DOs; MCQs RD.docx Section 1 Q2',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_3',
    disease: NeonatalCondition.respiratoryDistress,
    category: "CPAP initiation KPI",
    questionType: QuestionType.mcq,
    question:
        "What is the Key Performance Indicator (KPI) target for timely initiation of CPAP (within 30 minutes of identification) in eligible neonates?",
    options: [
      ">75%",
      ">80%",
      ">85%",
      ">90%",
    ],
    correctAnswerIndex: 3,
    explanation:
        "The KPI target for timely CPAP initiation—starting CPAP within 30 minutes of identifying an eligible neonate—is >90%.",
    stwReference:
        '$_ref, KEY PERFORMANCE INDICATORS (KPIs); MCQs RD.docx Section 1 Q3',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_4',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Early rescue surfactant",
    questionType: QuestionType.mcq,
    question:
        "In a preterm neonate <34 weeks gestational age receiving CPAP, what FiO₂ threshold on CPAP ≥6 cm H₂O indicates early rescue surfactant therapy?",
    options: [
      "FiO₂ >0.25",
      "FiO₂ >0.30",
      "FiO₂ >0.40",
      "FiO₂ >0.50",
    ],
    correctAnswerIndex: 1,
    explanation:
        "Early rescue surfactant is indicated in a preterm neonate <34 weeks with suspected worsening RDS who requires an FiO₂ >0.30 on CPAP ≥6 cm H₂O to maintain SpO₂ at 91–95%.",
    stwReference: '$_ref, EARLY RESCUE SURFACTANT; MCQs RD.docx Section 1 Q4',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_5',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Avoid routine investigations",
    questionType: QuestionType.mcq,
    question:
        "Which of the following routine diagnostic investigations is explicitly listed as a \"DON'T\" in uncomplicated mild respiratory distress?",
    options: [
      "Continuous pulse oximetry monitoring",
      "Silverman–Andersen Score (SAS) assessment",
      "Routine CBC/CRP, chest X-ray, or arterial blood gas",
      "Thermal protection and TABC stabilization",
    ],
    correctAnswerIndex: 2,
    explanation:
        "The guidelines explicitly state: \"Do NOT order routine CBC/CRP, chest X-ray or blood gas in uncomplicated mild RD\" to avoid unnecessary procedures.",
    stwReference: '$_ref, DON’Ts; MCQs RD.docx Section 1 Q5',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_6',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Silverman–Andersen Score",
    questionType: QuestionType.mcq,
    question:
        "Which five physical parameters are evaluated as part of the Silverman–Andersen Score (SAS)?",
    options: [
      "Respiratory rate, heart rate, capillary refill time, grunting, and skin color",
      "Upper chest movement, lower chest retractions, xiphoid retractions, nares dilatation, and expiratory grunt",
      "Nasal flaring, stridor, wheezing, abdominal distension, and cyanosis",
      "Apnea duration, heart rate, head bobbing, intercostal retractions, and SpO₂",
    ],
    correctAnswerIndex: 1,
    explanation:
        "The Silverman–Andersen Score evaluates 5 parameters, each scored from 0 to 2 (total 0–10): Upper chest movement (synchronized, lag, or see-saw), lower chest retractions, xiphoid retractions, nares dilatation, and expiratory grunt. An SAS ≤3 indicates mild RD, while ≥4 indicates moderate-to-severe RD.",
    stwReference: '$_ref, SILVERMAN–ANDERSEN SCORE; MCQs RD.docx Section 1 Q6',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_7',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Caffeine",
    questionType: QuestionType.mcq,
    question:
        "According to the STW algorithm, which group of neonates should receive caffeine citrate therapy as part of their initial management?",
    options: [
      "All term neonates presenting with transient tachypnea",
      "Preterm infants <34 weeks gestation requiring respiratory support",
      "Only preterm infants who fail CPAP and require mechanical ventilation",
      "All preterm neonates <34 weeks",
    ],
    correctAnswerIndex: 1,
    explanation:
        "Caffeine citrate is indicated for all preterm infants <34 weeks gestational age who require respiratory support (such as CPAP or oxygen) as per protocol.",
    stwReference: '$_ref, START CPAP; MCQs RD.docx Section 1 Q7',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_8',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Uncertain gestational age",
    questionType: QuestionType.mcq,
    question:
        "When gestational age (GA) is uncertain, what operational surrogate birth weight (BW) cutoff may be used to guide management in the STW algorithm?",
    options: [
      "BW ≤1000 g",
      "BW ≤1500 g",
      "BW ≤1800 g",
      "BW ≤2500 g",
    ],
    correctAnswerIndex: 2,
    explanation:
        "The algorithm explicitly notes: \"If GA is uncertain, BW ≤1800 g may be used as an operational surrogate\" to decide eligibility for CPAP and caffeine therapy.",
    stwReference: '$_ref, START CPAP; MCQs RD.docx Section 1 Q8',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_9',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Reassessment",
    questionType: QuestionType.mcq,
    question:
        "What is the mandatory clinical reassessment frequency for a neonate placed on supplemental oxygen or CPAP?",
    options: [
      "Reassess within 15–30 min of starting/changing support, then at least 1 hourly",
      "Reassess every 4 hours",
      "Reassess only once per shift (every 12 hours)",
      "Reassess only if the pulse oximeter alarm sounds",
    ],
    correctAnswerIndex: 0,
    explanation:
        "Guidelines mandate reassessing clinical status, SAS, and FiO₂ requirement within 15–30 minutes of starting or changing support, and at least 1 hourly while on respiratory support (and immediately if any worsening occurs).",
    stwReference: '$_ref, MONITORING; MCQs RD.docx Section 1 Q9',
  ),
  FollowUpQuestion(
    id: 'rd_mcq_10',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Weaning CPAP",
    questionType: QuestionType.mcq,
    question:
        "Following a trial off CPAP when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25, how long must continuous pulse oximetry monitoring be maintained?",
    options: [
      "2 hours",
      "6 hours",
      "12 hours",
      "24 hours",
    ],
    correctAnswerIndex: 3,
    explanation:
        "After trialing off CPAP when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25, clinicians must monitor SpO₂ for 24 hours after stopping.",
    stwReference: '$_ref, WEAN WHEN STABLE; MCQs RD.docx Section 1 Q10',
  ),
];

const List<FollowUpQuestion> rdFollowUpCaseScenarios = [
  FollowUpQuestion(
    id: 'rd_case_1',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Preterm respiratory support",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 31-week preterm infant born in a primary care center presents with nasal flaring and mild intercostal retractions 15 minutes after birth. The Silverman–Andersen Score (SAS) is calculated as 3.",
    question: "What is the most appropriate initial respiratory management?",
    options: [
      "Initiate low-flow nasal prongs oxygen at 0.5 L/min",
      "Start CPAP at 5–6 cm H₂O with blended oxygen titrated to SpO₂ 91–95%",
      "Administer prophylactic surfactant via endotracheal tube immediately",
      "Intubate and initiate mechanical ventilation",
    ],
    correctAnswerIndex: 1,
    explanation:
        "For any neonate with GA ≤34 weeks presenting with ANY respiratory distress (regardless of whether SAS is mild or severe), the algorithm mandates starting CPAP at 5–6 cm H₂O with blended oxygen. Low-flow nasal prongs oxygen is reserved only for GA >34 weeks with mild RD.",
    stwReference: '$_ref, START CPAP; MCQs RD.docx Section 2 Q11',
  ),
  FollowUpQuestion(
    id: 'rd_case_2',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Term mild respiratory distress",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 38-week term newborn exhibits a respiratory rate of 66/min and mild subcostal retractions (SAS = 2). Pulse oximetry on room air reads 88%.",
    question:
        "How should oxygen therapy be initiated according to the STW algorithm?",
    options: [
      "Start CPAP at 7 cm H₂O immediately",
      "Administer an IV bolus of caffeine citrate",
      "Start nasal prongs oxygen at 0.5–1 L/min and titrate to SpO₂ 91–95%",
      "Order an urgent blood gas and chest X-ray prior to initiating oxygen",
    ],
    correctAnswerIndex: 2,
    explanation:
        "For neonates with GA >34 weeks having mild RD (SAS ≤3) and SpO₂ <91%, the initial step is nasal prongs oxygen at 0.5–1 L/min, titrating FiO₂ to achieve SpO₂ 91–95%. Routine lab tests or X-rays are not indicated for uncomplicated mild RD.",
    stwReference: '$_ref, NASAL PRONGS OXYGEN; MCQs RD.docx Section 2 Q12',
  ),
  FollowUpQuestion(
    id: 'rd_case_3',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Early rescue surfactant",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 29-week infant with RDS is managed on CPAP at 6 cm H₂O. Over the last 30 minutes, the infant's oxygen requirement has progressively escalated from FiO₂ 0.25 to 0.35 to keep SpO₂within 91–95%. Circuit and prong placements are verified.",
    question: "What is the next best clinical action?",
    options: [
      "Wait for established CPAP failure before intervening",
      "Administer early rescue surfactant promptly",
      "Increase CPAP pressure to 10 cm H₂O",
      "Wait for 2 hours to administer surfactant",
    ],
    correctAnswerIndex: 1,
    explanation:
        "In preterm neonates <34 weeks with suspected worsening RDS, requiring FiO₂ >0.30 on CPAP ≥6 cm H₂O to maintain target saturation is a direct indication for early rescue surfactant, which should be given promptly before CPAP failure occurs.",
    stwReference: '$_ref, EARLY RESCUE SURFACTANT; MCQs RD.docx Section 2 Q13',
  ),
  FollowUpQuestion(
    id: 'rd_case_4',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Escalating respiratory support",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 36-week infant receiving nasal prongs oxygen at 1 L/min develops increasing intercostal retractions, grunting, and rising oxygen demand, with SAS increasing from 2 to 5.",
    question: "What is the correct management escalation?",
    options: [
      "Increase nasal prongs oxygen flow to 4 L/min",
      "Initiate CPAP, check prongs/circuit, and optimize pressure up to 7–8 cm H₂O",
      "Administer routine IV fluid bolus and broad-spectrum antibiotics",
      "Discontinue oxygen and start oral bolus feeding",
    ],
    correctAnswerIndex: 1,
    explanation:
        "When a baby on nasal prongs oxygen shows rising oxygen requirement or worsening distress (SAS ≥4), the protocol directs escalating to CPAP, checking the circuit/prongs, increasing pressure up to 7–8 cm H₂O, and titrating FiO₂.",
    stwReference:
        '$_ref, OPTIMIZE RESPIRATORY SUPPORT; MCQs RD.docx Section 2 Q14',
  ),
  FollowUpQuestion(
    id: 'rd_case_5',
    disease: NeonatalCondition.respiratoryDistress,
    category: "CPAP failure and referral",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 30-week neonate on CPAP 8 cm H₂O and FiO₂ 0.50 experiences recurrent severe apnoeic spells, persistent hypoxaemia (SpO₂ 83%), and marked chest wall fatigue. Pneumothorax is ruled out by transillumination.",
    question: "What urgent action is mandated?",
    options: [
      "Continue CPAP 8 cm H₂O and re-evaluate in 4 hours",
      "Recognize CPAP failure, escalate support (intubate/ventilate when indicated), stabilize, and refer urgently",
      "Reduce CPAP pressure to 4 cm H₂O to rest the respiratory muscles",
      "Switch to unmonitored supplemental oxygen via nasal prongs",
    ],
    correctAnswerIndex: 1,
    explanation:
        "Persistent hypoxaemia/rising FiO₂ despite optimized CPAP, recurrent apnoea, shock, or fatigue defines CPAP failure. Guidelines require escalating support, intubating/ventilating when indicated, stabilizing, and referring urgently without delay.",
    stwReference:
        '$_ref, CPAP FAILURE — ESCALATE PROMPTLY; MCQs RD.docx Section 2 Q15',
  ),
  FollowUpQuestion(
    id: 'rd_case_6',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Bubble CPAP troubleshooting",
    questionType: QuestionType.caseScenario,
    scenario:
        "A staff nurse in the SNCU is setting up a bubble CPAP system for a 30-week preterm newborn with respiratory distress. After positioning the binasal prongs and starting gas flow, the nurse notices that there is no continuous bubbling in the water generator bottle and the infant's chest retractions are worsening.",
    question:
        "What is the most appropriate immediate step to troubleshoot this setup?",
    options: [
      "Increase the water level in the bottle above the target PEEP line",
      "Check for circuit air leaks, verify snug fit of binasal prongs, and check gas flow",
      "Immediately escalate FiO₂ to 1.0 without checking the circuit",
      "Increase the PEEP",
    ],
    correctAnswerIndex: 1,
    explanation:
        "Continuous bubbling in the generator bottle confirms delivered PEEP. If bubbling stops or distress worsens, the primary troubleshooting steps are inspecting for circuit leaks, ensuring proper sizing/seal of binasal prongs, and verifying gas flow.",
    stwReference: '$_ref, DOs; MCQs RD.docx Section 2 Q16',
  ),
  FollowUpQuestion(
    id: 'rd_case_7',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Worsening respiratory distress",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 30-week preterm neonate with respiratory distress was started on Bubble CPAP at birth. At 6 hours of life, despite circuit verification, the baby exhibits persistent SAS, rising oxygen demand (FiO₂ increased from 0.25 to 0.45), and new-onset recurrent apnoea/bradycardia episodes.",
    question:
        "According to the STW algorithm, what underlying complication should be actively considered at this stage?",
    options: [
      "Apnea of prematurity",
      "Sepsis",
      "Normal physiological adaptation",
      "Congenital pulmonary airway malformation",
    ],
    correctAnswerIndex: 1,
    explanation:
        "In the algorithm under \"NOT IMPROVING / WORSENING\" (characterized by persisting/increasing SAS, SpO₂ <91% or rising oxygen demand, and recurrent apnoea/bradycardia), the protocol explicitly instructs clinicians to \"Consider sepsis (Refer to sepsis STW)\".",
    stwReference:
        '$_ref, NOT IMPROVING / WORSENING; MCQs RD.docx Section 2 Q17',
  ),
  FollowUpQuestion(
    id: 'rd_case_8',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Feeding on CPAP",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 31-week preterm infant with RDS is stable on CPAP at 5 cm H₂O and FiO₂ 0.25, demonstrating comfortable breathing and an SAS of 2.",
    question:
        "According to the STW, what is the most appropriate feeding management strategy?",
    options: [
      "Keep the baby strictly NPO on IV fluids until completely weaned off CPAP",
      "Initiate orogastric (OG) tube feeds when appropriate, ensuring stomach decompression",
      "Start direct oral bottle feeding immediately",
      "Provide rapid bolus feeds via nasogastric tube without venting",
    ],
    correctAnswerIndex: 1,
    explanation:
        "When stable on CPAP, orogastric (OG) tube feeds are indicated when appropriate, along with stomach decompression to vent swallowed air. Withholding feeds and giving IV fluids is reserved for severe RD, recurrent apnoea, poor perfusion, or abdominal concerns.",
    stwReference: '$_ref, DOs; MCQs RD.docx Section 2 Q18',
  ),
  FollowUpQuestion(
    id: 'rd_case_9',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Silverman–Andersen Score",
    questionType: QuestionType.caseScenario,
    scenario:
        "A 32-week preterm newborn presents 20 minutes after birth with respiratory distress. Physical evaluation reveals:\n• Upper chest: Lag on inspiration\n• Lower chest: Marked intercostal retractions\n• Xiphoid retractions: Just visible indentation\n• Nares dilatation: Minimal nasal flaring\n• Expiratory grunt: Heard only with a stethoscope over the chest",
    question:
        "What is the calculated SAS score, and how is the severity classified?",
    options: [
      "SAS = 4 (Mild Respiratory Distress)",
      "SAS = 5 (Moderate–Severe Respiratory Distress)",
      "SAS = 6 (Moderate–Severe Respiratory Distress)",
      "SAS = 8 (Severe Respiratory Distress)",
    ],
    correctAnswerIndex: 2,
    explanation:
        "Upper chest lag = 1; Marked lower chest retractions = 2; Just visible xiphoid retractions = 1; Minimal nares dilatation = 1; Grunt heard with stethoscope = 1. Total SAS = 6 / 10 (SAS ≥4 indicates Moderate–Severe Respiratory Distress, requiring CPAP).",
    stwReference: '$_ref, SILVERMAN–ANDERSEN SCORE; MCQs RD.docx Section 2 Q19',
  ),
  FollowUpQuestion(
    id: 'rd_case_10',
    disease: NeonatalCondition.respiratoryDistress,
    category: "Immediate stabilization",
    questionType: QuestionType.caseScenario,
    scenario:
        "A newborn presents at delivery with gasping, poor respiratory effort, and signs of shock.",
    question:
        "According to the STW \"IMMEDIATE ACTIONS\", what is the priority?",
    options: [
      "Calculate the Silverman–Andersen Score before taking any action",
      "Stabilize immediately (maintain TABC, provide warmth) and ventilate when indicated",
      "Administer IV caffeine citrate bolus prior to airway assessment",
      "Order an emergency chest X-ray and arterial blood gas",
    ],
    correctAnswerIndex: 1,
    explanation:
        "Under \"IMMEDIATE ACTIONS\", if a baby presents with apnoea/gasping, poor effort, or shock, the protocol specifies: \"Stabilize immediately; ventilate when indicated. Maintain TABC; provide warmth; admit to SNCU/NICU\".",
    stwReference: '$_ref, IMMEDIATE ACTIONS; MCQs RD.docx Section 2 Q20',
  ),
];
