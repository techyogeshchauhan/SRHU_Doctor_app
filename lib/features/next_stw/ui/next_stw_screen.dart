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
/// remaining available STWs. Continue opens a separate list of checked modules.
class NextStwScreen extends ConsumerStatefulWidget {
  const NextStwScreen({super.key, this.selectedModules});

  /// When provided, shows only these modules as individual screening launchers.
  final Set<NeonatalCondition>? selectedModules;

  @override
  ConsumerState<NextStwScreen> createState() => _NextStwScreenState();
}

class _NextStwScreenState extends ConsumerState<NextStwScreen> {
  final _selected = <NeonatalCondition>{};
  final _completed = <NeonatalCondition>{};

  bool get _showSelected => widget.selectedModules != null;

  void _toggle(NeonatalCondition condition) {
    setState(() {
      if (!_selected.add(condition)) _selected.remove(condition);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = [
      for (final d in stwModuleDefinitions)
        if (d.implemented &&
            (!_showSelected || widget.selectedModules!.contains(d.id)) &&
            stwPdfFor(d.id) != null)
          d.id,
    ];

    void showSelected() {
      final selected = _selected.intersection(remaining.toSet());
      if (selected.isEmpty) return;
      context.push('/selected-stws',
          extra: Set<NeonatalCondition>.unmodifiable(selected));
    }

    Future<void> startScreening(NeonatalCondition condition) async {
      clearConditionData(ref);
      ref
          .read(assessmentProvider.notifier)
          .start({condition}, forceReset: true);
      setState(() => _completed.remove(condition));
      await context.push('/workflow', extra: {'returnToSelectedStws': true});
      if (!mounted) return;
      final result = ref.read(assessmentProvider);
      if (result.isComplete &&
          result.context.selected.length == 1 &&
          result.context.selected.contains(condition)) {
        setState(() => _completed.add(condition));
      }
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
          tooltip: _showSelected ? 'Back to STW selection' : 'Back to results',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(_showSelected ? '/next-stw' : '/workflow'),
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
                  _showSelected
                      ? 'Selected STW Diseases'
                      : 'Select the Next STW',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _showSelected
                      ? 'Click a disease to start its screening. Return to this '
                          'list after screening to choose the next disease.'
                      : 'Triage is complete. Select one or more STW modules, '
                          'then click Continue to view your selected diseases.',
                  style: text.bodyMedium?.copyWith(
                    color: AppTheme.mutedText,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                if (_showSelected && remaining.isEmpty)
                  const Text(
                      'No STW diseases selected. Go back to select diseases.'),
                for (final (index, c) in remaining.indexed) ...[
                  DiseaseCard(
                    key: ValueKey(
                        '${_showSelected ? 'selected' : 'next'}-stw-${c.name}'),
                    number: index + 1,
                    title: stwPdfFor(c)!.title,
                    icon: conditionIcons[c] ?? Icons.medical_services_outlined,
                    accentColor: _accentOf(c),
                    highlighted: !_showSelected && _selected.contains(c),
                    trailing: _showSelected
                        ? (_completed.contains(c)
                            ? Icon(
                                Icons.check_circle,
                                key: ValueKey('completed-stw-${c.name}'),
                                color: AppTheme.primaryTeal,
                                semanticLabel: 'Screening completed',
                              )
                            : null)
                        : Checkbox(
                            key: ValueKey('next-stw-checkbox-${c.name}'),
                            value: _selected.contains(c),
                            semanticLabel: 'Select ${stwPdfFor(c)!.title}',
                            onChanged: (_) => _toggle(c),
                          ),
                    pdfAssetPath: stwPdfFor(c)!.asset,
                    pdfTitle: stwPdfFor(c)!.title,
                    onOpenStwText: c == NeonatalCondition.ancs ||
                            c == NeonatalCondition.hypoglycemia
                        ? () => context.push(StwReferenceScreen.routeFor(c))
                        : null,
                    onStartScreening: () {
                      if (_showSelected) {
                        startScreening(c);
                      } else {
                        _toggle(c);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_showSelected)
                  FilledButton.icon(
                    key: const ValueKey('continue-selected-stws'),
                    onPressed: _selected.isEmpty ? null : showSelected,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue'),
                  ),
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
