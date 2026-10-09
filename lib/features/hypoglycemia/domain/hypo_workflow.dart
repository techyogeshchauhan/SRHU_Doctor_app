/// Neonatal Hypoglycemia workflow for the dynamic assessment engine.
///
/// Pure Dart. Questions, derived variables and rules only; branching is done
/// by `hypo_rules.dart` and all wording comes from `hypo_content.dart`
/// (verbatim from the STW PDF flowchart).
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'hypo_content.dart';
import 'hypo_rules.dart';

const _hypo = NeonatalCondition.hypoglycemia;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const hypoRiskKey = 'hypo_risk';
const hypoBgKey = 'hypo_bg';
const hypoSymptomsKey = 'hypo_symptoms';
const hypoWeightKey = 'hypo_weight_g';
const hypoRecheckNowKey = 'hypo_recheck_now';
const hypoRecheckBgKey = 'hypo_recheck_bg';
const hypoSymptomsDevelopedKey = 'hypo_symptoms_developed';
const hypoIvNowKey = 'hypo_iv_now';
const hypoGirKey = 'hypo_gir';
const hypoIvBgKey = 'hypo_iv_bg';
const hypoEuglycemicKey = 'hypo_euglycemic_24h';
const hypoToleratingFeedsKey = 'hypo_tolerating_feeds';
const hypoPersistentKey = 'hypo_persistent_refractory';

// Derived variables
const hypoAtRiskKey = 'hypo_at_risk';
const hypoBranchKey = 'hypo_branch';
const hypoRecheckOutcomeKey = 'hypo_recheck_outcome';
const hypoOnIvKey = 'hypo_on_iv';
const hypoIvOutcomeKey = 'hypo_iv_outcome';
const hypoNextGirKey = 'hypo_next_gir';

// Findings
const hypoAtRiskId = 'hypo.atRisk';
const hypoNoRiskId = 'hypo.noRisk';
const hypoNotTriggeredId = 'hypo.notTriggered';
const hypoLowId = 'hypo.low';
const hypoFeedingId = 'hypo.supervisedFeeding';
const hypoIvGlucoseId = 'hypo.ivGlucose';
const hypoBolusVolumeId = 'hypo.bolusVolume';
const hypoRecheckOkId = 'hypo.recheck.continueFeeds';
const hypoRecheckIvId = 'hypo.recheck.startIv';
const hypoPracticalId = 'hypo.practicalPoints';
const hypoIncreaseGirId = 'hypo.iv.increaseGir';
const hypoMaxGirId = 'hypo.iv.maxGir';
const hypoGirAboveMaxId = 'hypo.iv.girAboveMax';
const hypoReferId = 'hypo.refer';
const hypoDrugsId = 'hypo.refractoryDrugs';
const hypoAwaitEuglycemiaId = 'hypo.iv.awaitEuglycemia';
const hypoWeanId = 'hypo.iv.wean';
const hypoStopIvId = 'hypo.iv.stop';
const hypoStopNotYetId = 'hypo.iv.stopNotYet';
const hypoGirBelowId = 'hypo.iv.girBelowStw';
const hypoNeuroFollowUpId = 'hypo.neuroFollowUp';

// ---------------------------------------------------------------------------
// Sources (PDF box headings; region ids in assets/regions/regions.json)
// ---------------------------------------------------------------------------

