/// Bubble view of the STW Map: STWs as hubs, their PDF boxes around them,
/// and what each box drives in the app around the box. Pure Dart.
///
/// A projection of [StwMap]; it adds no content. Edge labels name the kind
/// of relation only ("asks", "produces", "mentions").
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import '../../clinical_workflow/domain/assessment_context.dart';
import '../../clinical_workflow/domain/assessment_engine.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import 'kg_graph.dart';
import 'kg_value_format.dart';
import 'reasoning.dart';
import 'stw_map.dart';

enum BubbleKind {
  topic,
  pendingTopic,
  box,
  question,
  finding,
  link,
  input,
  computed,
  rule,
}

class Bubble {
  Bubble({
    required this.id,
    required this.kind,
    required this.label,
    this.node,
    this.item,
    this.feeds,
    this.subtitle,
    this.topicOverride,
    this.parentId,
    this.edgeLabel,
    this.draft = false,
    this.children = const [],
  });

  final String id;
  final BubbleKind kind;
  final String label;

  /// The static STW Map node, or an assessment node with live values.
  final MapNode? node;
  final KgItem? item;

  /// Parent assessment item used to describe the relationship in details.
  final KgItem? feeds;
  final String? subtitle;
  final NeonatalCondition? topicOverride;
  final String? parentId;

  /// Label of the edge from the parent ("asks", "produces", …).
  final String? edgeLabel;

  /// A link between STWs not yet approved by a clinician.
  final bool draft;
  final List<Bubble> children;

  bool get isHub => kind == BubbleKind.topic || kind == BubbleKind.pendingTopic;
  bool get expandable => children.isNotEmpty;
  NeonatalCondition? get topic =>
      topicOverride ?? node?.topic ?? item?.topics.firstOrNull;
}

/// A relation between two STWs.
class HubEdge {
  const HubEdge({
    required this.from,
    required this.to,
    required this.label,
    this.draft = false,
    this.mutual = false,
  });

  /// Hub bubble ids.
  final String from;
  final String to;
  final String label;
  final bool draft;

  /// Same relation both ways (shared answers): no arrowhead.
  final bool mutual;
}

class BubbleGraph {
  BubbleGraph(this.hubs, this.hubEdges) {
    void index(Bubble b) {
      _byId[b.id] = b;
      b.children.forEach(index);
    }

    hubs.forEach(index);
  }

  final List<Bubble> hubs;
  final List<HubEdge> hubEdges;
  final _byId = <String, Bubble>{};

  Bubble? byId(String id) => _byId[id];

  Bubble? hubOf(NeonatalCondition c) =>
      hubs.where((h) => h.topic == c).firstOrNull;

  /// The bubble of PDF box [regionId].
  Bubble? box(String regionId) => _byId['box:$regionId'];
}

String _short(MapNode topic) => topic.label.replaceFirst('STW ', '');

