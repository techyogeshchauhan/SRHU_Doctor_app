import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/layout.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../domain/neonatal_condition.dart';
import '../state/condition_selection_controller.dart';

/// Icon per topic (display only).
const _topicIcons = <NeonatalCondition, IconData>{
  NeonatalCondition.triage: Icons.low_priority_rounded,
  NeonatalCondition.thermalCare: Icons.thermostat_rounded,
  NeonatalCondition.kmc: Icons.favorite_border_rounded,
  NeonatalCondition.fluidsAndFeeds: Icons.water_drop_outlined,
  NeonatalCondition.respiratoryDistress: Icons.air_rounded,
  NeonatalCondition.ancs: Icons.vaccines_outlined,
  NeonatalCondition.sepsis: Icons.coronavirus_outlined,
  NeonatalCondition.hypoglycemia: Icons.bloodtype_outlined,
  NeonatalCondition.jaundice: Icons.wb_sunny_outlined,
  NeonatalCondition.seizures: Icons.bolt_rounded,
  NeonatalCondition.hie: Icons.psychology_outlined,
  NeonatalCondition.transport: Icons.airport_shuttle_outlined,
  NeonatalCondition.rop: Icons.visibility_outlined,
  NeonatalCondition.dischargeAndFollowUp: Icons.event_available_outlined,
};

class ConditionSelectionScreen extends ConsumerWidget {
  const ConditionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(conditionSelectionProvider);
    final n = ref.read(conditionSelectionProvider.notifier);
    final text = Theme.of(context).textTheme;
    final available = [
      for (final d in conditionDefinitions)
        if (d.implemented) d,
    ];
    final pending = [
      for (final d in conditionDefinitions)
        if (!d.implemented) d,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Select Conditions'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text(
                'Select Conditions',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Select one or more conditions/topics to continue.',
                style: text.bodyMedium?.copyWith(color: AppTheme.mutedText),
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'Available now',
                count: available.length,
                tone: Tone.success,
              ),
              const SizedBox(height: 8),
              for (final d in available)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TopicSelectTile(
                    definition: d,
                    selected: selected.contains(d.id),
                    onToggle: () => n.toggle(d.id),
                  ),
                ),
              const SizedBox(height: 10),
              _SectionHeader(
                title: 'Awaiting approved STW',
                count: pending.length,
                tone: Tone.info,
              ),
              const SizedBox(height: 4),
              Text(
                'Selectable. Shows a placeholder until the approved STW is '
                'added — no clinical questions or recommendations.',
                style: text.bodySmall?.copyWith(color: AppTheme.mutedText),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 560 ? 3 : 2;
                  return Column(
                    children: [
                      for (var i = 0; i < pending.length; i += columns)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var j = i; j < i + columns; j++) ...[
                                  if (j > i) const SizedBox(width: 8),
                                  Expanded(
                                    child: j < pending.length
                                        ? TopicSelectTile(
                                            definition: pending[j],
                                            compact: true,
                                            selected: selected
                                                .contains(pending[j].id),
                                            onToggle: () =>
                                                n.toggle(pending[j].id),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
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
                const SizedBox(height: 2),
                FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          ref.read(assessmentProvider.notifier).start(selected);
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.tone,
  });

  final String title;
  final int count;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: tone.background(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone.foreground(),
            ),
          ),
        ),
      ],
    );
  }
}

/// A selectable topic with a checkbox. Full card for available topics,
/// compact tile for topics awaiting their STW.
class TopicSelectTile extends StatelessWidget {
  const TopicSelectTile({
    super.key,
    required this.definition,
    required this.selected,
    required this.onToggle,
    this.compact = false,
  });

  final ConditionDefinition definition;
  final bool selected;
  final VoidCallback onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    final accent = compact ? AppTheme.midBlue : AppTheme.primaryBlue;
    final checkbox = Checkbox(
      value: selected,
      onChanged: (_) => onToggle(),
      visualDensity: compact
          ? const VisualDensity(horizontal: -4, vertical: -4)
          : VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final content = compact
        ? Row(
            children: [
              checkbox,
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppTheme.primaryNavy
                        : const Color(0xFF334155),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _topicIcons[d.id] ?? Icons.medical_information_outlined,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                        height: 1.2,
                      ),
                    ),
                    if (d.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.description!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppTheme.mutedText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              checkbox,
            ],
          );

    return Semantics(
      checked: selected,
      label: '${d.title}, ${d.status.label}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppTheme.tint : Colors.white,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: compact
                ? const EdgeInsets.fromLTRB(6, 10, 8, 10)
                : const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
              border: Border.all(
                color: selected ? accent : AppTheme.dividerColor,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
