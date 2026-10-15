/// Neonatal emergency triage workflow from the July 2020 ICMR/DHR STW.
///
/// Measurements may be left blank. The clinician records observable signs;
/// when several triage categories match, the STW category is selected by the
/// clinician from the matching categories.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';

const _triage = NeonatalCondition.triage;

const triageTemperatureKey = 'triage_temperature_c';
const triageSpo2Key = 'triage_spo2';
const triageHeartRateKey = 'triage_heart_rate';
const triageWeightKey = 'triage_weight_g';
const triageBloodGlucoseKey = 'triage_blood_glucose';
const triageEmergencySignsKey = 'triage_emergency_signs';
const triagePrioritySignsKey = 'triage_priority_signs';
const triageNonUrgentSignsKey = 'triage_nonurgent_signs';
const triageSpecificFindingsKey = 'triage_specific_findings';
const triageHypoglycemiaSymptomsKey = 'triage_hypoglycemia_symptoms';
const triageCategoryKey = 'triage_category';

const _emergency = 'emergency';
const _priority = 'priority';
const _nonUrgent = 'nonUrgent';

const triageMatchedCategoriesKey = 'triage_matched_categories';
const triageCategoryCountKey = 'triage_category_count';
const triageSelectedCategoryKey = 'triage_selected_category';

const _srcClassify = SourceReference.triage('Triage classification');
const _srcEmergency = SourceReference.triage('TREAT IMMEDIATELY');
const _srcPriority = SourceReference.triage('ASSESS PROMPTLY AND ACT RAPIDLY');
const _srcNonUrgent = SourceReference.triage('ASSESS AND COUNSEL');
const _srcSpecific = SourceReference.triage('SPECIFIC MANAGEMENT WORKFLOWS');
const _srcDos = SourceReference.triage("DOs");
const _srcDonts = SourceReference.triage("DON'Ts");
const _srcKpi = SourceReference.triage('KEY PERFORMANCE INDICATORS (KPIs)');

const triageGroups = [
  QuestionGroup(
    'triage_measurements',
    'Initial triage measurements',
    subtitle: 'Leave a measurement blank if it is not available.',
    footnote:
        "Examples indicate the expected input format only. Enter the baby's actual measured values.",
  ),
  QuestionGroup(
    'triage_signs',
    'Signs for triage classification',
    subtitle: 'Select every sign that applies in each category.',
  ),
  QuestionGroup('triage_category', 'Triage category'),
  QuestionGroup('triage_glucose', 'Blood glucose management'),
];

const qTriageTemperature = ClinicalQuestion(
  id: triageTemperatureKey,
  group: 'triage_measurements',
  question: 'Temperature',
  type: QuestionType.decimal,
  unit: '°C',
  inputHint: 'e.g., 36.5',
  sources: [_srcClassify, _srcSpecific],
);

const qTriageSpo2 = ClinicalQuestion(
  id: triageSpo2Key,
  group: 'triage_measurements',
  question: 'Oxygen saturation (SpO₂)',
  type: QuestionType.numeric,
  unit: '%',
  inputHint: 'e.g., 95',
  sources: [_srcClassify, _srcEmergency],
);

const qTriageHeartRate = ClinicalQuestion(
  id: triageHeartRateKey,
  group: 'triage_measurements',
  question: 'Heart rate',
  type: QuestionType.numeric,
  unit: 'bpm',
  inputHint: 'e.g., 140',
  sources: [_srcClassify, _srcSpecific],
);

const qTriageWeight = ClinicalQuestion(
  id: triageWeightKey,
  group: 'triage_measurements',
  question: 'Weight',
  type: QuestionType.numeric,
  unit: 'g',
  inputHint: 'e.g., 2.5',
  displayUnit: 'kg',
  displayFactor: 1000,
  sources: [_srcClassify],
);

const qTriageBloodGlucose = ClinicalQuestion(
  id: triageBloodGlucoseKey,
  group: 'triage_measurements',
  question: 'Blood glucose',
  type: QuestionType.numeric,
  unit: 'mg/dL',
  inputHint: 'e.g., 60',
  sources: [_srcEmergency, _srcSpecific, _srcKpi],
);

