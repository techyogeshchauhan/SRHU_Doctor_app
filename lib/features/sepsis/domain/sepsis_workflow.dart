/// Sepsis in neonates, ICD-10-P36; supplied updated PDF only.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'sepsis_content.dart';
import 'sepsis_rules.dart';

const sepsisStageKey = 'sepsis_stage';
const sepsisAgeKey = 'sepsis_age_hours';
const sepsisGaKey = 'sepsis_gestation_weeks';
const sepsisBwKey = 'sepsis_birth_weight_g';
const sepsisRedKey = 'sepsis_red_flags';
const sepsisMaternalRedKey = 'sepsis_maternal_red';
const sepsisYellowKey = 'sepsis_yellow_signs';
const sepsisMaternalKey = 'sepsis_maternal_risks';
const sepsisClassKey = 'sepsis_classification';
const sepsisNewFlagKey = 'sepsis_another_flag';
const sepsisCulturePositiveKey = 'sepsis_observation_positive_culture';
const sepsisReviewKey = 'sepsis_review_status';
const sepsisWellKey = 'sepsis_day5_well';
const sepsisSterileKey = 'sepsis_48h_culture_sterile';
const sepsisCsfNormalKey = 'sepsis_csf_normal';
const sepsisDurationKey = 'sepsis_duration_condition';

const sepsisRedSource =
    SourceReference.sepsis('RED FLAGS', regionId: 'sepsis_red_flags');
const sepsisYellowSource = SourceReference.sepsis(
    'YELLOW FLAGS: SIGNS OR MATERNAL RISK FACTORS',
    regionId: 'sepsis_yellow_signs');
const sepsisMaternalSource = SourceReference.sepsis('Maternal risk factors',
    regionId: 'sepsis_maternal_risks');
const sepsisHighSource = SourceReference.sepsis('HIGH PROBABILITY OF SEPSIS',
    regionId: 'sepsis_high_probability');
const sepsisObserveSource = SourceReference.sepsis('AT-RISK / SUSPECT SEPSIS',
    regionId: 'sepsis_observation');
const sepsisDurationSource = SourceReference.sepsis('DURATION OF ANTIBIOTICS',
    regionId: 'sepsis_duration');
const sepsisDay5Source =
    SourceReference.sepsis('Review at 5 days', regionId: 'sepsis_review_day5');
const _entry =
    SourceReference.dataEntry('Choose the current assessment or review stage.');

final _initial = const Var(sepsisStageKey).isIn({'initial', 'observation'});
final _young = AllOf([_initial, const Var(sepsisAgeKey).lt(72)]);

