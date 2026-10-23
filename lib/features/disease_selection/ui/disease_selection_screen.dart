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
import '../../clinical_workflow/ui/screening_session_panel.dart';
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
    bool show(NeonatalCondition c) =>
        selected.contains(c) || initialCondition == c || selected.isEmpty;

    void startScreening(NeonatalCondition c) {
      clearConditionData(ref);
      ref.read(assessmentProvider.notifier).start({c}, forceReset: true);
      context.push('/workflow');
    }

    // Existing card presentation, displayed in the shared module order.
    const cards = {
      NeonatalCondition.hie: (
        'Post Asphyxia',
        Icons.monitor_heart_outlined,
        AppTheme.primaryTeal
      ),
      NeonatalCondition.fluidsAndFeeds: (
        'Feeding and Nutrition in Neonates',
        Icons.water_drop_outlined,
        AppTheme.primaryTeal
      ),
      NeonatalCondition.rop: (
        'Retinopathy of Prematurity',
        Icons.visibility_outlined,
        AppTheme.accentRop
      ),
      NeonatalCondition.respiratoryDistress: (
        'Respiratory Distress in Neonates',
        Icons.air_rounded,
        AppTheme.accentRd
      ),
      NeonatalCondition.sepsis: (
        'Sepsis in Neonates',
        Icons.coronavirus_outlined,
        AppTheme.primaryTeal
      ),
      NeonatalCondition.kmc: (
        'Kangaroo Mother Care (KMC)',
        Icons.favorite_border_rounded,
        AppTheme.primaryTeal
      ),
      NeonatalCondition.ancs: (
        'Antenatal Corticosteroids for Preterm Birth',
        Icons.vaccines_outlined,
        AppTheme.primaryNavy
      ),
      NeonatalCondition.hypoglycemia: (
        'Neonatal Hypoglycemia',
        Icons.bloodtype_outlined,
        AppTheme.primaryNavy
      ),
    };

    // Number only visible cards, starting again at one after filtering.
    var displayedIndex = 0;

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
                const AvailableDiseaseCount(showListed: true),
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

                for (final d in stwModuleDefinitions)
                  if (cards[d.id] case final card?)
                    if (show(d.id)) ...[
                      DiseaseCard(
                        number: ++displayedIndex,
                        title: card.$1,
                        icon: card.$2,
                        accentColor: card.$3,
                        highlighted: initialCondition == d.id,
                        pdfAssetPath: stwPdfFor(d.id)!.asset,
                        pdfTitle: stwPdfFor(d.id)!.title,
                        onOpenStwText: d.id == NeonatalCondition.ancs ||
                                d.id == NeonatalCondition.hypoglycemia
                            ? () =>
                                context.push(StwReferenceScreen.routeFor(d.id))
                            : null,
                        onStartScreening: () => startScreening(d.id),
                      ),
                      const SizedBox(height: 12),
                    ],

                const SizedBox(height: 16),
                const DisclaimerFooter(),
                const ScreeningHistoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact disease card with the full condition name and direct screening launcher.
class DiseaseCard extends StatelessWidget {
  const DiseaseCard({
    super.key,
    required this.number,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.pdfAssetPath,
    required this.pdfTitle,
    required this.onStartScreening,
    this.highlighted = false,
    this.onOpenStwText,
    this.trailing,
  });

  final String title;
  final int number;
  final IconData icon;
  final Color accentColor;
  final String pdfAssetPath;
  final String pdfTitle;
  final VoidCallback onStartScreening;
  final bool highlighted;

  /// Optional control in place of the navigation arrow.
  final Widget? trailing;

  /// Opens the verbatim STW text (DOs/DON'Ts, KPIs, ...); hidden when null.
  final VoidCallback? onOpenStwText;

  @override
  Widget build(BuildContext context) {
    // Narrow phones: tighter spacing leaves more room for the name.
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onStartScreening,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: narrow ? 12 : 16, vertical: narrow ? 12 : 14),
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
              SizedBox(width: narrow ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 5),
                          child: Icon(Icons.circle,
                              size: 8, color: Color(0xFF16A34A)),
                        ),
                        Text('$number.',
                            key: ValueKey('disease-card-index-$number'),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryNavy,
                            height: 1.25,
                          ),
                        )),
                      ],
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
              SizedBox(width: narrow ? 8 : 12),
              trailing ??
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
