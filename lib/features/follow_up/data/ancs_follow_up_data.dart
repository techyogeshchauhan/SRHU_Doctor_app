import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';

/// ANCS follow-up MCQs and case scenarios.
///
/// Written ONLY from facts stated in the ICMR/DHR STW "Antenatal
/// Corticosteroids for Preterm Birth" (August 2026). Every correct answer and
/// explanation quotes the PDF box named in [FollowUpQuestion.stwReference];
/// distractors are deliberately not STW statements.
const _ref = 'ICMR/DHR STW "Antenatal Corticosteroids for Preterm Birth" '
    '(August 2026)';

const List<FollowUpQuestion> ancsFollowUpMcqs = [
  FollowUpQuestion(
    id: 'ancs_mcq_1',
    disease: NeonatalCondition.ancs,
    category: 'When to give',
    questionType: QuestionType.mcq,
    question:
        'According to the STW, antenatal corticosteroids are given to pregnant women at which gestational age (with a high likelihood of preterm birth within the next 7 days)?',
    options: [
      '22+0 to 31+6 weeks',
      '24+0 to 33+6 weeks',
      '26+0 to 35+6 weeks',
      '28+0 to 36+6 weeks',
    ],
    correctAnswerIndex: 1,
    explanation:
        'WHEN TO GIVE: "Pregnant women at 24+0 to 33+6 weeks of gestation with a high likelihood of preterm birth within the next 7 days".',
    stwReference: '$_ref, WHEN TO GIVE',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_2',
    disease: NeonatalCondition.ancs,
    category: 'Drug & dose',
    questionType: QuestionType.mcq,
    question: 'Which regimen does the STW give under DRUG & DOSE?',
    options: [
      'Dexamethasone sodium phosphate 6 mg IM every 12 hours x 4 doses',
      'Dexamethasone sodium phosphate 12 mg IM every 24 hours x 4 doses',
      'Dexamethasone sodium phosphate 6 mg IV every 6 hours x 2 doses',
      'Dexamethasone sodium phosphate 6 mg orally once daily x 4 days',
    ],
    correctAnswerIndex: 0,
    explanation:
        'DRUG & DOSE: "DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES".',
    stwReference: '$_ref, DRUG & DOSE',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_3',
    disease: NeonatalCondition.ancs,
    category: 'Drug & dose',
    questionType: QuestionType.mcq,
    question: 'Why does the STW prefer dexamethasone?',
    options: [
      'It is given as a single dose',
      'It is effective, low-cost, widely available and more heat-stable',
      'It is the only corticosteroid available in India',
      'It does not need to be given intramuscularly',
    ],
    correctAnswerIndex: 1,
    explanation:
        'DRUG & DOSE: "Dexamethasone is preferred: it is effective, low-cost, widely available and more heat-stable". The STW adds that the betamethasone regimen requires an acetate + phosphate preparation, which is not available in India.',
    stwReference: '$_ref, DRUG & DOSE',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_4',
    disease: NeonatalCondition.ancs,
    category: 'Eligibility criteria',
    questionType: QuestionType.mcq,
    question:
        'All of the following are listed in the STW as causes of a high likelihood of preterm birth within the next 7 days EXCEPT:',
    options: [
      'PPROM without clinical infection',
      'Antepartum Hemorrhage',
      'Severe pre-eclampsia/eclampsia',
      'Multiple pregnancy alone',
    ],
    correctAnswerIndex: 3,
    explanation:
        'ELIGIBILITY CRITERIA 1 lists: spontaneous preterm labour, PPROM without clinical infection, Antepartum Hemorrhage, Severe pre-eclampsia/eclampsia, and planned preterm birth for maternal/fetal indication. Multiple pregnancy is not one of them; it appears under SPECIAL SITUATIONS as a reason NOT to withhold ACS when otherwise eligible.',
    stwReference: '$_ref, ELIGIBILITY CRITERIA',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_5',
    disease: NeonatalCondition.ancs,
    category: 'When not to give',
    questionType: QuestionType.mcq,
    question: 'Which of these is a reason NOT to give ACS according to the STW?',
    options: [
      'Clinical chorioamnionitis or systemic maternal infection',
      'Fetal growth restriction',
      'Hypertensive disorders',
      'Diabetes in pregnancy',
    ],
    correctAnswerIndex: 0,
    explanation:
        'WHEN NOT TO GIVE: "Clinical chorioamnionitis or systemic maternal infection". SPECIAL SITUATIONS: "When otherwise eligible, do not withhold ACS because of: multiple pregnancy, fetal growth restriction, hypertensive disorders, or diabetes in pregnancy".',
    stwReference: '$_ref, WHEN NOT TO GIVE; SPECIAL SITUATIONS',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_6',
    disease: NeonatalCondition.ancs,
    category: 'Repeat course',
    questionType: QuestionType.mcq,
    question: 'What does the STW say about a repeat course of ACS?',
    options: [
      'Repeat courses are given every week until 34 weeks',
      'Two repeat courses may be given if needed',
      'ONE repeat course only, if GA 24+0 to 33+6 weeks, high likelihood of preterm birth within the next 7 days, and the previous course was started ≥7 days earlier',
      'A repeat course is never given',
    ],
    correctAnswerIndex: 2,
    explanation:
        'WHEN TO GIVE REPEAT COURSE: "Give ONE repeat course only if ALL criteria are met": GA 24+0 to 33+6 weeks; high likelihood of preterm birth within the next 7 days; the previous ACS course was started ≥7 days earlier. "Do NOT give more than one repeat course (More than one repeat course may cause fetal harm, and is not recommended)".',
    stwReference: '$_ref, WHEN TO GIVE REPEAT COURSE',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_7',
    disease: NeonatalCondition.ancs,
    category: 'Referral/transfer',
    questionType: QuestionType.mcq,
    question:
        'What may a level I facility do for an eligible pregnant woman who needs referral?',
    options: [
      'Complete all 4 doses before referral',
      'Give the first dose of ACS before referral, without delaying referral/transfer to complete the course',
      'Give no ACS and refer immediately',
      'Keep the woman until birth and refer the newborn',
    ],
    correctAnswerIndex: 1,
    explanation:
        'REFERRAL/TRANSFER: "Level I facilities can give the first dose of ACS before referral, provided the pregnant woman meets the eligibility criteria, but referral/transfer should not be delayed to complete the course".',
    stwReference: '$_ref, REFERRAL/TRANSFER',
  ),
  FollowUpQuestion(
    id: 'ancs_mcq_8',
    disease: NeonatalCondition.ancs,
    category: 'KPIs',
    questionType: QuestionType.mcq,
    question: 'What is the STW target for ACS coverage?',
    options: ['≥50%', '≥70%', '≥80%', '≥95%'],
    correctAnswerIndex: 2,
    explanation:
        'KEY PERFORMANCE INDICATORS: ACS coverage = women at 24+0–33+6 weeks identified with high likelihood of preterm birth who received ≥1 ACS dose × 100 / all such women (Target: ≥80%). The target for appropriate ACS use is ≥95%.',
    stwReference: '$_ref, KEY PERFORMANCE INDICATORS (KPIs)',
  ),
];

