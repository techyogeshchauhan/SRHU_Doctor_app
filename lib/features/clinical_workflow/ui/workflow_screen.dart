import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils/app_reload.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../shared/pdf_navigation.dart';
import '../../../data/repositories/screening_sync_repository.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../follow_up/data/disease_follow_up_registry.dart';
import '../../follow_up/state/follow_up_controller.dart';
import '../../triage/domain/triage_workflow.dart';
import '../../triage/ui/triage_category_banner.dart';
import '../../triage/ui/triage_entry.dart';
import '../../triage/ui/triage_treatment_dashboard.dart';
import '../state/assessment_controller.dart';
import '../voice/voice_entry_bar.dart';
import '../voice/voice_entry_controller.dart';
import 'assessment_summary.dart';
import 'question_field.dart';
import 'screening_session_panel.dart';

/// Shown above the Triage summary to point to the Next Step button.
const nextStepInstruction =
    "Would you like to explore other STWs? Click 'Next Step' to view and "
    'select the available Standard Treatment Workflows.';

enum _WorkflowMenuAction {
  findings,
  restartTriage,
  newAssessment,
  refresh,
}

/// Dynamic clinical assessment: shows the page chosen by the engine from
/// the current context, then the combined summary.
class WorkflowScreen extends ConsumerWidget {
  const WorkflowScreen({super.key, this.returnToSelectedStws = false});

  final bool returnToSelectedStws;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final n = ref.read(assessmentProvider.notifier);
    final engine = ref.read(assessmentEngineProvider);
    final ctx = s.context;
    final group = s.currentGroup;
    final (done, total) = engine.progress(ctx);
    final canContinue = group != null && engine.canConfirm(ctx, group);
    // Triage results are shown: the next STW is chosen on its own page.
    final triageDone = group == null &&
        ctx.selected.length == 1 &&
        ctx.selected.single == NeonatalCondition.triage;
    final audit = ref.read(auditLogProvider);

    // Answers live in memory only; after a browser refresh or app restart
    // there is no assessment to resume.
    if (ctx.selected.isEmpty) return const _NoAssessment();

    Future<void> returnToList() async {
      if (!s.isComplete && hasConditionProgress(ref)) {
        if (!await confirmProgressReset(context) || !context.mounted) return;
        clearConditionData(ref);
      }
      if (context.mounted) context.pop();
    }

