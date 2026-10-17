/// Neonatal emergency triage workflow from the July 2020 ICMR/DHR STW.
///
/// One page of history, measurements and emergency signs. The triage
/// category is computed, never chosen: any emergency sign or threshold
/// classifies the neonate as EMERGENCY, otherwise a Priority threshold
/// (temperature, weight) classifies PRIORITY. Measurements may be left blank.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';

const _triage = NeonatalCondition.triage;

/// The single Triage page: history, measurements and signs.
const triageAssessmentGroup = 'triage_assessment';

const triageFastTrackKey = 'triage_fast_track';
const triageMaternalHistoryKey = 'triage_maternal_history';
const triageNewbornHistoryKey = 'triage_newborn_history';
const triageWeightKey = 'triage_weight_g';
const triageGestationKey = 'triage_gestation';
const triageTemperatureKey = 'triage_temperature_c';
const triageHeartRateKey = 'triage_heart_rate';
const triageSpo2Key = 'triage_spo2';
const triageBloodGlucoseKey = 'triage_blood_glucose';
const triageHypoglycemiaSymptomsKey = 'triage_hypoglycemia_symptoms';
const triageEmergencySignsKey = 'triage_emergency_signs';

/// Computed variables.
const triageEmergencyTriggersKey = 'triage_emergency_triggers';
const triagePriorityReasonsKey = 'triage_priority_reasons';
const triageMatchedCategoriesKey = 'triage_matched_categories';
const triageCategoryKey = 'triage_category';
const triageShockKey = 'triage_shock';
const triageHypoglycemiaKey = 'triage_hypoglycemia';
const triageRespiratoryEmergencyKey = 'triage_respiratory_emergency';

const triageEmergency = 'emergency';
const triagePriority = 'priority';

const triageTerm = 'term';
const triagePreterm = 'preterm';

/// Thresholds printed in the STW (RBS: product rule, see [_srcGlucoseTrigger]).
const triageHypothermiaEmergencyC = 35.5;
const triageSpo2EmergencyBelow = 91;
const triageHeartRateEmergencyAbove = 200;
const triageRbsEmergencyBelow = 45;
const triageRbsIvBelow = 20;

const _srcClassify = SourceReference.triage('Triage classification');
const _srcEmergencySigns = SourceReference.triage('EMERGENCY');
const _srcPrioritySigns = SourceReference.triage('PRIORITY');
const _srcEmergency = SourceReference.triage('TREAT IMMEDIATELY');
const _srcPriority = SourceReference.triage('ASSESS PROMPTLY AND ACT RAPIDLY');
const _srcSpecific = SourceReference.triage('SPECIFIC MANAGEMENT WORKFLOWS');
const _srcShock = SourceReference.triage('SHOCK');
const _srcHypoglycemia = SourceReference.triage('HYPOGLYCEMIA');
const _srcHypothermia = SourceReference.triage('HYPOTHERMIA');
const _srcSeizures = SourceReference.triage('SEIZURES');
const _srcDehydration = SourceReference.triage('SEVERE DEHYDRATION');
const _srcTachycardia = SourceReference.triage('PERSISTENT HR >200/MIN');
const _srcDos = SourceReference.triage("DOs");
const _srcDonts = SourceReference.triage("DON'Ts");
const _srcKpi = SourceReference.triage('KEY PERFORMANCE INDICATORS (KPIs)');
const _srcGlucoseTrigger = SourceReference.triage(
  'HYPOGLYCEMIA',
  needsClinicalReview: true,
  note: 'RBS <45 mg/dL is classified as Emergency by the triage product '
      'specification. The Triage STW lists blood glucose under specific '
      'management, not as an Emergency sign.',
);

const triageGroups = [
  QuestionGroup(
    triageAssessmentGroup,
    'Triage assessment',
    subtitle: 'The triage category is classified automatically from the '
        'signs and measurements. Leave a measurement blank if it is not '
        'available.',
    footnote:
        "Examples indicate the expected input format only. Enter the baby's actual measured values.",
    questionOrder: [
      triageFastTrackKey,
      triageMaternalHistoryKey,
      triageNewbornHistoryKey,
      triageWeightKey,
      triageGestationKey,
      triageTemperatureKey,
      triageHeartRateKey,
      triageSpo2Key,
      triageBloodGlucoseKey,
      triageHypoglycemiaSymptomsKey,
      triageEmergencySignsKey,
    ],
  ),
];

