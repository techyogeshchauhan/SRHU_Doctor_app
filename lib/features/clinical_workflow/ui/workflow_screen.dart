import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/responsive.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../state/assessment_controller.dart';
import 'assessment_summary.dart';
import 'question_field.dart';

/// Dynamic clinical assessment: shows the page chosen by the engine from
/// the current context, then the combined summary.
class WorkflowScreen extends ConsumerWidget {
  const WorkflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final n = ref.read(assessmentProvider.notifier);
    final engine = ref.read(assessmentEngineProvider);
    final ctx = s.context;
    final group = s.currentGroup;
    final (done, total) = engine.progress(ctx);
    final canContinue = group != null && engine.canConfirm(ctx, group);

    // Answers live in memory only; after a browser refresh or app restart
    // there is no assessment to resume.
    if (ctx.selected.isEmpty) return const _NoAssessment();

    void goBack() {
      if (!n.back() && context.canPop()) context.pop();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const StwNeoBrand(subtitle: 'Clinical Assessment'),
          actions: [
            const AppRefreshButton(),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Findings so far',
              child: IconButton(
                tooltip: 'Findings so far',
                icon: Badge(
                  isLabelVisible: ctx.findings.isNotEmpty,
                  label: Text('${ctx.findings.length}'),
                  child: const Icon(Icons.fact_check_outlined),
                ),
                onPressed: () => _showFindings(context),
              ),
            ),
            Semantics(
              button: true,
              label: 'New assessment',
              child: IconButton(
                tooltip: 'New assessment',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _confirmNewAssessment(context, ref),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    group == null
                        ? 'Assessment complete · $done of $total questions'
                        : '$done of $total questions answered '
                            '(more may appear)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: total == 0 ? 1 : done / total,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppTheme.primaryNavy,
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              key: PageStorageKey('assessment-${group ?? 'summary'}'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (group == null)
                    const AssessmentSummaryView()
                  else
                    _QuestionPage(group: group),
                  const DisclaimerFooter(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: MaxWidth(
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: goBack,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (group != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canContinue ? n.confirmPage : null,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Continue'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(140, 48),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFindings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final findings =
                ref.watch(assessmentProvider.select((s) => s.context.findings));
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Findings so far',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (findings.isEmpty)
                  const AlertBanner(
                    tone: Tone.info,
                    text: 'No STW pathway triggered yet.',
                  ),
                for (final f in findings) FindingCard(finding: f),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmNewAssessment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new assessment?'),
        content: const Text(
          'This clears the selected topics and every answer for the current '
          'baby.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('New assessment'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(assessmentProvider.notifier).newAssessment();
    if (context.canPop()) context.pop();
  }
}

class _QuestionPage extends ConsumerWidget {
  const _QuestionPage({required this.group});

  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final n = ref.read(assessmentProvider.notifier);
    final engine = ref.read(assessmentEngineProvider);
    final info = engine.groupInfo(ctx.selected, group);
    final questions = engine.pageQuestions(ctx, group);
    final sharedBy = {
      for (final rq in questions)
        if (rq.isShared) ...rq.topics,
    };

    return SectionCard(
      title: info?.title ?? group,
      subtitle: info?.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sharedBy.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AlertBanner(
                tone: Tone.info,
                text: 'Answered once and used by: '
                    '${[
                  for (final c in NeonatalCondition.values)
                    if (sharedBy.contains(c)) definitionOf(c).title,
                ].join(' · ')}',
              ),
            ),
          for (final rq in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: QuestionField(
                key: ValueKey(rq.id),
                question: rq.question,
                options: engine.visibleOptions(rq.question, ctx),
                value: ctx.answers[rq.question.variable],
                isRequired: engine.isRequired(rq, ctx),
                today: ctx.today,
                onChanged: (v) => n.answer(rq.id, v),
              ),
            ),
          if (info?.footnote != null)
            Text(
              info!.footnote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
        ],
      ),
    );
  }
}

class _NoAssessment extends StatelessWidget {
  const _NoAssessment();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Clinical Assessment'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  'No assessment in progress',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Answers are kept in memory only, so they are cleared when '
                  'the page is reloaded or the app is closed.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: AppTheme.mutedText),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/conditions'),
                  icon: const Icon(Icons.checklist_rtl),
                  label: const Text('Select conditions'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
