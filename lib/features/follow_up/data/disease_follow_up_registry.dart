import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';
import 'ancs_follow_up_data.dart';
import 'hypo_follow_up_data.dart';
import 'rop_follow_up_data.dart';

/// Package containing follow-up MCQs and bedside clinical case scenarios for a disease.
class DiseaseFollowUpPackage {
  const DiseaseFollowUpPackage({
    required this.condition,
    required this.title,
    required this.subtitle,
    required this.mcqs,
    this.caseScenarios = const [],
    required this.shortName,
    required this.introDescription,
    required this.mcqTopics,
    required this.caseTopics,
  });

  /// Short label used in buttons and headings, e.g. 'ROP'.
  final String shortName;

  /// Intro text under the assessment title.
  final String introDescription;

  /// What the MCQs cover (intro card).
  final String mcqTopics;

  /// What the case scenarios cover (intro card).
  final String caseTopics;

  /// The neonatal condition this package belongs to.
  final NeonatalCondition condition;

  /// Human-friendly display title for the assessment package.
  final String title;

  /// Summary description for the questions included in this package.
  final String subtitle;

  /// Ordered disease-specific MCQs.
  final List<FollowUpQuestion> mcqs;

  /// Ordered disease-specific bedside clinical case scenarios.
  final List<FollowUpQuestion> caseScenarios;

  /// Whether this package contains any questions.
  bool get hasQuestions => mcqs.isNotEmpty || caseScenarios.isNotEmpty;

  /// Whether this package contains standard MCQs.
  bool get hasMcqs => mcqs.isNotEmpty;

  /// Whether this package contains bedside case scenarios.
  bool get hasCaseScenarios => caseScenarios.isNotEmpty;
}

/// Registry mapping each disease to its official ICMR/DHR STW follow-up question package.
///
/// Designed to support disease-specific question sets in the future.
/// MCQs and case scenarios are provided for ROP, ANCS and Neonatal
/// Hypoglycemia.
/// When MCQs for Respiratory Distress or other conditions are added, register them here.
const Map<NeonatalCondition, DiseaseFollowUpPackage> diseaseFollowUpRegistry = {
  NeonatalCondition.rop: DiseaseFollowUpPackage(
    condition: NeonatalCondition.rop,
    title: 'Retinopathy of Prematurity (ROP)',
    subtitle:
        '8 MCQs and 8 bedside clinical case scenarios based on ICMR / DHR STW guidelines.',
    mcqs: ropFollowUpMcqs,
    caseScenarios: ropFollowUpCaseScenarios,
    shortName: 'ROP',
    introDescription:
        'Test and consolidate your clinical understanding of ROP prevention, screening protocols, timing criteria, analgesia, zone/stage treatment, and post-discharge surveillance.',
    mcqTopics:
        'Multiple choice questions covering KPIs, prevention measures, screening arrangements, pre-exam fasting/preparation, gestational age eligibility, screening timing, zone treatment, and Stage 1 management.',
    caseTopics:
        'Real-life bedside vignettes including oxygen titration, timely screening KPI calculations, transfer documentation, anti-VEGF surveillance, and aggressive ROP follow-up.',
  ),
  NeonatalCondition.ancs: DiseaseFollowUpPackage(
    condition: NeonatalCondition.ancs,
    title: 'Antenatal Corticosteroids for Preterm Birth (ANCS)',
    subtitle:
        '8 MCQs and 6 clinical case scenarios written only from the ICMR / DHR ANCS STW.',
    mcqs: ancsFollowUpMcqs,
    caseScenarios: ancsFollowUpCaseScenarios,
    shortName: 'ANCS',
    introDescription:
        'Test your understanding of the ANCS STW: when to give, eligibility, drug & dose, when not to give, repeat course, referral and KPIs.',
    mcqTopics:
        'Multiple choice questions on the gestation window, drug & dose, causes of high likelihood of preterm birth, when not to give, special situations, repeat course, referral and KPIs.',
    caseTopics:
        'Bedside vignettes applying the STW eligibility criteria, WHEN NOT TO GIVE, repeat course, special situations and referral/transfer boxes.',
  ),
  NeonatalCondition.hypoglycemia: DiseaseFollowUpPackage(
    condition: NeonatalCondition.hypoglycemia,
    title: 'Neonatal Hypoglycemia',
    subtitle:
        '8 MCQs and 6 clinical case scenarios written only from the ICMR / DHR Neonatal Hypoglycemia STW.',
    mcqs: hypoFollowUpMcqs,
    caseScenarios: hypoFollowUpCaseScenarios,
    shortName: 'Hypoglycemia',
    introDescription:
        'Test your understanding of the Neonatal Hypoglycemia STW: whom to screen, monitoring schedule, the management flowchart, practical points and refractory hypoglycemia.',
    mcqTopics:
        'Multiple choice questions on the BG threshold, whom to screen, monitoring schedule, IV bolus, GIR, peripheral dextrose limit and drugs for refractory hypoglycemia.',
    caseTopics:
        'Bedside vignettes following the flowchart: supervised feeding, IV bolus and GIR, the 1-hour re-check, increasing GIR, stopping IV fluids and referral.',
  ),
};

/// Retrieves the question package for [condition], or null if none available.
DiseaseFollowUpPackage? getFollowUpPackage(NeonatalCondition condition) {
  return diseaseFollowUpRegistry[condition];
}

/// Checks whether [condition] has follow-up MCQs available.
bool hasFollowUpForCondition(NeonatalCondition condition) {
  final pkg = diseaseFollowUpRegistry[condition];
  return pkg != null && pkg.hasQuestions;
}

/// Checks whether any of the conditions in [selected] has follow-up MCQs available.
bool hasFollowUpForSelected(Set<NeonatalCondition> selected) {
  return selected.any(hasFollowUpForCondition);
}
