import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/screening_sync_repository.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../data/disease_follow_up_registry.dart';
import '../data/rop_follow_up_data.dart';
import '../domain/follow_up_models.dart';

/// In-memory state of the follow-up assessment workflow.
class FollowUpState {
  const FollowUpState({
    this.stage = FollowUpStage.intro,
    this.mcqs = ropFollowUpMcqs,
    this.caseScenarios = ropFollowUpCaseScenarios,
    this.currentMcqIndex = 0,
    this.mcqAnswers = const {},
    this.currentCaseIndex = 0,
    this.caseAnswers = const {},
    this.condition = NeonatalCondition.rop,
  });

  /// Current workflow stage (intro, mcqs, mcqResult, caseScenarios, finalSummary).
  final FollowUpStage stage;

  /// Ordered list of standard MCQs.
  final List<FollowUpQuestion> mcqs;

  /// Ordered list of clinical case scenarios.
  final List<FollowUpQuestion> caseScenarios;

  /// Active question index in the MCQ section (0-indexed).
  final int currentMcqIndex;

  /// Map of question ID -> selected option index (0..3).
  final Map<String, int> mcqAnswers;

  /// Active question index in the case scenario section (0-indexed).
  final int currentCaseIndex;

  /// Map of case scenario ID -> selected option index (0..3).
  final Map<String, int> caseAnswers;

  /// The active disease/condition for this follow-up assessment.
  final NeonatalCondition condition;

  /// Display title for the active condition's package.
  String get conditionTitle =>
      getFollowUpPackage(condition)?.title ?? definitionOf(condition).title;

  /// Short label of the active package, e.g. 'ROP'.
  String get shortName =>
      getFollowUpPackage(condition)?.shortName ?? definitionOf(condition).title;

  /// The active condition's question package, if any.
  DiseaseFollowUpPackage? get package => getFollowUpPackage(condition);

  /// Currently viewed MCQ.
  FollowUpQuestion get currentMcq => mcqs[currentMcqIndex];

  /// Currently viewed Case Scenario.
  FollowUpQuestion get currentCase => caseScenarios[currentCaseIndex];

  /// Option index currently selected for the active MCQ, or null if unselected.
  int? get selectedMcqOption => mcqAnswers[currentMcq.id];

  /// Option index currently selected for the active Case Scenario, or null.
  int? get selectedCaseOption => caseAnswers[currentCase.id];

  /// Whether current MCQ is the last in the set.
  bool get isLastMcq =>
      mcqs.isEmpty || currentMcqIndex == mcqs.length - 1;

  /// Whether current Case Scenario is the last in the set.
  bool get isLastCase =>
      caseScenarios.isEmpty || currentCaseIndex == caseScenarios.length - 1;

  /// Total MCQs answered.
  int get mcqAnsweredCount => mcqAnswers.length;

  /// Whether every MCQ has been answered.
  bool get allMcqsAnswered =>
      mcqs.isNotEmpty &&
      mcqAnswers.length == mcqs.length &&
      mcqs.every((q) => mcqAnswers.containsKey(q.id));

  /// Index of the first unanswered MCQ, or null if all are answered.
  int? get firstUnansweredMcqIndex {
    for (int i = 0; i < mcqs.length; i++) {
      if (!mcqAnswers.containsKey(mcqs[i].id)) return i;
    }
    return null;
  }

  /// Total Case Scenarios answered.
  int get caseAnsweredCount => caseAnswers.length;

  /// Whether every Case Scenario has been answered.
  bool get allCasesAnswered =>
      caseScenarios.isNotEmpty &&
      caseAnswers.length == caseScenarios.length &&
      caseScenarios.every((q) => caseAnswers.containsKey(q.id));

  /// Index of the first unanswered Case Scenario, or null if all are answered.
  int? get firstUnansweredCaseIndex {
    for (int i = 0; i < caseScenarios.length; i++) {
      if (!caseAnswers.containsKey(caseScenarios[i].id)) return i;
    }
    return null;
  }

  /// Count of correctly answered MCQs.
  int get mcqCorrectCount =>
      mcqs.where((q) => mcqAnswers[q.id] == q.correctAnswerIndex).length;

  /// Count of incorrectly answered MCQs.
  int get mcqIncorrectCount => mcqs.where((q) {
        final ans = mcqAnswers[q.id];
        return ans != null && ans != q.correctAnswerIndex;
      }).length;