const qTriageEmergencySigns = ClinicalQuestion(
  id: triageEmergencySignsKey,
  group: 'triage_signs',
  question: 'Emergency signs (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('apnea', 'Apnea or gasping'),
    QuestionOption(
        'respiratoryDistress', 'Respiratory distress (retractions, grunt)'),
    QuestionOption('centralCyanosis', 'Central cyanosis'),
    QuestionOption(
      'shock',
      'Shock (cold peripheries, mottled/grey skin, CRT >3 s, weak pulses, low BP)',
    ),
    QuestionOption('convulsionsComa', 'Convulsions/coma'),
    QuestionOption(
      'severeDehydration',
      'Severe dehydration (diarrhoea plus any two: lethargy, very slow skin pinch, sunken eyes)',
    ),
    QuestionOption('persistentTachycardia', 'Persistent tachycardia >200/min'),
  ],
  sources: [_srcClassify, _srcSpecific],
);

const qTriagePrioritySigns = ClinicalQuestion(
  id: triagePrioritySignsKey,
  group: 'triage_signs',
  question: 'Priority signs (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption(
        'largeForGestationIdm', 'Large for gestation with risk factors (IDM)'),
    QuestionOption('tachypnea', 'Tachypnea without retractions or grunt'),
    QuestionOption('severeJaundice',
        'Severe jaundice (onset <24 h, palm or sole staining)'),
    QuestionOption('severePallor', 'Severe pallor'),
    QuestionOption('bleeding', 'Bleeding'),
    QuestionOption('majorMalformations', 'Major malformations'),
    QuestionOption('abdominalDistension', 'Abdominal distension'),
    QuestionOption(
      'irritableOrPoorFeeding',
      'Irritable/restless, refusal to feed, decreased activity',
    ),
  ],
  sources: [_srcClassify, _srcPriority],
);

const qTriageNonUrgentSigns = ClinicalQuestion(
  id: triageNonUrgentSignsKey,
  group: 'triage_signs',
  question: 'Non-urgent signs (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('mildJaundice', 'Mild jaundice'),
    QuestionOption('transitionalStools', 'Transitional stools'),
    QuestionOption('minorBirthTrauma', 'Minor birth trauma'),
    QuestionOption('minorMalformations', 'Minor malformations'),
    QuestionOption('superficialInfections', 'Superficial infections'),
    QuestionOption('breastfeedingDifficulty', 'Breastfeeding difficulty'),
    QuestionOption('regurgitation', 'Regurgitation'),
  ],
  sources: [_srcClassify, _srcNonUrgent],
);

const qTriageSpecificFindings = ClinicalQuestion(
  id: triageSpecificFindingsKey,
  group: 'triage_signs',
  question: 'Specific management findings (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('exposedSkinDefect', 'Exposed skin defect'),
    QuestionOption('cdh', 'Congenital diaphragmatic hernia (CDH)'),
    QuestionOption('tefAtresia', 'Suspected TEF/oesophageal atresia'),
    QuestionOption(
      'acuteBilirubinEncephalopathy',
      'Signs of acute bilirubin encephalopathy',
    ),
  ],
  sources: [_srcSpecific],
);

final qTriageCategory = ClinicalQuestion(
  id: triageCategoryKey,
  group: 'triage_category',
  question: 'Select the triage category',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(
      _emergency,
      'Emergency',
      visibleWhen: const Var(triageMatchedCategoriesKey).contains(_emergency),
    ),
    QuestionOption(
      _priority,
      'Priority',
      visibleWhen: const Var(triageMatchedCategoriesKey).contains(_priority),
    ),
    QuestionOption(
      _nonUrgent,
      'Non-urgent',
      visibleWhen: const Var(triageMatchedCategoriesKey).contains(_nonUrgent),
    ),
  ],
  visibleWhen: const Var(triageCategoryCountKey).gt(1),
  sources: [_srcClassify],
);

const qTriageHypoglycemiaSymptoms = ClinicalQuestion(
  id: triageHypoglycemiaSymptomsKey,
  group: 'triage_glucose',
  question: 'Is the neonate symptomatic?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes'),
    QuestionOption(false, 'No'),
  ],
  helper: 'Used for the blood glucose action shown in this STW.',
  sources: [_srcSpecific],
);