const qTriageFastTrack = ClinicalQuestion(
  id: triageFastTrackKey,
  group: triageAssessmentGroup,
  question: 'Baby is sick – proceed directly to examination',
  type: QuestionType.boolean,
  helper: 'Skips the maternal and newborn history.',
  sources: [SourceReference.dataEntry('Skip history when the baby is sick')],
);

const qTriageMaternalHistory = ClinicalQuestion(
  id: triageMaternalHistoryKey,
  group: triageAssessmentGroup,
  question: 'Maternal history (H/O)',
  type: QuestionType.text,
  inputHint: 'e.g., PROM >18 h, maternal fever',
  sources: [SourceReference.dataEntry('Maternal history, free text')],
);

const qTriageNewbornHistory = ClinicalQuestion(
  id: triageNewbornHistoryKey,
  group: triageAssessmentGroup,
  question: 'Newborn history (NB H/O)',
  type: QuestionType.text,
  inputHint: 'e.g., not feeding since morning',
  sources: [SourceReference.dataEntry('Newborn history, free text')],
);

const qTriageWeight = ClinicalQuestion(
  id: triageWeightKey,
  group: triageAssessmentGroup,
  question: 'Weight',
  type: QuestionType.numeric,
  unit: 'g',
  inputHint: 'e.g., 2.5',
  displayUnit: 'kg',
  displayFactor: 1000,
  // PRIORITY: Weight <1800 g.
  stwRange: 'STW: Weight <1800 g: Priority',
  sources: [_srcPrioritySigns],
);

const qTriageGestation = ClinicalQuestion(
  id: triageGestationKey,
  group: triageAssessmentGroup,
  question: 'Gestation',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(triageTerm, 'Term (T)'),
    QuestionOption(triagePreterm, 'Preterm (PT)'),
  ],
  // SHOCK: NS bolus over 30–60 min in preterm, 15–20 min in term.
  sources: [_srcShock],
);

const qTriageTemperature = ClinicalQuestion(
  id: triageTemperatureKey,
  group: triageAssessmentGroup,
  question: 'Temperature',
  type: QuestionType.decimal,
  unit: '°C',
  inputHint: 'e.g., 36.5',
  // EMERGENCY: Significant hypothermia (<35.5°C);
  // PRIORITY: Temperature 35.5 to 36.4°C.
  stwRange: 'STW: <35.5°C: Emergency · 35.5 to 36.4°C: Priority',
  sources: [_srcEmergencySigns, _srcPrioritySigns, _srcHypothermia],
);

const qTriageHeartRate = ClinicalQuestion(
  id: triageHeartRateKey,
  group: triageAssessmentGroup,
  question: 'Heart rate (HR)',
  type: QuestionType.numeric,
  unit: 'bpm',
  inputHint: 'e.g., 140',
  // EMERGENCY: Persistent tachycardia >200/min.
  stwRange: 'STW: Persistent tachycardia >200/min: Emergency',
  sources: [_srcEmergencySigns, _srcTachycardia],
);

const qTriageSpo2 = ClinicalQuestion(
  id: triageSpo2Key,
  group: triageAssessmentGroup,
  question: 'Oxygen saturation (SpO₂)',
  type: QuestionType.numeric,
  unit: '%',
  inputHint: 'e.g., 95',
  // EMERGENCY: Central cyanosis or SpO₂ <91%;
  // TREAT IMMEDIATELY: titrate to 91–95%.
  stwRange: 'STW: SpO₂ <91%: Emergency · titrate to 91–95%',
  sources: [_srcEmergencySigns, _srcEmergency],
);

const qTriageBloodGlucose = ClinicalQuestion(
  id: triageBloodGlucoseKey,
  group: triageAssessmentGroup,
  question: 'Random blood sugar (RBS)',
  type: QuestionType.numeric,
  unit: 'mg/dL',
  inputHint: 'e.g., 60',
  // HYPOGLYCEMIA box (specific management workflows).
  stwRange: 'STW: <20 mg/dL OR symptomatic: 2 mL/kg 10% dextrose IV · '
      '<45 mg/dL and asymptomatic: supervised breastfeeding or EBM',
  sources: [_srcEmergency, _srcHypoglycemia, _srcKpi],
);

const qTriageHypoglycemiaSymptoms = ClinicalQuestion(
  id: triageHypoglycemiaSymptomsKey,
  group: triageAssessmentGroup,
  question: 'Is the neonate symptomatic?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes'),
    QuestionOption(false, 'No'),
  ],
  helper: 'RBS is below 45 mg/dL: chooses the hypoglycemia treatment.',
  sources: [_srcHypoglycemia],
);