  /// Percentage score for MCQs.
  double get mcqPercentage =>
      mcqs.isEmpty ? 0 : (mcqCorrectCount / mcqs.length) * 100;

  /// Count of correctly answered Case Scenarios.
  int get caseCorrectCount => caseScenarios
      .where((q) => caseAnswers[q.id] == q.correctAnswerIndex)
      .length;

  /// Count of incorrectly answered Case Scenarios.
  int get caseIncorrectCount => caseScenarios.where((q) {
        final ans = caseAnswers[q.id];
        return ans != null && ans != q.correctAnswerIndex;
      }).length;

  /// Percentage score for Case Scenarios.
  double get casePercentage => caseScenarios.isEmpty
      ? 0
      : (caseCorrectCount / caseScenarios.length) * 100;

  /// Total questions count across both MCQs and Case Scenarios.
  int get totalQuestionsCount => mcqs.length + caseScenarios.length;

  /// Combined correct count across both sections.
  int get totalCorrectCount => mcqCorrectCount + caseCorrectCount;

  /// Combined percentage score.
  double get totalPercentage => totalQuestionsCount == 0
      ? 0
      : (totalCorrectCount / totalQuestionsCount) * 100;

  FollowUpState copyWith({
    FollowUpStage? stage,
    List<FollowUpQuestion>? mcqs,
    List<FollowUpQuestion>? caseScenarios,
    int? currentMcqIndex,
    Map<String, int>? mcqAnswers,
    int? currentCaseIndex,
    Map<String, int>? caseAnswers,
    NeonatalCondition? condition,
  }) {
    return FollowUpState(
      stage: stage ?? this.stage,
      mcqs: mcqs ?? this.mcqs,
      caseScenarios: caseScenarios ?? this.caseScenarios,
      currentMcqIndex: currentMcqIndex ?? this.currentMcqIndex,
      mcqAnswers: mcqAnswers ?? this.mcqAnswers,
      currentCaseIndex: currentCaseIndex ?? this.currentCaseIndex,
      caseAnswers: caseAnswers ?? this.caseAnswers,
      condition: condition ?? this.condition,
    );
  }
}

/// Controller managing the follow-up assessment workflow.
class FollowUpController extends StateNotifier<FollowUpState> {
  FollowUpController({this.syncRepo}) : super(const FollowUpState());

  final ScreeningSyncRepository? syncRepo;

  /// Begins the MCQ section from the intro screen.
  void startAssessment() {
    state = state.copyWith(
      stage: FollowUpStage.mcqs,
      currentMcqIndex: 0,
    );
  }

  /// Selects or changes the option for the current MCQ.
  void selectMcqOption(int optionIndex) {
    final updated = Map<String, int>.from(state.mcqAnswers);
    updated[state.currentMcq.id] = optionIndex;
    state = state.copyWith(mcqAnswers: updated);
  }

  /// Advances to the next MCQ.
  void nextMcq() {
    if (state.currentMcqIndex < state.mcqs.length - 1) {
      state = state.copyWith(currentMcqIndex: state.currentMcqIndex + 1);
    }
  }

  /// Returns to the previous MCQ.
  void previousMcq() {
    if (state.currentMcqIndex > 0) {
      state = state.copyWith(currentMcqIndex: state.currentMcqIndex - 1);
    }
  }

  /// Jumps directly to a specific MCQ by index.
  void goToMcq(int index) {
    if (index >= 0 && index < state.mcqs.length) {
      state = state.copyWith(currentMcqIndex: index);
    }
  }

  /// Submits the MCQ section and navigates to the MCQ Result screen.
  /// Returns true if all MCQs are answered and submission succeeds; false otherwise.
  bool submitMcqs() {
    if (!state.allMcqsAnswered) {
      return false;
    }
    state = state.copyWith(stage: FollowUpStage.mcqResult);

    // Goal B: Record MCQ attempts in background queue
    if (syncRepo != null) {
      final code = diseaseCodeOf(state.condition);
      for (final q in state.mcqs) {
        final optIdx = state.mcqAnswers[q.id];
        if (optIdx != null && optIdx >= 0 && optIdx < q.options.length) {
          syncRepo!.recordMcqAttempt(
            diseaseCode: code,
            questionId: q.id,
            selectedOption: q.options[optIdx],
            isCorrect: optIdx == q.correctAnswerIndex,
          );
        }
      }
    }

    return true;
  }

