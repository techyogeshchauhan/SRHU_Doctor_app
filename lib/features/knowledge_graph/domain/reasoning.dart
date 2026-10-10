/// Reasoning tree of an assessment: why each finding appeared. Pure Dart.
///
/// A finding is the main node; its children are the earlier findings,
/// computed values and answers its STW rule used, and each of those can be
/// opened to show what it came from in turn. The tree only explains the
/// existing rules: it is read from the selected workflows' questions,
/// variables and rules, and adds no clinical content or conclusions.
///
/// Inputs of a rule are its condition's variables plus whatever its finding
/// text reads. Inputs of a computed value are found by replaying it against
/// the final context through a [TracingReader] (variables are computed once,
/// in order, from fixed answers, so the replay reads what the engine read).
library;

import '../../clinical_workflow/domain/assessment_context.dart';
import '../../clinical_workflow/domain/assessment_engine.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'cond_introspection.dart';
import 'explained_values.dart';
import 'kg_value_format.dart';
import 'tracing_reader.dart';

enum ReasonKind {
  /// A finding produced by an STW rule.
  finding('Finding'),

  /// A value computed from answers, named in the STW.
  computed('Computed from your answers'),

  /// A clinician answer.
  answer('Your answer');

  const ReasonKind(this.label);
  final String label;
}

class ReasonNode {
  const ReasonNode({
    required this.id,
    required this.kind,
    required this.label,
    this.value,
    this.check,
    this.source,
    this.finding,
    this.topics = const {},
    this.children = const [],
  });

  /// `finding:<rule id>`, `value:<key>` or `answer:<key>`.
  final String id;
  final ReasonKind kind;

  /// Finding title, question text or STW value name.
  final String label;

  /// Formatted answer or computed value, e.g. "32 weeks".
  final String? value;

  /// The comparison the parent's rule made on this value, e.g. "< 45 mg/dL".
  final String? check;

  /// The STW box this step comes from; null for a step the STW does not
  /// cover (e.g. the assessment date).
  final SourceReference? source;

  /// Findings only.
  final ClinicalFinding? finding;

  /// Topics that use this answer (more than one: shared).
  final Set<NeonatalCondition> topics;

  /// What this step is based on.
  final List<ReasonNode> children;

  bool get isShared => topics.length > 1;

  FindingLevel? get level => finding?.level;

  /// Every node below this one.
  Iterable<ReasonNode> get descendants sync* {
    for (final c in children) {
      yield c;
      yield* c.descendants;
    }
  }
}

/// Answers used by more than one selected topic that lead to the same
/// findings, with those findings.
class SharedAnswer {
  const SharedAnswer(this.answers, this.findings);

  final List<ReasonNode> answers;
  final List<ClinicalFinding> findings;

  Set<NeonatalCondition> get topics => {for (final f in findings) f.topic};
}

class ReasoningBuilder {
  ReasoningBuilder(
    this.ctx, {
    this.engine = const AssessmentEngine(),
  }) {
    for (final w in engine.workflowsFor(ctx.selected)) {
      for (final v in w.variables) {
        _variables.putIfAbsent(v.key, () => v);
      }
      for (final r in w.rules) {
        _rules.putIfAbsent(r.id, () => r);
      }
    }
    for (final rq in engine.resolve(ctx.selected)) {
      _questions.putIfAbsent(rq.question.variable, () => rq);
    }
  }

  final ClinicalAssessmentContext ctx;
  final AssessmentEngine engine;

  final _variables = <String, ClinicalVariable>{};
  final _rules = <String, ClinicalRule>{};
  final _questions = <String, ResolvedQuestion>{};
  final _deps = <String, Set<String>>{};

  /// Why [f] appeared.
  ReasonNode explain(ClinicalFinding f) => _finding(f, {});

  /// Each finding of the assessment explained, in finding order.
  List<ReasonNode> explainAll() => [for (final f in ctx.findings) explain(f)];

  /// Answers that lead to findings of more than one topic.
  List<SharedAnswer> sharedAnswers([List<ReasonNode>? trees]) {
    final byAnswer = <String, (ReasonNode, List<ClinicalFinding>)>{};
    for (final t in trees ?? explainAll()) {
      for (final n in t.descendants) {
        if (n.kind != ReasonKind.answer) continue;
        final e = byAnswer.putIfAbsent(n.id, () => (n, []));
        if (!e.$2.contains(t.finding)) e.$2.add(t.finding!);
      }
    }
    // One entry per set of findings, so GA known + GA weeks read as one.
    final groups = <String, SharedAnswer>{};
    for (final (answer, findings) in byAnswer.values) {
      if ({for (final f in findings) f.topic}.length < 2) continue;
      final key = (findings.map((f) => f.id).toList()..sort()).join(',');
      final g = groups[key];
      groups[key] = SharedAnswer([...?g?.answers, answer], findings);
    }
    return groups.values.toList();
  }

