import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/ui/assessment_summary.dart' show toneFor;
import '../domain/kg_graph.dart';
import 'kg_widgets.dart';
import 'reasoning_tree.dart' show topicShort;

/// Colours and icon of each kind of node (the legend uses the same).
({Color bg, Color fg, IconData icon}) kgLook(KgKind kind, [FindingLevel? l]) =>
    switch (kind) {
      KgKind.answer => (
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF075985),
          icon: Icons.edit_note_rounded,
        ),
      KgKind.computed => (
          bg: const Color(0xFFE0E7FF),
          fg: const Color(0xFF3730A3),
          icon: Icons.calculate_outlined,
        ),
      KgKind.rule => (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF166534),
          icon: Icons.rule_rounded,
        ),
      KgKind.finding => (
          bg: toneFor(l ?? FindingLevel.info).background(),
          fg: toneFor(l ?? FindingLevel.info).foreground(),
          icon: toneFor(l ?? FindingLevel.info).icon,
        ),
      KgKind.stwBox => (
          bg: const Color(0xFFF3E8FF),
          fg: const Color(0xFF6B21A8),
          icon: Icons.picture_as_pdf_outlined,
        ),
    };

class KgLegend extends StatelessWidget {
  const KgLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final k in KgKind.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: k == KgKind.finding
                        ? const Color(0xFFDC2626)
                        : kgLook(k).fg,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  k.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.bodyText,
                  ),
                ),
              ],
            ),
        ],
      );
}

/// Where a node sits in the graph, for the details page.
class KgPlacement {
  const KgPlacement({required this.item, this.feeds});

  final KgItem item;

  /// The node directly below it (what it is used for).
  final KgItem? feeds;
}

/// The finding's node graph, top to bottom: what it is based on, the STW
/// rule, the finding, then its STW box and the findings that follow.
/// Nodes with a "+N" button open what they are based on as a new group
/// above them (one per level, so arrows never cross). Tapping a node calls
/// [onOpen].
class NodeGraphView extends StatefulWidget {
  const NodeGraphView({super.key, required this.graph, required this.onOpen});

  final FocusGraph graph;
  final void Function(KgPlacement placement) onOpen;

  @override
  State<NodeGraphView> createState() => _NodeGraphViewState();
}

class _Group {
  _Group(this.header, this.items, {this.target});
  final String header;
  final List<KgItem> items;

  /// The node this group explains (in the block below).
  final KgItem? target;
}

class _Box {
  _Box(this.item, this.rect, {this.feeds});
  final KgItem item;
  final Rect rect;
  final KgItem? feeds;
}

class _NodeGraphViewState extends State<NodeGraphView> {
  /// Expanded node id at each level, starting with the "Based on" group.
  final _expanded = <String>[];
  final _transform = TransformationController();

