/// Retinopathy of Prematurity workflow for the dynamic assessment engine.
///
/// Pure Dart. Every clinical decision is delegated to the existing validated
/// engine in `rop_rules.dart` (ropEligibility, firstScreenTiming,
/// eyeIndication, buildRopSummary). Section numbers refer to
/// docs/STW_APP_SPEC_FROM_PDFs.md.
library;

import '../../../content/stw_content.dart';
import '../../clinical_workflow/domain/assessment_context.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'rop_rules.dart';

const _rop = NeonatalCondition.rop;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const ropRisksKey = 'rop_risks';
const ropFollowUpAssuredKey = 'rop_followup_assured';
const ropExamDoneKey = 'rop_exam_done';
const ropExamDateKey = 'rop_exam_date';
const ropLeftSameKey = 'rop_left_same';
const ropNextExamDateKey = 'rop_next_exam_date';
const ropNextExamPlaceKey = 'rop_next_exam_place';
const ropCounselledKey = 'rop_counselled';
const ropFacilityKey = 'rop_facility';
const ropSncuNoKey = 'rop_sncu_no';

/// Per-eye question keys: `rop_r_zone`, `rop_l_stage`, …
enum RopEye {
  right('rop_r_', 'Right eye (OD)'),
  left('rop_l_', 'Left eye (OS)');

  const RopEye(this.prefix, this.label);
  final String prefix;
  final String label;

  String key(String field) => '$prefix$field';
  String get findingsKey => 'rop_${name}_findings';
  String get resultKey => 'rop_${name}_result';
  String get actionKey => 'rop_${name}_action';
  String get findingId => 'rop.eye.$name';
}

// Derived variables
const ropGaWeeksKey = 'rop_ga_weeks';
const ropEligibilityKey = 'rop_eligibility';
const ropEligibleKey = 'rop_eligible';
const ropEligibilityPendingKey = 'rop_eligibility_pending';
const ropTimingKey = 'rop_timing';
const ropFirstScreenStatusKey = 'rop_first_screen_status';
const ropPmaWeeksKey = 'rop_pma_weeks';
const ropPma65DateKey = 'rop_pma65_date';
const ropAnyTreatmentKey = 'rop_any_treatment';
const ropBothMayStopKey = 'rop_both_may_stop';
const ropAnyAntiVegfKey = 'rop_any_anti_vegf';
const ropFollowUpMissingKey = 'rop_followup_missing';
const ropSummaryTextKey = 'rop_summary_text';

// Findings
const ropEligibleId = 'rop.eligible';
const ropNotEligibleId = 'rop.notEligible';
const ropEligibilityPendingId = 'rop.eligibilityPending';
const ropOverdueId = 'rop.firstScreenOverdue';
const ropDueId = 'rop.firstScreenDue';
const ropScreenBeforeDischargeId = 'rop.screenBeforeDischarge';
const ropTreatUrgentlyId = 'rop.treatUrgently';
const ropAntiVegfFollowUpId = 'rop.antiVegfFollowUp';
const ropFollowUpMissingId = 'rop.followUpPlanMissing';
const ropNextExamId = 'rop.nextExam';
const ropCounselId = 'rop.counsel';

// ---------------------------------------------------------------------------
// Questions (wording as in the existing ROP screens / STW)
// ---------------------------------------------------------------------------

const ropGroups = [
  babyGroup,
  QuestionGroup(
    'rop_risks',
    'Risk factors (GA 34–36 weeks)',
    subtitle: 'Any one makes the baby eligible',
  ),
  QuestionGroup('rop_timing', 'Screening timing'),
  QuestionGroup('rop_exam_gate', 'ROP examination'),
  QuestionGroup(
    'rop_right',
    'Right eye (OD) findings',
    subtitle: 'Entered by / with the ROP-trained ophthalmologist (ICROP3)',
  ),
  QuestionGroup(
    'rop_left',
    'Left eye (OS) findings',
    subtitle: 'Entered by / with the ROP-trained ophthalmologist (ICROP3)',
  ),
  QuestionGroup(
    'rop_followup',
    'Next ROP examination',
    subtitle: 'Document date and place of next screening in discharge card',
  ),
];

