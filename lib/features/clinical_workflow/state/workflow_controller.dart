import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/baby_context.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../condition_selection/state/condition_selection_controller.dart';
import '../../rd/state/rd_controller.dart';
import '../../rop/state/rop_controller.dart';
import '../domain/clinical_question.dart';
import '../domain/workflow_definition.dart';

/// In-memory state of the combined workflow for the current baby.
class WorkflowState {
  const WorkflowState({
    this.plan = WorkflowPlan.empty,
    this.stepIndex = 0,
    this.answers = const {},
  });

  final WorkflowPlan plan;
  final int stepIndex;

  /// Questionnaire answers per condition (questionnaire workflows only).
  final Map<NeonatalCondition, Map<String, ClinicalAnswer>> answers;

  WorkflowStep? get currentStep => plan.isEmpty ? null : plan.steps[stepIndex];

  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex >= plan.steps.length - 1;

  Map<String, ClinicalAnswer> answersFor(NeonatalCondition c) =>
      answers[c] ?? const {};

  WorkflowState copyWith({
    WorkflowPlan? plan,
    int? stepIndex,
    Map<NeonatalCondition, Map<String, ClinicalAnswer>>? answers,
  }) =>
      WorkflowState(
        plan: plan ?? this.plan,
        stepIndex: stepIndex ?? this.stepIndex,
        answers: answers ?? this.answers,
      );
}

class WorkflowController extends Notifier<WorkflowState> {
  @override
  WorkflowState build() => const WorkflowState();

  /// How to clear a dedicated module's state when its condition is removed.
  late final Map<NeonatalCondition, void Function()> _moduleResets = {
    NeonatalCondition.respiratoryDistress: () =>
        ref.read(rdProvider.notifier).reset(),
    NeonatalCondition.rop: () => ref.read(ropProvider.notifier).reset(),
  };

  /// Builds the plan for [selected] and starts at the first step. Anything
  /// recorded for conditions that are no longer selected is discarded.
  void start(Set<NeonatalCondition> selected) {
    for (final c in state.plan.conditions) {
      if (!selected.contains(c)) _moduleResets[c]?.call();
    }
    state = WorkflowState(
      plan: buildWorkflowPlan(selected),
      answers: {
        for (final e in state.answers.entries)
          if (selected.contains(e.key)) e.key: e.value,
      },
    );
  }

  void goTo(int i) {
    if (state.plan.isEmpty) return;
    state = state.copyWith(stepIndex: i.clamp(0, state.plan.steps.length - 1));
  }

  void next() => goTo(state.stepIndex + 1);
  void back() => goTo(state.stepIndex - 1);

  void setAnswer(
    NeonatalCondition c,
    String questionId,
    ClinicalAnswer answer,
  ) {
    var forCondition = {...state.answersFor(c), questionId: answer};
    final w = workflowFor(c);
    if (w is QuestionnaireWorkflow) {
      forCondition = pruneHiddenAnswers(w.questions, forCondition);
    }
    state = state.copyWith(answers: {...state.answers, c: forCondition});
  }

  /// Everything for a new baby: selection, workflow, modules, baby details.
  void newAssessment() {
    for (final reset in _moduleResets.values) {
      reset();
    }
    ref.read(babyProvider.notifier).clear();
    ref.read(conditionSelectionProvider.notifier).clear();
    state = const WorkflowState();
  }
}

final workflowProvider =
    NotifierProvider<WorkflowController, WorkflowState>(WorkflowController.new);
