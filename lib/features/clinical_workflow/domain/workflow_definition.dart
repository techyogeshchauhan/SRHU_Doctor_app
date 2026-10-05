/// Workflow definitions for the 14 topics. Pure Dart.
///
/// A workflow does not own its questions: it lists [QuestionUse]s pointing at
/// question definitions, so a question shared by several workflows (e.g.
/// gestational age) is one object, asked once.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'clinical_question.dart';
import 'clinical_rule.dart';
import 'condition_expr.dart';
import 'source_reference.dart';

/// How one workflow uses a question.
class QuestionUse {
  const QuestionUse(
    this.question, {
    this.when,
    this.required = false,
    this.requiredWhen,
  });

  final ClinicalQuestion question;

  /// This workflow needs the question only while [when] holds.
  final Cond? when;
  final bool required;

  /// Required only while this holds (otherwise optional).
  final Cond? requiredWhen;

  bool isActive(VariableReader r) => when?.evaluate(r) ?? true;

  bool isRequired(VariableReader r) =>
      required || (requiredWhen?.evaluate(r) ?? false);
}

sealed class WorkflowDefinition {
  const WorkflowDefinition(this.condition);

  final NeonatalCondition condition;

  ConditionDefinition get definition => definitionOf(condition);
}

/// A workflow implemented from an approved STW.
class StwWorkflow extends WorkflowDefinition {
  const StwWorkflow(
    super.condition, {
    required this.source,
    required this.groups,
    required this.uses,
    required this.variables,
    required this.rules,
    this.persistentKeys = const {},
    this.recordTextKey,
  });

  final SourceReference source;
  final List<QuestionGroup> groups;

  /// In asking order.
  final List<QuestionUse> uses;

  /// Computed in order after answers change; later variables may read
  /// earlier ones.
  final List<ClinicalVariable> variables;

  /// Evaluated in order after variables.
  final List<ClinicalRule> rules;

  /// Context keys written by actions rather than questions (e.g. the RD SAS
  /// history), kept while the workflow is selected.
  final Set<String> persistentKeys;

  /// Variable holding a ready-to-copy record produced by the workflow's own
  /// engine (e.g. the ROP discharge-card text), shown in the summary.
  final String? recordTextKey;
}

/// No approved STW supplied yet: no questions, rules or recommendations.
class PendingWorkflow extends WorkflowDefinition {
  const PendingWorkflow(super.condition);
}
