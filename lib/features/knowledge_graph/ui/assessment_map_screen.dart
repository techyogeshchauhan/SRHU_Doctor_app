import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../../clinical_workflow/ui/assessment_summary.dart' show toneFor;
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/kg_graph.dart';
import '../domain/reasoning.dart';
import '../state/kg_providers.dart';
import 'node_details_screen.dart';
import 'node_graph_view.dart';
import 'reasoning_tree.dart';

/// The knowledge graph of the current assessment.
///
/// Graph view: one finding at a time as a node graph (what it is based on →
/// STW rule → finding → STW box and the findings that follow), with
/// expandable nodes and a details page per node. List view: every finding
/// as an expandable step-by-step list. Updates live while the assessment
/// continues.
class AssessmentMapScreen extends ConsumerStatefulWidget {
  const AssessmentMapScreen({super.key, this.focusFindingId});

  /// Rule id of the finding to show first (e.g. from "Why?").
  final String? focusFindingId;

  @override
  ConsumerState<AssessmentMapScreen> createState() =>
      _AssessmentMapScreenState();
}

class _AssessmentMapScreenState extends ConsumerState<AssessmentMapScreen> {
  var _listView = false;
  String? _focus;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusFindingId;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final trees = reasoningBuilder(ref, ctx).explainAll();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assessment map',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
      ),
      body: ctx.selected.isEmpty
          ? const _Empty('No assessment in progress.')
          : trees.isEmpty
              ? const _Empty('No STW pathway triggered yet.')
              : Column(
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
                            icon: Icon(Icons.format_list_bulleted),
                            label: Text('List view'),
                          ),
                        ],
                        selected: {_listView},
                        onSelectionChanged: (s) =>
                            setState(() => _listView = s.first),
                      ),
                    ),
                    Expanded(
                      child: _listView
                          ? _ListView(trees: trees)
                          : _graph(context, trees),
                    ),
                  ],
                ),
    );
  }

  Widget _graph(BuildContext context, List<ReasonNode> trees) {
    final tree = trees.firstWhere(
      (t) => t.finding!.id == _focus,
      orElse: () => trees.first,
    );
    final graph = focusGraphOf(tree, trees);
    final usedBy = findingsUsing(trees);

    void showFinding(ClinicalFinding f) {
      NodeDetailsScreen.closeAll(context);
      setState(() => _focus = f.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KgLegend(),
              const SizedBox(height: 8),
              _FindingPicker(
                trees: trees,
                selected: tree.finding!,
                onSelected: showFinding,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF1F5F9),
            child: NodeGraphView(
              key: ValueKey(graph.finding.id),
              graph: graph,
              onOpen: (p) => NodeDetailsScreen.open(
                context,
                placement: p,
                usedBy: usedBy,
                onShowFinding: showFinding,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Which finding the graph shows.
class _FindingPicker extends StatelessWidget {
  const _FindingPicker({
    required this.trees,
    required this.selected,
    required this.onSelected,
  });

  final List<ReasonNode> trees;
  final ClinicalFinding selected;
  final void Function(ClinicalFinding f) onSelected;

  @override
  Widget build(BuildContext context) {
    final findings = [for (final t in trees) t.finding!];
    return DropdownButtonFormField<String>(
      key: ValueKey(selected.id),
      initialValue: selected.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Showing finding',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: [
        for (final f in findings)
          DropdownMenuItem(
            value: f.id,
            child: Row(
              children: [
                Icon(
                  toneFor(f.level).icon,
                  size: 16,
                  color: toneFor(f.level).foreground(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${topicShort(f.topic)}: ${f.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        onSelected(findings.firstWhere((f) => f.id == id));
      },
    );
  }
}

/// Every finding grouped by topic, each opening step by step; answers used
/// by several topics first.
class _ListView extends ConsumerWidget {
  const _ListView({required this.trees});

  final List<ReasonNode> trees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final shared = reasoningBuilder(ref, ctx).sharedAnswers(trees);
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryNavy,
        );
    return MaxWidth(
      maxWidth: Breakpoints.contentMaxWidth,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Open a finding to see the answers it is based on, step by '
            'step. Tap any box to see its source highlighted in the STW PDF.',
            style: TextStyle(fontSize: 13, color: AppTheme.bodyText),
          ),
          const SizedBox(height: 8),
          const ReasonLegend(),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Answers used by more than one topic', style: heading),
            const SizedBox(height: 8),
            for (final s in shared) _SharedAnswerCard(shared: s),
          ],
          for (final topic in NeonatalCondition.values)
            if (trees.any((t) => t.finding!.topic == topic)) ...[
              const SizedBox(height: 20),
              _TopicHeader(
                topic: topic,
                count: trees.where((t) => t.finding!.topic == topic).length,
              ),
              for (final t in trees)
                if (t.finding!.topic == topic)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ReasonTree(root: t, initiallyOpen: false),
                  ),
            ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({required this.topic, required this.count});

  final NeonatalCondition topic;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                definitionOf(topic).title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '$count ${count == 1 ? 'finding' : 'findings'}',
              style: const TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
          ],
        ),
      );
}

/// Answers several topics share and the findings they lead to.
class _SharedAnswerCard extends StatelessWidget {
  const _SharedAnswerCard({required this.shared});

  final SharedAnswer shared;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in shared.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: a.label),
                      if (a.value != null)
                        TextSpan(
                          text: ':  ${a.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Leads to ${shared.findings.length} findings in '
              '${shared.topics.map(topicShort).join(' and ')}:',
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
            ),
            const SizedBox(height: 6),
            for (final f in shared.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      toneFor(f.level).icon,
                      size: 15,
                      color: toneFor(f.level).foreground(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${topicShort(f.topic)}: ${f.title}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