const _srcWhom = SourceReference.hypo(
  'WHOM TO SCREEN FOR HYPOGLYCEMIA',
  regionId: 'hypo_whom_to_screen',
);
const _srcSchedule = SourceReference.hypo(
  'SCHEDULE OF BLOOD GLUCOSE MONITORING',
  regionId: 'hypo_monitoring_schedule',
);
const _srcHowToMonitor = SourceReference.hypo(
  'HOW TO MONITOR BLOOD GLUCOSE (BG)',
  regionId: 'hypo_how_to_monitor',
);
const _srcSymptoms = SourceReference.hypo(
  'LOOK FOR THE FOLLOWING SYMPTOMS AND SIGNS',
  regionId: 'hypo_symptoms',
);
const _srcAsymptomatic = SourceReference.hypo(
  'ASYMPTOMATIC & BG ≥25 mg/dL',
  regionId: 'hypo_asymptomatic_branch',
);
const _srcRecheck1h = SourceReference.hypo(
  'RE-CHECK BG AFTER 1 HOUR',
  regionId: 'hypo_recheck_1h',
);
const _srcSymptomatic = SourceReference.hypo(
  'SYMPTOMATIC OR BG < 25 mg/dL',
  regionId: 'hypo_symptomatic_branch',
);
const _srcRecheck30 = SourceReference.hypo(
  'Flowchart: re-check BG every 30 min',
  regionId: 'hypo_recheck_30min',
);
const _srcIncreaseGir = SourceReference.hypo(
  'Flowchart: BG < 45 mg/dL → increase GIR',
  regionId: 'hypo_increase_gir',
);
const _srcPersistent = SourceReference.hypo(
  'Flowchart: persistent or refractory hypoglycemia',
  regionId: 'hypo_persistent_refractory',
  needsClinicalReview: true,
  note: 'Ranges ">3-7 days" and ">10-12 mg/kg/min" are recorded by the '
      'clinician as printed; the app does not pick a cut-off (open question '
      'H5).',
);
const _srcWean = SourceReference.hypo(
  'Flowchart: BG ≥ 45 mg/dL → euglycemic for 24 hours → reduce GIR',
  regionId: 'hypo_euglycemic_wean',
);
const _srcStop = SourceReference.hypo(
  'Flowchart: stop IV fluids',
  regionId: 'hypo_stop_iv',
);
const _srcPractical = SourceReference.hypo(
  'PRACTICAL POINTS',
  regionId: 'hypo_practical_points',
);
const _srcNeuro = SourceReference.hypo(
  'Follow-up banner',
  regionId: 'hypo_neuro_followup',
  needsClinicalReview: true,
  note: '"Severe" and "recurrent" are not defined in the STW; the app shows '
      'this when symptoms were recorded or persistent hypoglycemia is '
      'ticked (open question H7).',
);

// ---------------------------------------------------------------------------
// Questions (wording from the STW)
// ---------------------------------------------------------------------------

const hypoGroups = [
  QuestionGroup(
    'hypo_screen',
    'Whom to screen for hypoglycemia',
    subtitle: 'Tick all that apply (none = no listed risk factor)',
  ),
  QuestionGroup(
    'hypo_bg',
    'Blood glucose',
    subtitle: 'Point-of-care glucometer. BG should be measured pre-feeding.',
    questionOrder: [hypoBgKey, hypoSymptomsKey, hypoWeightKey],
  ),
  QuestionGroup(
    'hypo_recheck',
    'Re-check BG after 1 hour',
    questionOrder: [
      hypoRecheckNowKey,
      hypoRecheckBgKey,
      hypoSymptomsDevelopedKey,
    ],
  ),
  QuestionGroup(
    'hypo_iv',
    'On IV glucose infusion',
    subtitle: 'Re-check BG every 30 min until 2 consecutive values are '
        '≥45 mg/dL, then every 6 h',
    questionOrder: [
      hypoIvNowKey,
      hypoGirKey,
      hypoIvBgKey,
      hypoPersistentKey,
      hypoEuglycemicKey,
      hypoToleratingFeedsKey,
    ],
  ),
];

final qHypoRisk = ClinicalQuestion(
  id: hypoRiskKey,
  group: 'hypo_screen',
  question: 'Risk factors present',
  type: QuestionType.multipleChoice,
  options: [for (final r in HypoRisk.values) QuestionOption(r.name, r.label)],
  helper: 'SGA/LGA: as per INTERGROWTH-21st standards (assessed by the '
      'clinician; not computed by the app)',
  sources: const [_srcWhom],
);

const qHypoBg = ClinicalQuestion(
  id: hypoBgKey,
  group: 'hypo_bg',
  question: 'Blood glucose (BG)',
  type: QuestionType.numeric,
  min: 0,
  max: 600,
  unit: 'mg/dL',
  helper: 'Leave blank if not measured yet',
  sources: [_srcHowToMonitor, _srcSchedule],
);

final qHypoSymptoms = ClinicalQuestion(
  id: hypoSymptomsKey,
  group: 'hypo_bg',
  question: 'Look for the following symptoms and signs (tick all present; '
      'none = asymptomatic)',
  type: QuestionType.multipleChoice,
  options: [
    for (final s in HypoSymptom.values) QuestionOption(s.name, s.label),
  ],
  sources: const [_srcSymptoms],
);