const qSepsisStage = ClinicalQuestion(
  id: sepsisStageKey,
  group: 'sepsis_stage',
  question: 'Sepsis assessment stage',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption('initial', 'Initial assessment'),
    QuestionOption('observation', 'During serial observation'),
    QuestionOption('review48', 'Review at 48 hours after starting antibiotics'),
    QuestionOption('review5', 'Review at 5 days if antibiotics were continued'),
    QuestionOption('duration',
        'Antibiotic duration — select the applicable PDF condition'),
  ],
  sources: [_entry],
);
const qSepsisAge = ClinicalQuestion(
  id: sepsisAgeKey,
  group: 'sepsis_flags',
  question: 'Age of baby',
  type: QuestionType.decimal,
  unit: 'hours',
  min: 0,
  helper:
      'Maternal red/yellow risk factors apply only if age is less than 72 hours.',
  sources: [sepsisRedSource, sepsisMaternalSource],
);
const qSepsisGa = ClinicalQuestion(
  id: sepsisGaKey,
  group: 'sepsis_flags',
  question: 'Gestation at birth',
  type: QuestionType.decimal,
  unit: 'weeks',
  min: 0,
  helper: 'Leave blank if unknown. The PDF uses ≤32 weeks and >32 weeks.',
  sources: [sepsisHighSource, sepsisObserveSource],
);
const qSepsisBw = ClinicalQuestion(
  id: sepsisBwKey,
  group: 'sepsis_flags',
  question: 'Birth weight',
  type: QuestionType.numeric,
  unit: 'g',
  min: 0,
  helper:
      'Leave blank if unknown. The high-probability criterion uses <1500 g.',
  sources: [sepsisHighSource],
);
const qSepsisRed = ClinicalQuestion(
  id: sepsisRedKey,
  group: 'sepsis_flags',
  question: 'Red flags — select all present',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('shock', 'Shock'),
    QuestionOption('bleeding', 'Bleeding from multiple sites'),
    QuestionOption('sclerema', 'Sclerema — hardened skin over cheeks / thighs'),
    QuestionOption('respiratory',
        'Respiratory distress needing intubation or Silverman’s score >5'),
  ],
  sources: [sepsisRedSource],
);
const qSepsisMaternalRed = ClinicalQuestion(
  id: sepsisMaternalRedKey,
  group: 'sepsis_flags',
  question: 'Mother has foul-smelling liquor or chorioamnionitis?',
  type: QuestionType.boolean,
  helper: 'Red flag only while the baby is less than 72 hours old.',
  sources: [sepsisRedSource],
);
const qSepsisYellow = ClinicalQuestion(
  id: sepsisYellowKey,
  group: 'sepsis_flags',
  question: 'Yellow signs — select all present',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('seizure', 'Seizures'),
    QuestionOption('refusal', 'Refusal to feed'),
    QuestionOption(
        'hr', 'HR >180 persisting for one hour despite normal temperature'),
    QuestionOption('rr', 'Fast breathing (RR >60/min)'),
    QuestionOption('floppy', 'Floppiness'),
    QuestionOption('lethargy', 'Lethargy'),
    QuestionOption('intolerance', 'Feed intolerance'),
    QuestionOption('apnea', 'New or increased apneic episodes'),
    QuestionOption('temperature',
        'Fever, or hypothermia <36.0°C not corrected by rewarming'),
  ],
  sources: [sepsisYellowSource],
);
const qSepsisMaternal = ClinicalQuestion(
  id: sepsisMaternalKey,
  group: 'sepsis_flags',
  question: 'Maternal yellow risk factors — select all present',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('pv', '>3 PV examinations during labour'),
    QuestionOption('rom', 'Rupture of membranes >24 hrs'),
    QuestionOption('pprom', 'pPROM'),
    QuestionOption('uti', 'Urinary tract infection'),
    QuestionOption('diarrhea', 'Diarrhea'),
    QuestionOption('fever', 'Fever >38°C'),
  ],
  sources: [sepsisMaternalSource],
);
const qSepsisNewFlag = ClinicalQuestion(
  id: sepsisNewFlagKey,
  group: 'sepsis_observation',
  question: 'Has another yellow / red sign appeared during observation?',
  type: QuestionType.singleChoice,
  options: [QuestionOption(true, 'Yes'), QuestionOption(false, 'No')],
  sources: [sepsisObserveSource],
);
const qSepsisPositiveCulture = ClinicalQuestion(
  id: sepsisCulturePositiveKey,
  group: 'sepsis_observation',
  question: 'Is the blood culture positive?',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'Yes'),
    QuestionOption(false, 'No'),
    QuestionOption('unknown', 'Unknown / pending')
  ],
  sources: [sepsisObserveSource],
);
const qSepsisReview = ClinicalQuestion(
  id: sepsisReviewKey,
  group: 'sepsis_review',
  question: 'Signs at the 48-hour review',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption('disappeared', 'Signs of sepsis disappeared'),
    QuestionOption('improving', 'Signs improving but still present'),
    QuestionOption('worsened',
        'Signs worsened, or a red flag appeared after starting treatment'),
  ],
  sources: [
    SourceReference.sepsis('SIGNS OF SEPSIS DISAPPEARED',
        regionId: 'sepsis_review_disappeared'),
    SourceReference.sepsis('SIGNS OF SEPSIS IMPROVING BUT STILL PRESENT',
        regionId: 'sepsis_review_improving'),
    SourceReference.sepsis(
        'SIGNS OF SEPSIS WORSENED, OR A RED FLAG APPEARED AFTER STARTING TREATMENT',
        regionId: 'sepsis_review_worsened'),
  ],
);
ClinicalQuestion _day5Question(String id, String text) => ClinicalQuestion(
      id: id,
      group: 'sepsis_review',
      question: text,
      type: QuestionType.singleChoice,
      options: const [
        QuestionOption(true, 'Yes'),
        QuestionOption(false, 'No'),
        QuestionOption('unknown', 'Unknown / pending')
      ],
      sources: const [sepsisDay5Source],
    );
