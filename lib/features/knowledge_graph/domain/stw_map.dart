/// STW Map: the knowledge in the approved STWs, without a patient. Pure Dart.
///
/// ```
/// STW topic ─┬─ PDF box (verbatim heading) ─┬─ questions the app asks from it
///            │                              ├─ findings its rules produce
///            │                              └─ links to other STWs (quoted)
///            └─ links from other STWs that mention this topic
/// ```
///
/// Built from the workflow definitions (questions, rules, sources), the
/// boxes of `assets/regions/regions.json` and `assets/knowledge_graph/
/// stw_map.json` (verbatim box headings and the cross-STW links, each with
/// the exact quote that states it). It adds no clinical content.
library;

import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/clinical_rule.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/domain/workflow_definition.dart';
import '../../clinical_workflow/domain/workflow_registry.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'stw_region.dart';

enum StwLinkKind {
  /// The box sends the reader to another STW ("see STW: …").
  refersTo('Refers to'),

  /// The box names the topic of another STW.
  mentions('Mentions');

  const StwLinkKind(this.label);
  final String label;
}

/// A link from a PDF box to another STW topic, with the box's own words.
class StwLink {
  const StwLink({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.quote,
    required this.approved,
  });

  final String id;

  /// Region id of the box that states the link.
  final String from;
  final NeonatalCondition to;
  final StwLinkKind kind;

  /// Verbatim text of [from] that names [to].
  final String quote;

  /// Set by a clinician after review; drafts are shown as such.
  final bool approved;
}

/// `assets/knowledge_graph/stw_map.json`.
class StwMapData {
  const StwMapData({
    required this.headings,
    required this.contexts,
    required this.links,
  });

  factory StwMapData.fromJson(Map<String, dynamic> json) => StwMapData(
        headings: {
          for (final e in (json['headings'] as Map).entries)
            e.key as String: e.value as String,
        },
        contexts: {
          for (final e in ((json['contexts'] as Map?) ?? const {}).entries)
            e.key as String: [for (final c in e.value as List) c as String],
        },
        links: [
          for (final l in (json['links'] as List? ?? const []))
            if (NeonatalCondition.values.asNameMap()[(l as Map)['to']]
                case final to?)
              StwLink(
                id: l['id'] as String,
                from: l['from'] as String,
                to: to,
                kind: StwLinkKind.values.asNameMap()[l['kind']] ??
                    StwLinkKind.mentions,
                quote: l['quote'] as String,
                approved: l['approved'] == true,
              ),
        ],
      );

  /// Verbatim heading of each box.
  final Map<String, String> headings;

  /// Verbatim lines that tell boxes with the same heading apart (e.g. the
  /// two "START CPAP" boxes: "GA ≤34 weeks" / "GA >34 weeks").
  final Map<String, List<String>> contexts;
  final List<StwLink> links;
}

enum MapKind {
  topic('STW'),
  box('STW box'),
  question('Asked in the assessment'),
  finding('Finding'),
  link('Link to another STW');

  const MapKind(this.label);
  final String label;
}

class MapNode {
  const MapNode({
    required this.id,
    required this.kind,
    required this.label,
    this.subtitle,
    this.topic,
    this.topics = const {},
    this.boxId,
    this.source,
    this.question,
    this.level,
    this.category,
    this.rules = const [],
    this.link,
    this.pending = false,
    this.children = const [],
  });

  final String id;
  final MapKind kind;
  final String label;
  final String? subtitle;

  /// The STW this node belongs to.
  final NeonatalCondition? topic;

  /// Questions: every topic that asks it (more than one: shared).
  final Set<NeonatalCondition> topics;

  /// Boxes: own region id; links: the box that states the link.
  final String? boxId;

  /// Where "Open in PDF" goes (highlighting [SourceReference.pdfRegionId]).
  final SourceReference? source;

  final ClinicalQuestion? question;

  /// Findings with a fixed title.
  final FindingLevel? level;
  final FindingCategory? category;

  /// Findings worded from the answers: the rules (id, source) behind them.
  final List<(String, SourceReference)> rules;

  final StwLink? link;

  /// A topic whose approved STW is not bundled yet.
  final bool pending;

  final List<MapNode> children;

  bool get expandable => children.isNotEmpty;
  bool get isShared => topics.length > 1;
}

class StwMap {
  StwMap._(this.roots, this._boxes, this._boxTopic, this._documentTopic);

  /// One node per STW: the available ones, then pending topics that an
  /// approved STW links to.
  final List<MapNode> roots;
  final Map<String, MapNode> _boxes;
  final Map<String, NeonatalCondition> _boxTopic;
  final Map<String, NeonatalCondition> _documentTopic;

  MapNode? root(NeonatalCondition c) =>
      roots.where((r) => r.topic == c).firstOrNull;

  MapNode? box(String regionId) => _boxes[regionId];