const qHypoWeight = ClinicalQuestion(
  id: hypoWeightKey,
  group: 'hypo_bg',
  question: 'Current weight (optional)',
  type: QuestionType.numeric,
  min: 300,
  max: 6000,
  unit: 'g',
  helper: 'Only used to show the 2 ml/kg bolus volume if an IV bolus is '
      'indicated',
  sources: [
    SourceReference.hypo(
      'SYMPTOMATIC OR BG < 25 mg/dL',
      regionId: 'hypo_symptomatic_branch',
      needsClinicalReview: true,
      note: 'App multiplies the STW per-kg value by the weight (open '
          'question H8).',
    ),
  ],
);

const qHypoRecheckNow = ClinicalQuestion(
  id: hypoRecheckNowKey,
  group: 'hypo_recheck',
  question: 'Record the 1-hour re-check BG now?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes — record the re-check'),
    QuestionOption(false, 'Not now — initial assessment only'),
  ],
  sources: [
    SourceReference.dataEntry(
        'STW flowchart: RE-CHECK BG AFTER 1 HOUR; this only chooses whether '
        'the re-check is being recorded now.'),
  ],
);

const qHypoRecheckBg = ClinicalQuestion(
  id: hypoRecheckBgKey,
  group: 'hypo_recheck',
  question: 'BG at 1-hour re-check',
  type: QuestionType.numeric,
  min: 0,
  max: 600,
  unit: 'mg/dL',
  sources: [_srcRecheck1h],
);

const qHypoSymptomsDeveloped = ClinicalQuestion(
  id: hypoSymptomsDevelopedKey,
  group: 'hypo_recheck',
  question: 'Symptoms develop',
  type: QuestionType.boolean,
  sources: [_srcRecheck1h, _srcSymptoms],
);

const qHypoIvNow = ClinicalQuestion(
  id: hypoIvNowKey,
  group: 'hypo_iv',
  question: 'Record a BG re-check on IV glucose now?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes — record a re-check'),
    QuestionOption(false, 'Not now — initial plan only'),
  ],
  sources: [
    SourceReference.dataEntry(
        'STW flowchart: re-check BG every 30 min; this only chooses whether '
        'a re-check is being recorded now.'),
  ],
);

const qHypoGir = ClinicalQuestion(
  id: hypoGirKey,
  group: 'hypo_iv',
  question: 'Current GIR',
  type: QuestionType.numeric,
  min: 1,
  max: 20,
  unit: 'mg/kg/min',
  helper: 'GIR calculation: see the QR code in the STW PDF',
  sources: [_srcSymptomatic, _srcIncreaseGir, _srcWean],
);

const qHypoIvBg = ClinicalQuestion(
  id: hypoIvBgKey,
  group: 'hypo_iv',
  question: 'Latest re-check BG',
  type: QuestionType.numeric,
  min: 0,
  max: 600,
  unit: 'mg/dL',
  sources: [_srcRecheck30],
);

const qHypoPersistent = ClinicalQuestion(
  id: hypoPersistentKey,
  group: 'hypo_iv',
  question: hypoPersistentRefractory,
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('persistent', hypoPersistent),
    QuestionOption('refractory', hypoRefractory),
  ],
  sources: [_srcPersistent],
);

const qHypoEuglycemic = ClinicalQuestion(
  id: hypoEuglycemicKey,
  group: 'hypo_iv',
  question: hypoEuglycemic24h,
  type: QuestionType.boolean,
  sources: [_srcWean],
);

const qHypoToleratingFeeds = ClinicalQuestion(
  id: hypoToleratingFeedsKey,
  group: 'hypo_iv',
  question: 'Tolerating adequate enteral feeds',
  type: QuestionType.boolean,
  sources: [_srcStop],
);

// ---------------------------------------------------------------------------
// Derived variables
// ---------------------------------------------------------------------------

