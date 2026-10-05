/// Derived variables and deterministic clinical rules. Pure Dart.
///
/// No runtime LLM or heuristic: a rule is a [Cond] plus a builder that only
/// formats the outputs of the existing validated STW engines.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'clinical_finding.dart';
import 'condition_expr.dart';
import 'source_reference.dart';

/// A value computed from answers (and earlier variables), usually by the
/// existing validated RD/ROP engines, e.g. `rd_initial = initialPlan(...)`.
class ClinicalVariable {
  const ClinicalVariable(this.key, this.description, this.compute);

  final String key;
  final String description;
  final Object? Function(VariableReader r) compute;
}

/// Deterministic rule: when [when] holds, [then] builds the finding.
///
/// Rules run in declared order; a rule may test findings of earlier rules
/// via [HasFinding].
class ClinicalRule {
  const ClinicalRule({
    required this.id,
    required this.topic,
    required this.when,
    required this.source,
    required this.then,
  });

  final String id;
  final NeonatalCondition topic;
  final Cond when;
  final SourceReference source;
  final FindingContent Function(VariableReader r) then;
}
