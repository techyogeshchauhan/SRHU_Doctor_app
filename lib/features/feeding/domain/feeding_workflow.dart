/// Source-bound feeding workflow. Remaining poster boxes are conditional
/// guidance, retaining their full qualifiers rather than adding decision rules.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'feeding_content.dart';
import 'feeding_rules.dart';

const feedingSignsKey = 'feeding_stability_signs';
const feedingStableKey = 'feeding_stable';
const feedingAedfKey = 'feeding_aedf_redf';
const feedingDayKey = 'feeding_day_of_life';
const feedingPmaKey = 'feeding_current_pma';
const feedingToleranceKey = 'feeding_oral_difficulty';
const feedingFullKey = 'feeding_on_full_feeds';
const feedingSupportKey = 'feeding_on_respiratory_support';
const feedingPoorGainKey = 'feeding_poor_weight_gain';
const feedingVolumeKey = 'feeding_daily_enteral_ml';
const feedingStartKey = 'feeding_start_plan';
const feedingFluidKey = 'feeding_fluid_guide';
const feedingThreeHourlyKey = 'feeding_consider_three_hourly';

SourceReference feedingSource(String suffix) =>
    SourceReference.feeding(feedingHeadings['feeding_$suffix']!,
        regionId: 'feeding_$suffix');

// Reuse stable baby-data keys without changing other workflows' metadata.
final qFeedingGaKnown = ClinicalQuestion(
  id: gaKnownKey,
  group: 'baby',
  question: 'Gestational age',
  type: QuestionType.singleChoice,
  options: const [
    QuestionOption(true, 'GA known'),
    QuestionOption(false, 'GA uncertain')
  ],
  sources: [feedingSource('standard'), feedingSource('small')],
);
final qFeedingGa = ClinicalQuestion(
  id: gaWeeksKey,
  group: 'baby',
  question: 'Gestational age (completed weeks)',
  type: QuestionType.numeric,
  min: 22,
  max: 44,
  unit: 'weeks',
  visibleWhen: const Var(gaKnownKey).eq(true),
  sources: [feedingSource('standard'), feedingSource('small')],
);
final qFeedingBirthWeight = ClinicalQuestion(
  id: birthWeightKey,
  group: 'baby',
  question: 'Birth weight',
  type: QuestionType.numeric,
  min: 300,
  max: 6000,
  unit: 'g',
  sources: [feedingSource('fluids'), feedingSource('small')],
);

final qFeedingSigns = ClinicalQuestion(
  id: feedingSignsKey,
  group: 'feeding_stability',
  question:
      'Assess physiological stability for enteral feeding (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: const [
    QuestionOption('shock', 'Shock / poor perfusion'),
    QuestionOption('apnoea',
        'Recurrent apnoea requiring intervention / respiratory failure'),
    QuestionOption(
        'seizures', 'Ongoing seizures with physiological instability'),
    QuestionOption('hypothermia', 'Severe hypothermia'),
    QuestionOption('abdomen',
        'Concerning abdominal signs: bilious vomiting, bloody stools, marked or progressive distension, tenderness or discoloration'),
  ],
  helper:
      'Select none only when clinically stable with no feeding contraindication.',
  sources: [feedingSource('stability')],
);

ClinicalQuestion _choice(String key, String text, String section) =>
    ClinicalQuestion(
      id: key,
      group: 'feeding_status',
      question: text,
      type: QuestionType.singleChoice,
      options: const [QuestionOption(true, 'Yes'), QuestionOption(false, 'No')],
      sources: [feedingSource(section)],
    );

final qFeedingAedf =
    _choice(feedingAedfKey, 'Antenatal AEDF/REDF present?', 'aedf');
final qFeedingTolerance = _choice(
    feedingToleranceKey,
    'Does breastfeeding or spoon/paladai feeding cause coughing, choking, apnoea/desaturation, excessive fatigue or inadequate intake?',
    'route');
final qFeedingFull = _choice(
    feedingFullKey, 'On full feeds (clinician assessment)?', 'plan_notes');
final qFeedingSupport =
    _choice(feedingSupportKey, 'On respiratory support?', 'plan_notes');
final qFeedingPoorGain =
    _choice(feedingPoorGainKey, 'Poor weight gain present?', 'poor_gain');