Set<String> _set(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

int? _int(VariableReader r, String key) => r.valueOf(key) as int?;

final hypoVariables = [
  ClinicalVariable(hypoAtRiskKey, 'Any WHOM TO SCREEN item ticked', (r) {
    final v = r.valueOf(hypoRiskKey);
    return v is Set ? v.isNotEmpty : null;
  }),
  ClinicalVariable(hypoBranchKey, 'hypo_rules hypoBranch()', (r) {
    final s = r.valueOf(hypoSymptomsKey);
    return hypoBranch(
      _int(r, hypoBgKey),
      s is Set ? {for (final x in _set(s)) HypoSymptom.values.byName(x)} : null,
    )?.name;
  }),
  ClinicalVariable(
    hypoRecheckOutcomeKey,
    'hypo_rules hypoRecheckOutcome()',
    (r) => r.valueOf(hypoBranchKey) == HypoBranch.supervisedFeeding.name &&
            r.valueOf(hypoRecheckNowKey) == true
        ? hypoRecheckOutcome(
            _int(r, hypoRecheckBgKey),
            r.valueOf(hypoSymptomsDevelopedKey) as bool?,
          )?.name
        : null,
  ),
  ClinicalVariable(
    hypoOnIvKey,
    'IV glucose started (symptomatic/BG <25, or after the 1-hour re-check)',
    (r) =>
        r.valueOf(hypoBranchKey) == HypoBranch.ivGlucose.name ||
        r.valueOf(hypoRecheckOutcomeKey) ==
            HypoRecheckOutcome.startIvInfusion.name,
  ),
  ClinicalVariable(
    hypoIvOutcomeKey,
    'hypo_rules hypoIvOutcome()',
    (r) => r.valueOf(hypoOnIvKey) == true && r.valueOf(hypoIvNowKey) == true
        ? hypoIvOutcome(
            gir: _int(r, hypoGirKey),
            bg: _int(r, hypoIvBgKey),
            euglycemic24h: r.valueOf(hypoEuglycemicKey) as bool?,
            toleratingFeeds: r.valueOf(hypoToleratingFeedsKey) as bool?,
          )?.name
        : null,
  ),
  ClinicalVariable(hypoNextGirKey, 'GIR + 2, maximum 12', (r) {
    final gir = _int(r, hypoGirKey);
    return r.valueOf(hypoIvOutcomeKey) == HypoIvOutcome.increaseGir.name &&
            gir != null
        ? hypoIncreasedGir(gir)
        : null;
  }),
];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

Cond _branch(HypoBranch b) => const Var(hypoBranchKey).eq(b.name);
Cond _iv(HypoIvOutcome o) => const Var(hypoIvOutcomeKey).eq(o.name);

final _symptomatic = AnyOf([
  for (final s in HypoSymptom.values) const Var(hypoSymptomsKey).contains(s.name),
]);
final _persistentOrRefractory = AnyOf([
  const Var(hypoPersistentKey).contains('persistent'),
  const Var(hypoPersistentKey).contains('refractory'),
]);

final hypoRules = <ClinicalRule>[
  ClinicalRule(
    id: hypoAtRiskId,
    topic: _hypo,
    when: const Var(hypoAtRiskKey).eq(true),
    source: _srcWhom,
    then: (r) {
      final ticked = _set(r.valueOf(hypoRiskKey));
      return FindingContent(
        category: FindingCategory.screening,
        level: FindingLevel.action,
        title: 'At-risk infant — screen for hypoglycemia',
        actions: [
          hypoScheduleAtRisk,
          if (ticked.contains(HypoRisk.idm.name)) hypoScheduleIdm,
          hypoScheduleIv,
          hypoSchedulePreFeed,
          hypoMonitorGlucometer,
        ],
        why: [
          for (final x in HypoRisk.values)
            if (ticked.contains(x.name)) x.label,
        ],
      );
    },
  ),
  ClinicalRule(
    id: hypoNoRiskId,
    topic: _hypo,
    when: const Var(hypoAtRiskKey).eq(false),
    source: const SourceReference.hypo(
      'WHOM TO SCREEN FOR HYPOGLYCEMIA',
      regionId: 'hypo_whom_to_screen',
      needsClinicalReview: true,
      note: 'Shown when no listed risk factor is ticked; the STW line is '
          'about healthy term AGA neonates (open question H1).',
    ),
    then: (_) => const FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.ok,
      title: 'No listed risk factor recorded',
      actions: [hypoRoutineNotRequired],
    ),
  ),
  ClinicalRule(
    id: hypoNotTriggeredId,
    topic: _hypo,
    when: _branch(HypoBranch.notTriggered),
    source: const SourceReference.hypo(
      'Flowchart entry: BLOOD GLUCOSE <45 mg/dL',
      regionId: 'hypo_flowchart_entry',
      needsClinicalReview: true,
      note: 'The STW gives no action for BG ≥45 mg/dL outside the monitoring '
          'schedule (open question H2).',
    ),
    then: (r) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.ok,
      title: 'BG ≥45 mg/dL — hypoglycemia flowchart not triggered',
      actions: [
        if (r.valueOf(hypoAtRiskKey) == true) hypoScheduleAtRisk,
      ],
      why: ['BG ${r.valueOf(hypoBgKey)} mg/dL; flowchart entry: $hypoEntry'],
    ),
  ),
  ClinicalRule(
    id: hypoLowId,
    topic: _hypo,
    when: const Var(hypoBgKey).lt(hypoThresholdMgDl),
    source: _srcHowToMonitor,
    then: (r) => FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.urgent,
      title: hypoEntry,
      actions: const [hypoMonitorLab, hypoMonitorNoDelay],
      why: ['BG ${r.valueOf(hypoBgKey)} mg/dL'],
    ),
  ),
  ClinicalRule(
    id: hypoFeedingId,
    topic: _hypo,
    when: _branch(HypoBranch.supervisedFeeding),
    source: _srcAsymptomatic,
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: hypoAsymptomaticTitle,
      actions: const [hypoSupervisedFeeding, hypoFeedHow, hypoRecheck1h],
      why: ['Asymptomatic; BG ${r.valueOf(hypoBgKey)} mg/dL'],
    ),
  ),
  ClinicalRule(
    id: hypoIvGlucoseId,
    topic: _hypo,
    when: _branch(HypoBranch.ivGlucose),
    source: _srcSymptomatic,
    then: (r) {
      final symptoms = _set(r.valueOf(hypoSymptomsKey));
      return FindingContent(
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        title: hypoSymptomaticTitle,
        actions: const [hypoBolus, hypoStartInfusion, hypoRecheck30],
        why: [
          for (final s in HypoSymptom.values)
            if (symptoms.contains(s.name)) 'Symptom: ${s.label}',
          if ((r.valueOf(hypoBgKey) as int) < hypoSevereThresholdMgDl)
            'BG ${r.valueOf(hypoBgKey)} mg/dL (< 25 mg/dL)',
        ],
      );
    },
  ),
  ClinicalRule(
    id: hypoBolusVolumeId,
    topic: _hypo,
    when: AllOf([
      _branch(HypoBranch.ivGlucose),
      const Var(hypoWeightKey).exists(),
    ]),
    source: const SourceReference.hypo(
      'SYMPTOMATIC OR BG < 25 mg/dL',
      regionId: 'hypo_symptomatic_branch',
      needsClinicalReview: true,
      note: 'Weight × 2 ml/kg computed by the app; requires clinician '
          'sign-off before release (open question H8).',
    ),
    then: (r) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: 'IV bolus volume (2 ml/kg)',
      actions: [hypoBolusVolumeText(r.valueOf(hypoWeightKey)! as int)],
      why: const [hypoBolus],
    ),
  ),
  ClinicalRule(
    id: hypoRecheckOkId,
    topic: _hypo,
    when: const Var(hypoRecheckOutcomeKey)
        .eq(HypoRecheckOutcome.continueFeeds.name),
    source: _srcRecheck1h,
    then: (r) => FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.ok,
      title: hypoRecheckOkTitle,
      actions: const [hypoContinueFeeds, hypoContinueMonitoring],
      why: ['1-hour re-check BG ${r.valueOf(hypoRecheckBgKey)} mg/dL; no '
          'symptoms developed'],
    ),
  ),
  ClinicalRule(
    id: hypoRecheckIvId,
    topic: _hypo,
    when: const Var(hypoRecheckOutcomeKey)
        .eq(HypoRecheckOutcome.startIvInfusion.name),
    source: const SourceReference.hypo(
      'RE-CHECK BG AFTER 1 HOUR',
      regionId: 'hypo_recheck_1h',
      needsClinicalReview: true,
      note: 'This branch leads to the 30-min re-check box; the STW states no '
          'bolus or starting GIR for it (open question H3).',
    ),
    then: (r) {
      final bg = r.valueOf(hypoRecheckBgKey)! as int;
      return FindingContent(
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        title: 'Start IV glucose infusion',
        actions: const [hypoRecheck30],
        why: [
          if (bg < hypoThresholdMgDl) 'BG < 45 mg/dL ($bg mg/dL at 1 hour)',
          if (r.valueOf(hypoSymptomsDevelopedKey) == true)
            hypoStartIvIfSymptoms,
        ],
      );
    },
  ),
  ClinicalRule(
    id: hypoPracticalId,
    topic: _hypo,
    when: const Var(hypoOnIvKey).eq(true),
    source: _srcPractical,
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.info,
      title: 'PRACTICAL POINTS',
      actions: hypoPracticalPoints,
    ),
  ),
  ClinicalRule(
    id: hypoIncreaseGirId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.increaseGir),
    source: _srcIncreaseGir,
    then: (r) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.urgent,
      title: 'BG < 45 mg/dL on IV glucose — increase GIR',
      actions: [
        hypoIncreaseGir,
        'GIR ${r.valueOf(hypoGirKey)} → ${r.valueOf(hypoNextGirKey)} '
            'mg/kg/min',
        hypoRecheck30,
      ],
      why: ['Latest BG ${r.valueOf(hypoIvBgKey)} mg/dL'],
    ),
  ),
  ClinicalRule(
    id: hypoMaxGirId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.maxGirReached),
    source: _srcIncreaseGir,
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'BG < 45 mg/dL at the maximum GIR (12 mg/kg/min)',
      actions: const [hypoIncreaseGir, hypoPersistentRefractory],
      why: [
        'Current GIR ${r.valueOf(hypoGirKey)} mg/kg/min; latest BG '
            '${r.valueOf(hypoIvBgKey)} mg/dL',
      ],
    ),
  ),
  ClinicalRule(
    id: hypoGirAboveMaxId,
    topic: _hypo,
    when: AllOf([
      const Var(hypoOnIvKey).eq(true),
      const Var(hypoGirKey).gt(hypoMaxGir),
    ]),
    source: _srcIncreaseGir,
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'GIR above the STW maximum',
      actions: const ['STW: maximum 12 mg/kg/min'],
      why: ['Current GIR ${r.valueOf(hypoGirKey)} mg/kg/min'],
    ),
  ),
  ClinicalRule(
    id: hypoReferId,
    topic: _hypo,
    when: _persistentOrRefractory,
    source: _srcPersistent,
    then: (r) {
      final ticked = _set(r.valueOf(hypoPersistentKey));
      return FindingContent(
        category: FindingCategory.referral,
        level: FindingLevel.urgent,
        title: hypoConsiderRefer,
        why: [
          if (ticked.contains('persistent')) hypoPersistent,
          if (ticked.contains('refractory')) hypoRefractory,
        ],
      );
    },
  ),
  ClinicalRule(
    id: hypoDrugsId,
    topic: _hypo,
    when: _persistentOrRefractory,
    source: const SourceReference.hypo(
      'DRUGS FOR REFRACTORY HYPOGLYCEMIA',
      regionId: 'hypo_drugs_refractory',
      needsClinicalReview: true,
      note: 'The flowchart arrow leads here from the persistent/refractory '
          'box; the box title says refractory (open question H6).',
    ),
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: hypoDrugsTitle,
      actions: [hypoHydrocortisone, hypoAdditionalDrugs],
    ),
  ),
  ClinicalRule(
    id: hypoAwaitEuglycemiaId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.awaitEuglycemia24h),
    source: _srcWean,
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: 'BG ≥ 45 mg/dL on IV glucose',
      actions: const [
        hypoRecheck30,
        'After: $hypoEuglycemic24h → $hypoReduceGir',
      ],
      why: ['Latest BG ${r.valueOf(hypoIvBgKey)} mg/dL; not yet euglycemic '
          'for 24 hours on IV fluids'],
    ),
  ),
  ClinicalRule(
    id: hypoWeanId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.wean),
    source: _srcWean,
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: hypoEuglycemic24h,
      actions: const [
        hypoReduceGir,
        hypoIncreaseOralFeeds,
        hypoMonitor6h,
        hypoStopIv,
      ],
      why: ['Current GIR ${r.valueOf(hypoGirKey)} mg/kg/min'],
    ),
  ),
  ClinicalRule(
    id: hypoStopIvId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.stopIv),
    source: _srcStop,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.ok,
      title: 'Stop IV fluids',
      why: [hypoStopIv],
    ),
  ),
  ClinicalRule(
    id: hypoStopNotYetId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.stopCriteriaNotMet),
    source: _srcStop,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: 'Stop criteria not yet met',
      actions: [hypoStopIv, hypoIncreaseOralFeeds, hypoMonitor6h],
      why: ['On GIR 4 mg/kg/min; not yet tolerating adequate enteral feeds'],
    ),
  ),
  ClinicalRule(
    id: hypoGirBelowId,
    topic: _hypo,
    when: _iv(HypoIvOutcome.girBelowStw),
    source: const SourceReference.hypo(
      'Flowchart: stop IV fluids',
      regionId: 'hypo_stop_iv',
      needsClinicalReview: true,
      note: 'The STW stops IV fluids "on GIR 4 mg/kg/min"; a GIR below 4 is '
          'not addressed (open question H4).',
    ),
    then: (r) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.action,
      title: 'GIR below 4 mg/kg/min — not addressed by the STW',
      actions: const [hypoStopIv],
      why: ['Current GIR ${r.valueOf(hypoGirKey)} mg/kg/min'],
    ),
  ),
  ClinicalRule(
    id: hypoNeuroFollowUpId,
    topic: _hypo,
    when: AnyOf([
      AllOf([const Var(hypoBgKey).lt(hypoThresholdMgDl), _symptomatic]),
      const Var(hypoSymptomsDevelopedKey).eq(true),
      const Var(hypoPersistentKey).contains('persistent'),
    ]),
    source: _srcNeuro,
    then: (_) => const FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.action,
      title: 'Structured neurodevelopmental follow-up',
      actions: [hypoNeuroFollowUp],
    ),
  ),
];

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

