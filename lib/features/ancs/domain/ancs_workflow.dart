/// Antenatal Corticosteroids (ANCS) workflow for the dynamic assessment
/// engine.
///
/// Pure Dart. Questions, derived variables and rules only; the decision is
/// made by `ancs_rules.dart` and all wording comes from `ancs_content.dart`
/// (verbatim from the STW PDF). The person assessed is a pregnant woman, so
/// the shared baby questions are not used and no identifier is asked.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'ancs_content.dart';
import 'ancs_rules.dart';

const _ancs = NeonatalCondition.ancs;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const ancsGaWeeksKey = 'ancs_ga_weeks';
const ancsGaDaysKey = 'ancs_ga_days';
const ancsCausesKey = 'ancs_causes';
const ancsGaAccurateKey = 'ancs_ga_accurate';
const ancsInfectionKey = 'ancs_infection';
const ancsChildbirthCareKey = 'ancs_childbirth_care';
const ancsNewbornCareKey = 'ancs_newborn_care';
const ancsPreviousCourseKey = 'ancs_previous_course';
const ancsDaysSincePreviousKey = 'ancs_days_since_previous';
const ancsSpecialKey = 'ancs_special';
const ancsLevel2Key = 'ancs_facility_level2';

// Derived variables
const ancsInWindowKey = 'ancs_in_window';
const ancsLikelyKey = 'ancs_likely';
const ancsResultKey = 'ancs_result';
const ancsDecisionKey = 'ancs_decision';

// Findings
const ancsGiveId = 'ancs.give';
const ancsRepeatId = 'ancs.repeat';
const ancsDrugNoteId = 'ancs.drugNote';
const ancsDoNotGiveId = 'ancs.doNotGive';
const ancsNotMetId = 'ancs.notMet';
const ancsSpecialId = 'ancs.special';
const ancsReferralId = 'ancs.referral';
const ancsDocumentationId = 'ancs.documentation';
const ancsPendingId = 'ancs.pending';

// ---------------------------------------------------------------------------
// Sources (PDF box headings; region ids in assets/regions/regions.json)
// ---------------------------------------------------------------------------

const _srcWhenToGive = SourceReference.ancs(
  'WHEN TO GIVE',
  regionId: 'ancs_when_to_give',
);
const _srcEligibility = SourceReference.ancs(
  'ELIGIBILITY CRITERIA',
  regionId: 'ancs_eligibility',
);
const _srcDrug = SourceReference.ancs(
  'DRUG & DOSE',
  regionId: 'ancs_drug_dose',
);
const _srcNotGive = SourceReference.ancs(
  'WHEN NOT TO GIVE',
  regionId: 'ancs_when_not_to_give',
);
const _srcSpecial = SourceReference.ancs(
  'SPECIAL SITUATIONS',
  regionId: 'ancs_special_situations',
);
const _srcRepeat = SourceReference.ancs(
  'WHEN TO GIVE REPEAT COURSE',
  regionId: 'ancs_repeat_course',
);
const _srcDocumentation = SourceReference.ancs(
  'DOCUMENTATION',
  regionId: 'ancs_documentation',
);
const _srcReferral = SourceReference.ancs(
  'REFERRAL/TRANSFER',
  regionId: 'ancs_referral',
);

// ---------------------------------------------------------------------------
// Questions (wording from the STW)
// ---------------------------------------------------------------------------

const ancsGroups = [
  QuestionGroup(
    'ancs_ga',
    'Gestational age',
    subtitle: 'Pregnant woman — no name, MRN, date of birth or phone is '
        'recorded.',
    questionOrder: [ancsGaWeeksKey, ancsGaDaysKey],
  ),
  QuestionGroup(
    'ancs_likelihood',
    'High likelihood of preterm birth within the next 7 days',
    subtitle: 'Due to any one (tick all that apply; none = unlikely)',
  ),
  QuestionGroup(
    'ancs_criteria',
    'Eligibility criteria 2–5',
    questionOrder: [
      ancsGaAccurateKey,
      ancsInfectionKey,
      ancsChildbirthCareKey,
      ancsNewbornCareKey,
    ],
  ),
  QuestionGroup(
    'ancs_course',
    'Previous ACS course',
    questionOrder: [ancsPreviousCourseKey, ancsDaysSincePreviousKey],
  ),
  QuestionGroup('ancs_special', 'Special situations'),
  QuestionGroup('ancs_referral', 'Referral / transfer'),
];