const List<FollowUpQuestion> ancsFollowUpCaseScenarios = [
  FollowUpQuestion(
    id: 'ancs_case_1',
    disease: NeonatalCondition.ancs,
    category: 'Eligibility',
    questionType: QuestionType.caseScenario,
    scenario:
        'A pregnant woman at 30+2 weeks (GA confirmed by early USG) has PPROM without clinical infection. There is no clinical chorioamnionitis or systemic infection. Your facility has adequate childbirth care and preterm newborn care including CPAP. She has not received ACS before.',
    question: 'What should be done as per the STW?',
    options: [
      'Wait for labour to start before giving ACS',
      'Give ACS: dexamethasone sodium phosphate 6 mg IM every 12 hours x 4 doses, starting promptly',
      'Do not give ACS because of PPROM',
      'Give ACS only if birth will be delayed until the full course is completed',
    ],
    correctAnswerIndex: 1,
    explanation:
        'All five ELIGIBILITY CRITERIA are met (24+0 to 33+6 weeks; PPROM without clinical infection; GA assessed accurately; no chorioamnionitis or systemic infection; adequate childbirth and preterm newborn care). "IMPORTANT: Start ACS promptly once eligibility criteria are met, even if the full course may not be completed before birth".',
    stwReference: '$_ref, ELIGIBILITY CRITERIA; DRUG & DOSE',
  ),
  FollowUpQuestion(
    id: 'ancs_case_2',
    disease: NeonatalCondition.ancs,
    category: 'When not to give',
    questionType: QuestionType.caseScenario,
    scenario:
        'A pregnant woman at 35+1 weeks is in spontaneous preterm labour with regular contractions and cervical change.',
    question: 'What does the STW advise about ACS?',
    options: [
      'Give ACS routinely',
      'Do NOT routinely use ACS at ≥34+0 weeks',
      'Give a half dose',
      'Give one dose and refer',
    ],
    correctAnswerIndex: 1,
    explanation:
        'WHEN NOT TO GIVE: "Routine use at ≥34 weeks". DON\'Ts: "Do NOT routinely use ACS at ≥34+0 weeks or give more than one repeat course".',
    stwReference: '$_ref, WHEN NOT TO GIVE; DONTs',
  ),
  FollowUpQuestion(
    id: 'ancs_case_3',
    disease: NeonatalCondition.ancs,
    category: 'When not to give',
    questionType: QuestionType.caseScenario,
    scenario:
        'A pregnant woman at 28+4 weeks with spontaneous preterm labour has been diagnosed with clinical chorioamnionitis.',
    question: 'What does the STW advise about ACS?',
    options: [
      'Give ACS promptly',
      'Give ACS after the first dose of antibiotics',
      'Do NOT give ACS in clinical chorioamnionitis or systemic maternal infection',
      'Give a repeat course instead',
    ],
    correctAnswerIndex: 2,
    explanation:
        'Criterion 3 ("No clinical chorioamnionitis or systemic maternal infection") is not met. WHEN NOT TO GIVE: "Clinical chorioamnionitis or systemic maternal infection". DON\'Ts: "Do NOT give ACS in clinical chorioamnionitis or systemic maternal infection".',
    stwReference: '$_ref, ELIGIBILITY CRITERIA; WHEN NOT TO GIVE',
  ),
  FollowUpQuestion(
    id: 'ancs_case_4',
    disease: NeonatalCondition.ancs,
    category: 'Repeat course',
    questionType: QuestionType.caseScenario,
    scenario:
        'A pregnant woman at 31+0 weeks received one ACS course that was started 10 days ago. She now has antepartum hemorrhage with a high likelihood of preterm birth within the next 7 days. She meets the other eligibility criteria and has not had a repeat course.',
    question: 'What should be done as per the STW?',
    options: [
      'Give ONE repeat course',
      'No further ACS can ever be given',
      'Give two repeat courses 7 days apart',
      'Wait until 34 weeks',
    ],
    correctAnswerIndex: 0,
    explanation:
        'WHEN TO GIVE REPEAT COURSE: ONE repeat course if ALL are met: GA 24+0 to 33+6 weeks; high likelihood of preterm birth within the next 7 days; the previous ACS course was started ≥7 days earlier. "Do NOT give more than one repeat course".',
    stwReference: '$_ref, WHEN TO GIVE REPEAT COURSE',
  ),
  FollowUpQuestion(
    id: 'ancs_case_5',
    disease: NeonatalCondition.ancs,
    category: 'Referral/transfer',
    questionType: QuestionType.caseScenario,
    scenario:
        'At a level I facility without CPAP, a pregnant woman at 29+3 weeks with severe pre-eclampsia meets the ACS eligibility criteria (preterm newborn care including CPAP is ensured at the receiving facility).',
    question: 'What does the STW advise?',
    options: [
      'Complete the full ACS course before referral',
      'Give the first dose of ACS and refer for in-utero transfer to a facility with at least level II care (CPAP), without delaying referral to complete the course',
      'Refer without giving ACS',
      'Keep her at the level I facility until birth',
    ],
    correctAnswerIndex: 1,
    explanation:
        'REFERRAL/TRANSFER: "Pregnant women with likelihood of early preterm birth should be referred to a facility (in-utero transfer) with at least level II care (CPAP) for preterm infants"; "Level I facilities can give the first dose of ACS before referral, provided the pregnant woman meets the eligibility criteria, but referral/transfer should not be delayed to complete the course".',
    stwReference: '$_ref, REFERRAL/TRANSFER',
  ),
  FollowUpQuestion(
    id: 'ancs_case_6',
    disease: NeonatalCondition.ancs,
    category: 'Special situations',
    questionType: QuestionType.caseScenario,
    scenario:
        'A woman with a twin pregnancy and diabetes in pregnancy is at 32+1 weeks in spontaneous preterm labour and meets all ACS eligibility criteria.',
    question: 'What does the STW advise?',
    options: [
      'Withhold ACS because of twins',
      'Withhold ACS because of diabetes',
      'Give ACS; do not withhold because of multiple pregnancy or diabetes; monitor and optimize maternal glucose control',
      'Give half the dose because of diabetes',
    ],
    correctAnswerIndex: 2,
    explanation:
        'SPECIAL SITUATIONS: "When otherwise eligible, do not withhold ACS because of: multiple pregnancy, fetal growth restriction, hypertensive disorders, or diabetes in pregnancy"; "In diabetes: monitor and optimize maternal glucose control". DOs: "Monitor maternal glucose closely in women with diabetes".',
    stwReference: '$_ref, SPECIAL SITUATIONS; DOs',
  ),
];