final _low = const Var(hypoBgKey).lt(hypoThresholdMgDl);
final _feeding = _branch(HypoBranch.supervisedFeeding);
final _recording1h = AllOf([_feeding, const Var(hypoRecheckNowKey).eq(true)]);
final _onIv = const Var(hypoOnIvKey).eq(true);
final _recordingIv = AllOf([_onIv, const Var(hypoIvNowKey).eq(true)]);
final _ivBgLow = AllOf([_recordingIv, const Var(hypoIvBgKey).lt(45)]);
final _ivBgOk = AllOf([_recordingIv, const Var(hypoIvBgKey).ge(45)]);

final hypoWorkflow = StwWorkflow(
  _hypo,
  source: const SourceReference.hypo('Whole document (ICD-11 KB60.4)'),
  groups: hypoGroups,
  uses: [
    QuestionUse(qHypoRisk),
    const QuestionUse(qHypoBg),
    QuestionUse(qHypoSymptoms, when: _low),
    // Same page as BG/symptoms, so shown for any BG <45 (the bolus volume
    // finding itself only appears on the IV branch).
    QuestionUse(qHypoWeight, when: _low),
    QuestionUse(qHypoRecheckNow, when: _feeding, required: true),
    QuestionUse(qHypoRecheckBg, when: _recording1h, required: true),
    QuestionUse(qHypoSymptomsDeveloped, when: _recording1h),
    QuestionUse(qHypoIvNow, when: _onIv, required: true),
    QuestionUse(qHypoGir, when: _recordingIv, required: true),
    QuestionUse(qHypoIvBg, when: _recordingIv, required: true),
    QuestionUse(qHypoPersistent, when: _ivBgLow),
    QuestionUse(qHypoEuglycemic, when: _ivBgOk),
    QuestionUse(
      qHypoToleratingFeeds,
      when: AllOf([_ivBgOk, const Var(hypoEuglycemicKey).eq(true)]),
    ),
  ],
  variables: hypoVariables,
  rules: hypoRules,
  subjectLabel: 'Neonate',
  subjectLine: (r) {
    final bg = r.valueOf(hypoBgKey);
    return bg == null ? 'BG not recorded' : 'BG $bg mg/dL';
  },
);