const qAncsGaWeeks = ClinicalQuestion(
  id: ancsGaWeeksKey,
  group: 'ancs_ga',
  question: 'Gestational age (completed weeks)',
  type: QuestionType.numeric,
  min: 20,
  max: 44,
  unit: 'weeks',
  helper: 'Eligibility window: 24+0 to 33+6 weeks',
  sources: [_srcWhenToGive, _srcEligibility, _srcNotGive],
);

const qAncsGaDays = ClinicalQuestion(
  id: ancsGaDaysKey,
  group: 'ancs_ga',
  question: '+ days',
  type: QuestionType.numeric,
  min: 0,
  max: 6,
  unit: 'd',
  sources: [_srcWhenToGive],
);

final qAncsCauses = ClinicalQuestion(
  id: ancsCausesKey,
  group: 'ancs_likelihood',
  question: ancsCriterion1,
  type: QuestionType.multipleChoice,
  options: [for (final c in AncsCause.values) QuestionOption(c.name, c.label)],
  sources: const [_srcEligibility, _srcNotGive],
);

const _yesNo = [QuestionOption(true, 'Yes'), QuestionOption(false, 'No')];

const qAncsGaAccurate = ClinicalQuestion(
  id: ancsGaAccurateKey,
  group: 'ancs_criteria',
  question: ancsCriterion2,
  type: QuestionType.singleChoice,
  options: _yesNo,
  sources: [_srcEligibility],
);

const qAncsInfection = ClinicalQuestion(
  id: ancsInfectionKey,
  group: 'ancs_criteria',
  question: 'Clinical chorioamnionitis or systemic maternal infection',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Present'),
    QuestionOption(false, 'Absent'),
  ],
  sources: [_srcEligibility, _srcNotGive],
);

const qAncsChildbirthCare = ClinicalQuestion(
  id: ancsChildbirthCareKey,
  group: 'ancs_criteria',
  question: ancsCriterion4,
  type: QuestionType.singleChoice,
  options: _yesNo,
  sources: [_srcEligibility],
);

const qAncsNewbornCare = ClinicalQuestion(
  id: ancsNewbornCareKey,
  group: 'ancs_criteria',
  question: ancsCriterion5,
  type: QuestionType.singleChoice,
  options: _yesNo,
  sources: [_srcEligibility],
);

final qAncsPreviousCourse = ClinicalQuestion(
  id: ancsPreviousCourseKey,
  group: 'ancs_course',
  question: 'ACS courses already given in this pregnancy',
  type: QuestionType.singleChoice,
  options: [
    for (final p in AncsPreviousCourse.values) QuestionOption(p.name, p.label),
  ],
  sources: const [_srcRepeat, _srcNotGive],
);

final qAncsDaysSincePrevious = ClinicalQuestion(
  id: ancsDaysSincePreviousKey,
  group: 'ancs_course',
  question: 'Days since the previous ACS course was started',
  type: QuestionType.numeric,
  min: 0,
  max: 120,
  unit: 'days',
  helper: 'Repeat course only if started ≥7 days earlier',
  visibleWhen: const Var(ancsPreviousCourseKey).eq(AncsPreviousCourse.one.name),
  sources: const [_srcRepeat],
);

final qAncsSpecial = ClinicalQuestion(
  id: ancsSpecialKey,
  group: 'ancs_special',
  question: 'Special situations present (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    for (final s in AncsSpecialSituation.values)
      QuestionOption(s.name, s.label),
  ],
  sources: const [_srcSpecial],
);

const qAncsLevel2 = ClinicalQuestion(
  id: ancsLevel2Key,
  group: 'ancs_referral',
  question: 'This facility has at least level II care (CPAP) for preterm '
      'infants',
  type: QuestionType.singleChoice,
  options: _yesNo,
  sources: [_srcReferral],
);

// ---------------------------------------------------------------------------
// Derived variables
// ---------------------------------------------------------------------------