  NeonatalCondition? topicOfBox(String regionId) => _boxTopic[regionId];

  /// The STW whose PDF file name is [file] (e.g. a chatbot source).
  NeonatalCondition? topicOfFile(String file) {
    for (final e in _boxFile.entries) {
      if (e.value == file) return _boxTopic[e.key];
    }
    return null;
  }

  final Map<String, String> _boxFile = {};

  Iterable<MapNode> get boxes => _boxes.values;

  /// Boxes and questions whose text contains every word of [query].
  List<MapNode> search(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return const [];
    bool hit(String text) {
      final t = text.toLowerCase();
      return words.every(t.contains);
    }

    final out = <MapNode>[];
    final seen = <String>{};
    for (final b in _boxes.values) {
      if (hit('${b.label} ${b.subtitle ?? ''}') && seen.add(b.id)) out.add(b);
    }
    for (final b in _boxes.values) {
      for (final c in b.children) {
        if (c.kind == MapKind.question && hit(c.label) && seen.add(c.id)) {
          out.add(c);
        }
      }
    }
    return out;
  }

  /// Box an MCQ / citation text like `ICMR/DHR STW "Neonatal Hypoglycemia"
  /// (August 2026), DRUGS FOR REFRACTORY HYPOGLYCEMIA` points to: the first
  /// box of that STW whose heading is one of the cited headings, else whose
  /// text contains it. Null when none matches.
  String? resolveReference(String reference) {
    final doc = RegExp('"([^"]+)"').firstMatch(reference)?.group(1);
    final topic = doc == null ? null : _documentTopic[doc];
    if (topic == null) return null;
    final cut = reference.indexOf('), ');
    final cited = cut < 0 ? reference : reference.substring(cut + 3);
    final candidates = <String>[];
    for (final part in cited.split(';')) {
      final p = part.trim();
      final inner = RegExp(r'\(([^)]+)\)$').firstMatch(p)?.group(1);
      candidates.addAll([
        p,
        if (inner != null) inner,
        if (inner != null && inner.contains('→')) inner.split('→').last.trim(),
      ]);
    }
    final boxes = [
      for (final e in _boxes.entries)
        if (_boxTopic[e.key] == topic) e.value,
    ];
    for (final c in candidates) {
      final lc = c.toLowerCase();
      for (final b in boxes) {
        if (b.label.toLowerCase() == lc) return b.boxId;
      }
    }
    for (final c in candidates) {
      final lc = c.toLowerCase();
      if (lc.length < 6) continue;
      for (final b in boxes) {
        if ((b.subtitle ?? '').toLowerCase().contains(lc) ||
            (_boxText[b.boxId] ?? '').contains(lc)) {
          return b.boxId;
        }
      }
    }
    return null;
  }

  final Map<String, String> _boxText = {};
}

class _NoAnswers implements VariableReader {
  @override
  Object? valueOf(String key) => null;
  @override
  bool hasFinding(String id) => false;
}

/// The finding of [rule] when its wording does not depend on the answers.
FindingContent? _fixedContent(ClinicalRule rule) {
  try {
    return rule.then(_NoAnswers());
  } catch (_) {
    return null; // worded from the answers
  }
}