Set<String> _values(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

Set<String> _matchingCategories(VariableReader r) {
  final emergency = _values(r.valueOf(triageEmergencySignsKey));
  final priority = _values(r.valueOf(triagePrioritySignsKey));
  final nonUrgent = _values(r.valueOf(triageNonUrgentSignsKey));
  final temperature = r.valueOf(triageTemperatureKey);
  final spo2 = r.valueOf(triageSpo2Key);
  final weight = r.valueOf(triageWeightKey);
  return {
    if (emergency.isNotEmpty ||
        (temperature is num && temperature < 35.5) ||
        (spo2 is num && spo2 < 91))
      _emergency,
    if (priority.isNotEmpty ||
        (temperature is num && temperature >= 35.5 && temperature <= 36.4) ||
        (weight is num && weight < 1800))
      _priority,
    if (nonUrgent.isNotEmpty) _nonUrgent,
  };
}

String? _selectedCategory(VariableReader r) {
  final matched = r.valueOf(triageMatchedCategoriesKey) as Set<String>? ?? {};
  if (matched.length == 1) return matched.single;
  final choice = r.valueOf(triageCategoryKey);
  return choice is String && matched.contains(choice) ? choice : null;
}

final triageVariables = [
  const ClinicalVariable(
    triageMatchedCategoriesKey,
    'Categories matched by the signs and recorded measurements',
    _matchingCategories,
  ),
  ClinicalVariable(
    triageCategoryCountKey,
    'Number of matching triage categories',
    (r) => (r.valueOf(triageMatchedCategoriesKey) as Set<String>).length,
  ),
  const ClinicalVariable(
    triageSelectedCategoryKey,
    'Clinician-selected category when multiple categories match',
    _selectedCategory,
  ),
];

const _isCategory = Var(triageSelectedCategoryKey);
const _bg = Var(triageBloodGlucoseKey);
final _symptomatic = const Var(triageHypoglycemiaSymptomsKey).eq(true);

final triageRules = <ClinicalRule>[
  ClinicalRule(
    id: 'triage.initialChecks',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).exists(),
    source: const SourceReference.triage('Initial assessment'),
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.action,
      title: 'Initial triage checks',
      actions: [
        'Place under radiant warmer.',
        'Attach temperature probe and pulse oximeter.',
        'Assess for emergency signs using TABC & CD.',
        'T: Temperature; A: Airway; B: Breathing; C: Circulation; C: Coma/convulsions; D: Dehydration.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.classification',
    topic: _triage,
    when: const Var(triageSelectedCategoryKey).exists(),
    source: _srcClassify,
    then: (r) {
      final category = r.valueOf(triageSelectedCategoryKey) as String;
      final label = switch (category) {
        _emergency => 'EMERGENCY',
        _priority => 'PRIORITY',
        _ => 'NON-URGENT',
      };
      return FindingContent(
        category: FindingCategory.classification,
        level: category == _emergency
            ? FindingLevel.urgent
            : category == _priority
                ? FindingLevel.action
                : FindingLevel.ok,
        title: 'Triage category: $label',
        why: [
          if (category == _emergency)
            'Emergency signs selected or measured: ${_values(r.valueOf(triageEmergencySignsKey)).join(', ')}',
          if (category == _priority)
            'Priority signs selected or measured: ${_values(r.valueOf(triagePrioritySignsKey)).join(', ')}',
          if (category == _nonUrgent)
            'Non-urgent signs selected: ${_values(r.valueOf(triageNonUrgentSignsKey)).join(', ')}',
        ],
      );
    },
  ),
  ClinicalRule(
    id: 'triage.classificationUndetermined',
    topic: _triage,
    when: const Var(triageCategoryCountKey).eq(0),
    source: _srcClassify,
    then: (_) => const FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'Triage category not determined',
      actions: [
        'No Emergency, Priority or Non-urgent sign was recorded. Assess the neonate and select the applicable signs.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.emergencyActions',
    topic: _triage,
    when: _isCategory.eq(_emergency),
    source: _srcEmergency,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.urgent,
      title: 'TREAT IMMEDIATELY',
      actions: [
        'Maintain TABC.',
        'Respiratory support: Nasal prong O₂ if SpO₂ <91% (titrate to 91–95%); nasal CPAP if respiratory distress; intubate if gasping or poor effort.',
        'Check blood glucose; send CBC and electrolytes.',
        'If sepsis is likely, draw blood culture and give the first antibiotic dose without delay.',
        'Start IV fluids as per weight and postnatal age.',
        'Manage shock, dehydration and seizures.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.priorityActions',
    topic: _triage,
    when: _isCategory.eq(_priority),
    source: _srcPriority,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'ASSESS PROMPTLY AND ACT RAPIDLY',
      actions: [
        'Maintain TABC.',
        'Nasal prong oxygen if SpO₂ <91%.',
        'Check blood glucose and act accordingly.',
        'Start IV fluids (if abdominal distension/GI malformation) or gavage feeds.',
        'Assess the risk factors for sepsis.',
        'Investigations as per clinical findings.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.nonUrgentActions',
    topic: _triage,
    when: _isCategory.eq(_nonUrgent),
    source: _srcNonUrgent,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: 'ASSESS AND COUNSEL',
      actions: [
        'Treat as per indication.',
        'Counsel for breastfeeding.',
        'Explain danger signs and follow-up.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.followSpecific',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).exists(),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'Follow specific STWs',
      actions: [
        'A neonate may have more than one condition.',
        'Follow the specific STW for the condition.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.shock',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).contains('shock'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Shock',
      actions: [
        'IV NS 10 mL/kg if volume expansion is indicated: preterm over 30–60 min; term over 15–20 min.',
        'Consider inotropes early.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.severeDehydration',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).contains('severeDehydration'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Severe dehydration',
      actions: [
        'Diarrhoeal severe dehydration: IV RL/NS 30 mL/kg in 1 h, then 70 mL/kg over 5 h (WHO Plan C).',
        'If IV not possible: ORS 20 mL/kg/h for 6 h. Assess 1–2 hourly and titrate fluids.',
        'Hypernatremic dehydration related to poor feeding/hot environment: manage as per the standard neonatal protocol.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.seizures',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).contains('convulsionsComa'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Seizures',
      actions: [
        'For seizures: Inj. phenobarbitone 20 mg/kg IV over 15 min. If seizures persist after 15 min, give a further 10 mg/kg IV over 10 min.',
        'If uncontrolled, consider levetiracetam as second-line treatment.',
        'Correct glucose and calcium if abnormal, concurrently.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.surgical.exposedSkinDefect',
    topic: _triage,
    when: const Var(triageSpecificFindingsKey).contains('exposedSkinDefect'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.referral,
      level: FindingLevel.urgent,
      title: 'Exposed skin defect',
      actions: [
        'Cover exposed skin defects with warm saline sterile gauze; maintain hydration.',
        'Arrange urgent referral to a surgical centre.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.surgical.cdh',
    topic: _triage,
    when: const Var(triageSpecificFindingsKey).contains('cdh'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.referral,
      level: FindingLevel.urgent,
      title: 'Congenital diaphragmatic hernia (CDH)',
      actions: [
        'Avoid CPAP/bag-mask ventilation.',
        'Intubate if necessary; decompress stomach with an OG/NG tube.',
        'Arrange urgent referral to a surgical centre.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.surgical.tefAtresia',
    topic: _triage,
    when: const Var(triageSpecificFindingsKey).contains('tefAtresia'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.referral,
      level: FindingLevel.urgent,
      title: 'Suspected TEF/oesophageal atresia',
      actions: [
        'Nil by mouth, IV fluids, head-up position; upper-pouch suction.',
        'Arrange urgent referral to a surgical centre.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.persistentTachycardia',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).contains('persistentTachycardia'),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.urgent,
      title: 'Persistent HR >200/min',
      actions: [
        'Check ECG for arrhythmia.',
        'Check and correct hyperthermia; refer for further management.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.hypothermia',
    topic: _triage,
    when: const Var(triageTemperatureKey).lt(36.5),
    source: _srcSpecific,
    then: (r) {
      final temperature = r.valueOf(triageTemperatureKey) as num;
      return FindingContent(
        category: FindingCategory.treatment,
        level: temperature < 35.5 ? FindingLevel.urgent : FindingLevel.action,
        title: 'Hypothermia',
        actions: temperature < 35.5
            ? const [
                'Temperature <35.5°C: nurse under a radiant warmer in servo mode.'
              ]
            : const [
                'Temperature 35.5–36.4°C and baby is well: warm environment, skin-to-skin contact; recheck in 30 min.',
                'If unwell or temperature fails to improve, nurse under a warmer.',
              ],
      );
    },
  ),
  ClinicalRule(
    id: 'triage.hypoglycemia.iv',
    topic: _triage,
    when: AnyOf([
      AllOf([_bg.exists(), _bg.lt(20)]),
      _symptomatic
    ]),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Hypoglycemia',
      actions: [
        'Blood glucose <20 mg/dL OR symptomatic: 2 mL/kg 10% dextrose IV, followed by infusion at 6 mg/kg/min.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.hypoglycemia.feeding',
    topic: _triage,
    when: AllOf([
      _bg.exists(),
      _bg.ge(20),
      _bg.lt(45),
      Not(_symptomatic),
    ]),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.action,
      title: 'Hypoglycemia',
      actions: [
        'Blood glucose <45 mg/dL and asymptomatic: supervised breastfeeding or EBM.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.severeJaundice',
    topic: _triage,
    when: AnyOf([
      const Var(triagePrioritySignsKey).contains('severeJaundice'),
      const Var(triageSpecificFindingsKey).contains('acuteBilirubinEncephalopathy'),
    ]),
    source: _srcSpecific,
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Serious jaundice',
      actions: [
        'Serious jaundice (onset <24 h, palms/soles yellow, or signs of acute bilirubin encephalopathy): intensive phototherapy; consider IV fluids if dehydrated; prepare for exchange transfusion as indicated.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.dos',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).exists(),
    source: _srcDos,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: 'DOs',
      actions: [
        'Screen every neonate immediately on arrival for emergency and priority signs.',
        'Maintain TABC, assess SpO₂ and blood glucose, and start indicated treatment promptly. Reassess after each intervention.',
        'Administer the first dose of antibiotic within 1 hour if there is a high likelihood of sepsis.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.donts',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).exists(),
    source: _srcDonts,
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: "DON'Ts",
      actions: [
        'Do NOT delay emergency treatment for investigations or documentation.',
        'Obtain blood culture before the first dose of antibiotics, but do not delay treatment.',
        'Do NOT discharge a neonate with persistent emergency or priority signs; arrange admission or appropriate referral.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.kpis',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).exists(),
    source: _srcKpi,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'Key performance indicators (KPIs)',
      actions: [
        'Triage classification documented (%): neonates with a documented triage category at initial assessment ÷ all neonates assessed × 100.',
        'Complete triage measurements (%): sick neonates with temperature, SpO₂ AND blood glucose recorded at initial assessment ÷ all sick neonates assessed × 100.',
      ],
      why: [
        'Triage every neonate on arrival — treat emergency signs immediately and assess priority signs promptly.',
      ],
    ),
  ),
];

final triageWorkflow = StwWorkflow(
  _triage,
  source: const SourceReference.triage('Whole document (July 2020)'),
  groups: triageGroups,
  uses: [
    const QuestionUse(qTriageTemperature),
    const QuestionUse(qTriageSpo2),
    const QuestionUse(qTriageHeartRate),
    const QuestionUse(qTriageWeight),
    const QuestionUse(qTriageBloodGlucose),
    const QuestionUse(qTriageEmergencySigns),
    const QuestionUse(qTriagePrioritySigns),
    const QuestionUse(qTriageNonUrgentSigns),
    const QuestionUse(qTriageSpecificFindings),
    QuestionUse(
      qTriageCategory,
      when: const Var(triageCategoryCountKey).gt(1),
      required: true,
    ),
    QuestionUse(
      qTriageHypoglycemiaSymptoms,
      when: AnyOf([
        Not(const Var(triageBloodGlucoseKey).exists()),
        const Var(triageBloodGlucoseKey).ge(20),
      ]),
      required: true,
    ),
  ],
  variables: triageVariables,
  rules: triageRules,
);