Set<String> _set(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

bool? _bool(Object? v) => v is bool ? v : null;

AncsInput _input(VariableReader r) {
  final causes = r.valueOf(ancsCausesKey);
  final previous = r.valueOf(ancsPreviousCourseKey);
  return AncsInput(
    gaWeeks: r.valueOf(ancsGaWeeksKey) as int?,
    gaDays: r.valueOf(ancsGaDaysKey) as int?,
    gaAccurate: _bool(r.valueOf(ancsGaAccurateKey)),
    causes: causes is Set
        ? {for (final c in _set(causes)) AncsCause.values.byName(c)}
        : null,
    infection: _bool(r.valueOf(ancsInfectionKey)),
    childbirthCare: _bool(r.valueOf(ancsChildbirthCareKey)),
    newbornCare: _bool(r.valueOf(ancsNewbornCareKey)),
    previousCourse: previous is String
        ? AncsPreviousCourse.values.byName(previous)
        : null,
    daysSincePrevious: r.valueOf(ancsDaysSincePreviousKey) as int?,
  );
}

AncsResult? _result(VariableReader r) => r.valueOf(ancsResultKey) as AncsResult?;

final ancsVariables = [
  ClinicalVariable(ancsInWindowKey, 'GA 24+0 to 33+6 weeks', (r) {
    final w = r.valueOf(ancsGaWeeksKey);
    return w is int ? ancsGaInWindow(w) : null;
  }),
  ClinicalVariable(
    ancsLikelyKey,
    'High likelihood of preterm birth within 7 days (any listed cause)',
    (r) {
      final c = r.valueOf(ancsCausesKey);
      return c is Set ? c.isNotEmpty : null;
    },
  ),
  ClinicalVariable(
    ancsResultKey,
    'ancs_rules evaluateAncs()',
    (r) => r.valueOf(ancsGaWeeksKey) is int ? evaluateAncs(_input(r)) : null,
  ),
  ClinicalVariable(
    ancsDecisionKey,
    'ACS decision',
    (r) => _result(r)?.decision.name,
  ),
];

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

Cond _decision(AncsDecision d) => const Var(ancsDecisionKey).eq(d.name);
final _likely = const Var(ancsLikelyKey).eq(true);
final _giving = AnyOf([
  _decision(AncsDecision.giveInitial),
  _decision(AncsDecision.giveRepeat),
]);

final ancsRules = <ClinicalRule>[
  ClinicalRule(
    id: ancsGiveId,
    topic: _ancs,
    when: _decision(AncsDecision.giveInitial),
    source: _srcEligibility,
    then: (r) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: 'GIVE ACS',
      actions: const [ancsDrugDose, ancsImportant],
      why: [ancsEligibilityHeading, ..._result(r)!.metCriteria],
    ),
  ),
  ClinicalRule(
    id: ancsRepeatId,
    topic: _ancs,
    when: _decision(AncsDecision.giveRepeat),
    source: const SourceReference.ancs(
      'WHEN TO GIVE REPEAT COURSE',
      regionId: 'ancs_repeat_course',
      needsClinicalReview: true,
      note: 'The repeat-course box lists three criteria; the app also '
          'requires eligibility criteria 2–5 (open question A3). The STW '
          'gives one regimen under DRUG & DOSE (open question A4).',
    ),
    then: (r) => FindingContent(
      category: FindingCategory.treatment,
      level: FindingLevel.treat,
      title: 'GIVE ONE REPEAT COURSE',
      actions: const [
        ancsDrugDose,
        ancsRepeatNoMore,
        ancsRepeatHarm,
        ancsImportant,
      ],
      why: [ancsRepeatHeading, ..._result(r)!.metCriteria],
    ),
  ),
  ClinicalRule(
    id: ancsDrugNoteId,
    topic: _ancs,
    when: _giving,
    source: _srcDrug,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'DRUG & DOSE',
      actions: [ancsDrugDose, ancsDexaPreferred, ancsBetaNote],
    ),
  ),
  ClinicalRule(
    id: ancsDoNotGiveId,
    topic: _ancs,
    when: _decision(AncsDecision.doNotGive),
    source: _srcNotGive,
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'Do NOT give ACS',
      actions: [
        for (final reason in _result(r)!.doNotGiveReasons)
          'WHEN NOT TO GIVE: $reason',
      ],
      why: _result(r)!.unmetCriteria.map((c) => 'Also not met: $c').toList(),
    ),
  ),
  ClinicalRule(
    id: ancsNotMetId,
    topic: _ancs,
    when: _decision(AncsDecision.criteriaNotMet),
    source: const SourceReference.ancs(
      'ELIGIBILITY CRITERIA',
      regionId: 'ancs_eligibility',
      needsClinicalReview: true,
      note: 'GA <24+0 weeks is outside the window but not listed under WHEN '
          'NOT TO GIVE (open question A1).',
    ),
    then: (r) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.action,
      title: 'ACS eligibility criteria not met',
      actions: [
        for (final c in _result(r)!.unmetCriteria) 'Not met: $c',
      ],
      why: [ancsEligibilityHeading, ..._result(r)!.metCriteria],
    ),
  ),
  ClinicalRule(
    id: ancsSpecialId,
    topic: _ancs,
    when: AllOf([
      _likely,
      AnyOf([
        for (final s in AncsSpecialSituation.values)
          const Var(ancsSpecialKey).contains(s.name),
      ]),
    ]),
    source: _srcSpecial,
    then: (r) {
      final ticked = _set(r.valueOf(ancsSpecialKey));
      return FindingContent(
        category: FindingCategory.assessment,
        level: FindingLevel.info,
        title: 'SPECIAL SITUATIONS',
        actions: [
          ancsSpecialDoNotWithhold,
          if (ticked.contains(AncsSpecialSituation.diabetes.name)) ...[
            ancsSpecialDiabetes,
            ancsDos[2],
          ],
        ],
        why: [
          for (final s in AncsSpecialSituation.values)
            if (ticked.contains(s.name)) 'Present: ${s.label}',
        ],
      );
    },
  ),
  ClinicalRule(
    id: ancsReferralId,
    topic: _ancs,
    when: AllOf([_likely, const Var(ancsLevel2Key).eq(false)]),
    source: const SourceReference.ancs(
      'REFERRAL/TRANSFER',
      regionId: 'ancs_referral',
      needsClinicalReview: true,
      note: '"Likelihood of early preterm birth" is not defined; the app uses '
          'criterion 1 within 24+0 to 33+6 weeks (open question A5).',
    ),
    then: (_) => const FindingContent(
      category: FindingCategory.referral,
      level: FindingLevel.urgent,
      title: 'REFERRAL/TRANSFER (in-utero transfer)',
      actions: [ancsReferral, ancsLevelOne],
      why: ['This facility: no level II care (CPAP) for preterm infants'],
    ),
  ),
  ClinicalRule(
    id: ancsDocumentationId,
    topic: _ancs,
    when: _giving,
    source: _srcDocumentation,
    then: (_) => const FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.info,
      title: 'DOCUMENTATION',
      actions: [ancsDocument, ancsRecordIn],
    ),
  ),
  ClinicalRule(
    id: ancsPendingId,
    topic: _ancs,
    when: _decision(AncsDecision.incomplete),
    source: _srcEligibility,
    then: (_) => const FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'ACS decision pending',
      actions: ['Complete the remaining eligibility questions.'],
    ),
  ),
];