  /// Advances from MCQ Result to the Case Scenarios section.
  void proceedToCaseScenarios() {
    state = state.copyWith(
      stage: FollowUpStage.caseScenarios,
      currentCaseIndex: 0,
    );
  }

  /// Selects or changes the option for the current Case Scenario.
  void selectCaseOption(int optionIndex) {
    final updated = Map<String, int>.from(state.caseAnswers);
    updated[state.currentCase.id] = optionIndex;
    state = state.copyWith(caseAnswers: updated);
  }

  /// Advances to the next Case Scenario.
  void nextCase() {
    if (state.currentCaseIndex < state.caseScenarios.length - 1) {
      state = state.copyWith(currentCaseIndex: state.currentCaseIndex + 1);
    }
  }

  /// Returns to the previous Case Scenario.
  void previousCase() {
    if (state.currentCaseIndex > 0) {
      state = state.copyWith(currentCaseIndex: state.currentCaseIndex - 1);
    }
  }

  /// Jumps directly to a specific Case Scenario by index.
  void goToCase(int index) {
    if (index >= 0 && index < state.caseScenarios.length) {
      state = state.copyWith(currentCaseIndex: index);
    }
  }

  /// Submits the Case Scenarios and navigates to the Final Summary screen.
  /// Returns true if all case scenarios are answered and submission succeeds; false otherwise.
  bool submitCaseScenarios() {
    if (!state.allCasesAnswered) {
      return false;
    }
    state = state.copyWith(stage: FollowUpStage.finalSummary);

    // Goal B: Record Case Scenario attempts in background queue
    if (syncRepo != null) {
      final code = diseaseCodeOf(state.condition);
      for (final q in state.caseScenarios) {
        final optIdx = state.caseAnswers[q.id];
        if (optIdx != null && optIdx >= 0 && optIdx < q.options.length) {
          syncRepo!.recordMcqAttempt(
            diseaseCode: code,
            questionId: q.id,
            selectedOption: q.options[optIdx],
            isCorrect: optIdx == q.correctAnswerIndex,
          );
        }
      }
    }

    return true;
  }

  /// Initializes the assessment for a specific disease condition.
  void initForCondition(
    NeonatalCondition condition, {
    bool startImmediately = false,
  }) {
    if (state.condition == condition && state.mcqs.isNotEmpty) {
      if (startImmediately && state.stage == FollowUpStage.intro) {
        state = state.copyWith(stage: FollowUpStage.mcqs);
      }
      return;
    }
    final pkg = getFollowUpPackage(condition);
    state = FollowUpState(
      stage: startImmediately ? FollowUpStage.mcqs : FollowUpStage.intro,
      condition: condition,
      mcqs: pkg?.mcqs ?? const [],
      caseScenarios: pkg?.caseScenarios ?? const [],
      currentMcqIndex: 0,
      mcqAnswers: const {},
      currentCaseIndex: 0,
      caseAnswers: const {},
    );
  }

  /// Resets the assessment back to the intro stage and clears all answers.
  void reset() {
    final pkg = getFollowUpPackage(state.condition);
    state = FollowUpState(
      stage: FollowUpStage.intro,
      condition: state.condition,
      mcqs: pkg?.mcqs ?? const [],
      caseScenarios: pkg?.caseScenarios ?? const [],
      currentMcqIndex: 0,
      mcqAnswers: const {},
      currentCaseIndex: 0,
      caseAnswers: const {},
    );
  }

  /// Retakes only the MCQ portion.
  void retakeMcqs() {
    state = state.copyWith(
      stage: FollowUpStage.mcqs,
      currentMcqIndex: 0,
      mcqAnswers: const {},
    );
  }

  /// Retakes only the Case Scenarios portion.
  void retakeCaseScenarios() {
    state = state.copyWith(
      stage: FollowUpStage.caseScenarios,
      currentCaseIndex: 0,
      caseAnswers: const {},
    );
  }
}

/// Global provider for follow-up assessment state and actions.
final followUpProvider =
    StateNotifierProvider<FollowUpController, FollowUpState>(
  (ref) => FollowUpController(
    syncRepo: ref.watch(screeningSyncRepositoryProvider),
  ),
);
