/// Workflow registry and orchestration for the selected conditions.
///
/// Pure Dart. [workflowFor] is the single place that says how each condition
/// is handled; [buildWorkflowPlan] turns a selection into ordered steps.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'clinical_question.dart';

/// Baby details collected once and shared by every workflow that needs them
/// (held in `babyProvider`).
enum SharedField {
  gestationalAge,
  birthWeight,
  dateOfBirth,
}

sealed class WorkflowDefinition {
  const WorkflowDefinition(this.condition, {this.sharedFields = const {}});

  final NeonatalCondition condition;
  final Set<SharedField> sharedFields;

  ConditionDefinition get definition => definitionOf(condition);
}

/// A condition with its own dedicated module (existing screen and engine).
class ModuleWorkflow extends WorkflowDefinition {
  const ModuleWorkflow(
    super.condition, {
    required this.route,
    super.sharedFields,
  });

  final String route;
}

/// A condition driven by a data-defined questionnaire. Reserved for future
/// STWs; questions must come from the approved STW.
class QuestionnaireWorkflow extends WorkflowDefinition {
  const QuestionnaireWorkflow(
    super.condition, {
    required this.questions,
    super.sharedFields,
  });

  final List<ClinicalQuestion> questions;
}

/// No approved STW available yet: no questions, no recommendations.
class PendingWorkflow extends WorkflowDefinition {
  const PendingWorkflow(super.condition);
}

/// RD reads GA and birth weight (BW surrogate when GA is uncertain); ROP also
/// needs the date of birth for screening timing and PMA.
const _registry = <NeonatalCondition, WorkflowDefinition>{
  NeonatalCondition.respiratoryDistress: ModuleWorkflow(
    NeonatalCondition.respiratoryDistress,
    route: '/rd',
    sharedFields: {SharedField.gestationalAge, SharedField.birthWeight},
  ),
  NeonatalCondition.rop: ModuleWorkflow(
    NeonatalCondition.rop,
    route: '/rop',
    sharedFields: {
      SharedField.gestationalAge,
      SharedField.birthWeight,
      SharedField.dateOfBirth,
    },
  ),
};

WorkflowDefinition workflowFor(NeonatalCondition c) =>
    _registry[c] ?? PendingWorkflow(c);

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

sealed class WorkflowStep {
  const WorkflowStep();

  String get title;
}

class CommonInfoStep extends WorkflowStep {
  const CommonInfoStep(this.fields);

  final Set<SharedField> fields;

  @override
  String get title => 'Baby details';
}

class ConditionStep extends WorkflowStep {
  const ConditionStep(this.workflow);

  final WorkflowDefinition workflow;

  NeonatalCondition get condition => workflow.condition;

  @override
  String get title => workflow.definition.title;
}

class SummaryStep extends WorkflowStep {
  const SummaryStep();

  @override
  String get title => 'Summary';
}

class WorkflowPlan {
  const WorkflowPlan(this.steps);

  static const empty = WorkflowPlan([]);

  final List<WorkflowStep> steps;

  /// Selected conditions in workflow order.
  List<NeonatalCondition> get conditions => [
        for (final s in steps)
          if (s is ConditionStep) s.condition,
      ];

  bool includes(NeonatalCondition c) => conditions.contains(c);

  Set<SharedField> get sharedFields => {
        for (final s in steps)
          if (s is CommonInfoStep) ...s.fields,
      };

  bool get isEmpty => steps.isEmpty;
}

/// Common info (only the shared fields actually needed, asked once) →
/// each selected condition in canonical order → combined summary.
WorkflowPlan buildWorkflowPlan(Set<NeonatalCondition> selected) {
  if (selected.isEmpty) return WorkflowPlan.empty;
  final workflows = [
    for (final c in NeonatalCondition.values)
      if (selected.contains(c)) workflowFor(c),
  ];
  final shared = {for (final w in workflows) ...w.sharedFields};
  return WorkflowPlan([
    if (shared.isNotEmpty) CommonInfoStep(shared),
    for (final w in workflows) ConditionStep(w),
    const SummaryStep(),
  ]);
}
