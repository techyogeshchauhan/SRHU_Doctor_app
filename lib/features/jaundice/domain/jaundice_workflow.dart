/// Neonatal Jaundice (infants ≥35 weeks) workflow for the dynamic
/// assessment engine.
///
/// Pure Dart. Branching is done by `jaundice_rules.dart`; recommendation
/// wording comes from `jaundice_content.dart` (verbatim from the STW PDF).
/// The STW prints no phototherapy / exchange transfusion chart: the
/// clinician records where TSB lies against the unit's own chart.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'jaundice_content.dart';
import 'jaundice_rules.dart';

const _j = NeonatalCondition.jaundice;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const jaundiceGa35Key = 'jaundice_ga35';
const jaundiceAgeHoursKey = 'jaundice_age_hours';
const jaundiceBefore24hKey = 'jaundice_before_24h';
const jaundiceKramerKey = 'jaundice_kramer';
const jaundiceTcbKey = 'jaundice_tcb';
const jaundiceNearCutoffKey = 'jaundice_near_cutoff';
const jaundiceAbeKey = 'jaundice_abe_signs';
const jaundicePostureKey = 'jaundice_posture_signs';
const jaundiceRiskKey = 'jaundice_risk';
const jaundiceTsbKey = 'jaundice_tsb';
const jaundiceCutoffResultKey = 'jaundice_tsb_vs_cutoff';
const jaundiceRepeatTsbKey = 'jaundice_repeat_tsb';
const jaundiceCutoffValueKey = 'jaundice_cutoff_value';

/// Kramer answer values besides the zones ([KramerZone.name]).
const kramerNone = 'none';
const kramerUnsure = 'unsure';

// Derived variables
const jaundiceAppliesKey = 'jaundice_applies';
const jaundiceFirst24hKey = 'jaundice_first_24h';
const jaundiceSeriousKey = 'jaundice_serious';
const jaundiceNeedsTsbKey = 'jaundice_needs_tsb';
const jaundiceStopMetKey = 'jaundice_stop_met';

// Findings
const jaundiceNotCoveredId = 'jaundice.notCovered';
const jaundiceSeriousId = 'jaundice.serious';
const jaundiceStartPtId = 'jaundice.startPhototherapy';
const jaundiceEbtId = 'jaundice.ebt';
const jaundiceNeedsTsbId = 'jaundice.needsTsb';
const jaundiceNoTsbId = 'jaundice.noTsb';
const jaundiceTsbAwaitedId = 'jaundice.tsbAwaited';
const jaundiceAboveCutoffId = 'jaundice.aboveCutoff';
const jaundiceInvestigationsId = 'jaundice.investigations';
const jaundiceBelowCutoffId = 'jaundice.belowCutoff';
const jaundiceStopMetId = 'jaundice.stopMet';
const jaundiceStopNotMetId = 'jaundice.stopNotMet';

SourceReference jaundiceSource(String suffix,
        {bool needsClinicalReview = false, String? note}) =>
    SourceReference.jaundice(jaundiceHeadings['jaundice_$suffix']!,
        regionId: 'jaundice_$suffix',
        needsClinicalReview: needsClinicalReview,
        note: note);

List<String> _evidence(String suffix) => jaundiceEvidence['jaundice_$suffix']!;

// ---------------------------------------------------------------------------
// Questions
// ---------------------------------------------------------------------------

const jaundiceGroups = [
  babyGroup,
  QuestionGroup(
    'jaundice_signs',
    'Jaundice: visual assessment',
    subtitle: 'Examine the naked baby in bright natural/ white fluorescent '
        'light; examine blanched skin.',
    questionOrder: [
      jaundiceAgeHoursKey,
      jaundiceBefore24hKey,
      jaundiceKramerKey,
      jaundiceTcbKey,
      jaundiceNearCutoffKey,
      jaundiceAbeKey,
      jaundicePostureKey,
    ],
  ),
  QuestionGroup('jaundice_risk', 'Look for these risk factors'),
  QuestionGroup(
    'jaundice_tsb',
    'Total serum bilirubin (TSB)',
    subtitle: 'As per TSB, determine if baby requires phototherapy/ EBT if '
        'TSB at/more than cut-off',
    footnote: 'The STW does not print an hour-specific cut-off chart. Use '
        'your unit\'s age- and risk-specific chart; the app does not '
        'calculate a cut-off.',
  ),
  QuestionGroup(
    'jaundice_review',
    'Repeat TSB under phototherapy',
    subtitle: 'Optional: leave blank if no repeat TSB yet',
  ),
];