const qTriageEmergencySigns = ClinicalQuestion(
  id: triageEmergencySignsKey,
  group: triageAssessmentGroup,
  question: 'Emergency signs (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('apnea', 'Apnea or gasping'),
    QuestionOption('centralCyanosis', 'Central cyanosis'),
    QuestionOption('convulsionsComa', 'Convulsions/coma'),
    QuestionOption(
      'shock',
      'Shock (cold peripheries, mottled/grey skin, CRT >3 s, weak pulses, low BP)',
    ),
    QuestionOption(
        'respiratoryDistress', 'Respiratory distress (retractions, grunt)'),
    QuestionOption(
      'severeDehydration',
      'Severe dehydration (diarrhoea plus any two: lethargy, very slow skin pinch, sunken eyes)',
    ),
  ],
  sources: [_srcEmergencySigns, _srcShock],
);

Set<String> _values(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

List<String> _labels(ClinicalQuestion q, Set<String> values) => [
      for (final o in q.options)
        if (values.contains(o.value.toString())) o.label,
    ];

String _fmt(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// Readable reasons the neonate is EMERGENCY; empty when none applies.
List<String> _emergencyTriggers(VariableReader r) {
  final temperature = r.valueOf(triageTemperatureKey);
  final hr = r.valueOf(triageHeartRateKey);
  final spo2 = r.valueOf(triageSpo2Key);
  final bg = r.valueOf(triageBloodGlucoseKey);
  return [
    if (temperature is num && temperature < triageHypothermiaEmergencyC)
      'Temperature ${_fmt(temperature)}°C (<35.5°C)',
    if (hr is num && hr > triageHeartRateEmergencyAbove)
      'HR ${_fmt(hr)}/min (>200/min)',
    if (spo2 is num && spo2 < triageSpo2EmergencyBelow)
      'SpO₂ ${_fmt(spo2)}% (<91%)',
    ..._labels(qTriageEmergencySigns, _values(r.valueOf(triageEmergencySignsKey))),
    if (bg is num && bg < triageRbsEmergencyBelow)
      'RBS ${_fmt(bg)} mg/dL (<45 mg/dL)',
  ];
}

List<String> _priorityReasons(VariableReader r) {
  final temperature = r.valueOf(triageTemperatureKey);
  final weight = r.valueOf(triageWeightKey);
  return [
    if (temperature is num && temperature >= 35.5 && temperature <= 36.4)
      'Temperature ${_fmt(temperature)}°C (35.5 to 36.4°C)',
    if (weight is num && weight < 1800) 'Weight ${_fmt(weight)} g (<1800 g)',
  ];
}

List<String> _list(Object? v) => v is List<String> ? v : const [];

/// Reasons for the computed [triageCategoryKey]; empty when there is none.
List<String> triageReasonsFor(VariableReader r) =>
    switch (r.valueOf(triageCategoryKey)) {
      triageEmergency => _list(r.valueOf(triageEmergencyTriggersKey)),
      triagePriority => _list(r.valueOf(triagePriorityReasonsKey)),
      _ => const [],
    };

/// Most severe matching category; null when nothing was recorded.
String? _category(VariableReader r) {
  final matched = r.valueOf(triageMatchedCategoriesKey) as Set<String>;
  for (final c in const [triageEmergency, triagePriority]) {
    if (matched.contains(c)) return c;
  }
  return null;
}

final triageVariables = [
  const ClinicalVariable(
    triageEmergencyTriggersKey,
    'Emergency signs and thresholds met',
    _emergencyTriggers,
  ),
  const ClinicalVariable(
    triagePriorityReasonsKey,
    'Priority signs and thresholds met',
    _priorityReasons,
  ),
  ClinicalVariable(
    triageMatchedCategoriesKey,
    'Categories matched by the signs and recorded measurements',
    (r) => {
      if (_list(r.valueOf(triageEmergencyTriggersKey)).isNotEmpty)
        triageEmergency,
      if (_list(r.valueOf(triagePriorityReasonsKey)).isNotEmpty)
        triagePriority,
    },
  ),
  const ClinicalVariable(
    triageCategoryKey,
    'Triage category, classified automatically (most severe match)',
    _category,
  ),
  ClinicalVariable(
    triageShockKey,
    'Shock recorded as an emergency sign',
    (r) => _values(r.valueOf(triageEmergencySignsKey)).contains('shock'),
  ),
  ClinicalVariable(
    triageHypoglycemiaKey,
    'RBS below 45 mg/dL',
    (r) {
      final bg = r.valueOf(triageBloodGlucoseKey);
      return bg is num && bg < triageRbsEmergencyBelow;
    },
  ),
  ClinicalVariable(
    triageRespiratoryEmergencyKey,
    'Apnea/gasping, central cyanosis, SpO₂ <91% or respiratory distress',
    (r) {
      final signs = _values(r.valueOf(triageEmergencySignsKey));
      final spo2 = r.valueOf(triageSpo2Key);
      return signs.contains('apnea') ||
          signs.contains('centralCyanosis') ||
          signs.contains('respiratoryDistress') ||
          (spo2 is num && spo2 < triageSpo2EmergencyBelow);
    },
  ),
];

String _thousandths(int thousandths) {
  final whole = thousandths ~/ 1000;
  final frac = (thousandths % 1000).toString().padLeft(3, '0');
  final trimmed = frac.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}

/// NS bolus volume as the straight multiplication of the STW per-kg value
/// (10 mL/kg) by the weight, with the formula shown. Exact; not rounded.
String triageNsBolusVolumeText(int weightG) =>
    'Bolus volume = 10 mL/kg × ${_thousandths(weightG)} kg = '
    '${_thousandths(10 * weightG)} mL of NS (straight multiplication of the '
    'STW per-kg value; verify before giving)';

/// "Baby details" line of the summary from the Triage answers, e.g.
/// "GA Term · Weight 2.5 kg". Triage records the weight on arrival, not the
/// birth weight, so it is shown as Weight rather than BW.
String describeTriageBaby(VariableReader r) {
  final gestation = switch (r.valueOf(triageGestationKey)) {
    triageTerm => 'Term',
    triagePreterm => 'Preterm',
    _ => '—',
  };
  final weight = r.valueOf(triageWeightKey);
  return [
    'GA $gestation',
    weight is num ? 'Weight ${_thousandths(weight.round())} kg' : 'Weight —',
  ].join(' · ');
}

/// HYPOGLYCEMIA box: IV 10% dextrose when RBS <20 mg/dL, or <45 mg/dL and
/// symptomatic.
bool triageIvDextroseIndicated(VariableReader r) {
  final bg = r.valueOf(triageBloodGlucoseKey);
  return bg is num &&
      (bg < triageRbsIvBelow ||
          (bg < triageRbsEmergencyBelow &&
              r.valueOf(triageHypoglycemiaSymptomsKey) == true));
}

/// The SHOCK box rate for the recorded gestation; null when not recorded.
String? triageShockRateText(VariableReader r) =>
    switch (r.valueOf(triageGestationKey)) {
      triagePreterm => 'Preterm: give the NS bolus over 30–60 min.',
      triageTerm => 'Term: give the NS bolus over 15–20 min.',
      _ => null,
    };

const _isCategory = Var(triageCategoryKey);
const _bg = Var(triageBloodGlucoseKey);
final _symptomatic = const Var(triageHypoglycemiaSymptomsKey).eq(true);

/// Set to the empty set when the Triage page is confirmed with no sign.
final _pageConfirmed = const Var(triageEmergencySignsKey).exists();

final triageRules = <ClinicalRule>[
  ClinicalRule(
    id: 'triage.initialChecks',
    topic: _triage,
    when: _pageConfirmed,
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
    when: _isCategory.exists(),
    source: _srcClassify,
    then: (r) {
      final category = r.valueOf(triageCategoryKey) as String;
      final emergency = category == triageEmergency;
      return FindingContent(
        category: FindingCategory.classification,
        level: emergency ? FindingLevel.urgent : FindingLevel.action,
        title: 'Triage category: ${emergency ? 'EMERGENCY' : 'PRIORITY'}',
        why: [
          'Classified automatically from: ${triageReasonsFor(r).join('; ')}',
        ],
      );
    },
  ),
  ClinicalRule(
    id: 'triage.glucoseEmergencyTrigger',
    topic: _triage,
    when: const Var(triageHypoglycemiaKey).eq(true),
    source: _srcGlucoseTrigger,
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'RBS <45 mg/dL: classified as Emergency',
      actions: const [
        'Treat as per the HYPOGLYCEMIA box (Refer to STW on neonatal hypoglycemia).',
      ],
      why: ['RBS ${_fmt(r.valueOf(triageBloodGlucoseKey) as num)} mg/dL'],
    ),
  ),
  ClinicalRule(
    id: 'triage.classificationUndetermined',
    topic: _triage,
    when: AllOf([_pageConfirmed, Not(_isCategory.exists())]),
    source: _srcClassify,
    then: (_) => const FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'No Emergency or Priority sign recorded',
      actions: [
        'No Emergency sign or Emergency/Priority threshold was recorded. Assess the neonate for the Priority and Non-urgent signs of the Triage STW.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'triage.emergencyActions',
    topic: _triage,
    when: _isCategory.eq(triageEmergency),
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
    when: _isCategory.eq(triagePriority),
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
    id: 'triage.followSpecific',
    topic: _triage,
    when: _pageConfirmed,
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
    when: const Var(triageShockKey).eq(true),
    source: _srcShock,
    then: (r) {
      final weight = r.valueOf(triageWeightKey);
      return FindingContent(
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        title: 'Shock',
        actions: [
          'IV NS 10 mL/kg if volume expansion is indicated: preterm over 30–60 min; term over 15–20 min.',
          if (triageShockRateText(r) case final rate?) rate,
          if (weight is num) triageNsBolusVolumeText(weight.round()),
          'Consider inotropes early.',
        ],
        why: const ['Shock recorded as an emergency sign'],
      );
    },
  ),
  ClinicalRule(
    id: 'triage.severeDehydration',
    topic: _triage,
    when: const Var(triageEmergencySignsKey).contains('severeDehydration'),
    source: _srcDehydration,
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
    source: _srcSeizures,
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
    id: 'triage.persistentTachycardia',
    topic: _triage,
    when: const Var(triageHeartRateKey).gt(triageHeartRateEmergencyAbove),
    source: _srcTachycardia,
    then: (r) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.urgent,
      title: 'Persistent HR >200/min',
      actions: const [
        'Check ECG for arrhythmia.',
        'Check and correct hyperthermia; refer for further management.',
      ],
      why: ['HR ${_fmt(r.valueOf(triageHeartRateKey) as num)}/min'],
    ),
  ),
  ClinicalRule(
    id: 'triage.hypothermia',
    topic: _triage,
    when: const Var(triageTemperatureKey).lt(36.5),
    source: _srcHypothermia,
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
      _bg.lt(triageRbsIvBelow),
      AllOf([_bg.lt(triageRbsEmergencyBelow), _symptomatic]),
    ]),
    source: _srcHypoglycemia,
    then: (r) {
      final weight = r.valueOf(triageWeightKey);
      return FindingContent(
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        title: 'Hypoglycemia',
        actions: [
          'Blood glucose <20 mg/dL OR symptomatic: 2 mL/kg 10% dextrose IV, followed by infusion at 6 mg/kg/min.',
          if (weight is num) triageDextroseBolusVolumeText(weight.round()),
        ],
      );
    },
  ),
  ClinicalRule(
    id: 'triage.hypoglycemia.feeding',
    topic: _triage,
    when: AllOf([
      _bg.ge(triageRbsIvBelow),
      _bg.lt(triageRbsEmergencyBelow),
      Not(_symptomatic),
    ]),
    source: _srcHypoglycemia,
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
    id: 'triage.dos',
    topic: _triage,
    when: _pageConfirmed,
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
    when: _pageConfirmed,
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
    when: _pageConfirmed,
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

/// 10% dextrose bolus volume (2 mL/kg) for the recorded weight.
String triageDextroseBolusVolumeText(int weightG) =>
    'Bolus volume = 2 mL/kg × ${_thousandths(weightG)} kg = '
    '${_thousandths(2 * weightG)} mL of 10% dextrose (straight '
    'multiplication of the STW per-kg value; verify before giving)';

final triageWorkflow = StwWorkflow(
  _triage,
  source: const SourceReference.triage('Whole document (July 2020)'),
  groups: triageGroups,
  uses: [
    const QuestionUse(qTriageFastTrack),
    QuestionUse(
      qTriageMaternalHistory,
      when: Not(const Var(triageFastTrackKey).eq(true)),
    ),
    QuestionUse(
      qTriageNewbornHistory,
      when: Not(const Var(triageFastTrackKey).eq(true)),
    ),
    const QuestionUse(qTriageWeight),
    const QuestionUse(qTriageGestation),
    const QuestionUse(qTriageTemperature),
    const QuestionUse(qTriageHeartRate),
    const QuestionUse(qTriageSpo2),
    const QuestionUse(qTriageBloodGlucose),
    QuestionUse(
      qTriageHypoglycemiaSymptoms,
      when: AllOf([_bg.ge(triageRbsIvBelow), _bg.lt(triageRbsEmergencyBelow)]),
      required: true,
    ),
    const QuestionUse(qTriageEmergencySigns),
  ],
  variables: triageVariables,
  rules: triageRules,
  subjectLabel: 'Baby',
  subjectLine: describeTriageBaby,
);
