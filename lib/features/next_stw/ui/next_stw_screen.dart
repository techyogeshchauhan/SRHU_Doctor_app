import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/pdf_navigation.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../condition_selection/ui/condition_selection_screen.dart';
import '../../disease_selection/ui/disease_selection_screen.dart';
import '../../references/ui/stw_reference_screen.dart';

/// Opened with "Next Step" once the Triage results are shown: lists the
/// remaining available STWs. Nothing starts until the user picks one, which
/// then runs its existing workflow.
class NextStwScreen extends ConsumerWidget {
  const NextStwScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final assessed = ref.read(assessmentProvider).context.selected;
    final remaining = [
      for (final d in conditionDefinitions)
        if (d.implemented &&
            d.id != NeonatalCondition.triage &&
            !assessed.contains(d.id) &&
            stwPdfFor(d.id) != null)
          d.id,
    ];

    // Same start as a card on the disease-selection screen.
    void startScreening(NeonatalCondition c) {
      clearConditionData(ref);
      ref.read(assessmentProvider.notifier).start({c}, forceReset: true);
      context.go('/workflow');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.primaryNavy,
          ),
          tooltip: 'Back to results',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/workflow'),
        ),
        title: Image.asset(
          'assets/images/icmr_logo.png',
          semanticLabel: 'ICMR Logo',
          height: 42,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        actions: [
          BackToHomeButton(
            iconOnly: true,
            onPressed: () => confirmLeaveCondition(
              context,
              ref,
              destinationRoute: '/home',
            ),
          ),
          const SizedBox(width: 4),
          const AppRefreshButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select the Next STW',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Triage is complete. Choose the STW to continue with; '
                  'its clinical screening starts when you select it.',
                  style: text.bodyMedium?.copyWith(
                    color: AppTheme.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                for (final (index, c) in remaining.indexed) ...[
                  DiseaseCard(
                    key: ValueKey('next-stw-${c.name}'),
                    number: index + 1,
                    title: stwPdfFor(c)!.title,
                    icon: conditionIcons[c] ?? Icons.medical_services_outlined,
                    accentColor: _accentOf(c),
                    pdfAssetPath: stwPdfFor(c)!.asset,
                    pdfTitle: stwPdfFor(c)!.title,
                    onOpenStwText: c == NeonatalCondition.ancs ||
                            c == NeonatalCondition.hypoglycemia
                        ? () => context.push(StwReferenceScreen.routeFor(c))
                        : null,
                    onStartScreening: () => startScreening(c),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                const DisclaimerFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card accents as on the disease-selection screen.
Color _accentOf(NeonatalCondition c) => switch (c) {
      NeonatalCondition.rop => AppTheme.accentRop,
      NeonatalCondition.respiratoryDistress => AppTheme.accentRd,
      NeonatalCondition.sepsis || NeonatalCondition.kmc => AppTheme.primaryTeal,
      _ => AppTheme.primaryNavy,
    };
