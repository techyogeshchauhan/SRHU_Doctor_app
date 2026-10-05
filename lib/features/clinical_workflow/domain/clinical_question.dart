/// Data-driven clinical questions. Pure Dart.
///
/// A question is defined once with a stable [ClinicalQuestion.id] and may be
/// used by several workflows (e.g. gestational age by RD and ROP); the engine
/// asks it once and every workflow reads the same answer. Question text and
/// options must come from the corresponding approved STW.
library;

import 'condition_expr.dart';
import 'source_reference.dart';

enum QuestionType { singleChoice, multipleChoice, numeric, text, date, boolean }

/// Answer value types by [QuestionType]: singleChoice → the option value
/// (String/int/bool), multipleChoice → `Set<Object>` of option values,
/// numeric → int, text → String, date → DateTime, boolean → bool.
class QuestionOption {
  const QuestionOption(
    this.value,
    this.label, {
    this.subtitle,
    this.image,
    this.visibleWhen,
  });

  final Object value;
  final String label;
  final String? subtitle;

  /// Optional asset shown with the option (e.g. the SAS drawings).
  final String? image;

  /// Option shown only when this holds (e.g. CPAP-only warning signs).
  final Cond? visibleWhen;
}

/// Questions with the same group are shown together on one page.
class QuestionGroup {
  const QuestionGroup(
    this.id,
    this.title, {
    this.subtitle,
    this.footnote,
    this.questionOrder = const [],
  });

  final String id;
  final String title;
  final String? subtitle;

  /// Shown under the questions (e.g. a figure credit the STW requires).
  final String? footnote;

  /// Display order of question ids on the page; others follow in
  /// resolution order. Display only: asking order is unaffected.
  final List<String> questionOrder;
}

class ClinicalQuestion {
  const ClinicalQuestion({
    required this.id,
    required this.group,
    required this.question,
    required this.type,
    required this.sources,
    String? variable,
    this.options = const [],
    this.visibleWhen,
    this.min,
    this.max,
    this.unit,
    this.helper,
    this.pastOnly = false,
  }) : variable = variable ?? id;

  final String id;
  final String group;
  final String question;
  final QuestionType type;

  /// Context key the answer is stored under (defaults to [id]).
  final String variable;
  final List<QuestionOption> options;

  /// Global visibility (applies to every workflow using the question).
  final Cond? visibleWhen;

  /// Numeric range (numeric questions only).
  final int? min;
  final int? max;
  final String? unit;
  final String? helper;

  /// Date questions: no date after the assessment date (e.g. date of birth).
  final bool pastOnly;
  final List<SourceReference> sources;

  /// Null when [value] is acceptable for this question, else the reason.
  String? validate(Object? value) {
    if (value == null) return null;
    final ok = switch (type) {
      QuestionType.singleChoice => options.any((o) => o.value == value),
      QuestionType.multipleChoice =>
        value is Set && value.every((v) => options.any((o) => o.value == v)),
      QuestionType.numeric => value is int &&
          (min == null || value >= min!) &&
          (max == null || value <= max!),
      QuestionType.text => value is String,
      QuestionType.date => value is DateTime,
      QuestionType.boolean => value is bool,
    };
    return ok ? null : 'Invalid answer for "$question"';
  }

  /// Value stored when a page is confirmed without an answer: an unticked
  /// switch is "no", an empty checklist is "none".
  Object? get defaultOnConfirm => switch (type) {
        QuestionType.boolean => false,
        QuestionType.multipleChoice => const <Object>{},
        _ => null,
      };

  bool isAnswered(Object? value) => switch (type) {
        QuestionType.text => value is String && value.trim().isNotEmpty,
        QuestionType.multipleChoice => value is Set,
        _ => value != null,
      };
}