final qFeedingDay = ClinicalQuestion(
  id: feedingDayKey,
  group: 'feeding_status',
  question: 'Day of life (not day of admission)',
  type: QuestionType.numeric,
  min: 1,
  unit: 'day',
  helper: 'The starting fluid guide covers D1–D7 only.',
  sources: [feedingSource('fluids')],
);
final qFeedingPma = ClinicalQuestion(
  id: feedingPmaKey,
  group: 'feeding_status',
  question: 'Current gestation / postmenstrual age for feeding route',
  type: QuestionType.decimal,
  min: 0,
  unit: 'weeks',
  helper:
      'Use current maturity, not gestation at birth. Leave blank if uncertain; the route guidance remains available.',
  sources: [feedingSource('route'), feedingSource('plan_notes')],
);
final qFeedingVolume = ClinicalQuestion(
  id: feedingVolumeKey,
  group: 'feeding_status',
  question: 'Daily enteral volume (optional)',
  type: QuestionType.decimal,
  min: 0,
  unit: 'mL/day',
  helper: 'Enter the prescribed daily enteral volume in mL, not mL/kg/day.',
  sources: [feedingSource('plan_notes')],
);

const _stable = Compare(feedingStableKey, CmpOp.eq, true);
const _unstable = Compare(feedingStableKey, CmpOp.eq, false);

num? _number(VariableReader r, String key) =>
    r.valueOf(key) is num ? r.valueOf(key) as num : null;
num? _birthGa(VariableReader r) =>
    r.valueOf(gaKnownKey) == true ? _number(r, gaWeeksKey) : null;

ClinicalRule _evidence(String suffix, Cond when,
        {String? title,
        FindingLevel level = FindingLevel.info,
        FindingCategory category = FindingCategory.pathway}) =>
    ClinicalRule(
      id: 'feeding.$suffix',
      topic: NeonatalCondition.fluidsAndFeeds,
      when: when,
      source: feedingSource(suffix),
      then: (_) => FindingContent(
          category: category,
          level: level,
          title: title ?? suffix,
          actions: feedingEvidence['feeding_$suffix']!),
    );