StwMap buildStwMap({
  required Map<String, StwRegionInfo> regions,
  required StwMapData data,
  WorkflowDefinition Function(NeonatalCondition) lookup = workflowFor,
}) {
  final workflows = [
    for (final c in NeonatalCondition.values)
      if (lookup(c) case final StwWorkflow w) w,
  ];

  // Each STW's PDF file, from the boxes its own sources cite.
  final fileOf = <NeonatalCondition, String>{};
  final documentTopic = <String, NeonatalCondition>{};
  for (final w in workflows) {
    documentTopic[w.source.document] = w.condition;
    final cited = [
      for (final r in w.rules) r.source,
      for (final u in w.uses) ...u.question.sources,
    ];
    for (final s in cited) {
      if (s.document != w.source.document) continue;
      final file = regions[s.pdfRegionId]?.document;
      if (file != null) {
        fileOf[w.condition] = file;
        break;
      }
    }
  }

  // Topics asking each question.
  final askedBy = <String, Set<NeonatalCondition>>{};
  for (final w in workflows) {
    for (final u in w.uses) {
      (askedBy[u.question.id] ??= {}).add(w.condition);
    }
  }

  SourceReference boxSource(StwWorkflow w, String id, String heading) =>
      SourceReference(
        document: w.source.document,
        section: heading,
        authority: w.source.authority,
        version: w.source.version,
        regionId: id,
      );

  final boxes = <String, MapNode>{};
  final boxTopic = <String, NeonatalCondition>{};
  final boxText = <String, String>{};
  final roots = <MapNode>[];

  for (final w in workflows) {
    final file = fileOf[w.condition];
    final topicBoxes = <MapNode>[];
    for (final r in regions.values) {
      if (r.document != file) continue;
      final heading = data.headings[r.id] ?? r.text.split('\n').first;

      final questions = <String, MapNode>{};
      for (final ww in workflows) {
        for (final u in ww.uses) {
          final q = u.question;
          for (final s in q.sources) {
            if (s.pdfRegionId != r.id || questions.containsKey(q.id)) continue;
            questions[q.id] = MapNode(
              id: 'q:${q.id}@${r.id}',
              kind: MapKind.question,
              label: q.question,
              subtitle: _questionSummary(q),
              topic: w.condition,
              topics: askedBy[q.id] ?? {ww.condition},
              boxId: r.id,
              source: s,
              question: q,
            );
          }
        }
      }

      final fixed = <MapNode>[];
      final worded = <(String, SourceReference)>[];
      for (final rule in w.rules) {
        if (rule.source.pdfRegionId != r.id) continue;
        final content = _fixedContent(rule);
        if (content == null) {
          worded.add((rule.id, rule.source));
        } else {
          fixed.add(MapNode(
            id: 'finding:${rule.id}',
            kind: MapKind.finding,
            label: content.title,
            subtitle: content.actions.firstOrNull,
            topic: w.condition,
            boxId: r.id,
            source: rule.source,
            level: content.level,
            category: content.category,
          ));
        }
      }

      final out = [
        for (final l in data.links)
          if (l.from == r.id)
            MapNode(
              id: 'link:${l.id}',
              kind: MapKind.link,
              label: '${l.kind.label}: ${definitionOf(l.to).title}',
              subtitle: l.quote,
              topic: l.to,
              boxId: r.id,
              source: boxSource(w, r.id, heading),
              link: l,
            ),
      ];

      final node = MapNode(
        id: 'box:${r.id}',
        kind: MapKind.box,
        label: heading,
        subtitle: data.contexts[r.id]?.join(' · '),
        topic: w.condition,
        boxId: r.id,
        source: boxSource(w, r.id, heading),
        children: [
          ...questions.values,
          ...fixed,
          if (worded.isNotEmpty)
            MapNode(
              id: 'findings:${r.id}',
              kind: MapKind.finding,
              label: 'Findings worded from the answers',
              subtitle: '${worded.length} STW '
                  '${worded.length == 1 ? 'rule' : 'rules'}',
              topic: w.condition,
              boxId: r.id,
              source: worded.first.$2,
              level: FindingLevel.info,
              rules: worded,
            ),
          ...out,
        ],
      );
      boxes[r.id] = node;
      boxTopic[r.id] = w.condition;
      boxText[r.id] = flatStwText(r.text).toLowerCase();
      topicBoxes.add(node);
    }

    roots.add(MapNode(
      id: 'topic:${w.condition.name}',
      kind: MapKind.topic,
      label: definitionOf(w.condition).title,
      subtitle: w.source.document,
      topic: w.condition,
      source: w.source,
      children: [...topicBoxes, ..._incoming(w.condition, data, boxes)],
    ));
  }

  // Pending topics that an approved STW links to.
  for (final c in NeonatalCondition.values) {
    if (roots.any((r) => r.topic == c)) continue;
    final incoming = _incoming(c, data, boxes);
    if (incoming.isEmpty) continue;
    roots.add(MapNode(
      id: 'topic:${c.name}',
      kind: MapKind.topic,
      label: definitionOf(c).title,
      subtitle: 'Awaiting approved STW',
      topic: c,
      pending: true,
      children: incoming,
    ));
  }

  return StwMap._(roots, boxes, boxTopic, documentTopic)
    .._boxText.addAll(boxText)
    .._boxFile.addAll({for (final id in boxes.keys) id: regions[id]!.document});
}

/// Links from other STWs' boxes to [c].
List<MapNode> _incoming(
  NeonatalCondition c,
  StwMapData data,
  Map<String, MapNode> boxes,
) =>
    [
      for (final l in data.links)
        if (l.to == c && boxes[l.from] != null)
          MapNode(
            id: 'linkin:${l.id}',
            kind: MapKind.link,
            label: 'Mentioned in ${definitionOf(boxes[l.from]!.topic!).title}: '
                '${boxes[l.from]!.label}',
            subtitle: l.quote,
            topic: boxes[l.from]!.topic,
            boxId: l.from,
            source: boxes[l.from]!.source,
            link: l,
          ),
    ];

/// The answer choices or unit of [q], as the assessment shows them.
String? _questionSummary(ClinicalQuestion q) => switch (q.type) {
      QuestionType.singleChoice ||
      QuestionType.multipleChoice =>
        q.options.isEmpty ? null : q.options.map((o) => o.label).join(' · '),
      QuestionType.numeric => q.stwRange ?? q.unit,
      QuestionType.boolean => 'Yes / No',
      QuestionType.date => 'Date',
      QuestionType.text => null,
    };