final qSepsisWell = _day5Question(sepsisWellKey, 'Is the baby now well?');
final qSepsisSterile =
    _day5Question(sepsisSterileKey, 'Is the 48-hour blood culture sterile?');
final qSepsisNormalCsf = _day5Question(sepsisCsfNormalKey, 'Is CSF normal?');
final qSepsisDuration = ClinicalQuestion(
  id: sepsisDurationKey,
  group: 'sepsis_duration',
  question: 'Select the applicable condition exactly as printed in the PDF',
  type: QuestionType.singleChoice,
  helper:
      'Confirm every condition in the selected row. Unknown culture/CSF results do not establish a normal result or absence of meningitis.',
  options: [
    for (final c in SepsisDurationCondition.values)
      QuestionOption(c.name, sepsisEvidence['sepsis_duration']![c.index]),
    const QuestionOption(
        'unconfirmed', 'No table condition confirmed / results pending'),
  ],
  sources: const [sepsisDurationSource],
);

int _count(VariableReader r, String key) =>
    r.valueOf(key) is Set ? (r.valueOf(key) as Set).length : 0;
num? _number(VariableReader r, String key) =>
    r.valueOf(key) is num ? r.valueOf(key) as num : null;

ClinicalRule _evidenceRule(
  String id,
  Cond when,
  String card,
  String title, {
  FindingCategory category = FindingCategory.pathway,
  FindingLevel level = FindingLevel.info,
  List<String>? actions,
}) =>
    ClinicalRule(
      id: 'sepsis.$id',
      topic: NeonatalCondition.sepsis,
      when: when,
      source: SourceReference.sepsis(title, regionId: 'sepsis_$card'),
      then: (_) => FindingContent(
          category: category,
          level: level,
          title: title,
          actions: actions ?? sepsisEvidence['sepsis_$card']!),
    );

