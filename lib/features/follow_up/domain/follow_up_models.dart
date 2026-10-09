import '../../condition_selection/domain/neonatal_condition.dart';

/// Type of follow-up question: standard multiple choice or clinical case scenario.
enum QuestionType {
  mcq,
  caseScenario,
}

/// Current stage in the follow-up assessment workflow.
enum FollowUpStage {
  intro,
  mcqs,
  mcqResult,
  caseScenarios,
  finalSummary,
}

/// A structured question item for follow-up assessment (MCQs and Case Scenarios).
class FollowUpQuestion {
  const FollowUpQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.category,
    required this.questionType,
    this.scenario,
    this.disease = NeonatalCondition.rop,
    this.stwReference,
  });

  /// Unique identifier, e.g. 'rop_mcq_1' or 'rop_case_1'.
  final String id;

  /// The question or required clinical action.
  final String question;

  /// Exactly 4 options for the question.
  final List<String> options;

  /// Index of the correct option (0 = A, 1 = B, 2 = C, 3 = D).
  final int correctAnswerIndex;

  /// Authoritative explanation / clinical rationale from ICMR/DHR STW.
  final String explanation;

  /// Subject category / clinical topic for categorization.
  final String category;

  /// MCQ or Case Scenario.
  final QuestionType questionType;

  /// Optional clinical patient scenario text (present on case scenarios).
  final String? scenario;

  /// Associated neonatal condition.
  final NeonatalCondition disease;

  /// STW box the answer comes from, e.g. 'ICMR/DHR STW "Neonatal
  /// Hypoglycemia" (August 2026), DRUGS FOR REFRACTORY HYPOGLYCEMIA'.
  final String? stwReference;

  /// Letter corresponding to correct answer ('A', 'B', 'C', 'D').
  String get correctAnswerLetter =>
      String.fromCharCode(65 + correctAnswerIndex);

  /// Full text of the correct answer.
  String get correctAnswer => options[correctAnswerIndex];
}
