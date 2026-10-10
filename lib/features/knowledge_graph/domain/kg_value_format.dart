/// Display text for answers and computed values in the graph. Pure Dart.
library;

import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';

/// [v] as shown on a node, using [q]'s option labels and unit when given.
/// Null when the value has no short text form (e.g. an engine result
/// object).
String? formatKgValue(Object? v, {ClinicalQuestion? q}) {
  if (v == null) return null;
  if (q != null) {
    String label(Object o) {
      for (final opt in q.options) {
        if (opt.value == o) return opt.label;
      }
      return _plain(o) ?? '$o';
    }

    switch (q.type) {
      case QuestionType.singleChoice:
        return label(v);
      case QuestionType.multipleChoice:
        if (v is! Iterable) return null;
        return v.isEmpty ? 'None' : v.whereType<Object>().map(label).join(', ');
      case QuestionType.numeric:
        return q.unit == null ? '$v' : '$v ${q.unit}';
      case QuestionType.date || QuestionType.text || QuestionType.boolean:
        break;
    }
  }
  return _plain(v);
}

String? _plain(Object v) => switch (v) {
      final bool b => b ? 'Yes' : 'No',
      final num n => '$n',
      final DateTime d => formatDmy(d),
      final String s => s.trim().isEmpty ? null : humanizeIdentifier(s),
      final Iterable i
          when i.every((e) => e is String || e is num || e is bool) =>
        i.isEmpty ? 'None' : i.map((e) => _plain(e as Object)).join(', '),
      _ => null,
    };

/// `moderateSevere` → `moderate severe`; other text unchanged.
String humanizeIdentifier(String s) {
  if (s.contains(' ') || !RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(s)) {
    return s;
  }
  return s.replaceAllMapped(
      RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}');
}

/// Short text of a comparison the rule made, e.g. `≥ 4` or
/// `includes Grunting`; null for presence checks and yes/no checks (the
/// node already shows Yes or No).
String? describeCheck(
  Compare c, {
  ClinicalQuestion? q,
  String? Function(Object value)? valueLabel,
}) {
  if (c.value is bool && (c.op == CmpOp.eq || c.op == CmpOp.ne)) return null;
  final asOne = q?.type == QuestionType.numeric ? q : _single(q);
  String fmt(Object? x) => x == null
      ? ''
      : (valueLabel?.call(x) ?? formatKgValue(x, q: asOne) ?? '$x');
  return switch (c.op) {
    CmpOp.exists => null,
    CmpOp.eq => '= ${fmt(c.value)}',
    CmpOp.ne => '≠ ${fmt(c.value)}',
    CmpOp.gt => '> ${fmt(c.value)}',
    CmpOp.ge => '≥ ${fmt(c.value)}',
    CmpOp.lt => '< ${fmt(c.value)}',
    CmpOp.le => '≤ ${fmt(c.value)}',
    CmpOp.isIn => c.value is Iterable
        ? 'one of ${(c.value as Iterable).whereType<Object>().map(fmt).join(', ')}'
        : null,
    CmpOp.contains => 'includes ${fmt(c.value)}',
  };
}

/// [q] as a single-choice question, so one compared value (e.g. one ticked
/// item of a checklist) maps to its option label.
ClinicalQuestion? _single(ClinicalQuestion? q) =>
    q == null || q.type == QuestionType.numeric
        ? null
        : ClinicalQuestion(
            id: q.id,
            group: q.group,
            question: q.question,
            type: QuestionType.singleChoice,
            options: q.options,
            sources: q.sources,
          );
