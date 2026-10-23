import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../shared/pdf_navigation.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../../condition_selection/domain/neonatal_condition.dart';

/// Starts a new Triage from its first page. Triage is the first step before
/// the STW modules: the landing page, the module list and the workflow menu
/// all open it here, so it starts the same way from everywhere.
///
/// Uses `go`, so Triage is the only route: Back on its first page asks to
/// leave to the module list, as when it is opened from the landing page.
void startTriage(BuildContext context, WidgetRef ref) {
  ref.read(auditLogProvider).log('module_entered', {'disease': 'triage'});
  clearConditionData(ref, clearSelections: true);
  ref
      .read(assessmentProvider.notifier)
      .start({NeonatalCondition.triage}, forceReset: true);
  context.go('/workflow');
}

/// [startTriage] after the "Progress will be reset" confirmation, shown only
/// when there are answers to lose.
Future<void> confirmRestartTriage(BuildContext context, WidgetRef ref) async {
  if (hasConditionProgress(ref) && !await confirmProgressReset(context)) {
    return;
  }
  if (context.mounted) startTriage(context, ref);
}

/// Shown above the STW module list: Triage is not one of the modules, so
/// this is where a new Triage is started once the user is past the landing
/// page.
class TriageEntryCard extends ConsumerWidget {
  const TriageEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdf = stwPdfFor(NeonatalCondition.triage);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentRd.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentRd.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.low_priority_rounded,
              size: 18,
              color: AppTheme.accentRd,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.circle,
                        key: ValueKey('stw-availability-triage'),
                        size: 8,
                        color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Neonatal Emergency Triage',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'First step for a new neonate. Classifies Emergency, '
                  'Priority or Non-urgent automatically and opens the '
                  'treatment steps; the STW modules follow its results.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppTheme.mutedText,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('start-triage'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => confirmRestartTriage(context, ref),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text(
                        'Start Triage',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (pdf != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => openStwPdf(
                          context,
                          assetPath: pdf.asset,
                          title: pdf.title,
                        ),
                        icon: const Icon(Icons.description_outlined, size: 13),
                        label: const Text(
                          'Reference',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
