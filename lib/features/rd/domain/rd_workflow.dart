/// Respiratory Distress workflow for the dynamic assessment engine.
///
/// Pure Dart. Questions, derived variables and rules only; every clinical
/// decision is delegated to the existing validated engine in `rd_rules.dart`
/// and `sas.dart` (initialPlan, reassess, RdSeverity). Section numbers refer
/// to docs/STW_APP_SPEC_FROM_PDFs.md.
library;

import '../../../content/stw_content.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'rd_rules.dart';
import 'sas.dart';

const _rd = NeonatalCondition.respiratoryDistress;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const rdRrKey = 'rd_rr';
const rdSignsKey = 'rd_signs';
const rdIvFlagsKey = 'rd_iv_flags';
const rdReassessNowKey = 'rd_reassess_now';
const rdSupportKey = 'rd_support';
const rdPeepKey = 'rd_peep';
const rdFio2Key = 'rd_fio2_pct';
const rdSpo2Key = 'rd_spo2';
const rdComfortableKey = 'rd_comfortable';
const rdWarningsKey = 'rd_warnings';
const rdSepsisKey = 'rd_sepsis';

/// Repeat-SAS totals of recorded reassessments (oldest first).
const rdSasHistoryKey = 'rd_sas_history';

String rdSasKey(SasItem i) => 'rd_sas_${i.assetKey}';
String rdReSasKey(SasItem i) => 'rd_resas_${i.assetKey}';

// Derived variables
const rdSignsEffectiveKey = 'rd_signs_effective';
const rdGestationKey = 'rd_gestation';
const rdSasScoreKey = 'rd_sas';
const rdSasTotalKey = 'rd_sas_total';
const rdSeverityKey = 'rd_severity';
const rdInitialKey = 'rd_initial';
const rdPlanReadyKey = 'rd_plan_ready';
const rdIvIndicatedKey = 'rd_iv_indicated';
const rdReSasScoreKey = 'rd_resas';
const rdPrevSasTotalKey = 'rd_prev_sas_total';
const rdReassessKey = 'rd_reassess';
const rdReassessStatusKey = 'rd_reassess_status';
const rdReassessAlertsKey = 'rd_reassess_alerts';

// Findings
const rdPresentId = 'rd.present';
const rdNotMetId = 'rd.notMet';
const rdImmediateId = 'rd.immediate';
const rdSeverityId = 'rd.severity';
const rdInitialPlanId = 'rd.initialPlan';
const rdIvFluidsId = 'rd.ivFluids';
const rdAvoidId = 'rd.avoid';
const rdPlanPendingId = 'rd.planPending';
const rdReassessAlertsId = 'rd.reassess.alerts';
String rdReassessId(ReassessStatus s) => 'rd.reassess.${s.name}';

// ---------------------------------------------------------------------------
// Questions (wording as in the existing RD screens / STW)
// ---------------------------------------------------------------------------

/// STW §1.4: the figure credit must be shown with the SAS drawings.
const sasFigureCredit =
    'The Silverman score for assessing the magnitude of respiratory '
    'distress. (From Avery, M.E., and Fletcher, B.D.: The Lung and Its '
    'Disorders in the Newborn. Philadelphia, W.B. Saunders Company, 1974) '
    '(Courtesy of W.A. Silverman).';

const rdGroups = [
  babyGroup,
  QuestionGroup(
    'rd_signs',
    'Signs of respiratory distress',
    subtitle: 'Presence of ANY ONE',
  ),
  QuestionGroup(
    'rd_sas',
    'Silverman-Andersen Score',
    subtitle: 'Select one grade per item',
    footnote: sasFigureCredit,
  ),
  QuestionGroup(
    'rd_other',
    'Other findings',
    subtitle: 'Decide IV fluids vs enteral feeds',
  ),
  QuestionGroup('rd_reassess_gate', 'Reassessment'),
  QuestionGroup('rd_support', 'Current support & oxygenation'),
  QuestionGroup(
    'rd_resas',
    'Repeat SAS',
    subtitle: 'Compared with the previous SAS',
    footnote: sasFigureCredit,
  ),
  QuestionGroup('rd_warnings', 'Warning signs'),
  QuestionGroup(
    'rd_sepsis',
    'Sepsis triggers',
    subtitle: 'Any one → consider sepsis',
  ),
];

const _srcDefinition =
    SourceReference.rd('§1.1 Definition: RD present if ANY ONE');
