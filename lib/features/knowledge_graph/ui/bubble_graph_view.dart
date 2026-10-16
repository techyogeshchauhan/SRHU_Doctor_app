import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/bubble_graph.dart';
import '../domain/kg_graph.dart';
import '../domain/stw_map.dart';
import 'reasoning_tree.dart' show hasPdf, openSourceInPdf;

/// Fill, border and icon of each kind of bubble.
({Color fill, Color border, IconData icon, String label}) bubbleLook(
  BubbleKind k,
) =>
    switch (k) {
      BubbleKind.topic => (
          fill: const Color(0xFFDBEAFE),
          border: const Color(0xFF3B6FB6),
          icon: Icons.menu_book_outlined,
          label: 'STW',
        ),
      BubbleKind.pendingTopic => (
          fill: const Color(0xFFF1F5F9),
          border: const Color(0xFF94A3B8),
          icon: Icons.hourglass_empty_rounded,
          label: 'Awaiting STW',
        ),
      BubbleKind.box => (
          fill: const Color(0xFFFFE8CC),
          border: const Color(0xFFD69E2E),
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF box',
        ),
      BubbleKind.question => (
          fill: const Color(0xFFD9EAD3),
          border: const Color(0xFF6AA84F),
          icon: Icons.edit_note_rounded,
          label: 'Question',
        ),
      BubbleKind.finding => (
          fill: const Color(0xFFF8D7DA),
          border: const Color(0xFFC0504D),
          icon: Icons.flag_outlined,
          label: 'Finding',
        ),
      BubbleKind.input => (
          fill: const Color(0xFFE0F2FE),
          border: const Color(0xFF075985),
          icon: Icons.edit_note_rounded,
          label: 'Assessment input',
        ),
      BubbleKind.computed => (
          fill: const Color(0xFFE0E7FF),
          border: const Color(0xFF3730A3),
          icon: Icons.calculate_outlined,
          label: 'Computed value',
        ),
      BubbleKind.rule => (
          fill: const Color(0xFFDCFCE7),
          border: const Color(0xFF166534),
          icon: Icons.rule_rounded,
          label: 'STW rule',
        ),
      BubbleKind.link => (
          fill: const Color(0xFFEEEEEE),
          border: const Color(0xFF616161),
          icon: Icons.link_rounded,
          label: 'Link to STW',
        ),
    };

double _radius(BubbleKind k) => switch (k) {
      BubbleKind.topic => 60,
      BubbleKind.pendingTopic => 48,
      BubbleKind.box => 32,
      _ => 26,
    };

class BubbleLegend extends StatelessWidget {
  const BubbleLegend({super.key});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final children = <Widget>[
          for (final k in BubbleKind.values) _LegendDot(k),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('- - -',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD69E2E))),
            SizedBox(width: 4),
            Text('Draft link', style: TextStyle(fontSize: 11.5)),
          ]),
        ];
        if (constraints.maxWidth < 600) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final child in children)
                Padding(
                    padding: const EdgeInsets.only(right: 10), child: child),
            ]),
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 4,
          children: children,
        );
      });
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.kind);
  final BubbleKind kind;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bubbleLook(kind).fill,
              shape: BoxShape.circle,
              border: Border.all(color: bubbleLook(kind).border, width: 2),
            ),
          ),
          const SizedBox(width: 4),
          Text(bubbleLook(kind).label, style: const TextStyle(fontSize: 11.5)),
        ],
      );
}

/// Where a bubble is drawn: centre (world coordinates around the origin),
/// scale and opacity.
class _Pose {
  const _Pose(this.c, this.scale, this.opacity);
  final Offset c;
  final double scale;
  final double opacity;
}

class _Track {
  _Track(this.bubble, this.from, this.to, {this.entering = false});
  final Bubble bubble;
  _Pose from;
  _Pose to;
  bool entering;
  bool exiting = false;
}

/// The STW Map as an interactive bubble network.
///
/// Overview: one circle per STW, joined by labelled arrows. Tapping an STW
/// moves it to the centre and springs its PDF boxes out around it; tapping
/// a box fans out the questions, findings and links it drives. Assessment
/// findings show spaced evidence pages instead of crowding a fixed arc. Tapping
/// again collapses. The camera follows smoothly; pinch and drag the
/// background to explore. Dragging a bubble moves only that bubble: what
/// hangs off it follows on springs, neighbours make room, and the graph
/// settles where it is let go. The card at the bottom shows the selected
/// bubble with "Details" and "Open in PDF".
class BubbleGraphView extends StatefulWidget {
  const BubbleGraphView({
    super.key,
    required this.graph,
    this.onDetails,
    this.onAssessmentDetails,
    this.focusBox,
    this.focusTopic,
    this.focusBubbleId,
    this.overviewLabel = 'All STWs',
  }) : assert(onDetails != null || onAssessmentDetails != null);

  final BubbleGraph graph;
  final void Function(MapNode node)? onDetails;
  final void Function(KgItem item, KgItem? feeds)? onAssessmentDetails;

  /// Open on this PDF box (its STW and the box expanded).
  final String? focusBox;

  /// Open on this STW, expanded.
  final NeonatalCondition? focusTopic;
  final String? focusBubbleId;
  final String overviewLabel;

  @override
  State<BubbleGraphView> createState() => _BubbleGraphViewState();
}