BubbleGraph buildBubbleGraph(StwMap map) {
  Bubble leaf(MapNode n, String parent) => Bubble(
        id: '$parent>${n.id}',
        kind: switch (n.kind) {
          MapKind.question => BubbleKind.question,
          MapKind.finding => BubbleKind.finding,
          _ => BubbleKind.link,
        },
        label: n.label,
        node: n,
        parentId: parent,
        edgeLabel: switch (n.kind) {
          MapKind.question => 'asks',
          MapKind.finding => 'produces',
          _ => n.link?.kind.label.toLowerCase() ?? 'links to',
        },
        draft: n.link != null && !n.link!.approved,
      );

  final hubs = <Bubble>[];
  for (final root in map.roots) {
    final hubId = 'hub:${root.topic!.name}';
    hubs.add(Bubble(
      id: hubId,
      kind: root.pending ? BubbleKind.pendingTopic : BubbleKind.topic,
      label: _short(root),
      node: root,
      children: [
        for (final c in root.children)
          if (c.kind == MapKind.box)
            Bubble(
              id: 'box:${c.boxId}',
              kind: BubbleKind.box,
              label: c.label,
              node: c,
              parentId: hubId,
              children: [
                for (final g in c.children) leaf(g, 'box:${c.boxId}'),
              ],
            )
          else if (root.pending && c.kind == MapKind.link)
            Bubble(
              id: '$hubId>${c.id}',
              kind: BubbleKind.link,
              label: c.label.replaceFirst('Mentioned in ', ''),
              node: c,
              parentId: hubId,
              edgeLabel: 'mentioned in',
              draft: !(c.link?.approved ?? false),
            ),
      ],
    ));
  }

  // Links between STWs, one edge per pair of topics.
  final linkEdges = <(NeonatalCondition, NeonatalCondition), List<StwLink>>{};
  for (final b in map.boxes) {
    for (final c in b.children) {
      final l = c.link;
      if (c.kind != MapKind.link || l == null || b.topic == null) continue;
      (linkEdges[(b.topic!, l.to)] ??= []).add(l);
    }
  }
  final edges = [
    for (final MapEntry(key: (from, to), value: links) in linkEdges.entries)
      HubEdge(
        from: 'hub:${from.name}',
        to: 'hub:${to.name}',
        label: links.any((l) => l.kind == StwLinkKind.refersTo)
            ? 'refers to'
            : 'mentions',
        draft: links.any((l) => !l.approved),
      ),
  ];

  // Answers asked by more than one STW.
  final shared = <(NeonatalCondition, NeonatalCondition)>{};
  for (final b in map.boxes) {
    for (final c in b.children) {
      if (c.kind != MapKind.question || !c.isShared) continue;
      final t = c.topics.toList()..sort((a, b) => a.index.compareTo(b.index));
      for (var i = 0; i < t.length; i++) {
        for (var j = i + 1; j < t.length; j++) {
          shared.add((t[i], t[j]));
        }
      }
    }
  }
  for (final (a, b) in shared) {
    edges.add(HubEdge(
      from: 'hub:${a.name}',
      to: 'hub:${b.name}',
      label: 'shares answers',
      mutual: true,
    ));
  }

  return BubbleGraph(hubs, edges);
}

/// Projects only the current assessment's selected workflows, answers and
/// triggered findings into the Home graph's bubble layout.
BubbleGraph buildAssessmentBubbleGraph({
  required ClinicalAssessmentContext context,
  required List<ReasonNode> trees,
  AssessmentEngine engine = const AssessmentEngine(),
}) {
  final workflows = {
    for (final w in engine.workflowsFor(context.selected)) w.condition: w,
  };
  final answersByTopic = <NeonatalCondition, List<KgItem>>{};
  final sharedTopicsByAnswer = <String, Set<NeonatalCondition>>{};
  final resolved = engine.resolve(context.selected);

  for (final rq in engine.applicableQuestions(context, resolved)) {
    final question = rq.question;
    if (!context.answers.containsKey(question.variable)) continue;
    final rawValue = context.answers[question.variable];
    final value = formatKgValue(rawValue, q: question);
    if (value == null) continue;

    final topics = {
      for (final (topic, use) in rq.uses)
        if (use.isActive(context)) topic,
    };
    if (topics.isEmpty) continue;

    SourceReference? source;
    for (final topic in topics) {
      final document = workflows[topic]?.source.document;
      source = question.sources
          .where((s) => s.isClinical && s.document == document)
          .firstOrNull;
      source ??= question.sources.where((s) => s.isClinical).firstOrNull;
      final item = KgItem(
        id: 'answer:${question.variable}',
        kind: KgKind.answer,
        label: question.question,
        value: value,
        source: source,
        topics: topics,
      );
      (answersByTopic[topic] ??= []).add(item);
    }
    sharedTopicsByAnswer['answer:${question.variable}'] = topics;
  }

  final usedAnswers = {
    for (final tree in trees)
      for (final node in tree.descendants)
        if (node.kind == ReasonKind.answer) node.id,
  };
  final hubs = <Bubble>[];

  for (final topic in NeonatalCondition.values) {
    if (!context.selected.contains(topic) || !workflows.containsKey(topic)) {
      continue;
    }
    final hubId = 'hub:${topic.name}';
    final topicTrees = [
      for (final tree in trees)
        if (tree.finding?.topic == topic) tree,
    ];
    final inputs = answersByTopic[topic] ?? const <KgItem>[];
    final children = <Bubble>[
      for (final item in inputs)
        if (!usedAnswers.contains(item.id))
          Bubble(
            id: '$hubId>${item.id}',
            kind: BubbleKind.input,
            label: item.label,
            item: item,
            topicOverride: topic,
            parentId: hubId,
            edgeLabel: 'answered',
          ),
      for (final tree in topicTrees)
        _findingBubble(focusGraphOf(tree, trees), hubId, topic),
    ];

    hubs.add(Bubble(
      id: hubId,
      kind: BubbleKind.topic,
      label: definitionOf(topic).title.replaceFirst('STW ', ''),
      subtitle: '${inputs.length} ${inputs.length == 1 ? 'input' : 'inputs'}'
          ' · ${topicTrees.length} '
          '${topicTrees.length == 1 ? 'finding' : 'findings'}',
      topicOverride: topic,
      children: children,
    ));
  }

  final edges = <HubEdge>[];
  final pairs = <(NeonatalCondition, NeonatalCondition)>{};
  for (final topics in sharedTopicsByAnswer.values) {
    final selectedTopics = topics.where(context.selected.contains).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (var i = 0; i < selectedTopics.length; i++) {
      for (var j = i + 1; j < selectedTopics.length; j++) {
        pairs.add((selectedTopics[i], selectedTopics[j]));
      }
    }
  }
  for (final (a, b) in pairs) {
    if (!workflows.containsKey(a) || !workflows.containsKey(b)) continue;
    edges.add(HubEdge(
      from: 'hub:${a.name}',
      to: 'hub:${b.name}',
      label: 'shares answers',
      mutual: true,
    ));
  }

  return BubbleGraph(hubs, edges);
}

