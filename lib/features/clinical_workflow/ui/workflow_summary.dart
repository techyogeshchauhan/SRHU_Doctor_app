import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/baby_context.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/state/rd_controller.dart';
import '../../rd/ui/rd_results.dart';
import '../../rop/state/rop_controller.dart';
import '../domain/combined_summary.dart';
import '../domain/workflow_definition.dart';
import '../state/workflow_controller.dart';
import 'workflow_steps.dart';

const _noRecommendations =
    'No recommendations — STW content not yet available.';

/// Combined summary for every condition in the current plan (and only those).
class WorkflowSummaryView extends ConsumerWidget {
  const WorkflowSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(workflowProvider.select((s) => s.plan));
    final baby = ref.watch(babyProvider);
    final text = Theme.of(context).textTheme;
    String summary() => _summaryText(ref, plan, baby.describe());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clinical Assessment Summary',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(baby.describe(), style: text.bodySmall),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Selected Conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in plan.conditions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check,
                          size: 18, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(definitionOf(c).title)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        for (final c in plan.conditions) _ConditionSection(condition: c),
        const AlertBanner(tone: Tone.info, text: combinedSummaryAdvisory),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: summary()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy summary'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(
                  summary(),
                  subject: 'Clinical assessment summary',
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConditionSection extends ConsumerWidget {
  const _ConditionSection({required this.condition});

  final NeonatalCondition condition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = definitionOf(condition);
    final Widget body = _moduleSummaries[condition]?.view ??
        const ResultCard(
          tone: Tone.info,
          title: _noRecommendations,
          actions: [pendingStwMessage],
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                ),
              ),
              StatusChip(
                tone: d.implemented ? Tone.success : Tone.info,
                label: d.status.label,
              ),
            ],
          ),
          const Divider(height: 16),
          body,
        ],
      ),
    );
  }
}

class _RdSummary extends ConsumerWidget {
  const _RdSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rdInitialProvider);
    final o = ref.watch(rdReassessProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdPlanView(result: r),
        if (r.plan != null && o.status != ReassessStatus.incomplete)
          ReassessView(outcome: o),
      ],
    );
  }
}

class _RopSummary extends ConsumerWidget {
  const _RopSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RopStatusView(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              ref.watch(ropSummaryProvider),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF1E293B),
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Summary view and share text for each dedicated module, built from that
/// module's own providers. Conditions not listed have no recommendations.
typedef _ModuleSummary = ({
  Widget view,
  List<String> Function(WidgetRef) lines
});

final Map<NeonatalCondition, _ModuleSummary> _moduleSummaries = {
  NeonatalCondition.respiratoryDistress: (
    view: const _RdSummary(),
    lines: (ref) =>
        _rdLines(ref.read(rdInitialProvider), ref.read(rdReassessProvider)),
  ),
  NeonatalCondition.rop: (
    view: const _RopSummary(),
    lines: (ref) => ref.read(ropSummaryProvider).split('\n'),
  ),
};

// ---------------------------------------------------------------------------
// Plain text for copy/share, built from each module's own outputs.
// ---------------------------------------------------------------------------

String _summaryText(WidgetRef ref, WorkflowPlan plan, String babyLine) {
  return buildCombinedSummary(
    babyLine: babyLine,
    selectedTitles: [for (final c in plan.conditions) definitionOf(c).title],
    sections: [
      for (final c in plan.conditions)
        SummarySection(
          title: definitionOf(c).title,
          lines: _moduleSummaries[c]?.lines(ref) ?? const [_noRecommendations],
        ),
    ],
  );
}

List<String> _rdLines(RdInitialResult r, ReassessOutcome o) {
  final p = r.plan;
  if (p == null) return ['Initial plan pending: ${r.pending}'];
  return [
    'Initial plan: ${initialTitle(r)}',
    for (final a in p.supportActions) '  $a',
    for (final w in p.why) '  Why: $w',
    'Feeding: ${p.feeding.text}',
    if (p.ivFluids) '  IV fluids for: ${p.ivFluidReasons.join(', ')}',
    for (final a in p.avoid) 'Avoid: $a',
    if (o.status != ReassessStatus.incomplete) ...[
      'Reassessment: ${o.title}',
      for (final a in o.actions) '  $a',
      for (final w in o.why) '  Why: $w',
      for (final a in o.alerts) '  Alert: $a',
    ],
  ];
}
