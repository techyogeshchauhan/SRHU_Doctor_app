import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/responsive.dart';
import '../../../shared/pdf_navigation.dart';
import '../domain/neonatal_condition.dart';
import '../state/condition_selection_controller.dart';

/// Topic icons mapping for all 14 conditions.
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

/// The main condition-selection screen displayed after the landing page.
///
/// Features:
/// - Main Heading: “Triaging — Based on history and clinical examination.”
///   Subtitle: "Select any condition."
/// - Single unified view displaying all 14 conditions in the exact same format.
/// - Checkboxes for conditions:
///   - 4 available conditions (Respiratory Distress, ANCS, Hypoglycemia, ROP)
///     have active checkboxes
///     and can be selected.
///   - 10 inactive conditions look normal as well, but their checkboxes are disabled
///     and they are not selectable.
/// - Live selection counter showing how many conditions have been selected.
/// - Continue button to proceed to the next page (/disease-selection) with the selected conditions.
/// - Direct PDF reference button for the active conditions.
class ConditionSelectionScreen extends ConsumerWidget {
  const ConditionSelectionScreen({super.key});

  void _showDisclaimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'STW Advisory Disclaimer',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    stwDisclaimer,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.bodyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(conditionSelectionProvider);
    final selectionNotifier = ref.read(conditionSelectionProvider.notifier);

    // Active topics first (ROP, RD, then the rest in list order), then the
    // topics awaiting their STW in list order.
    const pinned = [NeonatalCondition.rop, NeonatalCondition.respiratoryDistress];
    final orderedConditions = [
      for (final c in pinned) definitionOf(c),
      for (final d in conditionDefinitions)
        if (d.implemented && !pinned.contains(d.id)) d,
      for (final d in conditionDefinitions)
        if (!d.implemented) d,
    ];

    void onProceedToNextPage() {
      if (selected.isEmpty) return;
      context.push('/disease-selection');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        title: Image.asset(
          'assets/images/icmr_logo.png',
          semanticLabel: 'ICMR Logo',
          height: 42,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined,
                color: AppTheme.primaryNavy),
            tooltip: 'STW Map',
            onPressed: () => context.push('/stw-map'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryNavy),
            tooltip: 'STW Clinical Assistant',
            onPressed: () => context.push('/chat'),
          ),
          const AppRefreshButton(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
              ),
            ),
            child: const Text(
              'Based on ICMR / DHR Standard Treatment Workflows',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Main Heading as specified by the user
                const Text(
                  'Triaging',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Based on History and Clinical Examination.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select any condition.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Single view of all 14 conditions with active ones at top (ROP, then RD)
                for (final d in orderedConditions) ...[
                  _ConditionTile(
                    definition: d,
                    isSelected: selected.contains(d.id),
                    onToggle: d.implemented
                        ? () => selectionNotifier.toggle(d.id)
                        : null,
                    onViewPdf: switch (stwPdfFor(d.id)) {
                      final pdf? when d.implemented => () => openStwPdf(
                            context,
                            assetPath: pdf.asset,
                            title: pdf.title,
                          ),
                      _ => null,
                    },
                  ),
                  const SizedBox(height: 6),
                ],

                const SizedBox(height: 16),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: MaxWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    button: true,
                    label: selected.isNotEmpty
                        ? 'Continue with ${selected.length} conditions selected'
                        : 'Continue',
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: selected.isNotEmpty ? onProceedToNextPage : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (selected.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${selected.length}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Read STW disclaimer',
                        child: InkWell(
                          onTap: () => _showDisclaimerSheet(context),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'Disclaimer',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                      Semantics(
                        button: true,
                        label: 'Open STW references and original PDFs',
                        child: InkWell(
                          onTap: () => context.push('/references'),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'References',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single uniform condition tile for all 14 conditions.
///
/// Available conditions are selectable with active checkboxes and PDF reference.
/// Inactive conditions look normal as well, but their checkboxes are disabled
/// and they cannot be selected.
class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.definition,
    required this.isSelected,
    required this.onToggle,
    this.onViewPdf,
  });

  final ConditionDefinition definition;
  final bool isSelected;
  final VoidCallback? onToggle;
  final VoidCallback? onViewPdf;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    final isAvailable = d.implemented;
    final icon = _topicIcons[d.id] ?? Icons.medical_services_outlined;

    final content = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isAvailable ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.tint : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                    : const Color(0x06000000),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Checkbox for the condition
              Semantics(
                label:
                    '${d.title} ${isAvailable ? (isSelected ? "selected" : "not selected") : "not selectable"}',
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: isAvailable && onToggle != null
                        ? (_) => onToggle!()
                        : null,
                    activeColor: AppTheme.primaryBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Condition Icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppTheme.tint
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isAvailable
                      ? AppTheme.primaryBlue
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),

              // 3. Condition Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isAvailable
                                  ? AppTheme.primaryNavy
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isAvailable ? 'Available' : 'Awaiting STW',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isAvailable
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (d.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppTheme.mutedText,
                          height: 1.2,
                        ),
                      ),
                    ],
                    // Compact Reference button placed near the bottom of card content
                    if (isAvailable && onViewPdf != null) ...[
                      const SizedBox(height: 4),
                      Semantics(
                        button: true,
                        label: 'View source PDF reference for ${d.title}',
                        child: InkWell(
                          onTap: onViewPdf,
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 11.5,
                                  color: AppTheme.primaryBlue,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Reference',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isAvailable) {
      return Opacity(
        opacity: 0.55,
        child: content,
      );
    }
    return content;
  }
}
