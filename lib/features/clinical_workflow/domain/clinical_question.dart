/// Data-driven questionnaire model for future STW workflows.
///
/// Pure Dart. Questions and their branching are plain data, so a new STW can
/// define its questionnaire without new widgets. Question text, options and
/// branching must come from the corresponding approved STW.
library;

import '../../condition_selection/domain/neonatal_condition.dart';

enum QuestionType { singleChoice, multipleChoice, numeric, text, date, boolean }

class QuestionOption {
  const QuestionOption(this.value, this.label);

  final String value;
  final String label;
}

/// Immutable answer value. The type depends on [QuestionType]:
/// singleChoice/text → `String`, multipleChoice → `Set<String>`, numeric → num,
/// date → DateTime, boolean → bool.
class ClinicalAnswer {
  const ClinicalAnswer(this.value);

  final Object? value;

  bool get isEmpty =>
      value == null ||
      (value is String && (value as String).trim().isEmpty) ||
      (value is Set && (value as Set).isEmpty);

  String? get asString => value is String ? value as String : null;
  Set<String> get asSet =>
      value is Set<String> ? value as Set<String> : const {};
  num? get asNum => value is num ? value as num : null;
  DateTime? get asDate => value is DateTime ? value as DateTime : null;
  bool? get asBool => value is bool ? value as bool : null;
}

/// Show a question only when an earlier answer matches.
///
/// For multipleChoice answers, the condition holds if any selected value
/// matches.
class ShowWhen {
  const ShowWhen(this.questionId, {this.equals, this.anyOf = const {}});

  final String questionId;
  final Object? equals;
  final Set<Object> anyOf;

  bool isMetBy(Map<String, ClinicalAnswer> answers) {
    final v = answers[questionId]?.value;
    if (v == null) return false;
    final values = v is Set ? v : {v};
    return values.any((x) => x == equals || anyOf.contains(x));
  }
}

class ClinicalQuestion {
  const ClinicalQuestion({
    required this.id,
    required this.condition,
    required this.question,
    required this.type,
    this.options = const [],
    this.required = false,
    this.showWhen,
    this.min,
    this.max,
    this.unit,
  });

  final String id;
  final NeonatalCondition condition;
  final String question;
  final QuestionType type;
  final List<QuestionOption> options;
  final bool required;
  final ShowWhen? showWhen;

  /// Numeric range and unit (numeric questions only).
  final int? min;
  final int? max;
  final String? unit;
}

bool isVisible(ClinicalQuestion q, Map<String, ClinicalAnswer> answers) =>
    q.showWhen?.isMetBy(answers) ?? true;

List<ClinicalQuestion> visibleQuestions(
  List<ClinicalQuestion> questions,
  Map<String, ClinicalAnswer> answers,
) =>
    [
      for (final q in questions)
        if (isVisible(q, answers)) q
    ];

/// Required questions that are visible but not yet answered.
List<ClinicalQuestion> missingRequired(
  List<ClinicalQuestion> questions,
  Map<String, ClinicalAnswer> answers,
) =>
    [
      for (final q in visibleQuestions(questions, answers))
        if (q.required && (answers[q.id]?.isEmpty ?? true)) q,
    ];

/// Answers to questions that are no longer visible (a branch was switched
/// off) are dropped so they cannot feed into recommendations.
Map<String, ClinicalAnswer> pruneHiddenAnswers(
  List<ClinicalQuestion> questions,
  Map<String, ClinicalAnswer> answers,
) {
  final visible = {for (final q in visibleQuestions(questions, answers)) q.id};
  return {
    for (final e in answers.entries)
      if (visible.contains(e.key)) e.key: e.value,
  };
}
