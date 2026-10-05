/// Deterministic condition language used for question visibility and
/// clinical rules. Pure Dart.
///
/// Conditions are data (an expression tree), evaluated against a
/// [VariableReader] such as the `ClinicalAssessmentContext`.
///
/// Missing values: every comparison on a missing (null) variable is false,
/// including `!=`. Use [Var.exists] to test presence explicitly. Note that
/// `Not(x)` of a comparison on a missing variable is therefore true.
library;

/// Read access to variables (answers + derived values) and active findings.
abstract interface class VariableReader {
  Object? valueOf(String key);
  bool hasFinding(String id);
}

sealed class Cond {
  const Cond();

  bool evaluate(VariableReader r);

  /// Human-readable form, e.g. `ga_weeks >= 34 AND ga_weeks <= 36`.
  String describe();

  @override
  String toString() => describe();
}

/// AND: true when every part is true (true for an empty list).
class AllOf extends Cond {
  const AllOf(this.parts);
  final List<Cond> parts;

  @override
  bool evaluate(VariableReader r) => parts.every((p) => p.evaluate(r));

  @override
  String describe() => '(${parts.map((p) => p.describe()).join(' AND ')})';
}

/// OR: true when any part is true (false for an empty list).
class AnyOf extends Cond {
  const AnyOf(this.parts);
  final List<Cond> parts;

  @override
  bool evaluate(VariableReader r) => parts.any((p) => p.evaluate(r));

  @override
  String describe() => '(${parts.map((p) => p.describe()).join(' OR ')})';
}

class Not extends Cond {
  const Not(this.inner);
  final Cond inner;

  @override
  bool evaluate(VariableReader r) => !inner.evaluate(r);

  @override
  String describe() => 'NOT ${inner.describe()}';
}

/// True when a rule has produced the finding [id].
class HasFinding extends Cond {
  const HasFinding(this.id);
  final String id;

  @override
  bool evaluate(VariableReader r) => r.hasFinding(id);

  @override
  String describe() => 'finding($id)';
}

enum CmpOp {
  eq('=='),
  ne('!='),
  gt('>'),
  ge('>='),
  lt('<'),
  le('<='),

  /// Variable value is one of the given values.
  isIn('IN'),

  /// Variable (a collection) contains the given value.
  contains('CONTAINS'),
  exists('EXISTS');

  const CmpOp(this.symbol);
  final String symbol;
}

class Compare extends Cond {
  const Compare(this.key, this.op, [this.value]);

  final String key;
  final CmpOp op;
  final Object? value;

  @override
  bool evaluate(VariableReader r) {
    final v = r.valueOf(key);
    if (v == null) return false;
    final x = value;
    return switch (op) {
      CmpOp.exists => true,
      CmpOp.eq => v == x,
      CmpOp.ne => x != null && v != x,
      CmpOp.gt => _num(v, x, (a, b) => a > b),
      CmpOp.ge => _num(v, x, (a, b) => a >= b),
      CmpOp.lt => _num(v, x, (a, b) => a < b),
      CmpOp.le => _num(v, x, (a, b) => a <= b),
      CmpOp.isIn => x is Iterable && x.contains(v),
      CmpOp.contains => v is Iterable && v.contains(x),
    };
  }

  static bool _num(Object v, Object? x, bool Function(num, num) f) =>
      v is num && x is num && f(v, x);

  @override
  String describe() => op == CmpOp.exists
      ? '$key EXISTS'
      : '$key ${op.symbol} ${value is Iterable ? '{${(value as Iterable).join(', ')}}' : value}';
}

/// Fluent builder: `Var('ga_weeks').ge(34)`.
class Var {
  const Var(this.key);
  final String key;

  Cond eq(Object v) => Compare(key, CmpOp.eq, v);
  Cond ne(Object v) => Compare(key, CmpOp.ne, v);
  Cond gt(num v) => Compare(key, CmpOp.gt, v);
  Cond ge(num v) => Compare(key, CmpOp.ge, v);
  Cond lt(num v) => Compare(key, CmpOp.lt, v);
  Cond le(num v) => Compare(key, CmpOp.le, v);
  Cond isIn(Set<Object> values) => Compare(key, CmpOp.isIn, values);
  Cond contains(Object v) => Compare(key, CmpOp.contains, v);
  Cond exists() => Compare(key, CmpOp.exists);
}
