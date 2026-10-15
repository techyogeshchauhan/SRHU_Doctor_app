/// Kangaroo Mother Care workflow from the August 2026 ICMR/DHR STW.
///
/// The assessment asks only for eligibility data and the listed exclusions.
/// The remaining STW boxes are presented as guidance findings, not as added
/// assessment questions.
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../condition_selection/domain/neonatal_condition.dart';

const _kmc = NeonatalCondition.kmc;

const kmcEligibilityKey = 'kmc_eligibility';
const kmcPretermAssessmentKey = 'kmc_preterm_assessment';
const kmcExclusionsKey = 'kmc_exclusions';
const kmcExcludedKey = 'kmc_excluded';

const _kmcEligible = 'eligible';
const _kmcNotEligible = 'notEligible';
const _kmcUndetermined = 'undetermined';
final _needsPretermAssessment = AllOf([
  const Var(gaKnownKey).eq(false),
  const Var(birthWeightKey).ge(2500),
]);

const _srcEligibility = SourceReference.kmc('Start KMC eligibility');
const _srcPosition = SourceReference.kmc('KANGAROO POSITION');
const _srcProvider = SourceReference.kmc('KMC PROVIDER CAN BE');
const _srcNutrition = SourceReference.kmc('KANGAROO NUTRITION');
const _srcDischarge = SourceReference.kmc('KANGAROO DISCHARGE');
const _srcBefore = SourceReference.kmc('ENSURE BEFORE STARTING KMC');
const _srcMonitoring = SourceReference.kmc('MONITORING');
const _srcTransport = SourceReference.kmc('KMC DURING TRANSPORT');
const _srcContinue = SourceReference.kmc('CONTINUE KMC WHILE ON');
const _srcHome = SourceReference.kmc('HOME KMC COUNSELLING');
const _srcFollowUp = SourceReference.kmc('FOLLOW-UP VISITS');
const _srcDos = SourceReference.kmc("DO's");
const _srcDonts = SourceReference.kmc("DON'Ts");
const _srcKpi = SourceReference.kmc('KEY PERFORMANCE INDICATORS (KPIs)');

const kmcGroups = [
  babyGroup,
  QuestionGroup(
    'kmc_preterm_assessment',
    'Assess preterm status',
    subtitle: 'The KMC STW defines preterm as gestational age <37 weeks.',
  ),
  QuestionGroup(
    'kmc_exclusions',
    'KMC initiation exclusions',
    subtitle: 'Select any exclusion listed in the STW.',
  ),
];

final qKmcPretermAssessment = ClinicalQuestion(
  id: kmcPretermAssessmentKey,
  group: 'kmc_preterm_assessment',
  question: 'Has the clinician assessed the baby as preterm?',
  type: QuestionType.singleChoice,
  options: const [
    QuestionOption(true, 'Yes, preterm (<37 weeks)'),
    QuestionOption(false, 'No, not preterm'),
  ],
  visibleWhen: _needsPretermAssessment,
  helper: 'Use the clinician’s assessment when gestational age is unknown.',
  sources: [_srcEligibility],
);

const qKmcExclusions = ClinicalQuestion(
  id: kmcExclusionsKey,
  group: 'kmc_exclusions',
  question: 'Do any of these conditions apply? (tick all that apply)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption(
      'cannotBreatheSpontaneously',
      'Unable to breathe spontaneously after resuscitation',
    ),
    QuestionOption('shock', 'In shock'),
    QuestionOption('mechanicalVentilation', 'Needs mechanical ventilation'),
  ],
  sources: [_srcEligibility, SourceReference.kmc("DON'Ts")],
);

Set<String> _set(Object? value) =>
    value is Set ? {for (final v in value) v.toString()} : const {};

Object? _eligibility(VariableReader r) {
  final gaKnown = r.valueOf(gaKnownKey) == true;
  final gaWeeks = r.valueOf(gaWeeksKey);
  final weight = r.valueOf(birthWeightKey);
  final preterm = gaKnown && gaWeeks is int && gaWeeks < 37;
  final lowBirthWeight = weight is int && weight < 2500;
  if (preterm || lowBirthWeight) return _kmcEligible;
  if (!gaKnown && weight is int && weight >= 2500) {
    final assessedPreterm = r.valueOf(kmcPretermAssessmentKey);
    if (assessedPreterm == true) return _kmcEligible;
    if (assessedPreterm == false) return _kmcNotEligible;
    return null;
  }
  if (gaKnown &&
      gaWeeks is int &&
      weight is int &&
      gaWeeks >= 37 &&
      weight >= 2500) {
    return _kmcNotEligible;
  }
  return _kmcUndetermined;
}