final _gaUncertain = const Var(gaKnownKey).eq(false);

final qJaundiceGa35 = ClinicalQuestion(
  id: jaundiceGa35Key,
  group: 'baby',
  question: 'GA uncertain: is the infant ≥35 weeks by clinical assessment?',
  type: QuestionType.singleChoice,
  options: const [
    QuestionOption(true, 'Yes, ≥35 weeks'),
    QuestionOption(false, 'No, <35 weeks'),
  ],
  helper: 'This STW covers neonatal jaundice in infants ≥ 35 weeks only.',
  visibleWhen: _gaUncertain,
  sources: [jaundiceSource('scope')],
);

final qJaundiceAgeHours = ClinicalQuestion(
  id: jaundiceAgeHoursKey,
  group: 'jaundice_signs',
  question: 'Age of the baby',
  type: QuestionType.numeric,
  min: 0,
  max: 720,
  unit: 'hours',
  helper: 'Visible jaundice in first 24 hrs is serious jaundice.',
  stwRange: 'STW: visible jaundice in first 24 hrs · beyond 24 hrs: more '
      'than 12-14 mg/dL on visual assessment / TcB needs TSB',
  sources: [jaundiceSource('serious'), jaundiceSource('needs_tsb')],
);

final qJaundiceBefore24h = ClinicalQuestion(
  id: jaundiceBefore24hKey,
  group: 'jaundice_signs',
  question: 'Was jaundice visible in the first 24 hrs of life?',
  type: QuestionType.singleChoice,
  options: const [
    QuestionOption(true, 'Yes'),
    QuestionOption(false, 'No'),
  ],
  visibleWhen: const Var(jaundiceAgeHoursKey).ge(24),
  sources: [jaundiceSource('serious')],
);

final qJaundiceKramer = ClinicalQuestion(
  id: jaundiceKramerKey,
  group: 'jaundice_signs',
  question: 'Extent of jaundice (Kramer zone)',
  type: QuestionType.singleChoice,
  options: [
    const QuestionOption(kramerNone, 'No visible jaundice'),
    for (final z in KramerZone.values)
      QuestionOption(z.name, '${z.number} · ${z.label}',
          subtitle: 'Approx serum bilirubin ${z.approxTsb}'),
    const QuestionOption(kramerUnsure, 'Unsure about visual assessment'),
  ],
  sources: [jaundiceSource('kramer')],
);

final qJaundiceTcb = ClinicalQuestion(
  id: jaundiceTcbKey,
  group: 'jaundice_signs',
  question: 'TcB (optional)',
  type: QuestionType.decimal,
  min: 0,
  max: 40,
  unit: 'mg/dL',
  helper: 'Do not rely on visual assessment/ TcB while the baby is under '
      'phototherapy.',
  sources: [
    jaundiceSource('needs_tsb',
        needsClinicalReview: true,
        note: 'The STW prints "more than 12-14 mg/dL"; the app uses the '
            'lower end (TcB >12 mg/dL) so no TSB is missed.'),
  ],
);

final qJaundiceNearCutoff = ClinicalQuestion(
  id: jaundiceNearCutoffKey,
  group: 'jaundice_signs',
  question: 'Near the phototherapy (PT) cut-off on your unit\'s chart?',
  type: QuestionType.boolean,
  visibleWhen: const Var(jaundiceAgeHoursKey).ge(24),
  sources: [jaundiceSource('needs_tsb')],
);

final qJaundiceAbe = ClinicalQuestion(
  id: jaundiceAbeKey,
  group: 'jaundice_signs',
  question: 'Signs of acute bilirubin encephalopathy (ABE) (tick all present)',
  type: QuestionType.multipleChoice,
  options: [for (final s in AbeSign.values) QuestionOption(s.name, s.label)],
  sources: [jaundiceSource('serious')],
);

final qJaundicePosture = ClinicalQuestion(
  id: jaundicePostureKey,
  group: 'jaundice_signs',
  question: 'Abnormal posturing and related signs (tick all present)',
  type: QuestionType.multipleChoice,
  options: [
    for (final s in PostureSign.values) QuestionOption(s.name, s.label)
  ],
  sources: [jaundiceSource('serious')],
);