class _BubbleGraphViewState extends State<BubbleGraphView>
    with TickerProviderStateMixin {
  static const _world = 3000.0;
  static const _o = Offset(_world / 2, _world / 2);

  String? _hub;
  String? _branch;
  String? _selected;
  int _evidencePage = 0;

  Bubble? get _evidenceBranch {
    final branch = _branch == null ? null : widget.graph.byId(_branch!);
    if (branch?.item != null) return branch;
    // The new Sepsis poster has 20 cards. Page its source cards (and their
    // questions/rules) using the existing evidence layout. Other source
    // graphs retain their current layout.
    final source = branch ?? (_hub == null ? null : widget.graph.byId(_hub!));
    if (source?.topic == NeonatalCondition.sepsis &&
        source?.node != null &&
        source!.children.isNotEmpty) {
      return source;
    }
    return null;
  }

  int get _evidenceColumns {
    final width = _viewport?.width ?? 1000;
    if (width < 650 &&
        _evidenceBranch?.node != null &&
        _evidenceBranch?.topic == NeonatalCondition.sepsis) {
      return 1;
    }
    return width >= 1000
        ? 4
        : width >= 650
            ? 3
            : 2;
  }

  int get _evidencePageSize =>
      _evidenceColumns * ((_viewport?.height ?? 500) >= 340 ? 2 : 1);

  List<Bubble> _evidenceChildren(Bubble branch) {
    final pages = (branch.children.length / _evidencePageSize).ceil();
    final page = _evidencePage.clamp(0, math.max(0, pages - 1)).toInt();
    return branch.children
        .skip(page * _evidencePageSize)
        .take(_evidencePageSize)
        .toList();
  }

  void _changeEvidencePage(int page) {
    setState(() {
      _evidencePage = page;
      _selected = _evidenceBranch?.id ?? _branch;
      _resetDrags();
      _relayout();
    });
  }

  Widget _evidencePager(Bubble branch) {
    final total = branch.children.length;
    final pages = (total / _evidencePageSize).ceil();
    final page = _evidencePage.clamp(0, pages - 1).toInt();
    final start = page * _evidencePageSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('evidence-previous'),
            tooltip: 'Previous evidence',
            onPressed: page > 0 ? () => _changeEvidencePage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Flexible(
              child: Text(
            'Evidence ${start + 1}–${math.min(start + _evidencePageSize, total)} of $total',
            key: const ValueKey('evidence-page-label'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          )),
          IconButton(
            key: const ValueKey('evidence-next'),
            tooltip: 'Next evidence',
            onPressed:
                page + 1 < pages ? () => _changeEvidencePage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  final _tracks = <String, _Track>{};
  late Map<String, Offset> _hubBase;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _tracks.removeWhere((_, t) => t.exiting));
      }
    });

  late final AnimationController _cam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..addListener(_onCamera);
  Matrix4Tween? _camTween;
  final _transform = TransformationController();
  Size? _viewport;
  var _fitted = false;

  // Dragging: each bubble's displacement from its layout pose, moved by
  // springs (see [_step]). [_rest] is where a bubble rests, relative to its
  // parent's displacement (a hub's is absolute), so a dropped bubble stays
  // put and follows its parent afterwards.
  final _disp = <String, Offset>{};
  final _vel = <String, Offset>{};
  final _rest = <String, Offset>{};
  String? _dragId;

  /// The bubble just dropped, held still while the others settle.
  String? _settling;
  var _settleFrames = 0;
  Offset _grab = Offset.zero;
  (String?, String?)? _layoutKey;
  final _worldKey = GlobalKey();
  final _simFrame = ValueNotifier<int>(0);
  late final Ticker _physics = createTicker(_tick);
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _hubBase = _overviewPositions();
    final g = widget.graph;
    final box = widget.focusBox == null ? null : g.box(widget.focusBox!);
    if (box != null) {
      _hub = box.parentId;
      _branch = box.id;
      _selected = box.id;
    } else if (widget.focusBubbleId != null &&
        g.byId(widget.focusBubbleId!) != null) {
      _focusBubble(g.byId(widget.focusBubbleId!)!);
    } else if (widget.focusTopic != null) {
      _hub = g.hubOf(widget.focusTopic!)?.id;
      _selected = _hub;
    }
    _relayout(animate: false);
  }

  @override
  void didUpdateWidget(BubbleGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final graphChanged = !identical(oldWidget.graph, widget.graph);
    final focusChanged = oldWidget.focusBubbleId != widget.focusBubbleId;
    if (!graphChanged && !focusChanged) return;
    if (graphChanged) {
      _hubBase = _overviewPositions();
      if (_hub != null && widget.graph.byId(_hub!) == null) _hub = null;
      if (_branch != null && widget.graph.byId(_branch!) == null) {
        _branch = null;
      }
      if (_selected != null && widget.graph.byId(_selected!) == null) {
        _selected = _branch ?? _hub;
      }
    }
    if (focusChanged && widget.focusBubbleId != null) {
      final focused = widget.graph.byId(widget.focusBubbleId!);
      if (focused != null) _focusBubble(focused);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _relayout());
    });
  }

  void _focusBubble(Bubble focused) {
    _evidencePage = 0;
    var root = focused;
    while (root.parentId != null) {
      root = widget.graph.byId(root.parentId!) ?? root;
      if (root.isHub) break;
    }
    _hub = root.id;
    _branch = focused.expandable ? focused.id : null;
    _selected = focused.id;
  }

  @override
  void dispose() {
    _physics.dispose();
    _simFrame.dispose();
    _anim.dispose();
    _cam.dispose();
    _transform.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Layout
  // -------------------------------------------------------------------------

  /// STWs on an inner ring; topics awaiting an STW outside, near the STWs
  /// that mention them.
  Map<String, Offset> _overviewPositions() {
    final g = widget.graph;
    final out = <String, Offset>{};
    final available = [
      for (final h in g.hubs)
        if (h.kind == BubbleKind.topic) h
    ];
    final angle = <String, double>{};
    for (var i = 0; i < available.length; i++) {
      final a = -3 * math.pi / 4 + i * 2 * math.pi / available.length;
      angle[available[i].id] = a;
      out[available[i].id] = Offset.fromDirection(a, 150);
    }
    final pending = [
      for (final h in g.hubs)
        if (h.kind == BubbleKind.pendingTopic) h,
    ];
    final wanted = <(String, double)>[];
    for (final p in pending) {
      var x = 0.0, y = 0.0;
      for (final e in g.hubEdges) {
        if (e.to == p.id && angle[e.from] != null) {
          x += math.cos(angle[e.from]!);
          y += math.sin(angle[e.from]!);
        }
      }
      wanted.add((p.id, x == 0 && y == 0 ? 0 : math.atan2(y, x)));
    }
    wanted.sort((a, b) => a.$2.compareTo(b.$2));
    const minGap = 0.75;
    double? prev;
    for (final (id, a) in wanted) {
      final placed = prev == null ? a : math.max(a, prev + minGap);
      out[id] = Offset.fromDirection(placed, 320);
      prev = placed;
    }
    return out;
  }

  /// Horizontal and vertical stretch that fits the layout to a tall phone
  /// screen (1, 1 on wide screens).
  (double, double) get _stretch {
    final v = _viewport;
    if (v == null || v.width <= 0) return (1, 1);
    final tall = v.height / v.width;
    if (tall < 1.15) return (1, 1);
    final k = math.min(1.0, (tall - 1.15) / 0.6);
    return (1 - 0.3 * k, 1 + 0.2 * k);
  }

  /// Target pose of every visible bubble.
  Map<String, _Pose> _targets() {
    final g = widget.graph;
    final t = <String, _Pose>{};
    final (sx, sy) = _stretch;
    Offset fit(Offset o, [double amount = 1]) => Offset(
          o.dx * (1 + (sx - 1) * amount),
          o.dy * (1 + (sy - 1) * amount),
        );
    final hub = _hub == null ? null : g.byId(_hub!);
    if (hub == null) {
      for (final h in g.hubs) {
        t[h.id] = _Pose(fit(_hubBase[h.id]!), 1, 1);
      }
      return t;
    }

    t[hub.id] = const _Pose(Offset.zero, 1, 1);
    final evidence = _evidenceBranch;
    if (evidence != null) {
      final children = _evidenceChildren(evidence);
      final columns = math.min(_evidenceColumns, math.max(1, children.length));
      final rows = (children.length / columns).ceil();
      final middle = math.max(0, rows - 1) * 88.0;
      // Keep the selected finding and its STW away from the evidence.
      // Only this page's evidence is drawn; no faded siblings behind it.
      if (hub.id != evidence.id) {
        t[hub.id] = _Pose(Offset(-210, middle), 0.8, 1);
      }
      t[evidence.id] = _Pose(Offset(0, middle), 1, 1);
      for (var i = 0; i < children.length; i++) {
        t[children[i].id] = _Pose(
          Offset(200 + (i % columns) * 176.0, (i ~/ columns) * 176.0),
          1,
          1,
        );
      }
      return t;
    }
    final kids = hub.children;
    final n = kids.length;
    const spacing = 112.0;
    final twoRings = n > 10;
    final inner = twoRings ? (n / 2).ceil() : n;
    final rIn = math.max(150.0, inner * spacing / (2 * math.pi));
    final rOut = twoRings ? rIn + 120 : rIn;
    final branch = _branch == null ? null : g.byId(_branch!);
    for (var i = 0; i < n; i++) {
      final double r;
      final double a;
      if (!twoRings) {
        r = rIn;
        a = -math.pi / 2 + i * 2 * math.pi / n;
      } else {
        final outer = i.isOdd;
        final k = i ~/ 2;
        final step = 2 * math.pi / inner;
        r = outer ? rOut : rIn;
        a = -math.pi / 2 + k * step + (outer ? step / 2 : 0);
      }
      final dim = branch != null && kids[i].id != branch.id;
      t[kids[i].id] = _Pose(
        fit(Offset.fromDirection(a, r), 0.6),
        dim ? 0.7 : 1,
        dim ? 0.25 : 1,
      );
    }

    final others = rOut + (branch == null ? 200 : 360);
    for (final h in g.hubs) {
      if (h.id == hub.id) continue;
      final dir = _hubBase[h.id]! - _hubBase[hub.id]!;
      t[h.id] = _Pose(
        fit(Offset.fromDirection(dir.direction, others), 0.6),
        0.8,
        0.4,
      );
    }

    if (branch != null && t[branch.id] != null) {
      final bc = t[branch.id]!.c;
      final k = branch.children.length;
      const step = 0.75;
      final spread =
          k <= 1 ? 0.0 : math.min(2 * math.pi * 0.92, (k - 1) * step);
      final base = bc.direction;
      for (var i = 0; i < k; i++) {
        final a = k <= 1 ? base : base - spread / 2 + i * spread / (k - 1);
        t[branch.children[i].id] =
            _Pose(bc + Offset.fromDirection(a, 165), 1, 1);
      }
    }
    return t;
  }

  _Pose _current(_Track t) {
    final v = _anim.value;
    final p = Curves.easeOutCubic.transform(v);
    final s = t.entering
        ? Curves.easeOutBack.transform(v)
        : Curves.easeInOutCubic.transform(v);
    return _Pose(
      Offset.lerp(t.from.c, t.to.c, p)!,
      t.from.scale + (t.to.scale - t.from.scale) * s,
      (t.from.opacity + (t.to.opacity - t.from.opacity) * p).clamp(0.0, 1.0),
    );
  }

  void _relayout({bool animate = true}) {
    final targets = _targets();
    // A new layout (an STW or box opened or closed) starts from where the
    // bubbles are now, dragged or not, and drops the drags. Same layout
    // (selection, resize): the drags stay.
    final key = (_hub, _branch);
    final newLayout = _layoutKey != null && _layoutKey != key;
    _layoutKey = key;
    final now = {
      for (final e in _tracks.entries)
        e.key:
            newLayout ? _shifted(e.key, _current(e.value)) : _current(e.value),
    };
    if (newLayout) _resetDrags();

    _Pose? parentPose(Bubble b, {required bool target}) {
      final pid = b.parentId;
      if (pid == null) return null;
      return target ? targets[pid] ?? now[pid] : now[pid] ?? targets[pid];
    }

    final next = <String, _Track>{};
    targets.forEach((id, to) {
      final b = widget.graph.byId(id)!;
      final old = _tracks[id];
      if (old != null && !old.exiting) {
        next[id] = _Track(b, now[id]!, to);
      } else {
        final p = parentPose(b, target: false);
        final from = animate && p != null
            ? _Pose(p.c, 0.1, 0)
            : (animate ? _Pose(to.c, 0.1, 0) : to);
        next[id] = _Track(b, from, to, entering: animate);
      }
    });
    _tracks.forEach((id, old) {
      if (next.containsKey(id)) return;
      final p = parentPose(old.bubble, target: true);
      next[id] = _Track(old.bubble, now[id]!, _Pose(p?.c ?? now[id]!.c, 0.1, 0))
        ..exiting = true;
    });
    _tracks
      ..clear()
      ..addAll(next);

    if (animate) {
      _anim.forward(from: 0);
    } else {
      _anim.value = 1;
    }
    if (_viewport != null) _fitCamera(targets, animate: animate);
  }

  // -------------------------------------------------------------------------
  // Dragging and springs
  // -------------------------------------------------------------------------

  /// Pull of a hub back to where it rests (per second², per unit mass).
  static const _kHome = 30.0;

  /// Pull of a bubble to its place around its parent: what hangs off a
  /// dragged bubble follows it closely.
  static const _kFollow = 45.0;

  /// Pull of a bubble back on its parent: dragging a box nudges its STW.
  static const _kTug = 4.0;

  /// Pull along the links between STWs.
  static const _kLink = 9.0;

  /// Push between bubbles dragged into each other.
  static const _kPush = 600.0;

  /// Velocity lost per second.
  static const _damping = 8.5;

  /// Free space kept between two bubbles that are pushed apart.
  static const _gap = 16.0;

  Offset _d(String id) => _disp[id] ?? Offset.zero;

  _Pose _shifted(String id, _Pose p) {
    final d = _disp[id];
    return d == null ? p : _Pose(p.c + d, p.scale, p.opacity);
  }

  void _resetDrags() {
    _disp.clear();
    _vel.clear();
    _rest.clear();
    _dragId = null;
    _settling = null;
    _physics.stop();
  }

  void _wake() {
    if (_physics.isActive) return;
    _lastTick = Duration.zero;
    _physics.start();
  }

  /// The visible parent of [b] (null for hubs).
  String? _parentOf(Bubble b, Map<String, Offset> live) {
    final pid = b.parentId;
    return pid != null && live.containsKey(pid) ? pid : null;
  }

  /// Where [id] rests: its rest offset plus where its parent rests.
  Offset _restAt(String id) {
    final b = widget.graph.byId(id);
    final pid = b?.parentId;
    final own = _rest[id] ?? Offset.zero;
    final t = pid == null ? null : _tracks[pid];
    return t == null || t.exiting ? own : own + _restAt(pid!);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _lastTick = elapsed;
    if (dt <= 0) return;
    final steps = (dt * 120).ceil();
    var moving = false;
    for (var i = 0; i < steps; i++) {
      moving = _step(dt / steps);
    }
    _simFrame.value++;
    if (_dragId != null) return;
    if (!moving || ++_settleFrames > 300) _settle();
  }

  /// Everything stays where it came to rest.
  void _settle() {
    final live = {
      for (final t in _tracks.values)
        if (!t.exiting) t.bubble.id: _d(t.bubble.id),
    };
    for (final t in _tracks.values) {
      if (t.exiting) continue;
      final pid = _parentOf(t.bubble, live);
      _rest[t.bubble.id] =
          _d(t.bubble.id) - (pid == null ? Offset.zero : _d(pid));
    }
    _vel.clear();
    _settling = null;
    _physics.stop();
  }

  /// One step of [dt] seconds. Returns whether anything is still moving.
  bool _step(double dt) {
    final force = <String, Offset>{};
    final tracks = <_Track>[];
    for (final t in _tracks.values) {
      if (t.exiting) continue;
      force[t.bubble.id] = Offset.zero;
      tracks.add(t);
    }

    // Springs to each bubble's resting place (around its parent).
    for (final t in tracks) {
      final id = t.bubble.id;
      final pid = _parentOf(t.bubble, force);
      final want =
          (pid == null ? Offset.zero : _d(pid)) + (_rest[id] ?? Offset.zero);
      final stretch = want - _d(id);
      force[id] = force[id]! + stretch * (pid == null ? _kHome : _kFollow);
      if (pid != null) force[pid] = force[pid]! - stretch * _kTug;
    }

    // Links between STWs.
    Offset off(String id) => _d(id) - (_rest[id] ?? Offset.zero);
    for (final e in widget.graph.hubEdges) {
      if (!force.containsKey(e.from) || !force.containsKey(e.to)) continue;
      final s = (off(e.to) - off(e.from)) * _kLink;
      force[e.from] = force[e.from]! + s;
      force[e.to] = force[e.to]! - s;
    }

    // Bubbles pushed together make room, but never further apart than they
    // rest.
    final poses = [for (final t in tracks) _current(t)];
    for (var i = 0; i < tracks.length; i++) {
      if (poses[i].opacity < 0.3) continue;
      final a = tracks[i].bubble;
      final ca = poses[i].c + _d(a.id);
      final ra = _radius(a.kind) * poses[i].scale;
      for (var j = i + 1; j < tracks.length; j++) {
        if (poses[j].opacity < 0.3) continue;
        final b = tracks[j].bubble;
        final delta = poses[j].c + _d(b.id) - ca;
        final dist = delta.distance;
        if (dist < 0.001) continue;
        final rested =
            (poses[j].c + _restAt(b.id) - poses[i].c - _restAt(a.id)).distance;
        final minDist = math.min(
          ra + _radius(b.kind) * poses[j].scale + _gap,
          rested,
        );
        if (dist >= minDist) continue;
        final push = delta / dist * ((minDist - dist) * _kPush);
        force[a.id] = force[a.id]! - push;
        force[b.id] = force[b.id]! + push;
      }
    }

    var moving = false;
    final keep = math.exp(-_damping * dt);
    for (final t in tracks) {
      final id = t.bubble.id;
      if (id == _dragId || id == _settling) continue;
      final mass = _radius(t.bubble.kind) / 32;
      final a = force[id]! / mass;
      final v = ((_vel[id] ?? Offset.zero) + a * dt) * keep;
      _vel[id] = v;
      _disp[id] = _d(id) + v * dt;
      if (v.distance > 3 || a.distance > 6) moving = true;
    }
    return moving;
  }

  /// [global] in the coordinates bubbles are laid out in.
  Offset? _scene(Offset global) {
    final box = _worldKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  void _dragStart(Bubble b, DragStartDetails details) {
    final t = _tracks[b.id];
    final p = _scene(details.globalPosition);
    if (t == null || t.exiting || p == null) return;
    _cam.stop();
    _grab = p - (_o + _shifted(b.id, _current(t)).c);
    _vel.remove(b.id);
    _settling = null;
    _settleFrames = 0;
    setState(() => _dragId = b.id);
    _wake();
  }

  void _dragUpdate(Bubble b, DragUpdateDetails details) {
    final t = _tracks[b.id];
    final p = _scene(details.globalPosition);
    if (_dragId != b.id || t == null || p == null) return;
    const limit = _world / 2 - 80;
    final c = p - _grab - _o;
    _disp[b.id] = Offset(
          c.dx.clamp(-limit, limit),
          c.dy.clamp(-limit, limit),
        ) -
        _current(t).c;
    _wake();
  }

  void _dragEnd(Bubble b) {
    if (_dragId != b.id) return;
    _settleFrames = 0;
    setState(() {
      _dragId = null;
      _settling = b.id;
    });
    _wake();
  }

  // -------------------------------------------------------------------------
  // Camera
  // -------------------------------------------------------------------------

  void _onCamera() {
    final tween = _camTween;
    if (tween == null) return;
    _transform.value =
        tween.transform(Curves.easeInOutCubic.transform(_cam.value));
  }

  /// Zooms to what matters now: the opened box and its fan, else the opened
  /// STW and its ring, else every STW.
  void _fitCamera(Map<String, _Pose> targets, {bool animate = true}) {
    final view = _viewport;
    if (view == null || view.isEmpty) return;
    final g = widget.graph;
    Iterable<String> ids;
    final evidence = _evidenceBranch;
    if (evidence != null) {
      ids = [
        if (view.width >= 650) _hub!,
        if (view.width >= 650 && _branch != null) _branch!,
        ..._evidenceChildren(evidence).map((c) => c.id),
      ];
    } else if (_branch != null) {
      ids = [_branch!, ...g.byId(_branch!)!.children.map((c) => c.id)];
    } else if (_hub != null) {
      ids = [_hub!, ...g.byId(_hub!)!.children.map((c) => c.id)];
    } else {
      ids = targets.keys;
    }
    Rect? bounds;
    for (final id in ids) {
      final p = targets[id];
      final b = g.byId(id);
      if (p == null || b == null) continue;
      final r = _radius(b.kind) * p.scale;
      // Room for the label under a bubble (hubs have theirs inside).
      final side = b.isHub ? 8.0 : 62.0;
      final below = b.isHub ? 8.0 : 52.0;
      final rect = Rect.fromLTRB(p.c.dx - r - side, p.c.dy - r - 8,
          p.c.dx + r + side, p.c.dy + r + below);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    if (bounds == null) return;
    // The information card has its own space below the canvas. Reserve
    // the top toolbar here so labels never sit underneath its controls.
    const top = 64.0;
    final usableH = math.max(80.0, view.height - top);
    final s = math
        .min((view.width - 16) / bounds.width, (usableH - 16) / bounds.height)
        .clamp(0.35, 1.25);
    final center = _o + bounds.center;
    final target = Matrix4.translationValues(
      view.width / 2 - s * center.dx,
      top + usableH / 2 - s * center.dy,
      0,
    )..multiply(Matrix4.diagonal3Values(s, s, 1));
    if (!animate) {
      _cam.stop();
      _transform.value = target;
      return;
    }
    _camTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _cam.forward(from: 0);
  }

  void _zoom(double factor) {
    final view = _viewport;
    if (view == null) return;
    final m = _transform.value;
    final s = m.getMaxScaleOnAxis();
    final ns = (s * factor).clamp(0.3, 2.5);
    final f = ns / s;
    final c = Offset(view.width / 2, view.height / 2);
    _camTween = Matrix4Tween(
      begin: m.clone(),
      end: Matrix4.translationValues(c.dx * (1 - f), c.dy * (1 - f), 0)
        ..multiply(m),
    );
    _cam.forward(from: 0);
  }

  // -------------------------------------------------------------------------
  // Interaction
  // -------------------------------------------------------------------------

  void _tap(Bubble b) {
    HapticFeedback.selectionClick();
    setState(() {
      if (b.isHub || b.expandable) _evidencePage = 0;
      if (b.isHub) {
        if (_hub == b.id) {
          _hub = null;
          _branch = null;
        } else {
          _hub = b.id;
          _branch = null;
        }
      } else if (b.expandable) {
        _branch = _branch == b.id ? null : b.id;
      }
      _selected = b.id;
    });
    _relayout();
  }

  void _overview() {
    setState(() {
      _hub = null;
      _branch = null;
      _selected = null;
      _evidencePage = 0;
    });
    _relayout();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected == null ? null : widget.graph.byId(_selected!);
    final evidence = _evidenceBranch;
    return Column(children: [
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        if (_viewport != size) {
          _viewport = size;
          final first = !_fitted;
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _relayout(animate: !first));
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: 0.3,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(400),
                onInteractionStart: (_) => _cam.stop(),
                child: SizedBox(
                  key: _worldKey,
                  width: _world,
                  height: _world,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_anim, _transform, _simFrame]),
                    builder: (context, _) => _canvas(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _hub == null
                    ? const _Hint(key: ValueKey('hint'))
                    : ActionChip(
                        key: const ValueKey('back'),
                        avatar: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Text(widget.overviewLabel),
                        onPressed: _overview,
                      ),
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Column(
                children: [
                  if (size.width >= 650) ...[
                    _RoundIcon(
                      icon: Icons.add_rounded,
                      label: 'Zoom in',
                      onTap: () => _zoom(1.25),
                    ),
                    const SizedBox(height: 8),
                    _RoundIcon(
                      icon: Icons.remove_rounded,
                      label: 'Zoom out',
                      onTap: () => _zoom(1 / 1.25),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _RoundIcon(
                    icon: Icons.center_focus_strong_outlined,
                    label: 'Re-centre',
                    onTap: () => _fitCamera(_targets()),
                  ),
                ],
              ),
            ),
          ],
        );
      })),
      if (evidence != null && evidence.children.length > _evidencePageSize)
        _evidencePager(evidence),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, a) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
        child: selected == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : _InfoCard(
                key: ValueKey(selected.id),
                bubble: selected,
                expanded: selected.id == _hub || selected.id == _branch,
                onToggle: () => _tap(selected),
                onDetails: selected.node == null || widget.onDetails == null
                    ? null
                    : () => widget.onDetails!(selected.node!),
                onAssessmentDetails:
                    selected.item == null || widget.onAssessmentDetails == null
                        ? null
                        : () => widget.onAssessmentDetails!(
                              selected.item!,
                              selected.feeds,
                            ),
                onClose: () {
                  setState(() => _selected = null);
                  _fitCamera(_targets());
                },
              ),
      ),
    ]);
  }

  Widget _canvas() {
    final poses = {
      for (final e in _tracks.entries)
        e.key: _shifted(e.key, _current(e.value)),
    };
    final edges = <_Edge>[];
    final g = widget.graph;

    for (final e in g.hubEdges) {
      final a = poses[e.from];
      final b = poses[e.to];
      if (a == null || b == null) continue;
      edges.add(_Edge(
        from: _o + a.c,
        to: _o + b.c,
        fromR: _radius(g.byId(e.from)!.kind) * a.scale,
        toR: _radius(g.byId(e.to)!.kind) * b.scale,
        color: switch (e.label) {
          'shares answers' => const Color(0xFF6AA84F),
          'refers to' => const Color(0xFFC0504D),
          _ => const Color(0xFFD69E2E),
        },
        opacity: math.min(a.opacity, b.opacity),
        label: e.label,
        dashed: e.draft,
        arrow: !e.mutual,
      ));
    }
    for (final t in _tracks.values) {
      final pid = t.bubble.parentId;
      if (pid == null) continue;
      final a = poses[pid];
      final b = poses[t.bubble.id];
      if (a == null || b == null) continue;
      final parent = g.byId(pid)!;
      edges.add(_Edge(
        from: _o + a.c,
        to: _o + b.c,
        fromR: _radius(parent.kind) * a.scale,
        toR: _radius(t.bubble.kind) * b.scale,
        color: bubbleLook(parent.kind).border,
        opacity: math.min(a.opacity, b.opacity),
        // A label on every spoke obscures both evidence and the finding.
        // Show the relationship for the selected evidence only.
        label: _evidenceBranch == null ? t.bubble.edgeLabel : null,
        orthogonal: _evidenceBranch != null && pid == _evidenceBranch!.id,
        dashed: t.bubble.draft,
        arrow: true,
      ));
    }

    // Hubs under their children; the selected bubble on top.
    final order = _tracks.values.toList()
      ..sort((a, b) {
        int rank(_Track t) =>
            (t.bubble.id == _selected ? 10 : 0) + (t.bubble.isHub ? 0 : 1);
        return rank(a).compareTo(rank(b));
      });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_selected != null) setState(() => _selected = null);
            },
          ),
        ),
        Positioned.fill(
          child:
              IgnorePointer(child: CustomPaint(painter: _EdgePainter(edges))),
        ),
        for (final t in order) ..._bubble(t, poses[t.bubble.id]!),
      ],
    );
  }

  List<Widget> _bubble(_Track t, _Pose p) {
    final b = t.bubble;
    final look = bubbleLook(b.kind);
    final r = _radius(b.kind);
    final center = _o + p.c;
    final scaled = r * p.scale;
    final selected = b.id == _selected;
    final open = b.id == _hub || b.id == _branch;
    if (p.opacity <= 0.01 || scaled <= 0.5) return const [];
    final zoom = _transform.value.getMaxScaleOnAxis();
    final always = selected || b.parentId == _branch || b.id == _branch;
    final labelOpacity = p.opacity < 0.5
        ? 0.0
        : p.opacity * (always ? 1.0 : ((zoom - 0.5) / 0.2).clamp(0.0, 1.0));

    final circle = Container(
      width: 2 * r,
      height: 2 * r,
      decoration: BoxDecoration(
        color: look.fill,
        shape: BoxShape.circle,
        border: Border.all(color: look.border, width: open ? 4 : 3),
        boxShadow: [
          BoxShadow(
            color: look.border.withValues(alpha: selected ? 0.55 : 0.18),
            blurRadius: selected ? 18 : 6,
            spreadRadius: selected ? 3 : 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: b.isHub
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _wrapWords(b.label, 11),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: b.kind == BubbleKind.topic ? 16 : 13,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.bodyText,
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                Icon(look.icon, color: look.border, size: r * 0.85),
                if (b.expandable && !open)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child:
                        _CountDot(count: b.children.length, color: look.border),
                  ),
              ],
            ),
    );

    return [
      Positioned(
        left: center.dx - r,
        top: center.dy - r,
        width: 2 * r,
        height: 2 * r,
        child: Opacity(
          opacity: p.opacity,
          child: Transform.scale(
            scale: p.scale,
            child: t.exiting
                ? circle
                : Semantics(
                    button: true,
                    label: '${look.label}: ${b.label}'
                        '${b.expandable ? (open ? ', expanded' : ', tap to expand') : ''}',
                    excludeSemantics: true,
                    // The bubble claims the drag, so the view does not pan.
                    child: GestureDetector(
                      key: ValueKey('bubble:${b.id}'),
                      onTap: () => _tap(b),
                      onPanStart: (d) => _dragStart(b, d),
                      onPanUpdate: (d) => _dragUpdate(b, d),
                      onPanEnd: (_) => _dragEnd(b),
                      onPanCancel: () => _dragEnd(b),
                      child: MouseRegion(
                        cursor: _dragId == b.id
                            ? SystemMouseCursors.grabbing
                            : SystemMouseCursors.grab,
                        child: circle,
                      ),
                    ),
                  ),
          ),
        ),
      ),
      if (!b.isHub && labelOpacity > 0.02)
        Positioned(
          left: center.dx - 66,
          top: center.dy + scaled + 4,
          width: 132,
          child: IgnorePointer(
            child: Opacity(
              opacity: labelOpacity,
              child: Text(
                key: ValueKey('bubble-label:${b.id}'),
                b.label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: AppTheme.bodyText,
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 3),
                    Shadow(color: Colors.white, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _Edge {
  _Edge({
    required this.from,
    required this.to,
    required this.fromR,
    required this.toR,
    required this.color,
    required this.opacity,
    required this.arrow,
    this.label,
    this.dashed = false,
    this.orthogonal = false,
  });
  final Offset from;
  final Offset to;
  final double fromR;
  final double toR;
  final Color color;
  final double opacity;
  final bool arrow;
  final String? label;
  final bool dashed;
  final bool orthogonal;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges);
  final List<_Edge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      if (e.opacity <= 0.01) continue;
      final d = e.to - e.from;
      final len = d.distance;
      if (len <= e.fromR + e.toR + 2) continue;
      final u = d / len;
      final a = e.from + u * (e.fromR + 2);
      final b = e.to - u * (e.toR + 3);
      final color = e.color.withValues(alpha: e.opacity * 0.9);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (e.orthogonal) {
        // Route above each row and enter the top of the circle, keeping
        // lines away from the labels underneath every evidence node.
        final end = e.to - Offset(0, e.toR + 3);
        final laneY = e.to.dy - 76;
        final laneX = e.from.dx + 82;
        canvas.drawPath(
          Path()
            ..moveTo(e.from.dx + e.fromR + 2, e.from.dy)
            ..lineTo(laneX, e.from.dy)
            ..lineTo(laneX, laneY)
            ..lineTo(end.dx, laneY)
            ..lineTo(end.dx, end.dy),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(end.dx - 5, end.dy - 9)
            ..lineTo(end.dx + 5, end.dy - 9)
            ..close(),
          Paint()..color = color,
        );
        continue;
      }
      if (e.dashed) {
        final total = (b - a).distance;
        for (var s = 0.0; s < total; s += 12) {
          canvas.drawLine(
            a + u * s,
            a + u * math.min(s + 7, total),
            paint,
          );
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
      if (e.arrow) {
        final n = Offset(-u.dy, u.dx);
        final back = b - u * 11;
        canvas.drawPath(
          Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo((back + n * 6).dx, (back + n * 6).dy)
            ..lineTo((back - n * 6).dx, (back - n * 6).dy)
            ..close(),
          Paint()..color = color,
        );
      }
      final label = e.label;
      if (label != null && e.opacity > 0.5) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color.lerp(e.color, Colors.black, 0.35)!
                  .withValues(alpha: e.opacity),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final mid = (a + b) / 2;
        final rect = Rect.fromCenter(
          center: mid,
          width: tp.width + 10,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = Colors.white.withValues(alpha: 0.9 * e.opacity),
        );
        tp.paint(canvas, rect.topLeft + const Offset(5, 2));
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 16, color: AppTheme.mutedText),
            SizedBox(width: 4),
            Text(
              'Tap a circle to open it',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
            ),
          ],
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFFCBD5E1)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 42,
              child: Icon(icon, color: AppTheme.primaryNavy, size: 22),
            ),
          ),
        ),
      );
}

