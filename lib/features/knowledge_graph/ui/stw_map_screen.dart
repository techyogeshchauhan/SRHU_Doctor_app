import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/bubble_graph.dart';
import '../domain/stw_map.dart';
import '../state/stw_map_provider.dart';
import 'bubble_graph_view.dart';
import 'stw_map_details_screen.dart';
import 'stw_map_look.dart';

/// STW Map: what the approved STWs contain and how they connect, without a
/// patient. Opens on [focus] (a PDF box id or a topic name) or on the box
/// an MCQ [reference] cites.
class StwMapScreen extends ConsumerWidget {
  const StwMapScreen({super.key, this.focus, this.reference, this.file});

  final String? focus;
  final String? reference;

  /// PDF file name: opens that STW when [focus] is not a known box.
  final String? file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stwMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STW Map',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('The STW Map could not be loaded.'),
          ),
        ),
        data: (map) {
          var box = focus != null && map.box(focus!) != null ? focus : null;
          if (box == null && reference != null) {
            box = map.resolveReference(reference!);
          }
          final topic = box != null
              ? map.topicOfBox(box)
              : NeonatalCondition.values.asNameMap()[focus] ??
                  (file == null ? null : map.topicOfFile(file!));
          return _StwMapBody(map: map, topic: topic, focusBox: box);
        },
      ),
    );
  }
}

class _StwMapBody extends StatefulWidget {
  const _StwMapBody({required this.map, this.topic, this.focusBox});

  final StwMap map;
  final NeonatalCondition? topic;
  final String? focusBox;

  @override
  State<_StwMapBody> createState() => _StwMapBodyState();
}

class _StwMapBodyState extends State<_StwMapBody> {
  var _list = false;

  /// STW and box the graph opens on; null: the overview of all STWs.
  NeonatalCondition? _topic;
  String? _focusBox;
  var _query = '';
  late final BubbleGraph _bubbles = buildBubbleGraph(widget.map);

  /// Bumped to re-open the graph on [_topic] / [_focusBox].
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    _focusBox = widget.focusBox;
  }

  void _showBox(String regionId) {
    StwMapDetailsScreen.closeAll(context);
    setState(() {
      _list = false;
      _topic = widget.map.topicOfBox(regionId) ?? _topic;
      _focusBox = regionId;
      _generation++;
    });
  }

  void _showTopic(NeonatalCondition t) {
    StwMapDetailsScreen.closeAll(context);
    if (widget.map.root(t) == null) return;
    setState(() {
      _list = false;
      _topic = t;
      _focusBox = null;
      _generation++;
    });
  }

  void _open(MapNode n) => StwMapDetailsScreen.open(
        context,
        node: n,
        map: widget.map,
        onShowBox: _showBox,
        onShowTopic: _showTopic,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.account_tree_outlined),
                label: Text('Graph view'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.search_rounded),
                label: Text('Search & list'),
              ),
            ],
            selected: {_list},
            onSelectionChanged: (s) => setState(() => _list = s.first),
          ),
        ),
        Expanded(child: _list ? _listView() : _graph()),
      ],
    );
  }

  Widget _graph() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: BubbleLegend(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: BubbleGraphView(
                key: ValueKey('$_generation/$_topic/$_focusBox'),
                graph: _bubbles,
                focusBox: _focusBox,
                focusTopic: _topic,
                onDetails: _open,
              ),
            ),
          ),
        ],
      );

  Widget _listView() {
    final hits = widget.map.search(_query);
    return MaxWidth(
      maxWidth: Breakpoints.contentMaxWidth,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search the STWs, e.g. surfactant, sepsis, GIR',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 12),
          if (_query.trim().isNotEmpty) ...[
            Text(
              hits.isEmpty
                  ? 'No STW box or question matches.'
                  : '${hits.length} '
                      '${hits.length == 1 ? 'match' : 'matches'}',
              style: const TextStyle(color: AppTheme.mutedText),
            ),
            const SizedBox(height: 6),
            for (final n in hits) _ListTile(node: n, onTap: () => _open(n)),
          ] else
            for (final r in widget.map.roots) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  r.pending ? '${r.label} (awaiting STW)' : r.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
              for (final c in r.children)
                _ListTile(node: c, onTap: () => _open(c)),
            ],
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.node, required this.onTap});
  final MapNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = mapLook(node.kind, node.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: look.bg,
          child: Icon(look.icon, color: look.fg, size: 20),
        ),
        title: Text(node.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            node.kind.label,
            if (node.topic != null) definitionOf(node.topic!).title,
            if (node.kind == MapKind.link && node.link?.approved != true)
              'draft',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
