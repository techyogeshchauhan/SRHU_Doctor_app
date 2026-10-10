/// Node graph of one finding for the interactive graph view. Pure Dart.
///
/// Built from the finding's [ReasonNode] tree (see `reasoning.dart`), so it
/// shows only what the selected workflows' rules used:
///
/// ```
/// inputs / computed values / earlier findings   ("based on", expandable)
///                      ↓
///                  STW rule        (the checks it made, all met)
///                      ↓
///                   finding
///                      ↓
///      STW box  ·  findings that follow from this one
/// ```
library;

import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'reasoning.dart';

enum KgKind {
  answer('Input'),
  computed('Computed'),
  rule('STW rule'),
  finding('Finding'),
  stwBox('STW box');

  const KgKind(this.label);
  final String label;
}

/// A comparison an STW rule made, as shown on the rule node.
class RuleCheck {
  const RuleCheck({required this.label, this.value, required this.threshold});

  /// What was compared, e.g. "Blood glucose (BG)".
  final String label;

  /// The patient's value, e.g. "40 mg/dL".
  final String? value;

  /// The rule's threshold, e.g. "< 45 mg/dL".
  final String threshold;
}

class KgItem {
  const KgItem({
    required this.id,
    required this.kind,
    required this.label,
    this.value,
    this.check,
    this.source,
    this.finding,
    this.topics = const {},
    this.basedOn = const [],
    this.checks = const [],
  });

  final String id;
  final KgKind kind;
  final String label;
  final String? value;

  /// The threshold the rule below checked on this value.
  final String? check;
  final SourceReference? source;
  final ClinicalFinding? finding;
  final Set<NeonatalCondition> topics;

  /// What this node is based on (opened above it in the graph).
  final List<KgItem> basedOn;

  /// Rule nodes: the comparisons made.
  final List<RuleCheck> checks;

  bool get expandable => basedOn.isNotEmpty;
  bool get isShared => topics.length > 1;
}

/// The graph of one finding.
class FocusGraph {
  const FocusGraph({
    required this.rule,
    required this.finding,
    required this.stwBox,
    required this.leadsTo,
  });

  final KgItem rule;
  final KgItem finding;

  /// Null when the finding's source is not a clinical STW section.
  final KgItem? stwBox;

  /// Findings whose rule required this one.
  final List<KgItem> leadsTo;

  ClinicalFinding get clinicalFinding => finding.finding!;
}

KgItem kgItemOf(ReasonNode n) => KgItem(
      id: n.id,
      kind: switch (n.kind) {
        ReasonKind.answer => KgKind.answer,
        ReasonKind.computed => KgKind.computed,
        ReasonKind.finding => KgKind.finding,
      },
      label: n.label,
      value: n.value,
      check: n.check,
      source: n.source,
      finding: n.finding,
      topics: n.topics,
      basedOn: [for (final c in n.children) kgItemOf(c)],
    );

/// The graph of [tree]'s finding; [all] (every finding's tree) supplies the
/// findings that follow from it.
FocusGraph focusGraphOf(ReasonNode tree, List<ReasonNode> all) {
  final f = tree.finding!;
  final source = f.source.isClinical ? f.source : null;
  final reasons = [for (final c in tree.children) kgItemOf(c)];
  return FocusGraph(
    rule: KgItem(
      id: 'rule:${f.id}',
      kind: KgKind.rule,
      label: f.source.section,
      source: source,
      topics: {f.topic},
      basedOn: reasons,
      checks: [
        for (final r in reasons)
          if (r.check != null)
            RuleCheck(label: r.label, value: r.value, threshold: r.check!),
      ],
    ),
    finding: KgItem(
      id: 'finding:${f.id}',
      kind: KgKind.finding,
      label: f.title,
      source: source,
      finding: f,
      topics: {f.topic},
      basedOn: reasons,
    ),
    stwBox: source == null
        ? null
        : KgItem(
            id: 'stw:${f.id}',
            kind: KgKind.stwBox,
            label: source.section,
            source: source,
            topics: {f.topic},
          ),
    leadsTo: [
      for (final t in all)
        if (t.children.any((c) => c.id == tree.id)) kgItemOf(t),
    ],
  );
}

/// The findings each answer or computed value leads to, directly or
/// through other steps, across all of [trees].
Map<String, List<ClinicalFinding>> findingsUsing(List<ReasonNode> trees) {
  final out = <String, List<ClinicalFinding>>{};
  for (final t in trees) {
    for (final n in t.descendants) {
      final list = out.putIfAbsent(n.id, () => []);
      if (!list.contains(t.finding)) list.add(t.finding!);
    }
  }
  return out;
}