/// The selected bubble: what it is, and Details / Open in PDF / expand.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    super.key,
    required this.bubble,
    required this.expanded,
    required this.onToggle,
    this.onDetails,
    this.onAssessmentDetails,
    required this.onClose,
  });

  final Bubble bubble;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onDetails;
  final VoidCallback? onAssessmentDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final b = bubble;
    final look = bubbleLook(b.kind);
    final n = b.node;
    final item = b.item;
    final src = n?.source ?? item?.source;
    final label = n?.label ?? item?.label ?? b.label;
    final compact = MediaQuery.sizeOf(context).width < 650;
    final compactStyle = compact
        ? const ButtonStyle(
            padding:
                WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
            visualDensity: VisualDensity.compact,
          )
        : null;
    final subtitle = n?.kind == MapKind.topic
        ? n?.subtitle
        : n?.subtitle ??
            b.subtitle ??
            (item?.value == null ? null : 'Value: ${item!.value}');
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: look.border.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: look.fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: look.border, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    look.label,
                    if (item != null && b.edgeLabel != null && !b.expandable)
                      b.edgeLabel!,
                    if (b.draft) 'draft, awaiting clinical review',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color.lerp(look.border, Colors.black, 0.3),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.bodyText,
              ),
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12.5, color: AppTheme.mutedText),
              ),
            ),
          if (item?.check != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(
                'Check: ${item!.check}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedText,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (b.expandable)
                FilledButton.tonalIcon(
                  style: compactStyle,
                  onPressed: onToggle,
                  icon: Icon(
                    expanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 18,
                  ),
                  label: Text(expanded ? 'Collapse' : 'Expand'),
                ),
              if (onDetails != null || onAssessmentDetails != null)
                OutlinedButton.icon(
                  style: compactStyle,
                  onPressed: onDetails ?? onAssessmentDetails,
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Details'),
                ),
              if (hasPdf(src))
                OutlinedButton.icon(
                  style: compactStyle,
                  onPressed: () => openSourceInPdf(context, src!),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [text] broken between words into lines of about [width] characters.
String _wrapWords(String text, int width) {
  final lines = <String>[];
  var line = '';
  for (final w in text.split(' ')) {
    if (line.isEmpty) {
      line = w;
    } else if (line.length + 1 + w.length <= width) {
      line = '$line $w';
    } else {
      lines.add(line);
      line = w;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n');
}
