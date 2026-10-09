import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';

/// Neonatal Hypoglycemia follow-up MCQs and case scenarios.
///
/// Written ONLY from facts stated in the ICMR/DHR STW "Neonatal
/// Hypoglycemia" (ICD-11 KB60.4, August 2026). Every correct answer and
/// explanation quotes the PDF box named in [FollowUpQuestion.stwReference];
/// distractors are deliberately not STW statements.
const _ref = 'ICMR/DHR STW "Neonatal Hypoglycemia" (August 2026)';

const List<FollowUpQuestion> hypoFollowUpMcqs = [
  FollowUpQuestion(
    id: 'hypo_mcq_1',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Threshold',
    questionType: QuestionType.mcq,
    question:
        'Which blood glucose value is the entry point of the STW management flowchart?',
    options: [
      'BLOOD GLUCOSE <36 mg/dL',
      'BLOOD GLUCOSE <40 mg/dL',
      'BLOOD GLUCOSE <45 mg/dL',
      'BLOOD GLUCOSE <60 mg/dL',
    ],
    correctAnswerIndex: 2,
    explanation:
        'The flowchart starts at "BLOOD GLUCOSE <45 mg/dL". HOW TO MONITOR: "Low value (<45 mg/dL): send a blood sample to the lab"; "DO NOT delay treatment for lab confirmation".',
    stwReference: '$_ref, flowchart; HOW TO MONITOR BLOOD GLUCOSE (BG)',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_2',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Whom to screen',
    questionType: QuestionType.mcq,
    question:
        'In which of these neonates is routine blood glucose monitoring NOT required according to the STW?',
    options: [
      'Healthy term AGA neonate',
      'Preterm infant (<37 weeks\' gestation)',
      'Infant of a diabetic mother',
      'Neonate born to a mother receiving beta-blockers',
    ],
    correctAnswerIndex: 0,
    explanation:
        'WHOM TO SCREEN FOR HYPOGLYCEMIA lists preterm, low-birth-weight, SGA, LGA, infants of diabetic mothers, neonates of mothers on beta-blockers, sick neonates and neonates following exchange transfusion. "Routine blood glucose monitoring is not required in healthy term AGA neonates".',
    stwReference: '$_ref, WHOM TO SCREEN FOR HYPOGLYCEMIA',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_3',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Monitoring schedule',
    questionType: QuestionType.mcq,
    question:
        'What is the STW schedule of blood glucose monitoring for at-risk infants?',
    options: [
      '1, 2, 6, 12, 24, 48, 72 hours',
      'Every 2 hours for 48 hours',
      '1, 3, 6, 12 and 24 hours only',
      'Once daily for 3 days',
    ],
    correctAnswerIndex: 0,
    explanation:
        'SCHEDULE OF BLOOD GLUCOSE MONITORING: at-risk infants "1, 2, 6, 12, 24, 48, 72 hours" ("*in IDM, monitoring can be stopped between 24-36 hours provided feeding is established"); infants on IV fluids "Every 6-8 hours"; "BG should be measured pre-feeding".',
    stwReference: '$_ref, SCHEDULE OF BLOOD GLUCOSE MONITORING',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_4',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Symptomatic or BG <25 mg/dL',
    questionType: QuestionType.mcq,
    question:
        'What IV bolus does the STW give for a symptomatic neonate or BG < 25 mg/dL?',
    options: [
      '2 ml/kg of 10% dextrose slowly over 1 minute',
      '5 ml/kg of 10% dextrose over 10 minutes',
      '2 ml/kg of 25% dextrose as a rapid push',
      '10 ml/kg of normal saline',
    ],
    correctAnswerIndex: 0,
    explanation:
        'SYMPTOMATIC OR BG < 25 mg/dL: "IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute".',
    stwReference: '$_ref, SYMPTOMATIC OR BG < 25 mg/dL',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_5',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Symptomatic or BG <25 mg/dL',
    questionType: QuestionType.mcq,
    question:
        'At what glucose infusion rate (GIR) does the STW start the IV dextrose infusion after the bolus?',
    options: ['4 mg/kg/min', '6 mg/kg/min', '8 mg/kg/min', '12 mg/kg/min'],
    correctAnswerIndex: 1,
    explanation:
        'SYMPTOMATIC OR BG < 25 mg/dL: "Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min".',
    stwReference: '$_ref, SYMPTOMATIC OR BG < 25 mg/dL',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_6',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Increasing GIR',
    questionType: QuestionType.mcq,
    question:
        'On IV glucose, if BG remains < 45 mg/dL, how does the STW change the GIR?',
    options: [
      'Increase by 1 mg/kg/min, maximum 10 mg/kg/min',
      'Increase by 2 mg/kg/min, maximum 12 mg/kg/min',
      'Increase by 4 mg/kg/min, maximum 16 mg/kg/min',
      'Double the GIR each hour',
    ],
    correctAnswerIndex: 1,
    explanation:
        'Flowchart: BG < 45 mg/dL → "Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)".',
    stwReference: '$_ref, flowchart (BG < 45 mg/dL → increase GIR)',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_7',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Refractory hypoglycemia',
    questionType: QuestionType.mcq,
    question: 'Which drug does the STW list for refractory hypoglycemia?',
    options: [
      'Hydrocortisone: 5 mg/kg/day IV in two divided doses',
      'Hydrocortisone: 10 mg/kg/day IV once daily',
      'Dexamethasone 6 mg IM every 12 hours',
      'Oral dextrose solution',
    ],
    correctAnswerIndex: 0,
    explanation:
        'DRUGS FOR REFRACTORY HYPOGLYCEMIA: "Hydrocortisone: 5 mg/kg/day IV in two divided doses"; "Additional drugs should be administered at a tertiary care hospital with workup for underlying causes".',
    stwReference: '$_ref, DRUGS FOR REFRACTORY HYPOGLYCEMIA',
  ),
  FollowUpQuestion(
    id: 'hypo_mcq_8',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Practical points',
    questionType: QuestionType.mcq,
    question:
        'Which dextrose concentration does the STW say to avoid through a peripheral vein?',
    options: [
      '> 5% dextrose',
      '> 10% dextrose',
      '> 12.5-15% dextrose',
      'No limit is stated',
    ],
    correctAnswerIndex: 2,
    explanation:
        'PRACTICAL POINTS: "Avoid > 12.5-15% dextrose infusion through a peripheral vein".',
    stwReference: '$_ref, PRACTICAL POINTS',
  ),
];

