/// The single, in-memory state of the current neonatal assessment. Pure Dart.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'clinical_finding.dart';
import 'condition_expr.dart';

class ClinicalAssessmentContext implements VariableReader {
  const ClinicalAssessmentContext({
    required this.selected,
    required this.answers,
    required this.variables,
    required this.findings,
    required this.completedQuestions,
    required this.today,
  });

  factory ClinicalAssessmentContext.empty(DateTime today) =>
      ClinicalAssessmentContext(
        selected: const {},
        answers: const {},
        variables: const {},
        findings: const [],
        completedQuestions: const {},
        today: today,
      );

  /// Topics the clinician asked to assess (not diagnoses).
  final Set<NeonatalCondition> selected;

  /// Answers by variable key, limited to questions that currently apply.
  final Map<String, Object?> answers;

  /// Answers plus derived variables.
  final Map<String, Object?> variables;

  /// Findings from rules that fired, in rule order. Several may coexist.
  final List<ClinicalFinding> findings;

  /// Question ids the clinician has confirmed.
  final Set<String> completedQuestions;

  /// Date used for age/timing rules (date only).
  final DateTime today;

  @override
  Object? valueOf(String key) => key == todayKey ? today : variables[key];

  @override
  bool hasFinding(String id) => findings.any((f) => f.id == id);

  List<ClinicalFinding> findingsFor(NeonatalCondition topic) => [
        for (final f in findings)
          if (f.topic == topic) f
      ];

  /// Pathways, treatment, referral and follow-up results.
  List<ClinicalFinding> get outcomes => [
        for (final f in findings)
          if (f.category == FindingCategory.pathway ||
              f.category == FindingCategory.treatment ||
              f.category == FindingCategory.referral ||
              f.category == FindingCategory.followUp)
            f,
      ];
}

/// Variable key for the assessment date.
const todayKey = 'today';