final qJaundiceRisk = ClinicalQuestion(
  id: jaundiceRiskKey,
  group: 'jaundice_risk',
  question: 'Risk factors present (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    for (final r in JaundiceRisk.values) QuestionOption(r.name, r.label)
  ],
  sources: [jaundiceSource('risk_factors')],
);

final qJaundiceTsb = ClinicalQuestion(
  id: jaundiceTsbKey,
  group: 'jaundice_tsb',
  question: 'TSB value (if available)',
  type: QuestionType.decimal,
  min: 0,
  max: 40,
  unit: 'mg/dL',
  helper: 'Document serum bilirubin',
  sources: [jaundiceSource('start_pt')],
);

final qJaundiceCutoffResult = ClinicalQuestion(
  id: jaundiceCutoffResultKey,
  group: 'jaundice_tsb',
  question: 'Is TSB at or above the cut-off on your unit\'s chart?',
  type: QuestionType.singleChoice,
  options: const [
    QuestionOption('below', 'No: below the phototherapy cut-off'),
    QuestionOption('pt', 'Yes: at/above the phototherapy cut-off'),
    QuestionOption(
        'ebt', 'Yes: at/above the exchange blood transfusion (EBT) cut-off'),
    QuestionOption('pending', 'TSB result awaited'),
  ],
  helper: 'Age- and risk-specific chart of your unit. Not calculated by the '
      'app.',
  sources: [jaundiceSource('tsb_cutoff')],
);

final qJaundiceRepeatTsb = ClinicalQuestion(
  id: jaundiceRepeatTsbKey,
  group: 'jaundice_review',
  question: 'Repeat TSB under phototherapy (optional)',
  type: QuestionType.decimal,
  min: 0,
  max: 40,
  unit: 'mg/dL',
  helper: 'Hemolytic jaundice : 6 to 8 hourly during initial 24 to 48 hrs · '
      'Non-hemolytic jaundice : 12-24 hourly',
  stwRange: 'STW: stop phototherapy when TSB falls below 13-14 mg/dL or 2 '
      'mg/dL below cut-off',
  sources: [jaundiceSource('stop_pt')],
);

final qJaundiceCutoffValue = ClinicalQuestion(
  id: jaundiceCutoffValueKey,
  group: 'jaundice_review',
  question: 'Phototherapy cut-off from your unit\'s chart (optional)',
  type: QuestionType.decimal,
  min: 0,
  max: 40,
  unit: 'mg/dL',
  helper: 'Used only for "2 mg/dL below cut-off".',
  sources: [jaundiceSource('stop_pt')],
);

// ---------------------------------------------------------------------------
// Derived variables
// ---------------------------------------------------------------------------

