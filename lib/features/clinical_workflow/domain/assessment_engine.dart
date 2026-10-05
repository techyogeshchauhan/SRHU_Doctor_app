/// Question resolution and rule evaluation. Pure Dart, deterministic.
///
/// After every answer: answers → derived variables → rules → findings →
/// applicable questions. Answers to questions that no longer apply are
/// dropped (repeated until stable), so they cannot feed any rule.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'assessment_context.dart';
import 'clinical_finding.dart';
import 'clinical_question.dart';
import 'condition_expr.dart';
import 'workflow_definition.dart';
import 'workflow_registry.dart';

/// A question with every selected workflow that uses it.
class ResolvedQuestion {
  const ResolvedQuestion(this.question, this.uses);

  final ClinicalQuestion question;
  final List<(NeonatalCondition, QuestionUse)> uses;

  String get id => question.id;
  Set<NeonatalCondition> get topics => {for (final (t, _) in uses) t};
  bool get isShared => topics.length > 1;
}

class AssessmentEngine {
  const AssessmentEngine({this.lookup = workflowFor});

  final WorkflowDefinition Function(NeonatalCondition) lookup;

  static const _maxPasses = 12;

  /// Selected STW workflows in canonical topic order.
  List<StwWorkflow> workflowsFor(Set<NeonatalCondition> selected) => [
        for (final c in NeonatalCondition.values)
          if (selected.contains(c))
            if (lookup(c) case final StwWorkflow w) w,
      ];

  /// Questions of the selected workflows, de-duplicated by id. Questions
  /// used by more than one selected workflow come first, then the rest in
  /// topic order.
  List<ResolvedQuestion> resolve(Set<NeonatalCondition> selected) {
    final byId = <String, ResolvedQuestion>{};
    for (final w in workflowsFor(selected)) {
      for (final u in w.uses) {
        final existing = byId[u.question.id];
        byId[u.question.id] = ResolvedQuestion(
          u.question,
          [...?existing?.uses, (w.condition, u)],
        );
      }
    }
    final all = byId.values.toList();
    return [
      ...all.where((q) => q.isShared),
      ...all.where((q) => !q.isShared),
    ];
  }

  /// Builds the context for [selected] from raw [answers], dropping answers
  /// (and completions) for questions that do not apply.
  ClinicalAssessmentContext evaluate({
    required Set<NeonatalCondition> selected,
    required Map<String, Object?> answers,
    Set<String> completed = const {},
    required DateTime today,
  }) {
    final resolved = resolve(selected);
    final workflows = workflowsFor(selected);
    final persistent = {for (final w in workflows) ...w.persistentKeys};
    var effective = {
      for (final e in answers.entries)
        if (e.value != null) e.key: e.value,
    };
    late ClinicalAssessmentContext ctx;
    for (var pass = 0; pass < _maxPasses; pass++) {
      ctx = _derive(selected, workflows, effective, completed, today);
      final applicable = applicableQuestions(ctx, resolved);
      final next = <String, Object?>{
        for (final k in persistent)
          if (effective.containsKey(k)) k: effective[k],
      };
      for (final rq in applicable) {
        final q = rq.question;
        final v = _visibleValue(q, effective[q.variable], ctx);
        if (v != null) next[q.variable] = v;
      }
      if (_sameAnswers(next, effective)) break;
      effective = next;
    }
    final applicableIds = {
      for (final rq in applicableQuestions(ctx, resolved)) rq.id,
    };
    return _derive(
      selected,
      workflows,
      effective,
      completed.where(applicableIds.contains).toSet(),
      today,
    );
  }

  ClinicalAssessmentContext _derive(
    Set<NeonatalCondition> selected,
    List<StwWorkflow> workflows,
    Map<String, Object?> answers,
    Set<String> completed,
    DateTime today,
  ) {
    final vars = <String, Object?>{...answers};
    final findings = <ClinicalFinding>[];
    final reader = _Reader(vars, findings, today);
    final seen = <String>{};
    for (final w in workflows) {
      for (final v in w.variables) {
        if (seen.add(v.key)) vars[v.key] = v.compute(reader);
      }
    }
    for (final w in workflows) {
      for (final rule in w.rules) {
        if (rule.when.evaluate(reader)) {
          findings.add(ClinicalFinding(
            id: rule.id,
            topic: rule.topic,
            content: rule.then(reader),
            source: rule.source,
          ));
        }
      }
    }
    return ClinicalAssessmentContext(
      selected: Set.unmodifiable(selected),
      answers: Map.unmodifiable(answers),
      variables: Map.unmodifiable(vars),
      findings: List.unmodifiable(findings),
      completedQuestions: Set.unmodifiable(completed),
      today: today,
    );
  }

