import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/workflow_controller.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/state/rd_controller.dart';
import 'package:neonatal_stw/features/rop/state/rop_controller.dart';

const rd = NeonatalCondition.respiratoryDistress;
const rop = NeonatalCondition.rop;
const sepsis = NeonatalCondition.sepsis;

List<String> titles(WorkflowPlan p) => [for (final s in p.steps) s.title];

void main() {
  group('registry', () {
    test('RD and ROP reuse their existing modules', () {
      expect(workflowFor(rd), isA<ModuleWorkflow>());
      expect((workflowFor(rd) as ModuleWorkflow).route, '/rd');
      expect(workflowFor(rop), isA<ModuleWorkflow>());
      expect((workflowFor(rop) as ModuleWorkflow).route, '/rop');
    });

    test('the other 12 conditions are pending (no clinical content)', () {
      final pending = [
        for (final c in NeonatalCondition.values)
          if (workflowFor(c) is PendingWorkflow) c,
      ];
      expect(pending, hasLength(12));
      expect(pending, isNot(contains(rd)));
      expect(pending, isNot(contains(rop)));
      for (final c in pending) {
        expect(workflowFor(c).sharedFields, isEmpty);
      }
    });
  });

  group('buildWorkflowPlan', () {
    test('empty selection → empty plan', () {
      expect(buildWorkflowPlan({}).isEmpty, isTrue);
    });

    test('select RD → RD workflow is included', () {
      final p = buildWorkflowPlan({rd});
      expect(p.conditions, [rd]);
      expect(titles(p), ['Baby details', 'Respiratory Distress', 'Summary']);
    });

    test('select ROP → ROP workflow is included', () {
      final p = buildWorkflowPlan({rop});
      expect(p.conditions, [rop]);
      expect(p.includes(rop), isTrue);
    });

    test('select RD + ROP → both, shared details asked once', () {
      final p = buildWorkflowPlan({rop, rd});
      expect(titles(p),
          ['Baby details', 'Respiratory Distress', 'ROP', 'Summary']);
      expect(p.steps.whereType<CommonInfoStep>(), hasLength(1));
      expect(p.sharedFields, {
        SharedField.gestationalAge,
        SharedField.birthWeight,
        SharedField.dateOfBirth,
      });
    });

    test('canonical order regardless of selection order', () {
      final p = buildWorkflowPlan({rop, sepsis, rd});
      expect(p.conditions, [rd, sepsis, rop]);
    });

    test('DOB only asked when a selected workflow needs it', () {
      expect(buildWorkflowPlan({rd}).sharedFields,
          isNot(contains(SharedField.dateOfBirth)));
    });

    test('pending-only selection has no common step', () {
      final p = buildWorkflowPlan({sepsis, NeonatalCondition.jaundice});
      expect(titles(p), ['Sepsis', 'Jaundice', 'Summary']);
    });
  });

  group('WorkflowController', () {
    late ProviderContainer container;
    late WorkflowController n;
    WorkflowState state() => container.read(workflowProvider);

    setUp(() {
      container = ProviderContainer();
      n = container.read(workflowProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('remove ROP → ROP workflow removed and its state cleared', () {
      n.start({rd, rop});
      container.read(ropProvider.notifier).setPlace('District hospital');
      container.read(rdProvider.notifier).setSigns({RdSign.grunting});
      n.next();
      expect(state().stepIndex, 1);

      n.start({rd});
      expect(state().plan.includes(rop), isFalse);
      expect(state().plan.includes(rd), isTrue);
      expect(state().stepIndex, 0);
      expect(container.read(ropProvider).place, isEmpty);
      // Still-selected RD keeps its data.
      expect(container.read(rdProvider).signs, {RdSign.grunting});
    });

    test('answers for removed conditions are pruned', () {
      n.start({rd, sepsis});
      n.setAnswer(sepsis, 'q1', const ClinicalAnswer('x'));
      expect(state().answersFor(sepsis), isNotEmpty);
      n.start({rd});
      expect(state().answers.containsKey(sepsis), isFalse);
    });

    test('step navigation is clamped to the plan', () {
      n.start({rd});
      n.back();
      expect(state().stepIndex, 0);
      n.goTo(99);
      expect(state().isLast, isTrue);
      expect(state().currentStep, isA<SummaryStep>());
    });
  });

  group('questionnaire branching (test fixture, not clinical content)', () {
    const gate = ClinicalQuestion(
      id: 'gate',
      condition: sepsis,
      question: 'Fixture gate',
      type: QuestionType.boolean,
      required: true,
    );
    const branch = ClinicalQuestion(
      id: 'branch',
      condition: sepsis,
      question: 'Fixture branch',
      type: QuestionType.multipleChoice,
      options: [QuestionOption('a', 'A'), QuestionOption('b', 'B')],
      required: true,
      showWhen: ShowWhen('gate', equals: true),
    );
    const questions = [gate, branch];

    test('branch hidden until gate answered yes', () {
      expect(visibleQuestions(questions, {}).map((q) => q.id), ['gate']);
      expect(
        visibleQuestions(questions, {'gate': const ClinicalAnswer(false)})
            .map((q) => q.id),
        ['gate'],
      );
      expect(
        visibleQuestions(questions, {'gate': const ClinicalAnswer(true)})
            .map((q) => q.id),
        ['gate', 'branch'],
      );
    });

    test('missing required considers only visible questions', () {
      expect(missingRequired(questions, {}).map((q) => q.id), ['gate']);
      expect(
        missingRequired(questions, {'gate': const ClinicalAnswer(true)})
            .map((q) => q.id),
        ['branch'],
      );
    });

    test('anyOf matches multipleChoice answers', () {
      const w = ShowWhen('branch', anyOf: {'b'});
      expect(
          w.isMetBy({
            'branch': const ClinicalAnswer({'a'})
          }),
          isFalse);
      expect(
          w.isMetBy({
            'branch': const ClinicalAnswer({'a', 'b'})
          }),
          isTrue);
    });

    test('answers on a switched-off branch are dropped', () {
      final pruned = pruneHiddenAnswers(questions, {
        'gate': const ClinicalAnswer(false),
        'branch': const ClinicalAnswer({'a'}),
      });
      expect(pruned.keys, ['gate']);
    });
  });

  test('combined summary lays out only the given sections', () {
    final text = buildCombinedSummary(
      babyLine: 'GA 30+0 wk',
      selectedTitles: ['Respiratory Distress'],
      sections: const [
        SummarySection(title: 'Respiratory Distress', lines: ['Line 1']),
      ],
    );
    expect(text, contains('— RESPIRATORY DISTRESS —'));
    expect(text, contains('Line 1'));
    expect(text, isNot(contains('ROP')));
    expect(text, endsWith(combinedSummaryAdvisory));
  });
}