Set<String> _set(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

KramerZone? _zone(VariableReader r) =>
    KramerZone.values.asNameMap()[r.valueOf(jaundiceKramerKey)];

bool _visibleNow(VariableReader r) {
  final k = r.valueOf(jaundiceKramerKey);
  return k != null && k != kramerNone;
}

Set<AbeSign> _abe(VariableReader r) =>
    {for (final s in _set(r.valueOf(jaundiceAbeKey))) AbeSign.values.byName(s)};

Set<PostureSign> _posture(VariableReader r) => {
      for (final s in _set(r.valueOf(jaundicePostureKey)))
        PostureSign.values.byName(s)
    };

num? _num(VariableReader r, String key) {
  final v = r.valueOf(key);
  return v is num ? v : null;
}

final jaundiceVariables = [
  ClinicalVariable(
    jaundiceAppliesKey,
    'STW applies: GA ≥35 weeks (or clinician-assessed when GA uncertain)',
    (r) => switch (r.valueOf(gaKnownKey)) {
      true => jaundiceStwApplies(gaWeeks: r.valueOf(gaWeeksKey) as int?),
      false => jaundiceStwApplies(
          clinicianSays35OrMore: r.valueOf(jaundiceGa35Key) as bool?),
      _ => null,
    },
  ),
  ClinicalVariable(
    jaundiceFirst24hKey,
    'Visible jaundice in first 24 hrs',
    (r) => jaundiceInFirst24h(
      visibleNow: _visibleNow(r),
      ageHours: r.valueOf(jaundiceAgeHoursKey) as int?,
      visibleBefore24h: r.valueOf(jaundiceBefore24hKey) as bool?,
    ),
  ),
  ClinicalVariable(
    jaundiceSeriousKey,
    'jaundice_rules isSeriousJaundice()',
    (r) => isSeriousJaundice(
      first24h: r.valueOf(jaundiceFirst24hKey) == true,
      zone: _zone(r),
      abe: _abe(r),
      posture: _posture(r),
    ),
  ),
  ClinicalVariable(
    jaundiceNeedsTsbKey,
    'jaundice_rules needsTsb()',
    (r) => needsTsb(
      first24h: r.valueOf(jaundiceFirst24hKey) == true,
      zone: _zone(r),
      unsureVisual: r.valueOf(jaundiceKramerKey) == kramerUnsure,
      tcb: _num(r, jaundiceTcbKey),
      nearCutoff: r.valueOf(jaundiceNearCutoffKey) == true,
    ),
  ),
  ClinicalVariable(
    jaundiceStopMetKey,
    'jaundice_rules meetsStopPhototherapy() on the repeat TSB',
    (r) {
      final tsb = _num(r, jaundiceRepeatTsbKey);
      return tsb == null
          ? null
          : meetsStopPhototherapy(
              tsb: tsb, cutoff: _num(r, jaundiceCutoffValueKey));
    },
  ),
];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

final _applies = const Var(jaundiceAppliesKey).eq(true);
final _serious = AllOf([_applies, const Var(jaundiceSeriousKey).eq(true)]);
final _assessed = AllOf([_applies, const Var(jaundiceKramerKey).exists()]);
final _tsbNeeded = AllOf([
  _applies,
  AnyOf([
    const Var(jaundiceSeriousKey).eq(true),
    const Var(jaundiceNeedsTsbKey).eq(true),
  ]),
]);
final _atOrAboveCutoff = AllOf([
  _tsbNeeded,
  const Var(jaundiceCutoffResultKey).isIn({'pt', 'ebt'})
]);
final _onPhototherapy = AnyOf([_serious, _atOrAboveCutoff]);
final _anyNeuroSign = AnyOf([
  for (final s in AbeSign.values) const Var(jaundiceAbeKey).contains(s.name),
  for (final s in PostureSign.values)
    const Var(jaundicePostureKey).contains(s.name),
]);

List<String> _seriousReasons(VariableReader r) => [
      if (r.valueOf(jaundiceFirst24hKey) == true)
        'Visible jaundice in first 24 hrs',
      if (_zone(r) == KramerZone.zone5) 'Yellow palms and soles',
      if (_abe(r).isNotEmpty)
        'Signs of ABE: ${_abe(r).map((s) => s.label).join(', ')}',
      if (_posture(r).isNotEmpty)
        'Abnormal posturing: ${_posture(r).map((s) => s.label).join(', ')}',
    ];

List<String> _tsbReasons(VariableReader r) {
  final zone = _zone(r);
  final tcb = _num(r, jaundiceTcbKey);
  return [
    if (r.valueOf(jaundiceFirst24hKey) == true) 'Jaundice in first 24 hrs',
    if (zone != null && zone.number >= 3)
      'Kramer zone ${zone.number} (${zone.label}): approx ${zone.approxTsb}',
    if (tcb != null && tcb > tsbVisualOrTcbThreshold) 'TcB $tcb mg/dL',
    if (r.valueOf(jaundiceNearCutoffKey) == true) 'Near PT cut-off',
    if (r.valueOf(jaundiceKramerKey) == kramerUnsure)
      'Unsure about visual assessment',
  ];
}

ClinicalRule _always(String id, String suffix,
        {String? title,
        FindingCategory category = FindingCategory.pathway,
        FindingLevel level = FindingLevel.info,
        Cond? when}) =>
    ClinicalRule(
      id: id,
      topic: _j,
      when: when ?? _applies,
      source: jaundiceSource(suffix),
      then: (_) => FindingContent(
        category: category,
        level: level,
        title: title ?? jaundiceHeadings['jaundice_$suffix']!,
        actions: _evidence(suffix),
      ),
    );

final jaundiceRules = <ClinicalRule>[
  ClinicalRule(
    id: jaundiceNotCoveredId,
    topic: _j,
    when: const Var(jaundiceAppliesKey).eq(false),
    source: jaundiceSource('scope'),
    then: (r) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.info,
      title: 'Not covered by this STW (infants ≥35 weeks only)',
      actions: const [
        'This STW covers neonatal jaundice in infants ≥ 35 weeks. No '
            'jaundice recommendation is made for this baby by the app.',
      ],
      why: [
        if (r.valueOf(gaWeeksKey) case final int ga)
          'GA $ga weeks'
        else
          'Clinician assessment: <35 weeks',
      ],
    ),
  ),
  ClinicalRule(
    id: jaundiceSeriousId,
    topic: _j,
    when: _serious,
    source: jaundiceSource('serious'),
    then: (r) => FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.urgent,
      title: 'Serious jaundice',
      why: _seriousReasons(r),
    ),
  ),
  ClinicalRule(
    id: jaundiceStartPtId,
    topic: _j,
    when: _serious,
    source: jaundiceSource('start_pt'),
    then: (_) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'Start Intensive Phototherapy',
      actions: _evidence('start_pt').skip(1).toList(),
    ),
  ),
  ClinicalRule(
    id: jaundiceEbtId,
    topic: _j,
    when: AllOf([
      _applies,
      AnyOf([_anyNeuroSign, const Var(jaundiceCutoffResultKey).eq('ebt')]),
    ]),
    source: jaundiceSource('optimal_ebt',
        needsClinicalReview: true,
        note: 'The STW lists abnormal posturing next to the ABE signs; the '
            'app treats both as indicating EBT preparation. EBT volume uses '
            'the recorded birth weight; recalculate with current weight.'),
    then: (r) {
      final bw = r.valueOf(birthWeightKey);
      return FindingContent(
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        title: 'Prepare for exchange blood transfusion (EBT)',
        actions: [
          ..._evidence('optimal_ebt'),
          if (bw is int)
            'Exchange volume: 2 × 80-100 mL/kg × ${bw / 1000} kg = '
                '${exchangeVolumeMl(bw).$1}-${exchangeVolumeMl(bw).$2} mL',
        ],
        why: [
          if (_abe(r).isNotEmpty || _posture(r).isNotEmpty)
            'Signs of ABE / abnormal posturing recorded',
          if (r.valueOf(jaundiceCutoffResultKey) == 'ebt')
            'TSB at/above the EBT cut-off on the unit chart',
        ],
      );
    },
  ),
  ClinicalRule(
    id: jaundiceNeedsTsbId,
    topic: _j,
    when: AllOf([
      _applies,
      Not(const Var(jaundiceSeriousKey).eq(true)),
      const Var(jaundiceNeedsTsbKey).eq(true),
    ]),
    source: jaundiceSource('needs_tsb',
        needsClinicalReview: true,
        note: 'The STW prints "more than 12-14 mg/dL"; the app counts Kramer '
            'zone 3 or above, or TcB >12 mg/dL.'),
    then: (r) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.action,
      title: 'TSB measurement required',
      actions: _evidence('tsb_cutoff'),
      why: _tsbReasons(r),
    ),
  ),
  ClinicalRule(
    id: jaundiceNoTsbId,
    topic: _j,
    when: AllOf([
      _assessed,
      Not(const Var(jaundiceSeriousKey).eq(true)),
      Not(const Var(jaundiceNeedsTsbKey).eq(true)),
    ]),
    source: jaundiceSource('continue_visual'),
    then: (_) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: 'No serious jaundice; TSB not required now',
      actions: [
        ..._evidence('continue_visual'),
        _evidence('kramer').first,
      ],
    ),
  ),
  ClinicalRule(
    id: jaundiceTsbAwaitedId,
    topic: _j,
    when: AllOf([_tsbNeeded, const Var(jaundiceCutoffResultKey).eq('pending')]),
    source: jaundiceSource('tsb_cutoff'),
    then: (_) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.action,
      title: 'TSB result awaited',
      actions: _evidence('tsb_cutoff'),
    ),
  ),
  ClinicalRule(
    id: jaundiceAboveCutoffId,
    topic: _j,
    when: _atOrAboveCutoff,
    source: jaundiceSource('above_cutoff'),
    then: (r) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: 'TSB at/above cut-off: phototherapy',
      actions: _evidence('above_cutoff'),
      why: [
        if (_num(r, jaundiceTsbKey) case final tsb?) 'TSB $tsb mg/dL',
        r.valueOf(jaundiceCutoffResultKey) == 'ebt'
            ? 'At/above the EBT cut-off on the unit chart'
            : 'At/above the phototherapy cut-off on the unit chart',
      ],
    ),
  ),
  _always(jaundiceInvestigationsId, 'investigation',
      title: 'Investigations to determine the cause',
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.action,
      when: _atOrAboveCutoff),
  ClinicalRule(
    id: jaundiceBelowCutoffId,
    topic: _j,
    when: AllOf([_tsbNeeded, const Var(jaundiceCutoffResultKey).eq('below')]),
    source: jaundiceSource('below_cutoff'),
    then: (_) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: 'TSB below cut-off: stop phototherapy (if started)',
      actions: [..._evidence('below_cutoff'), ..._evidence('continue_visual')],
    ),
  ),
  _always('jaundice.optimalPhototherapy', 'optimal_pt', when: _onPhototherapy),
  _always('jaundice.stopCriteria', 'stop_pt',
      title: 'When to stop phototherapy', when: _onPhototherapy),
  ClinicalRule(
    id: jaundiceStopMetId,
    topic: _j,
    when: AllOf([_onPhototherapy, const Var(jaundiceStopMetKey).eq(true)]),
    source: jaundiceSource('stop_pt',
        needsClinicalReview: true,
        note: 'The STW prints "below 13-14 mg/dL"; the app uses the lower '
            'end (13 mg/dL) so phototherapy is not stopped early.'),
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: 'Stop phototherapy criteria met',
      actions: [..._evidence('stop_pt'), ..._evidence('continue_visual')],
      why: [
        'Repeat TSB ${_num(r, jaundiceRepeatTsbKey)} mg/dL',
        if (_num(r, jaundiceCutoffValueKey) case final c?)
          'Unit chart cut-off $c mg/dL',
      ],
    ),
  ),
  ClinicalRule(
    id: jaundiceStopNotMetId,
    topic: _j,
    when: AllOf([_onPhototherapy, const Var(jaundiceStopMetKey).eq(false)]),
    source: jaundiceSource('optimal_pt'),
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'Stop criteria not met: continue phototherapy',
      actions: _evidence('optimal_pt').skip(6).toList(),
      why: ['Repeat TSB ${_num(r, jaundiceRepeatTsbKey)} mg/dL'],
    ),
  ),
  ClinicalRule(
    id: 'jaundice.riskFactors',
    topic: _j,
    when: AllOf([_applies, const Var(jaundiceRiskKey).exists()]),
    source: jaundiceSource('risk_factors'),
    then: (r) {
      final ticked = _set(r.valueOf(jaundiceRiskKey));
      return FindingContent(
        category: FindingCategory.assessment,
        level: FindingLevel.info,
        title:
            ticked.isEmpty ? 'No risk factor recorded' : 'Risk factors present',
        actions: [
          for (final f in JaundiceRisk.values)
            if (ticked.contains(f.name)) f.label,
        ],
      );
    },
  ),
  _always('jaundice.visualAssessment', 'visual',
      title: 'Visual assessment', when: _assessed),
  _always('jaundice.discharge', 'discharge',
      category: FindingCategory.followUp, when: _assessed),
  _always('jaundice.dos', 'dos', when: _assessed),
  _always('jaundice.donts', 'donts', when: _assessed),
  // The banner text is its own heading; avoid repeating it as the title.
  _always('jaundice.keyMessage', 'key_message',
      title: 'Key message', when: _assessed),
];

