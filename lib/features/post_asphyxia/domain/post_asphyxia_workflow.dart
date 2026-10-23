/// PDF-only Post Asphyxia workflow in the existing persisted `hie` slot.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'post_asphyxia_content.dart';
import 'post_asphyxia_rules.dart';

const paStability = 'post_asphyxia_stability';
const paStage = 'post_asphyxia_stage';
const paSeizures = 'post_asphyxia_seizures';
const paWorsening = 'post_asphyxia_worsening';
const paGa = 'post_asphyxia_ga';
const paAcuteHypoxia = 'post_asphyxia_acute_hypoxia';
const paHighRisk = 'post_asphyxia_high_risk';
const paCooling = 'post_asphyxia_potential_cooling';

SourceReference postAsphyxiaSource(String suffix) =>
    SourceReference.postAsphyxia(postAsphyxiaHeadings['post_asphyxia_$suffix']!,
        regionId: 'post_asphyxia_$suffix');

ClinicalQuestion _choice(String key, String group, String text,
        List<QuestionOption> options, String section, {String? helper}) =>
    ClinicalQuestion(
        id: key,
        group: group,
        question: text,
        type: QuestionType.singleChoice,
        options: options,
        helper: helper,
        sources: [postAsphyxiaSource(section)]);

const _yesNoUnknown = [
  QuestionOption('yes', 'Yes'),
  QuestionOption('no', 'No'),
  QuestionOption('unknown', 'Not known / not assessed')
];

ClinicalQuestion _number(String key, String group, String text, String section,
        {String? unit, bool integer = false, int? min, int? max}) =>
    ClinicalQuestion(
        id: key,
        group: group,
        question: text,
        type: integer ? QuestionType.numeric : QuestionType.decimal,
        min: min,
        max: max,
        unit: unit,
        sources: [postAsphyxiaSource(section)]);

final qPaStability = _choice(
    paStability,
    'pa_initial',
    'Current physiological stability (clinical assessment)',
    const [
      QuestionOption('stable', 'Stable'),
      QuestionOption('unstable', 'Unstable'),
      QuestionOption('unknown', 'Not known / requires assessment')
    ],
    'stabilize',
    helper:
        'Breathing • Perfusion • Temperature • Glucose. If unstable: stabilize, contact referral NICU and arrange urgent transfer for advanced care.');
final qPaSeizures = _choice(
    paSeizures, 'pa_initial', 'Seizures present?', _yesNoUnknown, 'seizures',
    helper: postAsphyxiaEvidence['post_asphyxia_seizures']!.join('\n'));
final qPaWorsening = _choice(paWorsening, 'pa_initial',
    'Neurological examination worsening?', _yesNoUnknown, 'mild');
final qPaRisk = ClinicalQuestion(
    id: 'post_asphyxia_risk_signs',
    group: 'pa_initial',
    question: 'Identify risk (record observed features)',
    type: QuestionType.multipleChoice,
    options: const [
      QuestionOption('resuscitation', 'Resuscitation'),
      QuestionOption('cry', 'Delayed cry'),
      QuestionOption('event', 'Acute perinatal event'),
      QuestionOption('neurological', 'Abnormal neurological signs')
    ],
    helper: 'An unselected feature is not proof that risk is absent.',
    sources: [postAsphyxiaSource('risk')]);

// The PDF does not define an aggregation rule for mixed Sarnat domains.
// Observations remain separate; only the clinician records the overall stage.
const paDomains = <(String, String, List<String>)>[
  (
    'consciousness',
    'Consciousness',
    ['Hyperalert', 'Lethargic', 'Stupor / coma']
  ),
  (
    'activity',
    'Spontaneous activity',
    ['Normal / increased', 'Decreased', 'Absent']
  ),
  ('posture', 'Posture', ['Normal', 'Distal flexion', 'Decerebrate']),
  ('tone', 'Tone', ['Normal / increased', 'Hypotonia', 'Flaccid']),
  (
    'reflexes',
    'Primitive reflexes',
    [
      'Suck: normal / incomplete; Moro: exaggerated',
      'Suck: weak; Moro: incomplete',
      'Suck / Moro: absent'
    ]
  ),
  (
    'autonomic',
    'Autonomic signs',
    [
      'Pupils: normal; HR: normal / fast; Breathing: regular',
      'Pupils: constricted; HR: slow; Breathing: periodic / irregular',
      'Pupils: dilated / deviated; HR: variable; breathing: apnoea'
    ]
  ),
];
final paDomainQuestions = [
  for (final (key, title, cells) in paDomains)
    _choice(
        'post_asphyxia_domain_$key',
        'pa_sarnat',
        title,
        [
          for (var i = 0; i < 3; i++)
            QuestionOption(['mild', 'moderate', 'severe'][i],
                '${['Mild', 'Moderate', 'Severe'][i]}: ${cells[i]}'),
          const QuestionOption('unknown', 'Not assessed / mixed findings')
        ],
        'sarnat')
];
final qPaStage = _choice(
    paStage,
    'pa_sarnat',
    'Overall neurological examination / HIE stage (clinician assessed)',
    const [
      QuestionOption('normal', 'Normal examination'),
      QuestionOption('mild', 'Mild HIE'),
      QuestionOption('moderate', 'Moderate HIE'),
      QuestionOption('severe', 'Severe HIE'),
      QuestionOption('unknown', 'Uncertain / requires clinical review')
    ],
    'sarnat',
    helper:
        'Record seizures separately. Repeat serial assessments. Initial normal examination does not exclude evolving HIE. The PDF gives no rule to combine mixed domain findings; no stage is calculated by the app.');