final kmcVariables = [
  const ClinicalVariable(
    kmcEligibilityKey,
    'Eligibility from gestational age and birth weight in the KMC STW',
    _eligibility,
  ),
  ClinicalVariable(
    kmcExcludedKey,
    'Whether a listed KMC initiation exclusion was selected',
    (r) => _set(r.valueOf(kmcExclusionsKey)).isNotEmpty,
  ),
];

final _eligibleWithNoExclusion = AllOf([
  const Var(kmcEligibilityKey).eq(_kmcEligible),
  const Var(kmcExcludedKey).eq(false),
]);

final kmcRules = <ClinicalRule>[
  ClinicalRule(
    id: 'kmc.eligibility.met',
    topic: _kmc,
    when: const Var(kmcEligibilityKey).eq(_kmcEligible),
    source: _srcEligibility,
    then: (_) => const FindingContent(
      category: FindingCategory.screening,
      level: FindingLevel.ok,
      title: 'KMC eligibility criteria met',
      actions: [
        'Start KMC for every preterm (<37 weeks) or low birth weight baby (<2500 g) soon after birth.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.eligibility.notMet',
    topic: _kmc,
    when: const Var(kmcEligibilityKey).eq(_kmcNotEligible),
    source: _srcEligibility,
    then: (r) => FindingContent(
      category: FindingCategory.notMet,
      level: FindingLevel.info,
      title: 'KMC eligibility criteria not met',
      why: [
        r.valueOf(gaKnownKey) == false
            ? 'The clinician assessed the baby as not preterm and birth weight is 2500 g or more.'
            : 'The recorded gestational age is 37 weeks or more and birth weight is 2500 g or more.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.eligibility.undetermined',
    topic: _kmc,
    when: const Var(kmcEligibilityKey).eq(_kmcUndetermined),
    source: _srcEligibility,
    then: (_) => const FindingContent(
      category: FindingCategory.furtherAssessment,
      level: FindingLevel.info,
      title: 'KMC eligibility undetermined',
      actions: [
        'Gestational age is uncertain and birth weight is 2500 g or more, so the STW eligibility criteria cannot be confirmed from the recorded information.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.initiation.excluded',
    topic: _kmc,
    when: AllOf([
      const Var(kmcEligibilityKey).eq(_kmcEligible),
      const Var(kmcExcludedKey).eq(true),
    ]),
    source: const SourceReference.kmc("DON'Ts"),
    then: (r) => FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.urgent,
      title: 'Do not initiate KMC',
      actions: [
        'The STW says not to initiate KMC in babies unable to breathe spontaneously after resuscitation, in shock, or requiring mechanical ventilation.',
      ],
      why: _set(r.valueOf(kmcExclusionsKey)).toList(),
    ),
  ),
  ClinicalRule(
    id: 'kmc.position',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcPosition,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'Kangaroo position',
      actions: [
        'Skin-to-skin, upright, between the mother’s breasts.',
        'Head turned to one side, neck slightly extended.',
        'Hips flexed and abducted; arms flexed.',
        'Secure with binder/wrap/garment; keep face visible and airway unobstructed.',
        'Baby’s clothing: wear cap to prevent heat loss; socks to keep feet warm; diaper or nappy.',
        'Each session at least 1 hour. Aim for 24 hours while providing at least 8 hours. Record cumulative duration per 24 hours.',
        'Mother can sleep, stand and walk in KMC position.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.provider',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcProvider,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: 'KMC provider can be',
      actions: [
        'Mother (preferred) — the primary KMC provider.',
        'Father (alternate) — preferred alternate; identify and prepare before birth.',
        'Another trained adult family member (backup) when the mother is temporarily unavailable.',
        'Return to maternal KMC as soon as the mother is able.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.nutrition',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcNutrition,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'Kangaroo nutrition',
      actions: [
        'Initiate breastfeeding as early as possible.',
        'Support exclusive breastfeeding; encourage direct feeds.',
        'Expressed breast milk if direct feeding is not possible.',
        'Express and feed in KMC position.',
        'Use cup/spoon/paladai until effective feeding is established.',
        'Continue OG/NG tube feeds if indicated.',
        'Provide lactation support.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.discharge',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcDischarge,
    then: (_) => const FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.info,
      title: 'Kangaroo discharge',
      actions: [
        'Discharge when the neonate meets discharge criteria as per unit policy.',
        'Counsel for continuation of KMC while going home.',
        'Continue KMC at home.',
        'Refer to discharge and follow-up STW module.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.beforeStarting',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcBefore,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'Ensure before starting KMC',
      actions: [
        'Appropriate KMC bed/wrap available.',
        'Clean, comfortable, private area secured.',
        'Documentation and monitoring chart available.',
        'Trained healthcare provider available.',
        'Mother/caregiver counselled.',
        'Baby is upright or at least at 30 degrees.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.monitoring',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcMonitoring,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.action,
      title: 'Monitoring',
      actions: [
        'At initiation: monitor temperature after starting KMC; assess breathing and colour, positioning and airway, and feeding.',
        'During continuation: monitor temperature regularly; assess feeding and weight; track and document KMC duration.',
        'KMC in sick babies: monitor heart rate, SpO₂ and respiratory rate/breathing and colour.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.transport',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcTransport,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'KMC during transport',
      actions: [
        'Continue KMC at discharge to home.',
        'Continue KMC during intra- and inter-facility transport where feasible.',
        'Confirm clinical stability before transporting in KMC position.',
        'Secure safely with binder/wrap/KMC bag.',
        'Accompany with trained provider when indicated.',
        'Minimize interruption before, during and after transport.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.relatedInformation',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: const SourceReference.kmc('RELATED INFORMATION'),
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'Related information',
      actions: [
        'Breastfeeding in KMC Position.',
        'Expressing Milk in KMC Position.',
        'Initiating KMC after Birth.',
        'Placing in KMC Position.',
        'Postnatal Counselling for KMC.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.continueWhileOn',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcContinue,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.action,
      title: 'Continue KMC while on',
      actions: [
        'Oxygen therapy.',
        'CPAP.',
        'IV fluids or medications.',
        'OG/NG tube feeding.',
        'Phototherapy (interrupt only during treatment, resume immediately).',
        'Twins: individually or together, depending on stability and caregiver availability.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.homeCounselling',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcHome,
    then: (_) => const FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.info,
      title: 'Home KMC counselling',
      actions: [
        'Continue KMC as long as possible.',
        'Continue exclusive breastfeeding.',
        'Encourage family participation.',
        'Attend scheduled follow-up.',
        'Seek care if danger signs develop.',
        'Go to Neonatal Triage STW Module.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.followUpVisits',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcFollowUp,
    then: (_) => const FindingContent(
      category: FindingCategory.followUp,
      level: FindingLevel.action,
      title: 'Follow-up visits',
      actions: [
        'Assess weight gain, length and head circumference.',
        'Assess breastfeeding and feeding adequacy.',
        'Assess KMC practice.',
        'Screen for danger signs.',
        'ROP screening, hearing screening, neurodevelopmental assessment as required.',
        'Reinforce KMC and feeding counselling each visit.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.dos',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcDos,
    then: (_) => const FindingContent(
      category: FindingCategory.pathway,
      level: FindingLevel.info,
      title: "DO's",
      actions: [
        'Start KMC early in every eligible preterm or low-birth-weight baby; continue as long as possible.',
        'Ensure correct positioning, a clear airway, and secure support; monitor temperature, breathing, and feeding.',
        'Support exclusive breast milk feeding and counsel families to continue KMC at home with scheduled follow-up.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.donts',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcDonts,
    then: (_) => const FindingContent(
      category: FindingCategory.alert,
      level: FindingLevel.action,
      title: "DON'Ts",
      actions: [
        'Do not initiate KMC in babies unable to breathe spontaneously after resuscitation, in shock, or requiring mechanical ventilation.',
        'Do not routinely stop KMC for oxygen, CPAP, IV therapy, or tube feeding.',
        'Do not delay KMC because the mother is unavailable; involve a trained alternate caregiver.',
      ],
    ),
  ),
  ClinicalRule(
    id: 'kmc.kpis',
    topic: _kmc,
    when: _eligibleWithNoExclusion,
    source: _srcKpi,
    then: (_) => const FindingContent(
      category: FindingCategory.assessment,
      level: FindingLevel.info,
      title: 'Key performance indicators (KPIs)',
      actions: [
        'KMC coverage among eligible neonates = number of neonates initiated on KMC ÷ total eligible neonates during that period × 100 (target: ≥90%).',
        'Percentage of eligible neonates getting >8 hours of KMC = neonates receiving KMC for ≥8 h per 24 h ÷ all neonates receiving KMC × 100 (target: ≥80%).',
      ],
    ),
  ),
];

final kmcWorkflow = StwWorkflow(
  _kmc,
  source: const SourceReference.kmc('Whole document (August 2026)'),
  groups: kmcGroups,
  uses: [
    const QuestionUse(qGaKnown, required: true),
    QuestionUse(qGaWeeks, when: const Var(gaKnownKey).eq(true), required: true),
    const QuestionUse(qBirthWeight, required: true),
    QuestionUse(
      qKmcPretermAssessment,
      when: _needsPretermAssessment,
      required: true,
    ),
    QuestionUse(
      qKmcExclusions,
      when: const Var(kmcEligibilityKey).eq(_kmcEligible),
    ),
  ],
  variables: kmcVariables,
  rules: kmcRules,
);