final jaundiceWorkflow = StwWorkflow(
  _j,
  source: const SourceReference.jaundice('Whole document (ICD-10 P59.9)'),
  groups: jaundiceGroups,
  uses: [
    const QuestionUse(qGaKnown, required: true),
    QuestionUse(qGaWeeks, required: true),
    QuestionUse(qJaundiceGa35, required: true),
    QuestionUse(qBirthWeight, when: _applies),
    QuestionUse(qJaundiceAgeHours, when: _applies, required: true),
    QuestionUse(qJaundiceBefore24h, when: _applies, required: true),
    QuestionUse(qJaundiceKramer, when: _applies, required: true),
    QuestionUse(qJaundiceTcb, when: _applies),
    QuestionUse(qJaundiceNearCutoff, when: _applies),
    QuestionUse(qJaundiceAbe, when: _applies),
    QuestionUse(qJaundicePosture, when: _applies),
    QuestionUse(qJaundiceRisk, when: _applies),
    QuestionUse(qJaundiceTsb, when: _tsbNeeded),
    QuestionUse(qJaundiceCutoffResult, when: _tsbNeeded, required: true),
    QuestionUse(qJaundiceRepeatTsb, when: _atOrAboveCutoff),
    QuestionUse(qJaundiceCutoffValue, when: _atOrAboveCutoff),
  ],
  variables: jaundiceVariables,
  rules: jaundiceRules,
);
