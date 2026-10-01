import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../domain/sas.dart';

Tone severityTone(RdSeverity? s) => switch (s) {
      null => Tone.info,
      RdSeverity.mild => Tone.success,
      RdSeverity.moderateSevere => Tone.warning,
    };

/// Five radio groups (grade 0/1/2 per item) with the SAS drawings, plus a
/// prominent live score and severity badge.
class SasCalculator extends StatelessWidget {
  const SasCalculator({
    super.key,
    required this.score,
    required this.onGrade,
    this.onClear,
    this.previousTotal,
  });

  final SasScore score;
  final void Function(SasItem item, int grade) onGrade;
  final VoidCallback? onClear;

  /// Shows the trend when given.
  final int? previousTotal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final severity = score.severity;
    final trend = previousTotal == null || !score.isComplete
        ? null
        : score.total < previousTotal!
            ? '↓ from $previousTotal'
            : score.total > previousTotal!
                ? '↑ from $previousTotal'
                : '= $previousTotal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prominent Score Card / Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Big Score Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${score.total}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                          const TextSpan(
                            text: ' / 10',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Severity & Trend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusChip(
                          tone: severityTone(severity),
                          label: severity == null
                              ? '${score.gradedCount}/5 graded'
                              : '${severity.label} RD',
                        ),
                        if (trend != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            trend,
                            style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions: Chart and Clear
                  Semantics(
                    button: true,
                    label: 'Show Silverman-Andersen score chart',
                    child: IconButton(
                      tooltip: 'Show SAS chart',
                      icon: const Icon(Icons.image_outlined, color: AppTheme.primaryTeal),
                      onPressed: () => showSasChart(context),
                    ),
                  ),
                  if (onClear != null)
                    Semantics(
                      button: true,
                      label: 'Clear Silverman-Andersen score',
                      child: IconButton(
                        tooltip: 'Clear SAS',
                        icon: const Icon(Icons.clear_all, color: Color(0xFF64748B)),
                        onPressed: score.gradedCount == 0 ? null : onClear,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Mild ≤3 · Moderate–severe ≥4',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Item Radio Groups
        for (final item in SasItem.values) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                if (score.gradeOf(item) != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Grade ${score.gradeOf(item)}',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          RadioChoiceGroup<int>(
            value: score.gradeOf(item),
            onChanged: (g) => onGrade(item, g),
            options: [
              for (var g = 0; g < 3; g++)
                ChoiceOption(
                  g,
                  '$g · ${item.gradeLabels[g]}',
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      item.imageAsset(g),
                      width: 64,
                      height: 56,
                      fit: BoxFit.cover,
                      semanticLabel: '${item.title} grade $g drawing',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

void showSasChart(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Silverman-Andersen Score Chart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close chart',
                  child: IconButton(
                    tooltip: 'Close chart',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.asset('assets/images/sas_chart.png'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'The Silverman score for assessing the magnitude of respiratory '
              'distress. (From Avery, M.E., and Fletcher, B.D.: The Lung and '
              'Its Disorders in the Newborn. Philadelphia, W.B. Saunders '
              'Company, 1974) (Courtesy of W.A. Silverman).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}