// ---------------------------------------------------------------------------
// Workflow
// ---------------------------------------------------------------------------

final _inWindow = const Var(ancsInWindowKey).eq(true);
final _inWindowAndLikely = AllOf([_inWindow, _likely]);

final ancsWorkflow = StwWorkflow(
  _ancs,
  source: const SourceReference.ancs('Whole document (August 2026)'),
  groups: ancsGroups,
  uses: [
    const QuestionUse(qAncsGaWeeks, required: true),
    const QuestionUse(qAncsGaDays, required: true),
    QuestionUse(qAncsCauses, when: _inWindow),
    QuestionUse(qAncsGaAccurate, when: _inWindowAndLikely, required: true),
    QuestionUse(qAncsInfection, when: _inWindowAndLikely, required: true),
    QuestionUse(qAncsChildbirthCare, when: _inWindowAndLikely, required: true),
    QuestionUse(qAncsNewbornCare, when: _inWindowAndLikely, required: true),
    QuestionUse(qAncsPreviousCourse, when: _inWindowAndLikely, required: true),
    QuestionUse(
      qAncsDaysSincePrevious,
      when: _inWindowAndLikely,
      required: true,
    ),
    QuestionUse(qAncsSpecial, when: _inWindowAndLikely),
    QuestionUse(qAncsLevel2, when: _inWindowAndLikely, required: true),
  ],
  variables: ancsVariables,
  rules: ancsRules,
  subjectLabel: 'Pregnant woman',
  subjectLine: (r) => describeAncsGa(
    r.valueOf(ancsGaWeeksKey) as int?,
    r.valueOf(ancsGaDaysKey) as int?,
  ),
);