const _srcSas = SourceReference.rd(
    '§1.4 Silverman-Andersen Score (Avery & Fletcher, 1974)');

const qRdRr = ClinicalQuestion(
  id: rdRrKey,
  group: 'rd_signs',
  question: 'Respiratory rate (optional)',
  type: QuestionType.numeric,
  min: 0,
  max: 150,
  unit: '/min',
  helper: 'If entered, "RR >60/min" is taken from this value',
  sources: [_srcDefinition],
);

final qRdSigns = ClinicalQuestion(
  id: rdSignsKey,
  group: 'rd_signs',
  question: 'Signs present (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [for (final s in RdSign.values) QuestionOption(s.name, s.label)],
  sources: const [_srcDefinition],
);

ClinicalQuestion _sasQuestion(SasItem item, {required bool repeat}) =>
    ClinicalQuestion(
      id: repeat ? rdReSasKey(item) : rdSasKey(item),
      group: repeat ? 'rd_resas' : 'rd_sas',
      question: item.title,
      type: QuestionType.singleChoice,
      options: [
        for (var g = 0; g <= 2; g++)
          QuestionOption(
            g,
            '$g · ${item.gradeLabels[g]}',
            image: item.imageAsset(g),
          ),
      ],
      sources: const [_srcSas],
    );

final rdSasQuestions = [
  for (final i in SasItem.values) _sasQuestion(i, repeat: false),
];
final rdReSasQuestions = [
  for (final i in SasItem.values) _sasQuestion(i, repeat: true),
];

const qRdIvFlags = ClinicalQuestion(
  id: rdIvFlagsKey,
  group: 'rd_other',
  question: 'Other findings (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('severe', 'Severe distress (clinician judgement)'),
    QuestionOption('apnea', 'Recurrent apnea'),
    QuestionOption('perfusion', 'Poor perfusion (e.g. prolonged CRT)'),
    QuestionOption('abdomen', 'Abdominal signs'),
  ],
  sources: [
    SourceReference.rd(
      '§1.2 IV fluids if severe distress, recurrent apnea, poor perfusion, '
      'or abdominal signs',
      needsClinicalReview: true,
      note: 'STW defines no SAS cut-off for "severe"; clinician judgement '
          '(open point 6.2).',
    ),
  ],
);

const qRdReassessNow = ClinicalQuestion(
  id: rdReassessNowKey,
  group: 'rd_reassess_gate',
  question: 'Record a reassessment now?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(
      true,
      'Yes — record a reassessment',
      subtitle: 'After starting respiratory support',
    ),
    QuestionOption(false, 'Not now — initial assessment only'),
  ],
  sources: [
    SourceReference.dataEntry(
        'STW §1.5 says "reassess frequently"; this only chooses whether a '
        'reassessment is being recorded now.'),
  ],
);

const qRdSupport = ClinicalQuestion(
  id: rdSupportKey,
  group: 'rd_support',
  question: 'Current respiratory support',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption('cpap', 'CPAP'),
    QuestionOption('nasalO2', 'Nasal-prong O₂', subtitle: '0.5–1 L/min'),
    QuestionOption('none', 'Off respiratory support',
        subtitle: 'After weaning'),
  ],
  sources: [SourceReference.rd('§1.5 Algorithm; §1.7 Improving (weaning)')],
);

final _onCpap = const Var(rdSupportKey).eq('cpap');

final qRdPeep = ClinicalQuestion(
  id: rdPeepKey,
  group: 'rd_support',
  question: 'PEEP',
  type: QuestionType.numeric,
  min: peepMin,
  max: peepMax,
  unit: 'cm H₂O',
  visibleWhen: _onCpap,
  sources: const [SourceReference.rd('§1.8 Optimize CPAP; §1.9 Surfactant')],
);

final qRdFio2 = ClinicalQuestion(
  id: rdFio2Key,
  group: 'rd_support',
  question: 'FiO₂',
  type: QuestionType.numeric,
  min: 21,
  max: 100,
  unit: '%',
  helper: 'FiO₂ 0.21–1.00 entered as 21–100%',
  visibleWhen: _onCpap,
  sources: const [SourceReference.rd('§1.9 Surfactant: FiO₂ >0.30')],
);