Bubble _findingBubble(
  FocusGraph graph,
  String parentId,
  NeonatalCondition topic,
) {
  final finding = graph.finding;
  final children = <Bubble>[];
  final seenEvidence = <String>{};

  void addEvidence(KgItem parent, String relation) {
    for (final item in parent.basedOn) {
      if (!seenEvidence.add(item.id)) continue;
      children.add(Bubble(
        id: '${finding.id}>${item.id}',
        kind: switch (item.kind) {
          KgKind.answer => BubbleKind.input,
          KgKind.computed => BubbleKind.computed,
          KgKind.rule => BubbleKind.rule,
          KgKind.finding => BubbleKind.finding,
          KgKind.stwBox => BubbleKind.box,
        },
        label: item.label,
        item: item,
        feeds: parent,
        topicOverride: topic,
        parentId: finding.id,
        edgeLabel: relation,
      ));
      addEvidence(item, 'based on ${item.label}');
    }
  }

  addEvidence(graph.rule, 'used by rule');
  children.add(Bubble(
    id: '${finding.id}>${graph.rule.id}',
    kind: BubbleKind.rule,
    label: graph.rule.label,
    item: graph.rule,
    feeds: finding,
    topicOverride: topic,
    parentId: finding.id,
    edgeLabel: 'applies rule',
  ));
  if (graph.stwBox case final source?) {
    children.add(Bubble(
      id: '${finding.id}>${source.id}',
      kind: BubbleKind.box,
      label: source.label,
      item: source,
      feeds: finding,
      topicOverride: topic,
      parentId: finding.id,
      edgeLabel: 'source',
    ));
  }
  for (final next in graph.leadsTo) {
    children.add(Bubble(
      id: '${finding.id}>${next.id}',
      kind: BubbleKind.finding,
      label: next.label,
      item: next,
      feeds: finding,
      topicOverride: topic,
      parentId: finding.id,
      edgeLabel: 'leads to',
    ));
  }

  return Bubble(
    id: finding.id,
    kind: BubbleKind.finding,
    label: finding.label,
    item: finding,
    topicOverride: topic,
    parentId: parentId,
    edgeLabel: 'finding',
    children: children,
  );
}