num? _num(VariableReader r, String key) =>
    r.valueOf(key) is num ? r.valueOf(key) as num : null;
String? _str(VariableReader r, String key) => r.valueOf(key) as String?;
const _always = AllOf([]);
const _stable = Compare(paStability, CmpOp.eq, 'stable');
const _moderateSevere = Compare(paStage, CmpOp.isIn, ['moderate', 'severe']);
const _urgent =
    AnyOf([Compare(paStability, CmpOp.eq, 'unstable'), _moderateSevere]);

ClinicalRule _evidence(String suffix, Cond when,
        {String? title,
        FindingLevel level = FindingLevel.info,
        FindingCategory category = FindingCategory.pathway}) =>
    ClinicalRule(
        id: 'post_asphyxia.$suffix',
        topic: NeonatalCondition.hie,
        when: when,
        source: postAsphyxiaSource(suffix),
        then: (_) => FindingContent(
            category: category,
            level: level,
            title: title ?? postAsphyxiaHeadings['post_asphyxia_$suffix']!,
            actions: postAsphyxiaEvidence['post_asphyxia_$suffix']!));

final postAsphyxiaWorkflow = StwWorkflow(
  NeonatalCondition.hie,
  subjectLabel: 'Post Asphyxia assessment',
  subjectLine: (r) =>
      'GA at birth: ${_num(r, paGa)?.toString() ?? "not recorded"}'
      '${_num(r, paGa) == null ? "" : " weeks"} · '
      'Clinician-recorded examination: ${_str(r, paStage) ?? "not recorded"}',
  source: const SourceReference.postAsphyxia(
      'POST-ASPHYXIAL MANAGEMENT OF NEONATES',
      regionId: 'post_asphyxia_risk'),
  groups: const [
    QuestionGroup('pa_initial', 'Identify risk and stabilize',
        subtitle:
            'Record current findings. Stabilize breathing, perfusion, temperature and glucose.',
        footnote:
            'Seizures: Act immediately. Stabilize airway and breathing → Phenobarbitone 20 mg/kg IV over 15 min (Refer to Seizures STW). Check and correct blood glucose and calcium concurrently; urgent NICU consultation / referral.'),
    QuestionGroup('pa_sarnat', 'Modified Sarnat assessment',
        subtitle:
            'Record each domain and the clinician-assessed overall stage. The app does not infer a stage from mixed findings.'),
    QuestionGroup(
        'pa_referral', 'High-risk features and time-critical referral',
        subtitle:
            'Enter known observations. Potential TH candidates require immediate discussion with referral NICU and confirmation of strict NNF criteria.'),
  ],
  uses: [
    QuestionUse(qPaStability, required: true),
    QuestionUse(qPaSeizures, required: true),
    QuestionUse(qPaWorsening, required: true),
    QuestionUse(qPaRisk),
    for (final q in paDomainQuestions) QuestionUse(q),
    QuestionUse(qPaStage, required: true),
    QuestionUse(_number('post_asphyxia_apgar10', 'pa_referral',
        'Apgar at 10 minutes', 'high_risk',
        integer: true, min: 0, max: 10)),
    QuestionUse(_choice('post_asphyxia_ppv10', 'pa_referral',
        'Still requiring PPV at 10 minutes?', _yesNoUnknown, 'high_risk')),
    QuestionUse(_choice(
        'post_asphyxia_sample',
        'pa_referral',
        'Blood gas sample timing',
        const [
          QuestionOption('cord', 'Cord sample'),
          QuestionOption('within1h', 'Within 1 hour'),
          QuestionOption('later', 'Later than 1 hour'),
          QuestionOption('unknown', 'Not known / not available')
        ],
        'high_risk')),
    QuestionUse(_number(
        'post_asphyxia_ph', 'pa_referral', 'Blood gas pH', 'high_risk')),
    QuestionUse(_number('post_asphyxia_base_deficit', 'pa_referral',
        'Base deficit', 'high_risk',
        unit: 'mmol/L')),
    QuestionUse(_number(
        paGa, 'pa_referral', 'Gestational age at birth', 'cooling',
        unit: 'weeks')),
    QuestionUse(_choice(
        paAcuteHypoxia,
        'pa_referral',
        'Evidence of acute perinatal hypoxia (clinical assessment)?',
        _yesNoUnknown,
        'cooling')),
  ],
  variables: [
    ClinicalVariable(
        paHighRisk,
        'At least one printed high-risk feature documented',
        (r) => hasPostAsphyxiaHighRisk(
            apgar10: _num(r, 'post_asphyxia_apgar10'),
            ppv10: _str(r, 'post_asphyxia_ppv10') == 'yes',
            sampleTiming: _str(r, 'post_asphyxia_sample'),
            ph: _num(r, 'post_asphyxia_ph'),
            baseDeficit: _num(r, 'post_asphyxia_base_deficit'))),
    ClinicalVariable(
        paCooling,
        'Potential TH referral candidate, not final eligibility',
        (r) => isPotentialCoolingCandidate(
            gaWeeks: _num(r, paGa),
            stage: _str(r, paStage),
            acuteHypoxia: _str(r, paAcuteHypoxia))),
  ],
  rules: [
    _evidence('seizures', const Var(paSeizures).eq('yes'),
        level: FindingLevel.urgent, category: FindingCategory.alert),
    _evidence('urgent', _urgent,
        level: FindingLevel.urgent, category: FindingCategory.referral),
    _evidence(
        'normal',
        AllOf([
          _stable,
          const Var(paStage).eq('normal'),
          const Var(paSeizures).eq('no'),
          const Var(paWorsening).eq('no')
        ]),
        level: FindingLevel.action),
    _evidence('mild', AllOf([_stable, const Var(paStage).eq('mild')]),
        level: FindingLevel.action),
    ClinicalRule(
        id: 'post_asphyxia.review',
        topic: NeonatalCondition.hie,
        when: AnyOf([
          const Var(paStage).eq('unknown'),
          const Var(paStability).eq('unknown'),
          const Var(paSeizures).eq('unknown'),
          const Var(paWorsening).eq('unknown'),
          AllOf([
            const Var(paStage).eq('normal'),
            const Var(paWorsening).eq('yes')
          ])
        ]),
        source: const SourceReference.postAsphyxia('MODIFIED SARNAT STAGING',
            regionId: 'post_asphyxia_sarnat',
            needsClinicalReview: true,
            note:
                'The supplied PDF does not define how to aggregate mixed domain findings. Overall stage and unknown findings require clinical review.'),
        then: (_) => const FindingContent(
                category: FindingCategory.furtherAssessment,
                level: FindingLevel.action,
                title: 'Clinical assessment incomplete / uncertain',
                actions: [
                  'Review the recorded neurological examination and physiological stability. No normal examination, overall HIE stage or final TH eligibility has been inferred.'
                ])),
    ClinicalRule(
        id: 'post_asphyxia.worsening',
        topic: NeonatalCondition.hie,
        when: AllOf(
            [const Var(paStage).eq('mild'), const Var(paWorsening).eq('yes')]),
        source: postAsphyxiaSource('mild'),
        then: (_) => const FindingContent(
            category: FindingCategory.referral,
            level: FindingLevel.urgent,
            title: 'Neurological worsening: urgent review/referral',
            actions: ['Seizures/worsening: Urgent review/referral'])),
    _evidence('high_risk', const Var(paHighRisk).eq(true),
        level: FindingLevel.action),
    _evidence('cooling', _always,
        title: 'Therapeutic hypothermia: referral guidance'),
    ClinicalRule(
        id: 'post_asphyxia.potentialCooling',
        topic: NeonatalCondition.hie,
        when: const Var(paCooling).eq(true),
        source: postAsphyxiaSource('cooling'),
        then: (_) => FindingContent(
                category: FindingCategory.referral,
                level: FindingLevel.urgent,
                title:
                    'Potential TH candidate — discuss immediately with referral NICU',
                actions: postAsphyxiaEvidence['post_asphyxia_cooling']!,
                why: const [
                  'Potential referral criteria recorded; final eligibility requires confirmation of strict NNF criteria.'
                ])),
    for (final suffix in [
      'stabilize',
      'sarnat',
      'serial',
      'oxygen',
      'perfusion',
      'neurological',
      'temperature',
      'glucose',
      'fluids',
      'feeding',
      'discharge',
      'dos',
      'donts',
      'kpis'
    ])
      _evidence(suffix, _always),
    // The banner text is its own heading; avoid repeating it as the title.
    _evidence('key_message', _always, title: 'Key message'),
  ],
);