const qRdSpo2 = ClinicalQuestion(
  id: rdSpo2Key,
  group: 'rd_support',
  question: 'SpO₂',
  type: QuestionType.numeric,
  min: 50,
  max: 100,
  unit: '%',
  helper: 'Target 91–95%',
  sources: [SourceReference.rd('§1.6 Target SpO₂ 91–95%')],
);

const qRdComfortable = ClinicalQuestion(
  id: rdComfortableKey,
  group: 'rd_support',
  question: 'Comfortable breathing',
  type: QuestionType.boolean,
  helper: 'Required for improving / weaning per STW',
  sources: [
    SourceReference.rd(
      '§1.7 Improving',
      needsClinicalReview: true,
      note: 'App requires all three improving criteria (open point 6.4).',
    ),
  ],
);

final qRdWarnings = ClinicalQuestion(
  id: rdWarningsKey,
  group: 'rd_warnings',
  question: 'Warning signs (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    const QuestionOption('rising', 'Rising oxygen need'),
    const QuestionOption('apnea', 'Recurrent apnea / bradycardia'),
    const QuestionOption('fatigue', 'Fatigue'),
    const QuestionOption('shock', 'Shock'),
    const QuestionOption('deterioration', 'Clinical deterioration'),
    QuestionOption(
      'hypoxemia',
      'Persistent hypoxemia / high FiO₂ despite optimised CPAP',
      visibleWhen: _onCpap,
    ),
  ],
  sources: const [
    SourceReference.rd('§1.8 Not improving / worsening; §1.10 CPAP failure'),
  ],
);

final qRdSepsis = ClinicalQuestion(
  id: rdSepsisKey,
  group: 'rd_sepsis',
  question: 'Sepsis triggers (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    for (final t in SepsisTrigger.values) QuestionOption(t.name, t.label),
  ],
  sources: const [
    SourceReference.rd('§1.5 Consider sepsis (see STW: Sepsis in Neonates)'),
  ],
);

// ---------------------------------------------------------------------------
// Derived variables (computed by the existing RD engine)
// ---------------------------------------------------------------------------