const _srcWhom = SourceReference.rop('§2.1 Whom to screen');
const _srcWhen = SourceReference.rop('§2.2 When to screen');
const _srcTreat = SourceReference.rop('§2.6 Treatment indications');
const _srcFollowUp = SourceReference.rop("§2.10 DOs; §2.11 DON'Ts");

final qRopRisks = ClinicalQuestion(
  id: ropRisksKey,
  group: 'rop_risks',
  question: 'Risk factors (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    for (final r in RopRiskFactor.values) QuestionOption(r.name, r.label),
  ],
  sources: const [_srcWhom],
);

const qRopFollowUpAssured = ClinicalQuestion(
  id: ropFollowUpAssuredKey,
  group: 'rop_timing',
  question: 'Follow-up after discharge assured?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption('yes', 'Yes'),
    QuestionOption('no', 'No'),
    QuestionOption('uncertain', 'Uncertain'),
  ],
  sources: [
    SourceReference.rop(
        '§2.2 If follow-up uncertain, screen before discharge even if not due'),
  ],
);

const qRopExamDone = ClinicalQuestion(
  id: ropExamDoneKey,
  group: 'rop_exam_gate',
  question: 'Has the ROP eye examination been done?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes — enter findings'),
    QuestionOption(false, 'Not yet'),
  ],
  sources: [
    SourceReference.dataEntry(
        'STW §2.5 "Document ROP findings"; findings are asked only once an '
        'examination has been done.'),
  ],
);

final qRopExamDate = ClinicalQuestion(
  id: ropExamDateKey,
  group: 'rop_exam_gate',
  question: 'Examination date',
  type: QuestionType.date,
  pastOnly: true,
  visibleWhen: const Var(ropExamDoneKey).eq(true),
  sources: const [SourceReference.rop('§2.5 Document ROP findings')],
);

List<ClinicalQuestion> ropEyeQuestions(RopEye eye) {
  final group = eye == RopEye.right ? 'rop_right' : 'rop_left';
  ClinicalQuestion q(
    String field,
    String text,
    QuestionType type, {
    List<QuestionOption> options = const [],
    Cond? visibleWhen,
    int? min,
    int? max,
    SourceReference source = _srcTreat,
  }) =>
      ClinicalQuestion(
        id: eye.key(field),
        group: group,
        question: text,
        type: type,
        options: options,
        visibleWhen: visibleWhen,
        min: min,
        max: max,
        sources: [source],
      );
  return [
    q('zone', 'Zone', QuestionType.singleChoice, options: [
      for (final z in RopZone.values) QuestionOption(z.name, z.label),
    ]),
    q('stage', 'Stage', QuestionType.singleChoice, options: [
      const QuestionOption(0, 'No ROP'),
      for (var s = 1; s <= 5; s++) QuestionOption(s, 'Stage $s'),
    ]),
    q('vascular', 'Plus disease', QuestionType.singleChoice, options: const [
      QuestionOption('noPlus', 'No plus'),
      QuestionOption('prePlus', 'Pre-plus'),
      QuestionOption('plus', 'Plus present'),
    ]),
    q('clock_hours', 'Extent of disease (clock hours, optional)',
        QuestionType.numeric,
        min: 1,
        max: 12,
        source: const SourceReference.rop('ICROP3 / SNCU ROP record form')),
    q('arop', 'Aggressive ROP (A-ROP) suspected', QuestionType.boolean),
    q('progressive', 'Progressive disease since last exam',
        QuestionType.boolean,
        source: const SourceReference.rop('§2.2 Repeat screen')),
    q('anti_vegf', 'Previously treated with anti-VEGF', QuestionType.boolean,
        source: const SourceReference.rop('§2.8 When to stop screening')),
    q(
      'reactivation',
      'Reactivation / significant PAR',
      QuestionType.boolean,
      visibleWhen: Var(eye.key('anti_vegf')).eq(true),
      source: const SourceReference.rop(
        '§2.6 Reactivation/significant PAR after anti-VEGF',
        needsClinicalReview: true,
        note: 'STW line is ambiguous; read as reactivation with stage 2–3 → '
            'treat (open point 6.9).',
      ),
    ),
    q('status', 'Retina status', QuestionType.singleChoice,
        options: [
          for (final s in RetinaStatus.values) QuestionOption(s.name, s.label),
        ],
        source: const SourceReference.rop('§2.8 When to stop screening')),
  ];
}

