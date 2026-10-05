import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/layout.dart';
import '../../clinical_workflow/state/workflow_controller.dart';
import '../domain/neonatal_condition.dart';
import '../state/condition_selection_controller.dart';

class ConditionSelectionScreen extends ConsumerWidget {
  const ConditionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(conditionSelectionProvider);
    final n = ref.read(conditionSelectionProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Select Conditions'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Select Conditions',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select one or more conditions/topics to continue.',
                style: text.bodyMedium?.copyWith(color: AppTheme.mutedText),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 4),
              Card(
                child: Column(
                  children: [
                    for (final d in conditionDefinitions)
                      _ConditionTile(
                        definition: d,
                        selected: selected.contains(d.id),
                        onChanged: (_) => n.toggle(d.id),
                      ),
                  ],
                ),
              ),
              const DisclaimerFooter(),
            ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kept in the fixed bar so the count stays visible while
                // scrolling the list.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selected: ${selected.length}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: selected.isEmpty ? null : n.clear,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          ref.read(workflowProvider.notifier).start(selected);
                          context.push('/workflow');
                        },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Continue'),
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

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.definition,
    required this.selected,
    required this.onChanged,
  });

  final ConditionDefinition definition;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: onChanged,
      title: Text(d.title),
      subtitle: d.description == null ? null : Text(d.description!),
      secondary: StatusChip(
        tone: d.implemented ? Tone.success : Tone.info,
        label: d.status.label,
      ),
    );
  }
}