Set<String> _set(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

SasScore _sasFrom(VariableReader r, String Function(SasItem) key) => SasScore({
      for (final i in SasItem.values)
        if (r.valueOf(key(i)) case final int g) i: g,
    });

/// Same behaviour as the RD screen: a measured RR decides "RR >60/min".
Object? _signsEffective(VariableReader r) {
  final ticked = r.valueOf(rdSignsKey);
  final rr = r.valueOf(rdRrKey);
  if (ticked == null && rr == null) return null;
  final s = {..._set(ticked)};
  if (rr is int) {
    rr > rrThresholdPerMin
        ? s.add(RdSign.rrAbove60.name)
        : s.remove(RdSign.rrAbove60.name);
  }
  return s;
}

Object? _gestation(VariableReader r) {
  final known = r.valueOf(gaKnownKey);
  if (known is! bool) return null;
  return Gestation(
    gaKnown: known,
    gaWeeks: r.valueOf(gaWeeksKey) as int?,
    gaDays: (r.valueOf(gaDaysKey) as int?) ?? 0,
    birthWeightG: r.valueOf(birthWeightKey) as int?,
  );
}

Object? _initial(VariableReader r) {
  final signs = r.valueOf(rdSignsEffectiveKey);
  if (signs is! Set<String>) return null;
  final iv = _set(r.valueOf(rdIvFlagsKey));
  return initialPlan(
    signs: {for (final s in signs) RdSign.values.byName(s)},
    gestation: (r.valueOf(rdGestationKey) as Gestation?) ?? const Gestation(),
    sas: r.valueOf(rdSasScoreKey)! as SasScore,
    severeDistress: iv.contains('severe'),
    recurrentApnea: iv.contains('apnea'),
    poorPerfusion: iv.contains('perfusion'),
    abdominalSigns: iv.contains('abdomen'),
  );
}

Object? _reassessOutcome(VariableReader r) {
  if (r.valueOf(rdReassessNowKey) != true) return null;
  final support = r.valueOf(rdSupportKey);
  final gestation = r.valueOf(rdGestationKey);
  if (support is! String || gestation is! Gestation) return null;
  final w = _set(r.valueOf(rdWarningsKey));
  return reassess(ReassessInput(
    gestation: gestation,
    support: RespSupport.values.byName(support),
    peep: (r.valueOf(rdPeepKey) as int?) ?? 5,
    fio2: ((r.valueOf(rdFio2Key) as int?) ?? 21) / 100,
    spo2: r.valueOf(rdSpo2Key) as int?,
    previousSasTotal: r.valueOf(rdPrevSasTotalKey) as int?,
    sas: r.valueOf(rdReSasScoreKey)! as SasScore,
    comfortableBreathing: r.valueOf(rdComfortableKey) == true,
    risingO2Need: w.contains('rising'),
    recurrentApneaBrady: w.contains('apnea'),
    fatigue: w.contains('fatigue'),
    shock: w.contains('shock'),
    deterioration: w.contains('deterioration'),
    persistentHypoxemia: w.contains('hypoxemia'),
    sepsisTriggers: {
      for (final t in _set(r.valueOf(rdSepsisKey)))
        SepsisTrigger.values.byName(t),
    },
  ));
}

RdInitialPlan? _plan(VariableReader r) =>
    (r.valueOf(rdInitialKey) as RdInitialResult?)?.plan;

final rdVariables = [
  const ClinicalVariable(rdSignsEffectiveKey,
      'Signs present (RR decides "RR >60/min" when entered)', _signsEffective),
  const ClinicalVariable(rdGestationKey,
      'GA band / BW surrogate (rd_rules Gestation)', _gestation),
  ClinicalVariable(
      rdSasScoreKey, 'SAS (sas.dart)', (r) => _sasFrom(r, rdSasKey)),
  ClinicalVariable(rdSasTotalKey, 'SAS total when all 5 items graded', (r) {
    final s = r.valueOf(rdSasScoreKey)! as SasScore;
    return s.isComplete ? s.total : null;
  }),
  ClinicalVariable(rdSeverityKey, 'RdSeverity.fromTotal',
      (r) => (r.valueOf(rdSasScoreKey)! as SasScore).severity?.name),
  const ClinicalVariable(rdInitialKey, 'rd_rules initialPlan()', _initial),
  ClinicalVariable(
      rdPlanReadyKey, 'Initial plan available', (r) => _plan(r) != null),
  ClinicalVariable(
      rdIvIndicatedKey, 'IV fluids indicated', (r) => _plan(r)?.ivFluids),
  ClinicalVariable(
      rdReSasScoreKey, 'Repeat SAS', (r) => _sasFrom(r, rdReSasKey)),
  ClinicalVariable(rdPrevSasTotalKey,
      'Previous SAS: last recorded reassessment, else initial SAS', (r) {
    final history = r.valueOf(rdSasHistoryKey);
    if (history is List && history.isNotEmpty) return history.last;
    return r.valueOf(rdSasTotalKey);
  }),
  const ClinicalVariable(
      rdReassessKey, 'rd_rules reassess()', _reassessOutcome),
  ClinicalVariable(rdReassessStatusKey, 'Reassessment status',
      (r) => (r.valueOf(rdReassessKey) as ReassessOutcome?)?.status.name),
  ClinicalVariable(rdReassessAlertsKey, 'Reassessment side alerts', (r) {
    final a = (r.valueOf(rdReassessKey) as ReassessOutcome?)?.alerts;
    return (a == null || a.isEmpty) ? null : a;
  }),
];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

final _present = const HasFinding(rdPresentId);
final _planReady = const Var(rdPlanReadyKey).eq(true);

String _signLabels(VariableReader r) => [
      for (final s in _set(r.valueOf(rdSignsEffectiveKey)))
        RdSign.values.byName(s).label,
    ].join(', ');

final _reassessMeta =
    <ReassessStatus, (FindingCategory, FindingLevel, SourceReference)>{
  ReassessStatus.cpapFailure: (
    FindingCategory.referral,
    FindingLevel.urgent,
    const SourceReference.rd('§1.10 CPAP failure → refer urgently'),
  ),
  ReassessStatus.surfactant: (
    FindingCategory.treatment,
    FindingLevel.treat,
    const SourceReference.rd(
        '§1.9 Surfactant: GA <34 wk, on CPAP, PEEP >6 AND FiO₂ >0.30'),
  ),
  ReassessStatus.notImproving: (
    FindingCategory.pathway,
    FindingLevel.action,
    const SourceReference.rd(
      '§1.8 Not improving / worsening → optimize CPAP',
      needsClinicalReview: true,
      note: '"Persisting SAS" read as equal and ≥4 (open point 6.3); '
          'nasal-prong wording shown as in the STW box (open point 6.5).',
    ),
  ),
  ReassessStatus.improving: (
    FindingCategory.pathway,
    FindingLevel.ok,
    const SourceReference.rd(
      '§1.7 Improving → wean',
      needsClinicalReview: true,
      note: 'All three improving criteria required (open point 6.4).',
    ),
  ),
  ReassessStatus.stable: (
    FindingCategory.pathway,
    FindingLevel.info,
    const SourceReference.rd('§1.5 Reassess frequently'),
  ),
  ReassessStatus.offSupport: (
    FindingCategory.followUp,
    FindingLevel.ok,
    const SourceReference.rd('§1.7 Continue SpO₂ monitoring for 24 h'),
  ),
  ReassessStatus.incomplete: (
    FindingCategory.furtherAssessment,
    FindingLevel.info,
    const SourceReference.rd('§1.5 Reassess: clinical status, SAS, SpO₂'),
  ),
};

final rdRules = <ClinicalRule>[
  ClinicalRule(
    id: rdPresentId,
    topic: _rd,
    when: AnyOf([
      for (final s in RdSign.values)
        const Var(rdSignsEffectiveKey).contains(s.name),
    ]),
    source: _srcDefinition,
    then: (r) => FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.action,
      title: 'Respiratory distress criteria met',
      why: ['Present: ${_signLabels(r)}'],
    ),
  ),
  ClinicalRule(
    id: rdNotMetId,
    topic: _rd,
    when: AllOf([
      const Var(rdSignsEffectiveKey).exists(),
      Not(_present),
    ]),
    source: _srcDefinition,
    then: (_) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.ok,
      title: 'Respiratory distress criteria not met',
      actions: const ['RD pathway not triggered.'],
      why: [
        'None recorded: '
            '${RdSign.values.map((s) => s.label).join(', ')}',
      ],
    ),
  ),
  ClinicalRule(
    id: rdImmediateId,
    topic: _rd,
    when: _present,
    source: const SourceReference.rd('§1.2 Immediate actions'),
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: 'Immediate actions (TABC & stabilization)',
      actions: rdImmediateActions,
    ),
  ),
  ClinicalRule(
    id: rdSeverityId,
    topic: _rd,
    when: AllOf([_present, const Var(rdSeverityKey).exists()]),
    source: _srcSas,
    then: (r) {
      final sev = RdSeverity.values.byName(r.valueOf(rdSeverityKey)! as String);
      return FindingContent(
        category: FindingCategory.classification,
        level: FindingLevel.action,
        title: '${sev.label} RD (SAS ${r.valueOf(rdSasTotalKey)})',
        why: [
          sev == RdSeverity.mild
              ? 'STW: mild RD = SAS ≤3'
              : 'STW: moderate–severe RD = SAS ≥4',
        ],
      );
    },
  ),
  ClinicalRule(
    id: rdInitialPlanId,
    topic: _rd,
    when: AllOf([_present, _planReady]),
    source: const SourceReference.rd(
      '§1.5 Algorithm: choosing initial support',
      needsClinicalReview: true,
      note: 'GA uses completed weeks, so 34+3 counts as ≤34 (open point 6.1).',
    ),
    then: (r) {
      final p = _plan(r)!;
      return FindingContent(
        category: FindingCategory.pathway,
        level: FindingLevel.action,
        title: p.support == RespSupport.cpap
            ? 'START CPAP'
            : 'Nasal-prong oxygen 0.5–1 L/min',
        actions: [
          ...p.supportActions,
          p.caffeine.text,
          'Feeding: ${p.feeding.text}',
          'Reassess frequently: clinical status, SAS, SpO₂, FiO₂ requirement.',
        ],
        why: p.why,
      );
    },
  ),
  ClinicalRule(
    id: rdIvFluidsId,
    topic: _rd,
    when: AllOf([_present, const Var(rdIvIndicatedKey).eq(true)]),
    source: const SourceReference.rd('§1.2 IV fluids'),
    then: (r) => FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'IV fluids indicated',
      actions: [FeedingAdvice.ivFluids.text],
      why: _plan(r)!.ivFluidReasons,
    ),
  ),
  ClinicalRule(
    id: rdAvoidId,
    topic: _rd,
    when: AllOf([_present, _planReady]),
    source: const SourceReference.rd("§1.12 DON'Ts"),
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: "Avoid (STW DON'Ts)",
      actions: _plan(r)!.avoid,
    ),
  ),
  ClinicalRule(
    id: rdPlanPendingId,
    topic: _rd,
    when: AllOf([_present, Not(_planReady)]),
    source: const SourceReference.rd('§1.5 Assess gestation (GA) + SAS'),
    then: (r) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'Initial plan pending',
      actions: [
        (r.valueOf(rdInitialKey) as RdInitialResult?)?.pending ??
            'Complete the RD assessment.',
      ],
    ),
  ),
  for (final st in ReassessStatus.values)
    ClinicalRule(
      id: rdReassessId(st),
      topic: _rd,
      when: AllOf([_present, const Var(rdReassessStatusKey).eq(st.name)]),
      source: _reassessMeta[st]!.$3,
      then: (r) {
        final o = r.valueOf(rdReassessKey)! as ReassessOutcome;
        final (category, level, _) = _reassessMeta[st]!;
        return FindingContent(
          category: category,
          level: level,
          title: o.title,
          actions: o.actions,
          why: o.why,
        );
      },
    ),
  ClinicalRule(
    id: rdReassessAlertsId,
    topic: _rd,
    when: AllOf([_present, const Var(rdReassessAlertsKey).exists()]),
    source: const SourceReference.rd(
        '§1.5 Consider sepsis; §1.6 Target SpO₂ 91–95%'),
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: 'Reassessment alerts',
      actions: [...r.valueOf(rdReassessAlertsKey)! as List<String>],
    ),
  ),
];

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

