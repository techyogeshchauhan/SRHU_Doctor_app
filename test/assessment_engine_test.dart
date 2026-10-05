// Generic engine behaviour, using TEST FIXTURE workflows only. The fixture
// questions and rules below are placeholders, not clinical content.
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_rule.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/condition_expr.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

const _a = NeonatalCondition.triage;
const _b = NeonatalCondition.thermalCare;
const _src = SourceReference.dataEntry('test fixture');

ClinicalQuestion _q(
  String id,
  QuestionType type, {
  String group = 'g1',
  List<QuestionOption> options = const [],
  Cond? visibleWhen,
}) =>
    ClinicalQuestion(
      id: id,
      group: group,
      question: 'Fixture $id',
      type: type,
      options: options,
      visibleWhen: visibleWhen,
      sources: const [_src],
    );

final shared = _q('shared_num', QuestionType.numeric, group: 'common');
final gate = _q('gate', QuestionType.boolean);
final branch =
    _q('branch', QuestionType.numeric, visibleWhen: const Var('gate').eq(true));
final multi = _q('multi', QuestionType.multipleChoice, options: [
  const QuestionOption('x', 'X'),
  QuestionOption('y', 'Y', visibleWhen: const Var('gate').eq(true)),
]);
final onlyB = _q('only_b', QuestionType.text, group: 'g2');
final afterFinding = _q('after_finding', QuestionType.boolean, group: 'g2');

final wfA = StwWorkflow(
  _a,
  source: _src,
  groups: const [],
  uses: [
    QuestionUse(shared, required: true),
    QuestionUse(gate),
    QuestionUse(branch, required: true),
    QuestionUse(multi),
  ],
  variables: [
    ClinicalVariable(
        'double',
        'fixture',
        (r) => (r.valueOf('shared_num') as int?) == null
            ? null
            : (r.valueOf('shared_num')! as int) * 2),
  ],
  rules: [
    ClinicalRule(
      id: 'a.high',
      topic: _a,
      // NOT(gate) AND (double > 10 OR branch >= 3)
      when: AllOf([
        Not(const Var('gate').eq(true)),
        AnyOf([const Var('double').gt(10), const Var('branch').ge(3)]),
      ]),
      source: _src,
      then: (_) => const FindingContent(
        category: FindingCategory.assessment,
        level: FindingLevel.info,
        title: 'Fixture finding A',
      ),
    ),
  ],
);

final wfB = StwWorkflow(
  _b,
  source: _src,
  groups: const [],
  uses: [
    QuestionUse(shared, when: const Var('gate').ne(true)),
    QuestionUse(onlyB),
    QuestionUse(afterFinding, when: const HasFinding('a.high')),
  ],
  variables: const [],
  rules: const [],
);

WorkflowDefinition _lookup(NeonatalCondition c) => switch (c) {
      _a => wfA,
      _b => wfB,
      _ => PendingWorkflow(c),
    };

const fx = AssessmentEngine(lookup: _lookup);

Set<String> _applicable(Set<NeonatalCondition> sel, Map<String, Object?> a) {
  final ctx = fx.evaluate(selected: sel, answers: a, today: DateTime(2026));
  return {for (final q in fx.applicableQuestions(ctx)) q.id};
}

