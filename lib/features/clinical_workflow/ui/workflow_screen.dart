import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/layout.dart';
import '../domain/workflow_definition.dart';
import '../state/workflow_controller.dart';
import 'workflow_steps.dart';
import 'workflow_summary.dart';

/// Runs the plan built from the selected conditions: shared baby details →
/// each condition → combined summary.
class WorkflowScreen extends ConsumerWidget {
  const WorkflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(workflowProvider);
    final n = ref.read(workflowProvider.notifier);
    final step = s.currentStep;

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Clinical Workflow'),
        actions: [
          Semantics(
            button: true,
            label: 'Home overview',
            child: IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.push('/home'),
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
        bottom: step == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: _StepBar(
                  titles: [for (final st in s.plan.steps) st.title],
                  current: s.stepIndex,
                  onTap: n.goTo,
                ),
              ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            key: PageStorageKey('workflow-step-${s.stepIndex}'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step == null)
                  const ResultCard(
                    tone: Tone.info,
                    title: 'No conditions selected',
                    actions: ['Go back and select one or more conditions.'],
                  )
                else
                  _stepBody(step),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  // On the first step, Back returns to the selection screen
                  // with the current selection intact.
                  onPressed: () =>
                      s.isFirst || step == null ? context.pop() : n.back(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 48),
                  ),
                ),
                const SizedBox(width: 12),
                if (step != null && !s.isLast)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: n.next,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        'Next: ${s.plan.steps[s.stepIndex + 1].title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(WorkflowStep step) => switch (step) {
        CommonInfoStep(:final fields) => CommonInfoStepView(fields: fields),
        ConditionStep(:final workflow) => switch (workflow) {
            ModuleWorkflow() => ModuleStepView(workflow: workflow),
            QuestionnaireWorkflow() =>
              QuestionnaireStepView(workflow: workflow),
            PendingWorkflow() => PendingStepView(workflow: workflow),
          },
        SummaryStep() => const WorkflowSummaryView(),
      };

  Future<void> _confirmNewAssessment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new assessment?'),
        content: const Text(
          'This clears the selected conditions and everything entered for '
          'the current baby.',
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
    ref.read(workflowProvider.notifier).newAssessment();
    if (context.canPop()) context.pop();
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.titles,
    required this.current,
    required this.onTap,
  });

  final List<String> titles;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final progress = (current + 1) / titles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Step ${current + 1} of ${titles.length}: ${titles[current]}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: const Color(0xFFE2E8F0),
          color: AppTheme.primaryNavy,
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < titles.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${i + 1}. ${titles[i]}'),
                    selected: i == current,
                    onSelected: (_) => onTap(i),
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      color: i == current ? Colors.white : AppTheme.primaryNavy,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