const List<FollowUpQuestion> hypoFollowUpCaseScenarios = [
  FollowUpQuestion(
    id: 'hypo_case_1',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Asymptomatic & BG ≥25 mg/dL',
    questionType: QuestionType.caseScenario,
    scenario:
        'A preterm neonate (an at-risk infant) has a point-of-care BG of 32 mg/dL at 2 hours of life. On examination there are none of the listed symptoms or signs.',
    question: 'What is the next step as per the STW?',
    options: [
      'IV bolus 2 ml/kg of 10% dextrose',
      'Immediate supervised feeding (breastfeeding or a measured volume of expressed breastmilk by paladai or gavage) and re-check BG after 1 hour',
      'Wait for the lab result before any treatment',
      'Feed a dextrose solution instead of breastmilk',
    ],
    correctAnswerIndex: 1,
    explanation:
        'ASYMPTOMATIC & BG ≥25 mg/dL: "Immediate supervised feeding"; "Breastfeeding or a measured volume of expressed breastmilk (Formula milk if EBM not available) by paladai or gavage"; "RE-CHECK BG AFTER 1 HOUR". DON\'Ts: "Do NOT substitute dextrose solutions for breastmilk".',
    stwReference: '$_ref, ASYMPTOMATIC & BG ≥25 mg/dL',
  ),
  FollowUpQuestion(
    id: 'hypo_case_2',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Symptomatic or BG <25 mg/dL',
    questionType: QuestionType.caseScenario,
    scenario:
        'An infant of a diabetic mother has a BG of 20 mg/dL. The baby has no listed symptoms or signs.',
    question: 'What does the STW advise?',
    options: [
      'Supervised feeding and re-check after 1 hour',
      'IV bolus 2 ml/kg of 10% dextrose slowly over 1 minute and start IV dextrose infusion at GIR 6 mg/kg/min',
      'Re-check BG at 6 hours',
      'Give hydrocortisone',
    ],
    correctAnswerIndex: 1,
    explanation:
        'BG < 25 mg/dL takes the "SYMPTOMATIC OR BG < 25 mg/dL" branch even without symptoms: "IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute"; "Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min".',
    stwReference: '$_ref, SYMPTOMATIC OR BG < 25 mg/dL',
  ),
  FollowUpQuestion(
    id: 'hypo_case_3',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Re-check after 1 hour',
    questionType: QuestionType.caseScenario,
    scenario:
        'An asymptomatic neonate with BG 34 mg/dL was given supervised feeding. At the 1-hour re-check the BG is 38 mg/dL.',
    question: 'What does the STW advise now?',
    options: [
      'Continue feeds and re-check in 6 hours',
      'Start IV glucose infusion',
      'Stop monitoring',
      'Refer to a higher centre for endocrine work-up',
    ],
    correctAnswerIndex: 1,
    explanation:
        'RE-CHECK BG AFTER 1 HOUR: "Start IV glucose infusion if: BG < 45 mg/dL OR Symptoms develop". Then "Re-check BG every 30 min until 2 consecutive values are ≥45 mg/dL, then every 6 h".',
    stwReference: '$_ref, RE-CHECK BG AFTER 1 HOUR',
  ),
  FollowUpQuestion(
    id: 'hypo_case_4',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Increasing GIR',
    questionType: QuestionType.caseScenario,
    scenario:
        'A neonate on IV dextrose at GIR 8 mg/kg/min has a re-check BG of 40 mg/dL.',
    question: 'What does the STW advise?',
    options: [
      'Increase GIR by 2 mg/kg/min to 10 mg/kg/min',
      'Increase GIR to 16 mg/kg/min',
      'Reduce GIR by 2 mg/kg/min',
      'Stop IV fluids',
    ],
    correctAnswerIndex: 0,
    explanation:
        'Flowchart: BG < 45 mg/dL → "Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)"; 8 + 2 = 10 mg/kg/min.',
    stwReference: '$_ref, flowchart (BG < 45 mg/dL → increase GIR)',
  ),
  FollowUpQuestion(
    id: 'hypo_case_5',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Stopping IV fluids',
    questionType: QuestionType.caseScenario,
    scenario:
        'A neonate who has been euglycemic for 24 hours on IV fluids has been weaned and is now euglycemic on GIR 4 mg/kg/min, tolerating adequate enteral feeds.',
    question: 'What does the STW advise?',
    options: [
      'Increase GIR to 6 mg/kg/min',
      'Stop IV fluids',
      'Continue IV fluids for another 24 hours at GIR 4 mg/kg/min',
      'Give a dextrose bolus before stopping',
    ],
    correctAnswerIndex: 1,
    explanation:
        'Flowchart: "Stop IV fluids when euglycemic on GIR 4 mg/ kg/min and tolerating adequate enteral feeds". Before that: "Reduce GIR by 2 mg/ kg/min every 6 hours; Increase oral feeds; Monitor BG every 6 hours".',
    stwReference: '$_ref, flowchart (stop IV fluids)',
  ),
  FollowUpQuestion(
    id: 'hypo_case_6',
    disease: NeonatalCondition.hypoglycemia,
    category: 'Refractory hypoglycemia',
    questionType: QuestionType.caseScenario,
    scenario:
        'A neonate has needed a GIR > 10-12 mg/kg/min for 24 hours and BG remains < 45 mg/dL.',
    question: 'What does the STW advise?',
    options: [
      'Keep increasing GIR beyond 12 mg/kg/min',
      'Consider ENDOCRINE/METABOLIC disorders & REFER to higher centre; drugs for refractory hypoglycemia include hydrocortisone 5 mg/kg/day IV in two divided doses',
      'Start antibiotics for hypoglycemia',
      'Stop IV fluids and feed dextrose solution',
    ],
    correctAnswerIndex: 1,
    explanation:
        'Flowchart: "Persistent (GIR requirement >3-7 days) or Refractory (GIR > 10-12 mg/kg/min for 24 hours) hypoglycemia" → "Consider ENDOCRINE/ METABOLIC disorders & REFER to higher centre". DRUGS FOR REFRACTORY HYPOGLYCEMIA: "Hydrocortisone: 5 mg/kg/day IV in two divided doses". DON\'Ts: "Do NOT give antibiotics for hypoglycemia unless sepsis is suspected".',
    stwReference: '$_ref, flowchart (persistent/refractory); DRUGS FOR REFRACTORY HYPOGLYCEMIA',
  ),
];