final ropRightQuestions = ropEyeQuestions(RopEye.right);
final ropLeftQuestions = ropEyeQuestions(RopEye.left);

const qRopLeftSame = ClinicalQuestion(
  id: ropLeftSameKey,
  group: 'rop_left',
  question: 'Same findings as right eye',
  type: QuestionType.boolean,
  sources: [SourceReference.dataEntry('Copies the right-eye findings.')],
);

const qRopNextExamDate = ClinicalQuestion(
  id: ropNextExamDateKey,
  group: 'rop_followup',
  question: 'Date of next ROP examination',
  type: QuestionType.date,
  helper: 'Chosen by the clinician; usually every 1–3 weeks as advised by '
      'the ROP-trained ophthalmologist',
  sources: [_srcFollowUp, _srcWhen],
);

const qRopNextExamPlace = ClinicalQuestion(
  id: ropNextExamPlaceKey,
  group: 'rop_followup',
  question: 'Place of next ROP examination',
  type: QuestionType.text,
  sources: [_srcFollowUp],
);

const qRopCounselled = ClinicalQuestion(
  id: ropCounselledKey,
  group: 'rop_followup',
  question: 'Family counselled on follow-up and risk of vision loss',
  type: QuestionType.boolean,
  sources: [_srcFollowUp],
);

const qRopFacility = ClinicalQuestion(
  id: ropFacilityKey,
  group: 'rop_followup',
  question: 'Facility / hospital name (optional)',
  type: QuestionType.text,
  sources: [SourceReference.rop('SNCU ROP record form (discharge card)')],
);

const qRopSncuNo = ClinicalQuestion(
  id: ropSncuNoKey,
  group: 'rop_followup',
  question: 'SNCU / CR number (optional)',
  type: QuestionType.text,
  sources: [SourceReference.rop('SNCU ROP record form (discharge card)')],
);

// ---------------------------------------------------------------------------
// Derived variables (computed by the existing ROP engine)
// ---------------------------------------------------------------------------

T? _byName<T extends Enum>(List<T> values, Object? name) =>
    name is String ? values.byName(name) : null;

