import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/condition_expr.dart';

class _R implements VariableReader {
  _R(this.vars, [this.findings = const {}]);
  final Map<String, Object?> vars;
  final Set<String> findings;

  @override
  Object? valueOf(String key) => vars[key];

  @override
  bool hasFinding(String id) => findings.contains(id);
}

void main() {
  final r = _R({
    'ga': 35,
    'sas': 4,
    'flag': true,
    'support': 'cpap',
    'signs': <Object>{'grunting', 'nasalFlaring'},
  }, {
    'rd.present',
  });

  test('comparison operators', () {
    expect(const Var('ga').eq(35).evaluate(r), isTrue);
    expect(const Var('ga').ne(34).evaluate(r), isTrue);
    expect(const Var('ga').gt(34).evaluate(r), isTrue);
    expect(const Var('ga').gt(35).evaluate(r), isFalse);
    expect(const Var('ga').ge(35).evaluate(r), isTrue);
    expect(const Var('ga').lt(36).evaluate(r), isTrue);
    expect(const Var('ga').le(34).evaluate(r), isFalse);
    expect(const Var('support').isIn({'cpap', 'nasalO2'}).evaluate(r), isTrue);
    expect(const Var('support').isIn({'none'}).evaluate(r), isFalse);
    expect(const Var('signs').contains('grunting').evaluate(r), isTrue);
    expect(const Var('signs').contains('retractions').evaluate(r), isFalse);
    expect(const Var('flag').exists().evaluate(r), isTrue);
    expect(const HasFinding('rd.present').evaluate(r), isTrue);
    expect(const HasFinding('rop.eligible').evaluate(r), isFalse);
  });

  test('AND / OR / NOT', () {
    // gestational_age > 34 AND silverman_score >= 4
    final andCond = AllOf([const Var('ga').gt(34), const Var('sas').ge(4)]);
    expect(andCond.evaluate(r), isTrue);
    expect(AllOf([const Var('ga').gt(34), const Var('sas').ge(5)]).evaluate(r),
        isFalse);

    // gestational_age >= 34 AND gestational_age <= 36
    expect(AllOf([const Var('ga').ge(34), const Var('ga').le(36)]).evaluate(r),
        isTrue);

    expect(
        AnyOf([const Var('ga').lt(30), const Var('flag').eq(true)]).evaluate(r),
        isTrue);
    expect(
        AnyOf([const Var('ga').lt(30), const Var('flag').eq(false)])
            .evaluate(r),
        isFalse);
    expect(Not(const Var('flag').eq(true)).evaluate(r), isFalse);
    expect(const AllOf([]).evaluate(r), isTrue);
    expect(const AnyOf([]).evaluate(r), isFalse);
  });

  test('missing values: every comparison is false, EXISTS is false', () {
    for (final c in [
      const Var('x').eq(1),
      const Var('x').ne(1),
      const Var('x').gt(0),
      const Var('x').ge(0),
      const Var('x').lt(0),
      const Var('x').le(0),
      const Var('x').isIn({1}),
      const Var('x').contains(1),
      const Var('x').exists(),
    ]) {
      expect(c.evaluate(r), isFalse, reason: c.describe());
    }
    // NOT of an unknown comparison is true: use EXISTS where it matters.
    expect(Not(const Var('x').eq(1)).evaluate(r), isTrue);
  });

  test('numeric comparison never applies to non-numbers', () {
    expect(const Var('support').gt(1).evaluate(r), isFalse);
  });

  test('describe() is readable', () {
    expect(
      AllOf([const Var('ga').ge(34), const Var('ga').le(36)]).describe(),
      '(ga >= 34 AND ga <= 36)',
    );
  });
}
