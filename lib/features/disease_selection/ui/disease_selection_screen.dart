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
import '../../condition_selection/state/condition_selection_controller.dart';
import '../../references/ui/stw_reference_screen.dart';

/// Screen displayed after the user selects an active condition on the
/// main 14-condition screen.
///
/// Features:
/// - "Back to Home" button taking the user back to the 14 conditions list
/// - List of all available/selectable diseases/conditions with approved STWs
/// - Clickable disease cards to launch each disease's screening process
/// - Direct PDF reference buttons for the active conditions
class DiseaseSelectionScreen extends ConsumerWidget {
  const DiseaseSelectionScreen({
    super.key,
    this.initialCondition,
  });

  /// The active condition that was tapped on the previous screen, if any.
  final NeonatalCondition? initialCondition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final selected = ref.watch(conditionSelectionProvider);
    final showRop = selected.contains(NeonatalCondition.rop) ||
        initialCondition == NeonatalCondition.rop ||
        selected.isEmpty;
    final showRd = selected.contains(NeonatalCondition.respiratoryDistress) ||
        initialCondition == NeonatalCondition.respiratoryDistress ||
        selected.isEmpty;
    bool show(NeonatalCondition c) =>
        selected.contains(c) || initialCondition == c || selected.isEmpty;

    void startScreening(NeonatalCondition c) {
      clearConditionData(ref);
      ref.read(assessmentProvider.notifier).start({c}, forceReset: true);
      context.push('/workflow');
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
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Image.asset(
          'assets/images/icmr_logo.png',
          semanticLabel: 'ICMR Logo',
          height: 42,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        actions: const [
          BackToHomeButton(iconOnly: true),
          SizedBox(width: 4),
          AppRefreshButton(),
          SizedBox(width: 8),
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
                // Screen header
                Text(
                  'Available Clinical Workflows',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected.isNotEmpty
                      ? '${selected.length} condition${selected.length > 1 ? "s" : ""} selected. Click any condition below to begin its clinical screening process.'
                      : 'Select any condition below to begin its clinical screening process per ICMR / DHR guidelines.',
                  style: text.bodyMedium?.copyWith(
                    color: AppTheme.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Retinopathy of Prematurity (ROP) Card (if selected or default)
                if (showRop) ...[
                  _DiseaseCard(
                    title: 'Retinopathy of Prematurity',
                    icon: Icons.visibility_outlined,
                    accentColor: AppTheme.accentRop,
                    highlighted: initialCondition == NeonatalCondition.rop,
                    pdfAssetPath: ropPdfAsset,
                    pdfTitle: ropPdfTitle,
                    onStartScreening: () {
                      clearConditionData(ref);
                      ref.read(assessmentProvider.notifier).start({
                        NeonatalCondition.rop,
                      }, forceReset: true);
                      context.push('/workflow');
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 2. Respiratory Distress in Neonates Card (if selected or default)
                if (showRd) ...[
                  _DiseaseCard(
                    title: 'Respiratory Distress in Neonates',
                    icon: Icons.air_rounded,
                    accentColor: AppTheme.accentRd,
                    highlighted: initialCondition ==
                        NeonatalCondition.respiratoryDistress,
                    pdfAssetPath: rdPdfAsset,
                    pdfTitle: rdPdfTitle,
                    onStartScreening: () {
                      clearConditionData(ref);
                      ref.read(assessmentProvider.notifier).start({
                        NeonatalCondition.respiratoryDistress,
                      }, forceReset: true);
                      context.push('/workflow');
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 3. ANCS and Neonatal Hypoglycemia cards (if selected or default)
                for (final (c, title) in const [
                  (
                    NeonatalCondition.ancs,
                    'Antenatal Corticosteroids for Preterm Birth',
                  ),
                  (NeonatalCondition.hypoglycemia, 'Neonatal Hypoglycemia'),
                ])
                  if (show(c)) ...[
                    _DiseaseCard(
                      title: title,
                      icon: c == NeonatalCondition.ancs
                          ? Icons.vaccines_outlined
                          : Icons.bloodtype_outlined,
                      accentColor: AppTheme.primaryNavy,
                      highlighted: initialCondition == c,
                      pdfAssetPath: stwPdfFor(c)!.asset,
                      pdfTitle: stwPdfFor(c)!.title,
                      onOpenStwText: () =>
                          context.push(StwReferenceScreen.routeFor(c)),
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

/// Compact disease card with single-line condition name and direct screening launcher.
class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.pdfAssetPath,
    required this.pdfTitle,
    required this.onStartScreening,
    this.highlighted = false,
    this.onOpenStwText,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final String pdfAssetPath;
  final String pdfTitle;
  final VoidCallback onStartScreening;
  final bool highlighted;

  /// Opens the verbatim STW text (DOs/DON'Ts, KPIs, ...); hidden when null.
  final VoidCallback? onOpenStwText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onStartScreening,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  highlighted ? AppTheme.primaryBlue : const Color(0xFFD4E3F8),
              width: highlighted ? 1.8 : 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x081F5FBF),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Open reference PDF for $title',
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryBlue,
                              backgroundColor: const Color(0xFFF8FAFC),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => openStwPdf(
                              context,
                              assetPath: pdfAssetPath,
                              title: pdfTitle,
                            ),
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 13,
                              color: AppTheme.primaryBlue,
                            ),
                            label: const Text(
                              'Reference',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (onOpenStwText != null)
                          Semantics(
                            button: true,
                            label: 'Open STW text for $title',
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: onOpenStwText,
                              icon: const Icon(
                                Icons.checklist_rtl_outlined,
                                size: 13,
                                color: AppTheme.primaryBlue,
                              ),
                              label: const Text(
                                "DOs/DON'Ts & KPIs",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