Set<String> _set(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

EyeFindings _eyeFrom(VariableReader r, RopEye eye) {
  final vascular = r.valueOf(eye.key('vascular'));
  return EyeFindings(
    zone: _byName(RopZone.values, r.valueOf(eye.key('zone'))),
    stage: r.valueOf(eye.key('stage')) as int?,
    plus: vascular == 'plus',
    prePlus: vascular == 'prePlus',
    clockHours: r.valueOf(eye.key('clock_hours')) as int?,
    aRop: r.valueOf(eye.key('arop')) == true,
    progressive: r.valueOf(eye.key('progressive')) == true,
    priorAntiVegf: r.valueOf(eye.key('anti_vegf')) == true,
    reactivationOrPar: r.valueOf(eye.key('reactivation')) == true,
    status: _byName(RetinaStatus.values, r.valueOf(eye.key('status'))),
  );
}

Object? _eligibility(VariableReader r) {
  if (r.valueOf(gaKnownKey) is! bool) return null;
  final ga = r.valueOf(ropGaWeeksKey) as int?;
  return ropEligibility(
    gaWeeks: ga,
    birthWeightG: r.valueOf(birthWeightKey) as int?,
    risks: riskFactorsRelevant(ga)
        ? {
            for (final x in _set(r.valueOf(ropRisksKey)))
              RopRiskFactor.values.byName(x),
          }
        : const {},
  );
}

Object? _timing(VariableReader r) {
  final dob = r.valueOf(dobKey);
  if (dob is! DateTime) return null;
  return firstScreenTiming(
    dob: dob,
    today: r.valueOf(todayKey)! as DateTime,
    gaWeeks: r.valueOf(ropGaWeeksKey) as int?,
    birthWeightG: r.valueOf(birthWeightKey) as int?,
  );
}

Object? _pmaWeeks(VariableReader r) {
  final ga = r.valueOf(ropGaWeeksKey);
  final dob = r.valueOf(dobKey);
  if (ga is! int || dob is! DateTime) return null;
  final on = (r.valueOf(ropExamDateKey) as DateTime?) ??
      r.valueOf(todayKey)! as DateTime;
  return pmaDays(
        gaWeeks: ga,
        gaDays: (r.valueOf(gaDaysKey) as int?) ?? 0,
        dob: dob,
        onDate: on,
      ) ~/
      7;
}

Object? _eyeFindings(VariableReader r, RopEye eye) {
  if (r.valueOf(ropExamDoneKey) != true) return null;
  if (eye == RopEye.left && r.valueOf(ropLeftSameKey) == true) {
    return _eyeFrom(r, RopEye.right);
  }
  return _eyeFrom(r, eye);
}

EyeIndication? _result(VariableReader r, RopEye eye) =>
    r.valueOf(eye.resultKey) as EyeIndication?;

final ropVariables = <ClinicalVariable>[
  ClinicalVariable(ropGaWeeksKey, 'GA when known',
      (r) => r.valueOf(gaKnownKey) == true ? r.valueOf(gaWeeksKey) : null),
  const ClinicalVariable(
      ropEligibilityKey, 'rop_rules ropEligibility()', _eligibility),
  ClinicalVariable(ropEligibleKey, 'Eligible for screening',
      (r) => (r.valueOf(ropEligibilityKey) as RopEligibility?)?.eligible),
  ClinicalVariable(ropEligibilityPendingKey, 'Eligibility not decidable', (r) {
    final e = r.valueOf(ropEligibilityKey) as RopEligibility?;
    return e != null && e.eligible == null;
  }),
  const ClinicalVariable(
      ropTimingKey, 'rop_rules firstScreenTiming()', _timing),
  ClinicalVariable(ropFirstScreenStatusKey, 'First-screen status',
      (r) => (r.valueOf(ropTimingKey) as FirstScreenTiming?)?.status.name),
  const ClinicalVariable(ropPmaWeeksKey, 'PMA (completed weeks)', _pmaWeeks),
  ClinicalVariable(ropPma65DateKey, 'Date at 65 weeks PMA', (r) {
    final ga = r.valueOf(ropGaWeeksKey);
    final dob = r.valueOf(dobKey);
    if (ga is! int || dob is! DateTime) return null;
    return dateAtPma(
      gaWeeks: ga,
      gaDays: (r.valueOf(gaDaysKey) as int?) ?? 0,
      dob: dob,
      targetWeeks: antiVegfFollowUpPmaWeeks,
    );
  }),
  for (final eye in RopEye.values) ...[
    ClinicalVariable(
        eye.findingsKey, '${eye.label} findings', (r) => _eyeFindings(r, eye)),
    ClinicalVariable(eye.resultKey, 'rop_rules eyeIndication()', (r) {
      final f = r.valueOf(eye.findingsKey) as EyeFindings?;
      return f == null
          ? null
          : eyeIndication(f, pmaWeeks: r.valueOf(ropPmaWeeksKey) as int?);
    }),
    ClinicalVariable(eye.actionKey, '${eye.label} action',
        (r) => _result(r, eye)?.action.name),
  ],
  ClinicalVariable(ropAnyTreatmentKey, 'Any eye needs treatment',
      (r) => RopEye.values.any((e) => _result(r, e)?.needsTreatment ?? false)),
  ClinicalVariable(
      ropBothMayStopKey,
      'Both eyes: screening may stop',
      (r) => RopEye.values
          .every((e) => _result(r, e)?.action == EyeAction.mayStop)),
  ClinicalVariable(
      ropAnyAntiVegfKey,
      'Any eye treated with anti-VEGF',
      (r) => RopEye.values.any((e) =>
          (r.valueOf(e.findingsKey) as EyeFindings?)?.priorAntiVegf ?? false)),
  ClinicalVariable(ropFollowUpMissingKey, 'Next exam date or place missing',
      (r) {
    final place = r.valueOf(ropNextExamPlaceKey);
    return r.valueOf(ropNextExamDateKey) == null ||
        place is! String ||
        place.trim().isEmpty;
  }),
  ClinicalVariable(ropSummaryTextKey, 'rop_rules buildRopSummary()', (r) {
    final e = r.valueOf(ropEligibilityKey) as RopEligibility?;
    if (e == null) return null;
    final right = r.valueOf(RopEye.right.findingsKey) as EyeFindings?;
    final left = r.valueOf(RopEye.left.findingsKey) as EyeFindings?;
    return buildRopSummary(
      babyLine: describeBabyLine(r),
      eligibility: e,
      hospitalName: (r.valueOf(ropFacilityKey) as String?) ?? '',
      sncuNumber: (r.valueOf(ropSncuNoKey) as String?) ?? '',
      timing: r.valueOf(ropTimingKey) as FirstScreenTiming?,
      examDate: r.valueOf(ropExamDateKey) as DateTime?,
      right: right,
      left: left,
      rightResult:
          right == null || right.isEmpty ? null : _result(r, RopEye.right),
      leftResult: left == null || left.isEmpty ? null : _result(r, RopEye.left),
      nextExamDate: r.valueOf(ropNextExamDateKey) as DateTime?,
      nextExamPlace: (r.valueOf(ropNextExamPlaceKey) as String?) ?? '',
      familyCounselled: r.valueOf(ropCounselledKey) == true,
      formatDate: formatDmy,
    );
  }),
];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

final _eligible = const HasFinding(ropEligibleId);
final _notExamined = Not(const Var(ropExamDoneKey).eq(true));

FirstScreenTiming _timingOf(VariableReader r) =>
    r.valueOf(ropTimingKey)! as FirstScreenTiming;

List<String> _timingWhy(FirstScreenTiming t) => [
      t.ruleText,
      'Postnatal age: ${t.postnatalAgeDays} days '
          '(${formatWeeksDays(t.postnatalAgeDays)})',
    ];

FindingContent _eyeContent(VariableReader r, RopEye eye) {
  final res = _result(r, eye)!;
  final f = r.valueOf(eye.findingsKey)! as EyeFindings;
  final (category, level) = switch (res.action) {
    EyeAction.urgentTreatment => (
        FindingCategory.treatment,
        FindingLevel.urgent
      ),
    EyeAction.treat => (FindingCategory.treatment, FindingLevel.treat),
    EyeAction.surgeryReferral => (
        FindingCategory.referral,
        FindingLevel.urgent
      ),
    EyeAction.observe => (FindingCategory.followUp, FindingLevel.action),
    EyeAction.mayStop => (FindingCategory.followUp, FindingLevel.ok),
    EyeAction.incomplete => (
        FindingCategory.furtherAssessment,
        FindingLevel.info
      ),
  };
  return FindingContent(
    category: category,
    level: level,
    title: '${eye.label}: ${res.title}',
    actions: [if (res.followUp != null) res.followUp!],
    why: [f.describe(), ...res.why],
  );
}

final ropRules = <ClinicalRule>[
  ClinicalRule(
    id: ropEligibleId,
    topic: _rop,
    when: const Var(ropEligibleKey).eq(true),
    source: const SourceReference.rop(
        '§2.1 Whom to screen; §2.3 How to arrange screening'),
    then: (r) => FindingContent(
      category: FindingCategory.screening,
      level: FindingLevel.action,
      title: 'Screening eligible — SCREEN FOR ROP',
      actions: ropArrangeScreening,
      why: (r.valueOf(ropEligibilityKey)! as RopEligibility).reasons,
    ),
  ),
  ClinicalRule(
    id: ropNotEligibleId,
    topic: _rop,
    when: const Var(ropEligibleKey).eq(false),
    source: _srcWhom,
    then: (r) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.ok,
      title: 'Not eligible per STW screening criteria',
      actions: const ['ROP screening pathway not triggered.'],
      why: (r.valueOf(ropEligibilityKey)! as RopEligibility).reasons,
    ),
  ),
  ClinicalRule(
    id: ropEligibilityPendingId,
    topic: _rop,
    when: const Var(ropEligibilityPendingKey).eq(true),
    source: _srcWhom,
    then: (r) => FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'ROP eligibility pending',
      actions: (r.valueOf(ropEligibilityKey)! as RopEligibility).reasons,
    ),
  ),
  ClinicalRule(
    id: ropOverdueId,
    topic: _rop,
    when: AllOf([
      _eligible,
      _notExamined,
      const Var(ropFirstScreenStatusKey).eq(FirstScreenStatus.overdue.name),
    ]),
    source: _srcWhen,
    then: (r) => FindingContent(
      category: FindingCategory.screening,
      level: FindingLevel.urgent,
      title: 'First screen OVERDUE — screen ASAP',
      why: _timingWhy(_timingOf(r)),
    ),
  ),
  ClinicalRule(
    id: ropDueId,
    topic: _rop,
    when: AllOf([
      _eligible,
      _notExamined,
      const Var(ropFirstScreenStatusKey).eq(FirstScreenStatus.notYetDue.name),
    ]),
    source: _srcWhen,
    then: (r) {
      final t = _timingOf(r);
      return FindingContent(
        category: FindingCategory.screening,
        level: FindingLevel.action,
        title: 'First screen due by ${formatDmy(t.dueBy)}',
        actions: [
          if (t.windowStart != null)
            'Window: ${formatDmy(t.windowStart!)} – ${formatDmy(t.dueBy)}',
        ],
        why: _timingWhy(t),
      );
    },
  ),
  ClinicalRule(
    id: ropScreenBeforeDischargeId,
    topic: _rop,
    when: AllOf([
      _eligible,
      _notExamined,
      const Var(ropFollowUpAssuredKey).isIn({'no', 'uncertain'}),
    ]),
    source: const SourceReference.rop(
        '§2.2 If follow-up uncertain, screen before discharge'),
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: 'Follow-up not assured: screen before discharge even if not due',
    ),
  ),
  for (final eye in RopEye.values)
    ClinicalRule(
      id: eye.findingId,
      topic: _rop,
      when: AllOf([_eligible, Var(eye.actionKey).exists()]),
      source: const SourceReference.rop(
        '§2.6 Treatment indications; §2.8 When to stop screening',
        needsClinicalReview: true,
        note: 'Reactivation/PAR line read as stage 2–3 → treat '
            '(open point 6.9).',
      ),
      then: (r) => _eyeContent(r, eye),
    ),
  ClinicalRule(
    id: ropTreatUrgentlyId,
    topic: _rop,
    when: AllOf([_eligible, const Var(ropAnyTreatmentKey).eq(true)]),
    source: const SourceReference.rop(
        '§2.6 Treatment indications; §2.7 Treatment options'),
    then: (_) => const FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: 'Treat urgently — within 48–72 h of decision',
      actions: ropTreatmentOptions,
    ),
  ),
  ClinicalRule(
    id: ropAntiVegfFollowUpId,
    topic: _rop,
    when: AllOf([_eligible, const Var(ropAnyAntiVegfKey).eq(true)]),
    source:
        const SourceReference.rop('§2.8 After anti-VEGF: until 65 weeks PMA'),
    then: (r) {
      final d = r.valueOf(ropPma65DateKey) as DateTime?;
      return FindingContent(
        category: FindingCategory.followUp,
        level: FindingLevel.action,
        title: 'After anti-VEGF: follow up at least until '
            '$antiVegfFollowUpPmaWeeks weeks PMA',
        actions: [
          d == null
              ? 'Enter GA and date of birth to calculate the date.'
              : '$antiVegfFollowUpPmaWeeks weeks PMA on ${formatDmy(d)}',
        ],
        why: const [
          'Risk of late reactivation and persistent avascular retina'
        ],
      );
    },
  ),
  ClinicalRule(
    id: ropFollowUpMissingId,
    topic: _rop,
    when: AllOf([
      _eligible,
      const Var(ropFollowUpMissingKey).eq(true),
      Not(const Var(ropBothMayStopKey).eq(true)),
    ]),
    source: const SourceReference.rop("§2.11 DON'Ts"),
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'DO NOT discharge/transfer an at-risk neonate without a '
          'documented ROP follow-up plan.',
      actions: ['Enter the date and place of the next ROP examination.'],
    ),
  ),
  ClinicalRule(
    id: ropNextExamId,
    topic: _rop,
    when: AllOf([_eligible, const Var(ropNextExamDateKey).exists()]),
    source: _srcFollowUp,
    then: (r) {
      final place = ((r.valueOf(ropNextExamPlaceKey) as String?) ?? '').trim();
      return FindingContent(
        category: FindingCategory.followUp,
        level: FindingLevel.info,
        title: 'Next ROP examination: '
            '${formatDmy(r.valueOf(ropNextExamDateKey)! as DateTime)} at '
            '${place.isEmpty ? 'PLACE NOT DOCUMENTED' : place}',
      );
    },
  ),
  ClinicalRule(
    id: ropCounselId,
    topic: _rop,
    when: AllOf([_eligible, const Var(ropCounselledKey).eq(false)]),
    source: _srcFollowUp,
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: 'Family not yet counselled',
      actions: [
        'Counsel the family regarding need for follow-up and risk of vision '
            'loss if screening is delayed.',
      ],
    ),
  ),
];

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