    void goBack() {
      audit.tap('back', {'group': group ?? 'results'});
      if (returnToSelectedStws && s.isComplete) {
        returnToList();
        return;
      }
      if (n.back()) return;
      if (returnToSelectedStws) {
        returnToList();
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        // Opened directly from the landing page (Triage first): no route
        // to pop, so leave to condition selection.
        confirmLeaveCondition(context, ref, destinationRoute: '/home');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 58,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.primaryNavy,
            ),
            tooltip: 'Back',
            onPressed: goBack,
          ),
          title: Image.asset(
            'assets/images/icmr_logo.png',
            semanticLabel: 'ICMR Logo',
            height: 44,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          actions: [
            const SyncStatusIndicator(),
            BackToHomeButton(
              iconOnly: true,
              onPressed: () => confirmLeaveCondition(
                context,
                ref,
                destinationRoute: '/home',
              ),
            ),
            Semantics(
              button: true,
              label: 'Reset Screening',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmResetScreening(context, ref),
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  // Short label on phones, leaving room for the sync icon.
                  label: Text(
                    MediaQuery.sizeOf(context).width < 420
                        ? 'Reset'
                        : 'Reset Screening',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side:
                        const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'More options',
              child: PopupMenuButton<_WorkflowMenuAction>(
                tooltip: 'More options',
                icon: Badge(
                  isLabelVisible: ctx.findings.isNotEmpty,
                  label: Text('${ctx.findings.length}'),
                  child: const Icon(
                    Icons.more_vert_rounded,
                    size: 22,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                onSelected: (action) {
                  audit.tap('menu', {'action': action.name});
                  switch (action) {
                    case _WorkflowMenuAction.findings:
                      _showFindings(context);
                    case _WorkflowMenuAction.restartTriage:
                      confirmRestartTriage(context, ref);
                    case _WorkflowMenuAction.newAssessment:
                      _confirmNewAssessment(context, ref);
                    case _WorkflowMenuAction.refresh:
                      reloadApplication();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _WorkflowMenuAction.findings,
                    child: _MenuRow(
                      icon: Badge(
                        isLabelVisible: ctx.findings.isNotEmpty,
                        label: Text('${ctx.findings.length}'),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          size: 20,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      label: ctx.findings.isNotEmpty
                          ? 'Findings so far (${ctx.findings.length})'
                          : 'Findings so far',
                    ),
                  ),
                  const PopupMenuItem(
                    key: ValueKey('menu-restart-triage'),
                    value: _WorkflowMenuAction.restartTriage,
                    child: _MenuRow(
                      icon: Icon(
                        Icons.low_priority_rounded,
                        size: 20,
                        color: AppTheme.primaryNavy,
                      ),
                      label: 'Restart Triage',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _WorkflowMenuAction.newAssessment,
                    child: _MenuRow(
                      icon: Icon(
                        Icons.restart_alt,
                        size: 20,
                        color: AppTheme.primaryNavy,
                      ),
                      label: 'New assessment',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _WorkflowMenuAction.refresh,
                    child: _MenuRow(
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: AppTheme.primaryNavy,
                      ),
                      label: 'Refresh application',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Clinical Assessment',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group == null
                        ? 'Assessment complete · $done of $total questions'
                        : '$done of $total questions answered '
                            '(more may appear)',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: total == 0 ? 1 : done / total,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: AppTheme.primaryNavy,
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ScreeningSessionPanel(diseaseCodes: {
                    for (final c in ctx.selected) diseaseCodeOf(c),
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: VoiceEntryBar(canStart: group != null),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey('assessment-${group ?? 'summary'}'),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (group == null) ...[
                          if (triageDone) const TriageTreatmentDashboard(),
                          if (triageDone)
                            const Padding(
                              key: ValueKey('next-step-instruction'),
                              padding: EdgeInsets.only(bottom: 12),
                              child: AlertBanner(
                                tone: Tone.info,
                                text: nextStepInstruction,
                              ),
                            ),
                          const AssessmentSummaryView(),
                        ] else
                          _QuestionPage(group: group),
                        DisclaimerFooter(
                          sourceVersion: ctx.selected
                                  .contains(NeonatalCondition.fluidsAndFeeds)
                              ? ctx.selected.length == 1
                                  ? 'Oct 2026'
                                  : 'Aug / Oct 2026'
                              : 'Aug 2026',
                        ),
                      ],
                    ),
                  ),
                ),
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
              child: MaxWidth(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    final backToSelectionBtn = OutlinedButton.icon(
                      key: returnToSelectedStws
                          ? const ValueKey('return-selected-stws')
                          : null,
                      onPressed: () {
                        audit.tap(returnToSelectedStws
                            ? 'return_selected_stws'
                            : 'back_to_selection');
                        if (returnToSelectedStws) {
                          returnToList();
                        } else {
                          confirmLeaveCondition(
                            context,
                            ref,
                            destinationRoute: '/disease-selection',
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 15),
                      label: Text(returnToSelectedStws
                          ? 'Return to selected STWs'
                          : 'Back to Selection'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 12,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );

                    final actionsGroup = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Reset Screening',
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmResetScreening(context, ref),
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 15,
                              color: Color(0xFFDC2626),
                            ),
                            label: Text(
                              compact ? 'Reset' : 'Reset Screening',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: const Color(0xFFFEF2F2),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 12,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: goBack,
                          icon: const Icon(Icons.arrow_back, size: 15),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 12,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 44),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (group != null)
                          FilledButton.icon(
                            onPressed: canContinue ? n.confirmPage : null,
                            icon: const Icon(Icons.arrow_forward, size: 15),
                            label: const Text('Continue'),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 10 : 14,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (triageDone)
                          Semantics(
                            button: true,
                            label: 'Next Step: select the next STW',
                            child: FilledButton.icon(
                              key: const ValueKey('next-step'),
                              onPressed: () {
                                audit.tap('next_step');
                                context.push('/next-stw');
                              },
                              icon: const Icon(Icons.arrow_forward, size: 15),
                              label: const Text('Next Step'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 10 : 14,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else if (hasFollowUpForSelected(ctx.selected))
                          FilledButton.icon(
                            onPressed: () {
                              audit.tap('next_mcqs');
                              final conditionWithMcqs = ctx.selected.firstWhere(
                                hasFollowUpForCondition,
                                orElse: () => ctx.selected.first,
                              );
                              ref
                                  .read(followUpProvider.notifier)
                                  .initForCondition(
                                    conditionWithMcqs,
                                    startImmediately: true,
                                  );
                              context.push('/follow-up-assessment');
                            },
                            icon: const Icon(Icons.arrow_forward, size: 15),
                            label: const Text('Next: MCQs'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 10 : 14,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    );

                    return SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                          backToSelectionBtn,
                          actionsGroup,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFindings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final findings =
                ref.watch(assessmentProvider.select((s) => s.context.findings));
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Findings so far',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (findings.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => context.push('/assessment-map'),
                        icon: const Icon(Icons.account_tree_outlined, size: 18),
                        label: const Text('Map'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (findings.isEmpty)
                  const AlertBanner(
                    tone: Tone.info,
                    text: 'No STW pathway triggered yet.',
                  ),
                for (final f in findings) FindingCard(finding: f),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmResetScreening(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.restart_alt_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Reset Screening',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryNavy,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Choose whether to restart the current screening from the beginning or reset all screening data and return to condition selection.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF334155),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('restart'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryNavy,
            ),
            child: const Text('Restart Screening'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('home'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset & Go to Home'),
          ),
        ],
      ),
    );

    ref.read(auditLogProvider).tap('reset_screening', {
      'choice': action ?? 'cancel',
    });
    if (action == null || !context.mounted) return;

    if (action == 'restart') {
      final selected = ref.read(assessmentProvider).context.selected;
      clearConditionData(ref, clearSelections: false);
      ref.read(assessmentProvider.notifier).start(selected, forceReset: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screening restarted from the beginning.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (action == 'home') {
      resetAllScreeningData(ref);
      if (context.mounted) {
        context.go('/home');
      }
    }
  }

  Future<void> _confirmNewAssessment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new assessment?'),
        content: const Text(
          'This clears the selected topics and every answer for the current '
          'baby.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('New assessment'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    resetAllScreeningData(ref);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}

/// Icon and label of a "More options" item; the label shrinks rather than
/// overflowing the menu on narrow screens or with large text.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      );
}

class _QuestionPage extends ConsumerWidget {
  const _QuestionPage({required this.group});

  final String group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final n = ref.read(assessmentProvider.notifier);
    final engine = ref.read(assessmentEngineProvider);
    final info = engine.groupInfo(ctx.selected, group);
    final questions = engine.pageQuestions(ctx, group);
    final voice = ref.read(voiceEntryProvider.notifier);
    final voiceAvailable =
        ref.watch(voiceEntryProvider.select((s) => s.available)) != false;
    final voiceQuestion =
        ref.watch(voiceEntryProvider.select((s) => s.questionId));
    final sharedBy = {
      for (final rq in questions)
        if (rq.isShared) ...rq.topics,
    };

    return SectionCard(
      title: info?.title ?? group,
      subtitle: info?.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zero-click classification: recomputed after every answer.
          if (group == triageAssessmentGroup) TriageCategoryBanner(reader: ctx),
          if (sharedBy.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AlertBanner(
                tone: Tone.info,
                text: 'Answered once and used by: '
                    '${[
                  for (final c in conditionDisplayOrder)
                    if (sharedBy.contains(c)) definitionOf(c).title,
                ].join(' · ')}',
              ),
            ),
          // PDF references for active conditions (Requirement 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final c in conditionDisplayOrder)
                  if (ctx.selected.contains(c))
                    if (stwPdfFor(c) case final pdf?)
                      Builder(
                        builder: (context) {
                          final regionId = questions
                              .where((rq) => rq.topics.contains(c))
                              .expand((rq) => rq.question.sources)
                              .where((s) =>
                                  s.document == pdf.title ||
                                  stwPdfForDocument(s.document)?.asset ==
                                      pdf.asset)
                              .map((s) => s.pdfRegionId)
                              .firstWhere((id) => id != null,
                                  orElse: () => null);

                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                            onPressed: () {
                              final origin = 'question_page:$group';
                              if (regionId != null) {
                                openStwRegion(
                                  context,
                                  pdf: pdf,
                                  regionId: regionId,
                                  origin: origin,
                                );
                              } else {
                                openStwPdf(
                                  context,
                                  assetPath: pdf.asset,
                                  title: pdf.title,
                                  origin: origin,
                                );
                              }
                            },
                            icon: Icon(Icons.picture_as_pdf_outlined,
                                size: 14, color: _pdfAccent(c)),
                            label: Text(_pdfButtonLabel(c),
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
              ],
            ),
          ),
          for (final rq in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: QuestionField(
                key: ValueKey(rq.id),
                question: rq.question,
                options: engine.visibleOptions(rq.question, ctx),
                value: ctx.answers[rq.question.variable],
                isRequired: engine.isRequired(rq, ctx),
                today: ctx.today,
                onChanged: (v) => n.answer(rq.id, v),
                voiceActive: voiceQuestion == rq.id,
                onVoice: !voiceAvailable
                    ? null
                    : () => voiceQuestion == rq.id
                        ? voice.stop()
                        : voice.listenField(rq.id),
              ),
            ),
          if (info?.footnote != null)
            Text(
              info!.footnote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
        ],
      ),
    );
  }
}

class _NoAssessment extends StatelessWidget {
  const _NoAssessment();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
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
          height: 44,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        actions: const [
          BackToHomeButton(iconOnly: true),
          SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(34),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Clinical Assessment',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  'No assessment in progress',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Answers are kept in memory only, so they are cleared when '
                  'the page is reloaded or the app is closed.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: AppTheme.mutedText),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Home (Condition Selection)'),
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

String _pdfButtonLabel(NeonatalCondition c) => switch (c) {
      NeonatalCondition.respiratoryDistress => 'Respiratory Distress STW PDF',
      NeonatalCondition.rop => 'ROP STW PDF',
      NeonatalCondition.ancs => 'ANCS STW PDF',
      NeonatalCondition.hypoglycemia => 'Hypoglycemia STW PDF',
      NeonatalCondition.triage => 'Triage STW PDF',
      NeonatalCondition.kmc => 'KMC STW PDF',
      NeonatalCondition.sepsis => 'Sepsis STW PDF',
      _ => '${definitionOf(c).title} PDF',
    };

Color _pdfAccent(NeonatalCondition c) => switch (c) {
      NeonatalCondition.respiratoryDistress => AppTheme.accentRd,
      NeonatalCondition.rop => AppTheme.accentRop,
      NeonatalCondition.triage => AppTheme.accentRd,
      NeonatalCondition.kmc => AppTheme.primaryTeal,
      NeonatalCondition.ancs => const Color(0xFF0F766E),
      NeonatalCondition.hypoglycemia => const Color(0xFFB45309),
      _ => AppTheme.primaryNavy,
    };