final sepsisWorkflow = StwWorkflow(
  NeonatalCondition.sepsis,
  source: const SourceReference.sepsis('SEPSIS IN NEONATES',
      regionId: 'sepsis_assessment'),
  groups: const [
    QuestionGroup('sepsis_stage', 'Sepsis assessment stage'),
    QuestionGroup('sepsis_flags', 'Sepsis signs and risk factors',
        subtitle:
            'Select every applicable sign or risk factor. Leave unavailable measurements blank.'),
    QuestionGroup('sepsis_observation', 'During serial observation'),
    QuestionGroup('sepsis_review', 'Review of antibiotic treatment'),
    QuestionGroup('sepsis_duration', 'Duration of antibiotics'),
  ],
  uses: [
    const QuestionUse(qSepsisStage, required: true),
    QuestionUse(qSepsisAge, when: _initial),
    QuestionUse(qSepsisGa, when: _initial),
    QuestionUse(qSepsisBw, when: _initial),
    QuestionUse(qSepsisRed, when: _initial),
    QuestionUse(qSepsisMaternalRed, when: _young),
    QuestionUse(qSepsisYellow, when: _initial),
    QuestionUse(qSepsisMaternal, when: _young),
    QuestionUse(qSepsisNewFlag,
        when: const Var(sepsisStageKey).eq('observation'), required: true),
    QuestionUse(qSepsisPositiveCulture,
        when: const Var(sepsisStageKey).eq('observation'), required: true),
    QuestionUse(qSepsisReview,
        when: const Var(sepsisStageKey).eq('review48'), required: true),
    QuestionUse(qSepsisWell,
        when: const Var(sepsisStageKey).eq('review5'), required: true),
    QuestionUse(qSepsisSterile,
        when: const Var(sepsisStageKey).eq('review5'), required: true),
    QuestionUse(qSepsisNormalCsf,
        when: const Var(sepsisStageKey).eq('review5'), required: true),
    QuestionUse(qSepsisDuration,
        when: const Var(sepsisStageKey).eq('duration'), required: true),
  ],
  variables: [
    ClinicalVariable(sepsisClassKey,
        'Sepsis classification from the PDF red/yellow criteria', (r) {
      if (r.valueOf(sepsisRedKey) == null ||
          r.valueOf(sepsisYellowKey) == null) {
        return null;
      }
      final age = _number(r, sepsisAgeKey);
      final maternalApplies = age != null && age < 72;
      return classifySepsis(
        redFlags: _count(r, sepsisRedKey) +
            (maternalApplies && r.valueOf(sepsisMaternalRedKey) == true
                ? 1
                : 0),
        yellowFlags: _count(r, sepsisYellowKey) +
            (maternalApplies ? _count(r, sepsisMaternalKey) : 0),
        gestationWeeks: _number(r, sepsisGaKey),
        birthWeightG: _number(r, sepsisBwKey),
      ).name;
    }),
  ],
  rules: [
    _evidenceRule('assessment', const Var(sepsisStageKey).exists(),
        'assessment', 'Assess every neonate'),
    _evidenceRule('high', const Var(sepsisClassKey).eq('highProbability'),
        'high_probability', 'HIGH PROBABILITY OF SEPSIS',
        category: FindingCategory.treatment, level: FindingLevel.urgent),
    _evidenceRule('observe', const Var(sepsisClassKey).eq('observe'),
        'observation', 'AT-RISK / SUSPECT SEPSIS',
        level: FindingLevel.action),
    _evidenceRule(
        'overlap',
        const Var(sepsisClassKey).eq('overlap'),
        'high_probability',
        'Overlapping PDF criteria — clinical review required',
        category: FindingCategory.furtherAssessment,
        level: FindingLevel.action,
        actions: const [
          'One yellow flag with gestation >32 weeks and birth weight <1500 g matches both the HIGH PROBABILITY and AT-RISK / SUSPECT boxes. The PDF does not state precedence.',
          'High probability: one yellow flag AND gestation ≤32 weeks or birth weight <1500 g.',
          'Clinical review is required to resolve the overlapping source criteria.',
        ]),
    _evidenceRule(
        'overlapObservation',
        const Var(sepsisClassKey).eq('overlap'),
        'observation',
        'Overlapping observation criterion — clinical review required',
        category: FindingCategory.furtherAssessment,
        level: FindingLevel.action,
        actions: [
          sepsisEvidence['sepsis_observation']![1],
          'Clinical review is required to resolve the overlapping source criteria.'
        ]),
    _evidenceRule('missing', const Var(sepsisClassKey).eq('incomplete'),
        'high_probability', 'Classification needs gestation / birth weight',
        category: FindingCategory.furtherAssessment,
        level: FindingLevel.action,
        actions: const [
          'One yellow flag is present. Record gestation at birth and birth weight to compare the PDF criteria; unavailable values are not assumed.'
        ]),
    _evidenceRule('none', const Var(sepsisClassKey).eq('noListedCriterion'),
        'assessment', 'No listed classification criterion identified',
        category: FindingCategory.notMet,
        actions: const [
          'The recorded flags do not establish either listed classification criterion. Assess every neonate at admission and during hospital stay for red and yellow flag signs and risk factors.'
        ]),
    _evidenceRule(
        'ageMissing',
        AllOf([_initial, Not(const Var(sepsisAgeKey).exists())]),
        'maternal_risks',
        'Age required to assess maternal risk factors',
        category: FindingCategory.furtherAssessment,
        actions: const [
          'Record the baby’s age to assess maternal risk factors. The PDF restricts these factors to age less than 72 hours.'
        ]),
    _evidenceRule('seizure', const Var(sepsisYellowKey).contains('seizure'),
        'seizure', 'Neonatal seizure — urgent evaluation',
        category: FindingCategory.alert, level: FindingLevel.urgent),
    _evidenceRule('newFlag', const Var(sepsisNewFlagKey).eq(true),
        'observation', 'Another yellow / red sign during observation',
        category: FindingCategory.treatment,
        level: FindingLevel.urgent,
        actions: [...sepsisEvidence['sepsis_observation']!.skip(3)]),
    _evidenceRule(
        'positiveCulture',
        const Var(sepsisCulturePositiveKey).eq(true),
        'observation',
        'Positive blood culture during observation',
        category: FindingCategory.treatment,
        level: FindingLevel.action,
        actions: [sepsisEvidence['sepsis_observation']!.last]),
    for (final state in ['disappeared', 'improving', 'worsened'])
      _evidenceRule(
          'review.$state',
          const Var(sepsisReviewKey).eq(state),
          'review_$state',
          qSepsisReview.options.firstWhere((o) => o.value == state).label,
          category: FindingCategory.followUp,
          level:
              state == 'worsened' ? FindingLevel.urgent : FindingLevel.action),
    _evidenceRule('day5', const Var(sepsisStageKey).eq('review5'),
        'review_day5', 'Review at 5 days',
        category: FindingCategory.followUp),
    _evidenceRule(
        'day5Stop',
        AllOf([
          const Var(sepsisWellKey).eq(true),
          const Var(sepsisSterileKey).eq(true),
          const Var(sepsisCsfNormalKey).eq(true)
        ]),
        'review_day5',
        'Day 5 stopping criteria met',
        category: FindingCategory.treatment,
        level: FindingLevel.action),
    _evidenceRule(
        'day5Unconfirmed',
        AllOf([
          const Var(sepsisStageKey).eq('review5'),
          Not(AllOf([
            const Var(sepsisWellKey).eq(true),
            const Var(sepsisSterileKey).eq(true),
            const Var(sepsisCsfNormalKey).eq(true)
          ]))
        ]),
        'review_day5',
        'Day 5 stopping criteria not confirmed',
        category: FindingCategory.furtherAssessment,
        actions: const [
          'The PDF’s day 5 stopping condition requires the baby now well AND sterile 48-hour blood culture AND normal CSF. The recorded answers do not confirm all three. Review the culture / LP report and the duration table.'
        ]),
    for (final c in SepsisDurationCondition.values)
      _evidenceRule(
          'duration.${c.name}',
          const Var(sepsisDurationKey).eq(c.name),
          'duration',
          'Duration of antibiotics',
          category: FindingCategory.treatment,
          level: FindingLevel.action,
          actions: [sepsisEvidence['sepsis_duration']![c.index]]),
    _evidenceRule(
        'durationUnknown',
        const Var(sepsisDurationKey).eq('unconfirmed'),
        'duration',
        'No antibiotic duration condition confirmed',
        category: FindingCategory.furtherAssessment,
        actions: const [
          'Confirm the applicable condition in the PDF duration table. No duration is inferred from unknown culture or CSF results.'
        ]),
    _evidenceRule('dos', const Var(sepsisStageKey).exists(), 'dos', 'DOs'),
    _evidenceRule('earlyStop', const Var(sepsisStageKey).eq('review48'),
        'early_stopping', 'Early stopping of antibiotics',
        category: FindingCategory.followUp),
    _evidenceRule(
        'ongoingObservation',
        const Var(sepsisStageKey).eq('observation'),
        'observation',
        'Serial observation guidance'),
    _evidenceRule(
        'donts', const Var(sepsisStageKey).exists(), 'donts', 'DON’Ts'),
    _evidenceRule('prevention', const Var(sepsisStageKey).exists(),
        'prevention', 'PREVENT SEPSIS'),
  ],
);