final _examined = AllOf([_eligible, const Var(ropExamDoneKey).eq(true)]);

/// Zone, stage and plus are needed unless A-ROP is suspected or the retina
/// is already regressed / fully vascularised (as `eyeIndication` handles).
Cond _gradingRequired(RopEye eye) => Not(AnyOf([
      Var(eye.key('arop')).eq(true),
      Var(eye.key('status')).isIn({
        RetinaStatus.regressed.name,
        RetinaStatus.fullyVascularised.name,
      }),
    ]));

List<QuestionUse> _eyeUses(RopEye eye, List<ClinicalQuestion> qs, Cond when) =>
    [
      for (final q in qs)
        QuestionUse(
          q,
          when: when,
          requiredWhen: q.id.endsWith('zone') ||
                  q.id.endsWith('stage') ||
                  q.id.endsWith('vascular')
              ? _gradingRequired(eye)
              : null,
        ),
    ];

final ropWorkflow = StwWorkflow(
  _rop,
  source: const SourceReference.rop('Whole document (ICD-11 9B71.3)'),
  groups: ropGroups,
  uses: [
    const QuestionUse(qGaKnown, required: true),
    QuestionUse(qGaWeeks, required: true),
    QuestionUse(qGaDays),
    QuestionUse(
      qBirthWeight,
      requiredWhen: const Var(gaKnownKey).eq(false),
    ),
    // STW §2.1: "Gestation 34-36 weeks with specified risk factors".
    QuestionUse(
      qRopRisks,
      when: AllOf([
        const Var(gaKnownKey).eq(true),
        const Var(gaWeeksKey).ge(34),
        const Var(gaWeeksKey).le(36),
      ]),
    ),
    QuestionUse(qDob, when: _eligible, required: true),
    QuestionUse(qRopFollowUpAssured, when: _eligible, required: true),
    QuestionUse(qRopExamDone, when: _eligible, required: true),
    QuestionUse(qRopExamDate, when: _examined, required: true),
    ..._eyeUses(RopEye.right, ropRightQuestions, _examined),
    QuestionUse(qRopLeftSame, when: _examined),
    ..._eyeUses(
      RopEye.left,
      ropLeftQuestions,
      AllOf([_examined, Not(const Var(ropLeftSameKey).eq(true))]),
    ),
    QuestionUse(qRopNextExamDate, when: _eligible),
    QuestionUse(qRopNextExamPlace, when: _eligible),
    QuestionUse(qRopCounselled, when: _eligible),
    QuestionUse(qRopFacility, when: _eligible),
    QuestionUse(qRopSncuNo, when: _eligible),
  ],
  variables: ropVariables,
  rules: ropRules,
  recordTextKey: ropSummaryTextKey,
);