void main() {
  group('question resolution', () {
    test('a question used by two workflows appears once, first', () {
      final r = fx.resolve({_a, _b});
      expect(r.where((q) => q.id == 'shared_num'), hasLength(1));
      expect(r.first.id, 'shared_num');
      expect(r.first.topics, {_a, _b});
      expect(r.first.isShared, isTrue);
    });

    test('order: shared first, then each workflow in topic order', () {
      expect(fx.resolve({_b, _a}).map((q) => q.id).toList(), [
        'shared_num',
        'gate',
        'branch',
        'multi',
        'only_b',
        'after_finding',
      ]);
    });

    test('pending workflows contribute nothing', () {
      expect(fx.resolve({NeonatalCondition.sepsis}), isEmpty);
    });
  });

  group('conditional visibility', () {
    test('condition false → hidden, true → visible', () {
      expect(_applicable({_a}, {}), isNot(contains('branch')));
      expect(_applicable({_a}, {'gate': true}), contains('branch'));
    });

    test('shared question stays while any using workflow needs it', () {
      // wfB stops needing it when gate is on, but wfA still does.
      expect(_applicable({_a, _b}, {'gate': true}), contains('shared_num'));
      expect(_applicable({_b}, {'gate': true}), isNot(contains('shared_num')));
    });

    test('question activated by a rule finding (NOT + OR + numeric)', () {
      expect(_applicable({_a, _b}, {'shared_num': 4}),
          isNot(contains('after_finding')));
      expect(
          _applicable({_a, _b}, {'shared_num': 6}), contains('after_finding'));
      expect(_applicable({_a, _b}, {'shared_num': 6, 'gate': true}),
          isNot(contains('after_finding')));
    });
  });

  group('pruning', () {
    test('answers of hidden questions are dropped', () {
      final ctx = fx.evaluate(
        selected: {_a},
        answers: {'gate': false, 'branch': 9},
        completed: {'branch'},
        today: DateTime(2026),
      );
      expect(ctx.answers.containsKey('branch'), isFalse);
      expect(ctx.completedQuestions, isNot(contains('branch')));
      // branch = 9 must not fire the rule once hidden.
      expect(ctx.hasFinding('a.high'), isFalse);
    });

    test('hidden option values are dropped from answers', () {
      final ctx = fx.evaluate(
        selected: {_a},
        answers: {
          'multi': <Object>{'x', 'y'}
        },
        today: DateTime(2026),
      );
      expect(ctx.answers['multi'], {'x'});
    });

    test('deselecting a topic removes its questions, answers and findings', () {
      final both = fx.evaluate(
        selected: {_a, _b},
        answers: {'shared_num': 6, 'only_b': 'text'},
        today: DateTime(2026),
      );
      expect(both.answers['only_b'], 'text');
      final onlyA = fx.evaluate(
        selected: {_a},
        answers: both.answers,
        today: DateTime(2026),
      );
      expect(onlyA.answers.containsKey('only_b'), isFalse);
      expect(onlyA.answers['shared_num'], 6);
      final none = fx.evaluate(
        selected: {_b},
        answers: both.answers,
        today: DateTime(2026),
      );
      expect(none.findings, isEmpty);
    });
  });

  group('pages and progress', () {
    test('next page, required questions, confirm defaults', () {
      var ctx = fx.evaluate(selected: {_a}, answers: {}, today: DateTime(2026));
      expect(fx.nextGroup(ctx), 'common');
      expect(fx.canConfirm(ctx, 'common'), isFalse);
      ctx = fx.evaluate(
          selected: {_a}, answers: {'shared_num': 1}, today: DateTime(2026));
      expect(fx.canConfirm(ctx, 'common'), isTrue);
      final c = fx.confirmPage(ctx, 'common');
      ctx = fx.evaluate(
        selected: {_a},
        answers: c.answers,
        completed: c.completed,
        today: DateTime(2026),
      );
      expect(fx.nextGroup(ctx), 'g1');
      final c2 = fx.confirmPage(ctx, 'g1');
      expect(c2.answers['gate'], false);
      expect(c2.answers['multi'], <Object>{});
      ctx = fx.evaluate(
        selected: {_a},
        answers: c2.answers,
        completed: c2.completed,
        today: DateTime(2026),
      );
      expect(fx.nextGroup(ctx), isNull);
      expect(fx.progress(ctx), (3, 3));
    });

    test('validation rejects wrong types and out-of-range values', () {
      const q = ClinicalQuestion(
        id: 'n',
        group: 'g',
        question: 'n',
        type: QuestionType.numeric,
        min: 1,
        max: 5,
        sources: [_src],
      );
      expect(q.validate(3), isNull);
      expect(q.validate(9), isNotNull);
      expect(q.validate('3'), isNotNull);
      expect(multi.validate(<Object>{'x'}), isNull);
      expect(multi.validate(<Object>{'z'}), isNotNull);
    });
  });
}
