import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../domain/triage_workflow.dart';

Tone triageCategoryTone(String category) =>
    category == triageEmergency ? Tone.danger : Tone.warning;

String triageCategoryLabel(String category) =>
    category == triageEmergency ? 'EMERGENCY' : 'PRIORITY';

/// The automatically computed triage category and why; updates with every
/// answer. Hidden while no sign or threshold is recorded.
class TriageCategoryBanner extends StatelessWidget {
  const TriageCategoryBanner({super.key, required this.reader});

  final VariableReader reader;

  @override
  Widget build(BuildContext context) {
    final category = reader.valueOf(triageCategoryKey);
    if (category is! String) return const SizedBox.shrink();
    final tone = triageCategoryTone(category);
    final fg = tone.foreground();
    final reasons = triageReasonsFor(reader);
    final text = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Triage category ${triageCategoryLabel(category)}',
      child: Container(
        key: ValueKey('triage-category-$category'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tone.background(),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tone.icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${triageCategoryLabel(category)} · classified automatically',
                    style: text.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      reasons.join(' · '),
                      style: text.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