final feedingWorkflow = StwWorkflow(
  NeonatalCondition.fluidsAndFeeds,
  source: const SourceReference.feeding('FEEDING AND NUTRITION IN NEONATES',
      regionId: 'feeding_stability'),
  groups: const [
    QuestionGroup(
        'feeding_stability', 'Physiological stability for enteral feeding'),
    babyGroup,
    QuestionGroup('feeding_status', 'Feeding and nutrition assessment',
        subtitle:
            'Record known findings. Clinical guidance is taken only from the supplied STW.'),
  ],
  uses: [
    QuestionUse(qFeedingSigns),
    QuestionUse(qFeedingGaKnown, required: true),
    QuestionUse(qFeedingGa,
        when: const Var(gaKnownKey).eq(true), required: true),
    QuestionUse(qFeedingBirthWeight, required: true),
    QuestionUse(qFeedingDay),
    QuestionUse(qFeedingAedf, when: _stable),
    QuestionUse(qFeedingPma, when: _stable),
    QuestionUse(qFeedingTolerance, when: _stable, required: true),
    QuestionUse(qFeedingFull, when: _stable, required: true),
    QuestionUse(qFeedingSupport, when: _stable, required: true),
    QuestionUse(qFeedingPoorGain, when: _stable, required: true),
    QuestionUse(qFeedingVolume, when: _stable),
  ],
  variables: [
    ClinicalVariable(feedingStableKey, 'No listed feeding contraindication',
        (r) {
      final signs = r.valueOf(feedingSignsKey);
      return signs is Set ? signs.isEmpty : null;
    }),
    ClinicalVariable(
        feedingStartKey,
        'PDF enteral starting column',
        (r) => r.valueOf(feedingStableKey) == true
            ? feedingStart(
                birthGaWeeks: _birthGa(r),
                birthWeightG: _number(r, birthWeightKey),
                aedf: r.valueOf(feedingAedfKey) as bool?)
            : null),
    ClinicalVariable(
        feedingFluidKey,
        'D1–D7 total fluid starting guide',
        (r) => feedingFluidGuide(
            dayOfLife: r.valueOf(feedingDayKey) as int?,
            birthGaWeeks: _birthGa(r),
            birthWeightG: _number(r, birthWeightKey))),
    ClinicalVariable(
        feedingThreeHourlyKey,
        'May consider 3-hourly feeds',
        (r) => canConsiderThreeHourly(
            pmaWeeks: _number(r, feedingPmaKey),
            stable: r.valueOf(feedingStableKey) == true,
            fullFeeds: r.valueOf(feedingFullKey) == true,
            offRespiratorySupport: r.valueOf(feedingSupportKey) == false)),
  ],
  rules: [
    _evidence('unstable', _unstable,
        title: 'Unstable / feeding contraindication present',
        level: FindingLevel.urgent,
        category: FindingCategory.alert),
    _evidence('stable', _stable,
        title: 'Stable / no feeding contraindication',
        level: FindingLevel.action),
    _evidence('fluids', const AllOf([]),
        title: 'Total daily fluid requirement — starting guide'),
    ClinicalRule(
        id: 'feeding.fluidDay',
        topic: NeonatalCondition.fluidsAndFeeds,
        when: const Var(feedingFluidKey).exists(),
        source: feedingSource('fluids'),
        then: (r) => FindingContent(
                category: FindingCategory.assessment,
                level: FindingLevel.info,
                title: 'Day ${r.valueOf(feedingDayKey)} starting guide',
                actions: [
                  '${r.valueOf(feedingFluidKey)} mL/kg/day: enteral + IV + other fluid inputs.',
                  'Adjust total fluids and electrolytes as per daily weight change, urine output, blood glucose and clinical status.'
                ])),
    _evidence('iv_type', const AllOf([]), title: 'Maintenance IV fluid type'),
    _evidence('iv_review', const AllOf([]),
        title: 'IV review → transition to feeds'),
    _evidence('milk', _stable, title: 'Milk source'),
    _evidence('route', _stable, title: 'Route of feeding'),
    ClinicalRule(
        id: 'feeding.routeGuide',
        topic: NeonatalCondition.fluidsAndFeeds,
        when: AllOf([
          _stable,
          AnyOf([
            const Var(feedingPmaKey).exists(),
            const Var(feedingToleranceKey).eq(true)
          ])
        ]),
        source: feedingSource('route'),
        then: (r) {
          final pma = _number(r, feedingPmaKey);
          final index = r.valueOf(feedingToleranceKey) == true
              ? 3
              : pma! < 32
                  ? 0
                  : pma < 34
                      ? 1
                      : 2;
          return FindingContent(
              category: FindingCategory.pathway,
              level: FindingLevel.action,
              title: 'Feeding route guidance',
              actions: [
                feedingEvidence['feeding_route']![index],
                if (index != 3) feedingEvidence['feeding_route']![3]
              ]);
        }),
    for (final (plan, suffix, title) in [
      (FeedingStart.standard, 'standard', 'Standard start'),
      (FeedingStart.aedf, 'aedf', 'Cautious start: AEDF/REDF'),
      (FeedingStart.verySmall, 'small', 'Cautious start: very small infants'),
    ])
      _evidence(suffix, const Var(feedingStartKey).eq(plan),
          title: title, level: FindingLevel.action),
    ClinicalRule(
        id: 'feeding.planUnknown',
        topic: NeonatalCondition.fluidsAndFeeds,
        when: AllOf([_stable, Not(const Var(feedingStartKey).exists())]),
        source: feedingSource('standard'),
        then: (_) => const FindingContent(
                category: FindingCategory.furtherAssessment,
                level: FindingLevel.info,
                title: 'Starting column requires further assessment',
                actions: [
                  'Birth gestation, birth weight or antenatal AEDF/REDF status is not fully recorded. Review the enteral feeding plan in the PDF; no starting column has been assumed.'
                ])),
    _evidence('plan_notes', _stable,
        title: 'Enteral feeding plan: conditions, full feeds and frequency'),
    ClinicalRule(
        id: 'feeding.volume',
        topic: NeonatalCondition.fluidsAndFeeds,
        when: AllOf([_stable, const Var(feedingVolumeKey).exists()]),
        source: feedingSource('plan_notes'),
        then: (r) {
          final ml = _number(r, feedingVolumeKey)!;
          return FindingContent(
              category: FindingCategory.assessment,
              level: FindingLevel.info,
              title: 'Volume per feed from recorded daily enteral volume',
              actions: [
                '2-hourly: ${ml.toStringAsFixed(1)} ÷ 12 = ${(ml / 12).toStringAsFixed(1)} mL per feed.',
                if (r.valueOf(feedingThreeHourlyKey) == true)
                  'May consider 3-hourly: ${ml.toStringAsFixed(1)} ÷ 8 = ${(ml / 8).toStringAsFixed(1)} mL per feed; PMA >32 weeks, stable, on full feeds and off respiratory support.',
              ]);
        }),
    _evidence('monitoring', const AllOf([]), title: 'Monitoring'),
    _evidence(
        'poor_gain', AllOf([_stable, const Var(feedingPoorGainKey).eq(true)]),
        title: 'Poor weight gain'),
    for (final (suffix, title) in [
      ('iron', 'Iron'),
      ('vitamin_d', 'Vitamin D'),
      ('minerals', 'Calcium / phosphorus'),
      ('supplement_review', 'Review nutrient sources and zinc')
    ])
      _evidence(suffix, _stable, title: title),
    _evidence('dos', const AllOf([]), title: 'DOs'),
    _evidence('donts', const AllOf([]), title: 'DON’Ts'),
    _evidence('kpis', const AllOf([]),
        title: 'Key performance indicators (KPIs)'),
  ],
);