  ReasonNode _finding(ClinicalFinding f, Set<String> path, {String? check}) {
    final rule = _rules[f.id];
    final children = <ReasonNode>[];
    if (rule != null && path.add(f.id)) {
      final traced = TracingReader.trace(ctx, (r) => rule.then(r));

      // Earlier findings this rule requires (e.g. "RD present").
      for (final id in {...rule.when.findingIds, ...traced.findings}) {
        if (id == f.id) continue;
        final dep = _firedFinding(id);
        if (dep != null) children.add(_finding(dep, {...path}));
      }

      final checks = rule.when.leafComparisons;
      for (final key in {...rule.when.variableKeys, ...traced.keys}) {
        final labels = {
          for (final c in checks)
            if (c.key == key && c.evaluate(ctx))
              describeCheck(
                c,
                q: _questions[key]?.question,
                valueLabel: explainedValues[key]?.display,
              ),
        }.whereType<String>();
        children.addAll(_reasons(
          key,
          f.source,
          check: labels.isEmpty ? null : labels.join(' · '),
          seen: {},
        ));
      }
    }
    return ReasonNode(
      id: 'finding:${f.id}',
      kind: ReasonKind.finding,
      label: f.title,
      check: check,
      source: f.source.isClinical ? f.source : null,
      finding: f,
      topics: {f.topic},
      children: _tidy(children),
    );
  }

  ClinicalFinding? _firedFinding(String id) {
    for (final f in ctx.findings) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The steps value [key] contributes to a rule cited in [context]: one
  /// answer or explained value, or (for an engine-internal value) the
  /// steps of the values it was computed from.
  List<ReasonNode> _reasons(
    String key,
    SourceReference context, {
    String? check,
    required Set<String> seen,
  }) {
    if (!seen.add(key)) return const [];
    final value = ctx.valueOf(key);
    if (value == null) return const [];

    if (key == todayKey) {
      return [
        ReasonNode(
          id: 'answer:$key',
          kind: ReasonKind.answer,
          label: 'Date of this assessment',
          value: formatKgValue(value),
          check: check,
        ),
      ];
    }

    final rq = _questions[key];
    if (rq != null) {
      final q = rq.question;
      return [
        ReasonNode(
          id: 'answer:$key',
          kind: ReasonKind.answer,
          label: q.question,
          value: formatKgValue(value, q: q),
          check: check,
          source: _sourceFor(q.sources, context),
          topics: rq.topics,
        ),
      ];
    }

    if (!_variables.containsKey(key)) return const []; // action-written key

    final explained = explainedValues[key];
    final shown = explained?.display?.call(value) ?? formatKgValue(value);
    if (explained != null && shown != null) {
      return [
        ReasonNode(
          id: 'value:$key',
          kind: ReasonKind.computed,
          label: explained.label,
          value: shown,
          check: check,
          source: explained.source,
          children: _tidy([
            for (final dep in explained.inputs?.call(ctx) ?? _depsOf(key))
              ..._reasons(dep, explained.source, seen: {key}),
          ]),
        ),
      ];
    }

    // Engine-internal value: its own inputs stand in for it.
    return [
      for (final dep in _depsOf(key)) ..._reasons(dep, context, seen: seen),
    ];
  }

  /// The question source from the same STW as [context] (e.g. GA cites the
  /// RD algorithm under an RD finding, ROP "Whom to screen" under an ROP
  /// one); else its first clinical source.
  SourceReference? _sourceFor(
    List<SourceReference> sources,
    SourceReference context,
  ) {
    for (final s in sources) {
      if (s.isClinical && s.document == context.document) return s;
    }
    for (final s in sources) {
      if (s.isClinical) return s;
    }
    return null;
  }

  Set<String> _depsOf(String key) => _deps.putIfAbsent(key, () {
        final v = _variables[key];
        if (v == null) return const {};
        return TracingReader.trace(ctx, (r) => v.compute(r)).keys..remove(key);
      });

  /// Drops duplicate children, and answers already shown under a sibling
  /// step (unless the rule checked them directly). Orders findings, then
  /// computed values, then answers.
  static List<ReasonNode> _tidy(List<ReasonNode> nodes) {
    final byId = <String, ReasonNode>{};
    for (final n in nodes) {
      final existing = byId[n.id];
      if (existing == null || (existing.check == null && n.check != null)) {
        byId[n.id] = n;
      }
    }
    final covered = {
      for (final n in byId.values)
        if (n.kind != ReasonKind.answer) ...n.descendants.map((d) => d.id),
    };
    final kept = [
      for (final n in byId.values)
        if (!(covered.contains(n.id) && n.check == null)) n,
    ];
    return [
      for (final kind in ReasonKind.values)
        ...kept.where((n) => n.kind == kind),
    ];
  }
}
