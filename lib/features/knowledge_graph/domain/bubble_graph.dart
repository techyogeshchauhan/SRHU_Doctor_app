/// Bubble view of the STW Map: STWs as hubs, their PDF boxes around them,
/// and what each box drives in the app around the box. Pure Dart.
///
/// A projection of [StwMap]; it adds no content. Edge labels name the kind
/// of relation only ("asks", "produces", "mentions").
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'stw_map.dart';

enum BubbleKind { topic, pendingTopic, box, question, finding, link }

class Bubble {
  Bubble({
    required this.id,
    required this.kind,
    required this.label,
    required this.node,
    this.parentId,
    this.edgeLabel,
    this.draft = false,
    this.children = const [],
  });

  final String id;
  final BubbleKind kind;
  final String label;

  /// The STW Map node (for details, PDF and search).
  final MapNode node;
  final String? parentId;

  /// Label of the edge from the parent ("asks", "produces", …).
  final String? edgeLabel;

  /// A link between STWs not yet approved by a clinician.
  final bool draft;
  final List<Bubble> children;

  bool get isHub => kind == BubbleKind.topic || kind == BubbleKind.pendingTopic;
  bool get expandable => children.isNotEmpty;
  NeonatalCondition? get topic => node.topic;
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