final _reassessing =
    AllOf([_present, _planReady, const Var(rdReassessNowKey).eq(true)]);

final rdWorkflow = StwWorkflow(
  _rd,
  source: const SourceReference.rd('Whole document (ICD-11 KB23)'),
  groups: rdGroups,
  uses: [
    const QuestionUse(qRdRr),
    QuestionUse(qRdSigns),
    QuestionUse(qGaKnown, when: _present, required: true),
    QuestionUse(
      qGaWeeks,
      when: _present,
      required: true,
    ),
    QuestionUse(
      qBirthWeight,
      when: AllOf([_present, const Var(gaKnownKey).eq(false)]),
      required: true,
    ),
    for (final q in rdSasQuestions)
      QuestionUse(q, when: _present, required: true),
    QuestionUse(qRdIvFlags, when: _present),
    QuestionUse(
      qRdReassessNow,
      when: AllOf([_present, _planReady]),
      required: true,
    ),
    QuestionUse(qRdSupport, when: _reassessing, required: true),
    QuestionUse(qRdPeep, when: _reassessing, required: true),
    QuestionUse(qRdFio2, when: _reassessing, required: true),
    QuestionUse(qRdSpo2, when: _reassessing, required: true),
    QuestionUse(qRdComfortable, when: _reassessing),
    for (final q in rdReSasQuestions)
      QuestionUse(q, when: _reassessing, required: true),
    QuestionUse(qRdWarnings, when: _reassessing),
    QuestionUse(qRdSepsis, when: _reassessing),
  ],
  variables: rdVariables,
  rules: rdRules,
  persistentKeys: const {rdSasHistoryKey},
);

/// Records the repeat SAS in the trend and clears the per-reassessment
/// answers so the reassessment questions are asked again. Support settings
/// are kept but must be re-confirmed. Mirrors `RdController.recordReassessment`.
/// Returns null when the repeat SAS is incomplete.
({Map<String, Object?> answers, Set<String> completed})? recordRdReassessment(
  Map<String, Object?> answers,
  Set<String> completed,
) {
  final resas = SasScore({
    for (final i in SasItem.values)
      if (answers[rdReSasKey(i)] case final int g) i: g,
  });
  if (!resas.isComplete) return null;
  final history = [...?(answers[rdSasHistoryKey] as List<int>?), resas.total];
  final cleared = {
    rdSpo2Key,
    rdComfortableKey,
    rdWarningsKey,
    rdSepsisKey,
    for (final i in SasItem.values) rdReSasKey(i),
  };
  final reconfirm = {rdSupportKey, rdPeepKey, rdFio2Key, ...cleared};
  return (
    answers: {
      for (final e in answers.entries)
        if (!cleared.contains(e.key)) e.key: e.value,
      rdSasHistoryKey: history,
    },
    completed: completed.difference(reconfirm),
  );
}
