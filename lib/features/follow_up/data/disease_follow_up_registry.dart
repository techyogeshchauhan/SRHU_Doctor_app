import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/follow_up_models.dart';
import 'rop_follow_up_data.dart';

/// Package containing follow-up MCQs and bedside clinical case scenarios for a disease.
class DiseaseFollowUpPackage {
  const DiseaseFollowUpPackage({
    required this.condition,
    required this.title,
    required this.subtitle,
    required this.mcqs,
    this.caseScenarios = const [],
  });

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
/// Currently, MCQs and case scenarios are provided specifically for ROP.
/// When MCQs for Respiratory Distress or other conditions are added, register them here.
const Map<NeonatalCondition, DiseaseFollowUpPackage> diseaseFollowUpRegistry = {
  NeonatalCondition.rop: DiseaseFollowUpPackage(
    condition: NeonatalCondition.rop,
    title: 'Retinopathy of Prematurity (ROP)',
    subtitle:
        '8 MCQs and 8 bedside clinical case scenarios based on ICMR / DHR STW guidelines.',
    mcqs: ropFollowUpMcqs,
    caseScenarios: ropFollowUpCaseScenarios,
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