  /// Drops option values that are currently hidden.
  Object? _visibleValue(ClinicalQuestion q, Object? v, VariableReader r) {
    if (v == null) return null;
    bool shown(Object value) => q.options
        .any((o) => o.value == value && (o.visibleWhen?.evaluate(r) ?? true));
    return switch (q.type) {
      QuestionType.singleChoice => shown(v) ? v : null,
      QuestionType.multipleChoice =>
        v is Set ? <Object>{...v.whereType<Object>().where(shown)} : null,
      _ => v,
    };
  }

  static bool _sameAnswers(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      final v = e.value;
      if (v is Set && o is Set) {
        if (v.length != o.length || !v.containsAll(o)) return false;
      } else if (v != o) {
        return false;
      }
    }
    return true;
  }

  /// Questions that apply now: globally visible and needed by at least one
  /// selected workflow.
  List<ResolvedQuestion> applicableQuestions(
    ClinicalAssessmentContext ctx, [
    List<ResolvedQuestion>? resolved,
  ]) =>
      [
        for (final rq in resolved ?? resolve(ctx.selected))
          if ((rq.question.visibleWhen?.evaluate(ctx) ?? true) &&
              rq.uses.any((u) => u.$2.isActive(ctx)))
            rq,
      ];

  bool isRequired(ResolvedQuestion rq, ClinicalAssessmentContext ctx) =>
      rq.uses.any((u) => u.$2.isActive(ctx) && u.$2.isRequired(ctx));

  List<QuestionOption> visibleOptions(
    ClinicalQuestion q,
    VariableReader r,
  ) =>
      [
        for (final o in q.options)
          if (o.visibleWhen?.evaluate(r) ?? true) o,
      ];

  /// Group of the first applicable question not yet confirmed; null when
  /// the assessment is complete.
  String? nextGroup(ClinicalAssessmentContext ctx) {
    for (final rq in applicableQuestions(ctx)) {
      if (!ctx.completedQuestions.contains(rq.id)) return rq.question.group;
    }
    return null;
  }

  /// Applicable questions of [group], in the group's display order.
  List<ResolvedQuestion> pageQuestions(
    ClinicalAssessmentContext ctx,
    String group,
  ) {
    final page = [
      for (final rq in applicableQuestions(ctx))
        if (rq.question.group == group) rq,
    ];
    final order = groupInfo(ctx.selected, group)?.questionOrder ?? const [];
    int rank(ResolvedQuestion rq) {
      final i = order.indexOf(rq.id);
      return i < 0 ? order.length : i;
    }

    // Stable sort: unlisted questions keep resolution order.
    final indexed = page.indexed.toList()
      ..sort((a, b) {
        final c = rank(a.$2).compareTo(rank(b.$2));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, rq) in indexed) rq];
  }

  /// The page can be confirmed when every required question on it is
  /// answered.
  bool canConfirm(ClinicalAssessmentContext ctx, String group) =>
      pageQuestions(ctx, group).every((rq) =>
          !isRequired(rq, ctx) ||
          rq.question.isAnswered(ctx.answers[rq.question.variable]));

  /// Marks every applicable question of [group] as completed, storing the
  /// "no / none" default for unanswered switches and checklists. Re-run
  /// [evaluate] on the result.
  ({Map<String, Object?> answers, Set<String> completed}) confirmPage(
    ClinicalAssessmentContext ctx,
    String group,
  ) {
    final answers = {...ctx.answers};
    final completed = {...ctx.completedQuestions};
    for (final rq in pageQuestions(ctx, group)) {
      final q = rq.question;
      if (!q.isAnswered(answers[q.variable]) && q.defaultOnConfirm != null) {
        answers[q.variable] = q.defaultOnConfirm;
      }
      completed.add(q.id);
    }
    return (answers: answers, completed: completed);
  }

  /// (confirmed, applicable) question counts. The total can change as
  /// answers activate or skip questions.
  (int, int) progress(ClinicalAssessmentContext ctx) {
    final applicable = applicableQuestions(ctx);
    final done =
        applicable.where((rq) => ctx.completedQuestions.contains(rq.id));
    return (done.length, applicable.length);
  }

  QuestionGroup? groupInfo(Set<NeonatalCondition> selected, String id) {
    for (final w in workflowsFor(selected)) {
      for (final g in w.groups) {
        if (g.id == id) return g;
      }
    }
    return null;
  }
}

class _Reader implements VariableReader {
  _Reader(this.vars, this.findings, this.today);

  final Map<String, Object?> vars;
  final List<ClinicalFinding> findings;
  final DateTime today;

  @override
  Object? valueOf(String key) => key == todayKey ? today : vars[key];

  @override
  bool hasFinding(String id) => findings.any((f) => f.id == id);
}
