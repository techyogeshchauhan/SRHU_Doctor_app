import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../clinical_workflow/domain/assessment_context.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../../clinical_workflow/ui/assessment_summary.dart' show toneFor;
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/bubble_graph.dart';
import '../domain/kg_graph.dart';
import '../domain/reasoning.dart';
import '../state/kg_providers.dart';
import 'bubble_graph_view.dart';
import 'node_details_screen.dart';
import 'node_graph_view.dart' show KgPlacement;
import 'reasoning_tree.dart';

/// The knowledge graph of the current assessment.
///
/// Graph view reuses the Home bubble graph, but projects only the selected
/// conditions, entered answers and findings in the current assessment.
/// List view keeps the step-by-step explanation for every triggered finding.
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
                      : _graph(context, ctx, trees),
                ),
              ],
            ),
    );
  }

  Widget _graph(
    BuildContext context,
    ClinicalAssessmentContext ctx,
    List<ReasonNode> trees,
  ) {
    final graph = buildAssessmentBubbleGraph(context: ctx, trees: trees);
    final usedBy = findingsUsing(trees);

    void showFinding(ClinicalFinding finding) {
      NodeDetailsScreen.closeAll(context);
      setState(() => _focus = finding.id);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: BubbleLegend(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: BubbleGraphView(
                key: ValueKey(ctx.selected.map((c) => c.name).join(',')),
                graph: graph,
                focusBubbleId: _focus == null ? null : 'finding:$_focus',
                overviewLabel: 'All selected conditions',
                onAssessmentDetails: (item, feeds) => NodeDetailsScreen.open(
                  context,
                  placement: KgPlacement(item: item, feeds: feeds),
                  usedBy: usedBy,
                  onShowFinding: showFinding,
                ),
              ),
            ),
          ),
        ],
      ),
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
          if (trees.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No STW pathway triggered yet.'),
            ),
          if (shared.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Answers used by more than one topic', style: heading),
            const SizedBox(height: 8),
            for (final answer in shared) _SharedAnswerCard(shared: answer),
          ],
          for (final topic in conditionDisplayOrder)
            if (trees.any((t) => t.finding!.topic == topic)) ...[
              const SizedBox(height: 20),
              _TopicHeader(
                topic: topic,
                count: trees.where((t) => t.finding!.topic == topic).length,
              ),
              for (final tree in trees)
                if (tree.finding!.topic == topic)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ReasonTree(root: tree, initiallyOpen: false),
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
            for (final answer in shared.answers)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: answer.label),
                      if (answer.value != null)
                        TextSpan(
                          text: ':  ${answer.value}',
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
            for (final finding in shared.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      toneFor(finding.level).icon,
                      size: 15,
                      color: toneFor(finding.level).foreground(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${topicShort(finding.topic)}: ${finding.title}',
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