  @override
  void didUpdateWidget(NodeGraphView old) {
    super.didUpdateWidget(old);
    if (old.graph.finding.id != widget.graph.finding.id) {
      _expanded.clear();
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _zoom(double factor) {
    final s = (_scale * factor).clamp(0.5, 2.5);
    setState(() => _transform.value = Matrix4.diagonal3Values(s, s, 1));
  }

  void _toggle(int level, KgItem item) {
    setState(() {
      if (_expanded.length > level && _expanded[level] == item.id) {
        _expanded.removeRange(level, _expanded.length);
      } else {
        _expanded
          ..removeRange(math.min(level, _expanded.length), _expanded.length)
          ..add(item.id);
      }
      // Show the top, where the opened group appears.
      _transform.value = Matrix4.diagonal3Values(_scale, _scale, 1);
    });
  }

  List<_Group> _groups() {
    final g = widget.graph;
    final groups = [
      if (g.rule.basedOn.isNotEmpty)
        _Group('Based on', g.rule.basedOn, target: g.rule),
    ];
    for (var level = 0; level < _expanded.length; level++) {
      if (level >= groups.length) break;
      final item = groups[level]
          .items
          .where((i) => i.id == _expanded[level] && i.expandable)
          .firstOrNull;
      if (item == null) break;
      groups.add(_Group('${item.label}: based on', item.basedOn, target: item));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final layout = _layout(box.maxWidth);
      return Stack(
        children: [
          InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            minScale: 0.5,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(24),
            onInteractionEnd: (_) => setState(() {}),
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                children: [
                  for (final h in layout.headers)
                    Positioned(
                      left: h.rect.left,
                      top: h.rect.top,
                      width: h.rect.width,
                      height: h.rect.height,
                      child: KgGroupFrame(
                        header: h.header,
                        maxHeaderWidth: h.headerWidth,
                      ),
                    ),
                  // Arrows above the group frames, below the nodes.
                  Positioned.fill(
                    child: CustomPaint(painter: KgArrowPainter(layout.arrows)),
                  ),
                  for (final b in layout.boxes)
                    Positioned.fromRect(
                      rect: b.rect,
                      child: _NodeCard(
                        item: b.item,
                        expanded: _expanded.contains(b.item.id),
                        onTap: () => widget.onOpen(
                          KgPlacement(item: b.item, feeds: b.feeds),
                        ),
                        onToggle: b.level == null
                            ? null
                            : () => _toggle(b.level!, b.item),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: KgZoomBar(
              percent: (_scale * 100).round(),
              onOut: () => _zoom(1 / 1.2),
              onIn: () => _zoom(1.2),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: KgRoundButton(
              icon: Icons.fit_screen_rounded,
              tooltip: 'Reset view',
              onTap: () =>
                  setState(() => _transform.value = Matrix4.identity()),
            ),
          ),
        ],
      );
    });
  }

  _Layout _layout(double viewWidth) {
    const pad = 12.0;
    const gap = 14.0;
    const groupPad = 10.0;
    const headerH = 30.0;
    const nodeH = 104.0;
    const blockGap = 44.0;
    final width = math.max(viewWidth, 300.0);
    final cols = width < 560 ? 2 : (width < 860 ? 3 : 4);
    final nodeW = ((width - 2 * pad - 2 * groupPad - (cols - 1) * gap) / cols)
        .clamp(120.0, 220.0);
    final singleW = math.min(width - 2 * pad, 360.0);

    final boxes = <_PlacedBox>[];
    final headers = <_PlacedGroup>[];
    final arrows = <KgArrow>[];
    var y = pad;

    // Lays out a group; returns its frame.
    Rect group(_Group g, {int? level, KgItem? feeds}) {
      final n = g.items.length;
      final c = math.min(n, cols);
      final rows = (n / c).ceil();
      final w = c * nodeW + (c - 1) * gap + 2 * groupPad;
      final h = headerH + rows * nodeH + (rows - 1) * gap + groupPad;
      final x0 = (width - w) / 2;
      final frame = Rect.fromLTWH(x0, y, w, h);
      headers.add(_PlacedGroup(g.header, frame, nodeW - 4));
      for (var i = 0; i < n; i++) {
        final item = g.items[i];
        boxes.add(_PlacedBox(
          item,
          Rect.fromLTWH(
            x0 + groupPad + (i % c) * (nodeW + gap),
            y + headerH + (i ~/ c) * (nodeH + gap),
            nodeW,
            nodeH,
          ),
          feeds: feeds,
          level: item.expandable ? level : null,
          lane: (i % c) == 0
              ? x0 + groupPad / 2
              : x0 + groupPad + (i % c) * (nodeW + gap) - gap / 2,
        ));
      }
      y += h + blockGap;
      return frame;
    }

    Rect single(KgItem item, double h, {KgItem? feeds}) {
      final r = Rect.fromLTWH((width - singleW) / 2, y, singleW, h);
      boxes.add(_PlacedBox(item, r, feeds: feeds));
      y += h + blockGap;
      return r;
    }

    final g = widget.graph;
    final groups = _groups();
    // Top to bottom: the deepest opened group first.
    final frames = <int, Rect>{};
    for (var level = groups.length - 1; level >= 0; level--) {
      final grp = groups[level];
      frames[level] = group(grp, level: level, feeds: grp.target);
    }
    final rule = single(g.rule, 104, feeds: g.finding);
    final finding = single(g.finding, 112);
    final next = [if (g.stwBox != null) g.stwBox!, ...g.leadsTo];
    final nextFrame = next.isEmpty
        ? null
        : group(_Group('STW source and what follows', next),
            level: null, feeds: g.finding);

    // Arrows from each opened group into the node it explains.
    for (var level = groups.length - 1; level >= 1; level--) {
      final from = frames[level]!;
      final target = boxes.firstWhere((b) =>
          b.item.id == groups[level].target!.id && b.rect.top > from.bottom);
      final midY = from.bottom + blockGap / 2;
      arrows.add(KgArrow([
        Offset(from.center.dx, from.bottom),
        Offset(from.center.dx, midY),
        Offset(target.lane, midY),
        Offset(target.lane, target.rect.center.dy),
        Offset(target.rect.left, target.rect.center.dy),
      ]));
    }
    if (frames[0] case final base?) {
      arrows.add(KgArrow([
        Offset(base.center.dx, base.bottom),
        Offset(rule.center.dx, rule.top),
      ]));
    }
    arrows.add(KgArrow(
      [
        Offset(rule.center.dx, rule.bottom),
        Offset(finding.center.dx, finding.top)
      ],
      label: 'All conditions met',
    ));
    if (nextFrame != null) {
      arrows.add(KgArrow([
        Offset(finding.center.dx, finding.bottom),
        Offset(nextFrame.center.dx, nextFrame.top),
      ]));
    }

    return _Layout(
      width: width,
      // Room for the zoom controls.
      height: y - blockGap + pad + 64,
      boxes: boxes,
      headers: headers,
      arrows: arrows,
    );
  }
}

class _PlacedBox extends _Box {
  _PlacedBox(super.item, super.rect, {super.feeds, this.level, double? lane})
      : lane = lane ?? rect.left - 7;

  /// Group level whose expansion this node toggles; null when not
  /// expandable here.
  final int? level;

  /// Free vertical lane left of the node, for arrows into it.
  final double lane;
}

class _PlacedGroup {
  _PlacedGroup(this.header, this.rect, this.headerWidth);
  final String header;
  final Rect rect;
  final double headerWidth;
}

class _Layout {
  _Layout({
    required this.width,
    required this.height,
    required this.boxes,
    required this.headers,
    required this.arrows,
  });
  final double width;
  final double height;
  final List<_PlacedBox> boxes;
  final List<_PlacedGroup> headers;
  final List<KgArrow> arrows;
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.item,
    required this.expanded,
    required this.onTap,
    this.onToggle,
  });

  final KgItem item;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final look = kgLook(i.kind, i.finding?.level);
    final caption = switch (i.kind) {
      KgKind.finding => i.finding?.category.label ?? i.kind.label,
      _ => i.kind.label,
    };
    // A second line from the workflow: the finding's first STW action, or
    // what the rule compared.
    final detail = switch (i.kind) {
      KgKind.finding => i.finding?.actions.firstOrNull,
      KgKind.rule => i.checks.isEmpty
          ? 'Uses the ${i.basedOn.length} '
              '${i.basedOn.length == 1 ? 'step' : 'steps'} above'
          : [
              for (final c in i.checks)
                '${c.label}${c.value == null ? '' : ' ${c.value}'}: '
                    '${c.threshold}',
            ].join(' · '),
      _ => null,
    };
    final footer = switch (i.kind) {
      KgKind.rule => i.checks.isEmpty
          ? '✓ Conditions met'
          : '✓ ${i.checks.length} ${i.checks.length == 1 ? 'check' : 'checks'} met',
      KgKind.stwBox => 'Source text & PDF ›',
      _ => i.check != null ? '✓ ${i.check}' : null,
    };

    return KgCard(
      bg: look.bg,
      fg: look.fg,
      icon: look.icon,
      caption: i.isShared
          ? '$caption · ${i.topics.map(topicShort).join('+')}'
          : caption,
      label: i.label,
      boldLabel: i.kind == KgKind.finding || i.kind == KgKind.rule,
      labelInColor: i.kind == KgKind.finding,
      detail: detail,
      value: i.value,
      footer: footer,
      footerColor: i.kind == KgKind.stwBox ? look.fg : null,
      expandCount: i.basedOn.length,
      expanded: expanded,
      onTap: onTap,
      onToggle: onToggle,
    );
  }
}
