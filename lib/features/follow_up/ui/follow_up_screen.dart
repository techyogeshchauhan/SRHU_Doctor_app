import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../data/disease_follow_up_registry.dart';
import '../domain/follow_up_models.dart';
import '../state/follow_up_controller.dart';

/// Main screen for the Follow-up Assessment workflow.
///
/// Flow:
/// Intro -> MCQs -> MCQ Result -> Case Scenarios -> Final Summary
class FollowUpScreen extends ConsumerWidget {
  const FollowUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Follow-up Assessment'),
        actions: [
          BackToHomeButton(
            iconOnly: true,
            onPressed: () => confirmLeaveCondition(
              context,
              ref,
              destinationRoute: '/home',
            ),
          ),
          const AppRefreshButton(),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Reset follow-up assessment',
            child: IconButton(
              tooltip: 'Reset assessment',
              icon: const Icon(Icons.restart_alt),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Follow-up Assessment?'),
                    content: const Text(
                      'All progress, recorded MCQ answers, and case scenario choices will be reset.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          controller.reset();
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: state.mcqs.isEmpty
              ? const SizedBox.shrink()
              : _StageProgressBar(stage: state.stage),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            key: PageStorageKey('follow-up-${state.stage.name}'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.mcqs.isEmpty)
                  _EmptyFollowUpSection(condition: state.condition)
                else
                  switch (state.stage) {
                    FollowUpStage.intro => const _IntroSection(),
                    FollowUpStage.mcqs => const _McqSection(),
                    FollowUpStage.mcqResult => const _McqResultSection(),
                    FollowUpStage.caseScenarios => const _CaseScenarioSection(),
                    FollowUpStage.finalSummary => const _FinalSummarySection(),
                  },
                const SizedBox(height: 24),
                const DisclaimerFooter(),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => confirmLeaveCondition(
                    context,
                    ref,
                    destinationRoute: '/disease-selection',
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back to Selection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header Stage Progress Bar
// ---------------------------------------------------------------------------

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({required this.stage});

  final FollowUpStage stage;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Overview', FollowUpStage.intro),
      ('MCQs', FollowUpStage.mcqs),
      ('MCQ Result', FollowUpStage.mcqResult),
      ('Cases', FollowUpStage.caseScenarios),
      ('Summary', FollowUpStage.finalSummary),
    ];

    final currentIndex = stages.indexWhere((s) => s.$2 == stage);
    final progress = (currentIndex + 1) / stages.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stage ${currentIndex + 1} of ${stages.length}: ${stages[currentIndex].$1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryNavy),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFollowUpSection extends ConsumerWidget {
  const _EmptyFollowUpSection({required this.condition});

  final NeonatalCondition condition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppTheme.primaryNavy,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Follow-up Assessment: ${definitionOf(condition).title}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Follow-up MCQs and bedside clinical case scenarios for ${definitionOf(condition).title} are currently under preparation as per ICMR / DHR STW guidelines.\n\nCurrently, follow-up MCQs are available for ${diseaseFollowUpRegistry.values.map((p) => p.title).join(', ')}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Inter',
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => confirmLeaveCondition(
              context,
              ref,
              destinationRoute: '/disease-selection',
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back to Disease Selection'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// STAGE 1: INTRO SECTION
// ===========================================================================

class _IntroSection extends ConsumerWidget {
  const _IntroSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B2545), Color(0xFF133E68)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0B2545),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ICMR / DHR STANDARD TREATMENT WORKFLOWS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Follow-up Assessment: ${state.conditionTitle}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.package?.introDescription ?? '',
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Assessment Structure Info Cards
        const Text(
          'Assessment Workflow',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 10),

        _InfoTile(
          icon: Icons.quiz_outlined,
          color: const Color(0xFF2563EB),
          title:
              'Part 1: ${state.shortName} MCQs (${state.mcqs.length} Questions)',
          subtitle: state.package?.mcqTopics ?? '',
        ),
        const SizedBox(height: 10),
        _InfoTile(
          icon: Icons.analytics_outlined,
          color: const Color(0xFF059669),
          title: 'Part 2: MCQ Results & Explanations',
          subtitle:
              'Comprehensive score breakdown with detailed clinical rationales directly from the ICMR/DHR ${state.shortName} STW guidelines.',
        ),
        const SizedBox(height: 10),
        _InfoTile(
          icon: Icons.medical_services_outlined,
          color: const Color(0xFFD97706),
          title:
              'Part 3: Clinical Case Scenarios (${state.caseScenarios.length} Cases)',
          subtitle: state.package?.caseTopics ?? '',
        ),
        const SizedBox(height: 24),

        // Action Button
        FilledButton.icon(
          onPressed: controller.startAssessment,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: Text(
              'Start ${state.shortName} MCQs (${state.mcqs.length} Questions)'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => confirmLeaveCondition(
            context,
            ref,
            destinationRoute: '/disease-selection',
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to Disease Selection'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// STAGE 2: ROP MCQ SECTION
// ===========================================================================

class _McqSection extends ConsumerStatefulWidget {
  const _McqSection();

  @override
  ConsumerState<_McqSection> createState() => _McqSectionState();
}

class _McqSectionState extends ConsumerState<_McqSection> {
  bool _highlightUnanswered = false;

  void _onAttemptIncompleteSubmit() {
    setState(() => _highlightUnanswered = true);
    final state = ref.read(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please answer all questions before submitting'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

    final firstMissing = state.firstUnansweredMcqIndex;
    if (firstMissing != null) {
      controller.goToMcq(firstMissing);
    }
  }

  void _onAttemptIncompleteNext() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Please select an option before moving to the next question'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    final currentQuestion = state.currentMcq;
    final currentIndex = state.currentMcqIndex;
    final total = state.mcqs.length;
    final selectedOption = state.selectedMcqOption;
    final allAnswered = state.allMcqsAnswered;

    // Reset highlight automatically once all questions are answered
    if (allAnswered && _highlightUnanswered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _highlightUnanswered = false);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation Header / Question Tracker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'MCQ ${currentIndex + 1} OF $total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryNavy,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentQuestion.category,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_highlightUnanswered && selectedOption == null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please select an answer for this question before submitting.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Question Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_highlightUnanswered && selectedOption == null)
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFCBD5E1),
              width: (_highlightUnanswered && selectedOption == null) ? 1.6 : 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${currentIndex + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentQuestion.question,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  fontFamily: 'Poppins',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4 Options
        const Text(
          'Select One Option:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),

        for (int i = 0; i < currentQuestion.options.length; i++) ...[
          _OptionSelectCard(
            letter: String.fromCharCode(65 + i),
            text: currentQuestion.options[i],
            isSelected: selectedOption == i,
            onTap: () => controller.selectMcqOption(i),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 20),

        // Navigation Controls
        _QuestionNavigationButtons(
          currentIndex: currentIndex,
          total: total,
          hasSelectedAnswer: selectedOption != null,
          answeredCount: state.mcqAnsweredCount,
          allAnswered: allAnswered,
          onPrevious: currentIndex > 0 ? controller.previousMcq : null,
          onNext: currentIndex < total - 1 ? controller.nextMcq : null,
          onSubmit: allAnswered ? controller.submitMcqs : null,
          onAttemptIncompleteSubmit: _onAttemptIncompleteSubmit,
          onAttemptIncompleteNext: _onAttemptIncompleteNext,
          submitLabel: 'Submit Assessment',
        ),

        const SizedBox(height: 16),

        // Direct Question Jump Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(total, (i) {
            final isCurrent = i == currentIndex;
            final isAnswered = state.mcqAnswers.containsKey(state.mcqs[i].id);
            final isMissing = _highlightUnanswered && !isAnswered;

            return InkWell(
              onTap: () => controller.goToMcq(i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primaryNavy
                      : isMissing
                          ? const Color(0xFFFEE2E2)
                          : isAnswered
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? AppTheme.primaryNavy
                        : isMissing
                            ? const Color(0xFFDC2626)
                            : isAnswered
                                ? const Color(0xFF818CF8)
                                : const Color(0xFFCBD5E1),
                    width: isMissing ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent
                        ? Colors.white
                        : isMissing
                            ? const Color(0xFFB91C1C)
                            : isAnswered
                                ? const Color(0xFF3730A3)
                                : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _LegendItem(
              color: Color(0xFFE0E7FF),
              borderColor: Color(0xFF818CF8),
              label: 'Answered',
            ),
            const SizedBox(width: 14),
            _LegendItem(
              color: _highlightUnanswered
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFF1F5F9),
              borderColor: _highlightUnanswered
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFCBD5E1),
              label: 'Unanswered',
            ),
            const SizedBox(width: 14),
            const _LegendItem(
              color: AppTheme.primaryNavy,
              borderColor: AppTheme.primaryNavy,
              label: 'Current',
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// STAGE 3: MCQ RESULT & FEEDBACK
// ===========================================================================

class _McqResultSection extends ConsumerWidget {
  const _McqResultSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    final correct = state.mcqCorrectCount;
    final total = state.mcqs.length;
    final incorrect = state.mcqIncorrectCount;
    final percentage = state.mcqPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score Summary Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                percentage >= 75
                    ? 'Excellent Knowledge!'
                    : percentage >= 50
                        ? 'Good Understanding'
                        : 'Review Recommended',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: percentage >= 75
                      ? const Color(0xFF15803D)
                      : percentage >= 50
                          ? const Color(0xFFD97706)
                          : const Color(0xFFDC2626),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${state.shortName} Standard Treatment Workflow MCQ Results',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // Circle Score
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppTheme.primaryNavy,
                    width: 4,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$correct / $total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      '${percentage.round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _ResultStatCard(
                      label: 'Correct',
                      value: '$correct',
                      color: const Color(0xFF16A34A),
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStatCard(
                      label: 'Incorrect',
                      value: '$incorrect',
                      color: const Color(0xFFDC2626),
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStatCard(
                      label: 'Total',
                      value: '$total',
                      color: AppTheme.primaryNavy,
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action to Proceed to Case Scenarios
        FilledButton.icon(
          onPressed: controller.proceedToCaseScenarios,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: Text(
              'Proceed to Case Scenarios (${state.caseScenarios.length} Cases)'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.retakeMcqs,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Retake MCQs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Detailed Answers Review
        Row(
          children: [
            const Icon(Icons.rate_review_outlined,
                size: 18, color: AppTheme.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detailed Answers & Clinical Rationales',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                      fontFamily: 'Poppins',
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        for (int i = 0; i < state.mcqs.length; i++) ...[
          _QuestionFeedbackCard(
            questionNumber: i + 1,
            question: state.mcqs[i],
            userAnswerIndex: state.mcqAnswers[state.mcqs[i].id],
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: controller.proceedToCaseScenarios,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          label: Text(
              'Proceed to Case Scenarios (${state.caseScenarios.length} Cases)'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// STAGE 4: CASE SCENARIO SECTION
// ===========================================================================

class _CaseScenarioSection extends ConsumerStatefulWidget {
  const _CaseScenarioSection();

  @override
  ConsumerState<_CaseScenarioSection> createState() =>
      _CaseScenarioSectionState();
}

class _CaseScenarioSectionState extends ConsumerState<_CaseScenarioSection> {
  bool _highlightUnanswered = false;

  void _onAttemptIncompleteSubmit() {
    setState(() => _highlightUnanswered = true);
    final state = ref.read(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Please answer all case scenario questions before submitting'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

    final firstMissing = state.firstUnansweredCaseIndex;
    if (firstMissing != null) {
      controller.goToCase(firstMissing);
    }
  }

  void _onAttemptIncompleteNext() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Please select a clinical response before moving to the next case'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    final currentCase = state.currentCase;
    final currentIndex = state.currentCaseIndex;
    final total = state.caseScenarios.length;
    final selectedOption = state.selectedCaseOption;
    final allAnswered = state.allCasesAnswered;

    // Reset highlight automatically once all cases are answered
    if (allAnswered && _highlightUnanswered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _highlightUnanswered = false);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'CASE SCENARIO ${currentIndex + 1} OF $total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F766E),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentCase.category,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_highlightUnanswered && selectedOption == null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please select a clinical response for this case before submitting.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Clinical Scenario Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_highlightUnanswered && selectedOption == null)
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFCBD5E1),
              width:
                  (_highlightUnanswered && selectedOption == null) ? 1.6 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.person_pin_outlined,
                        color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clinical Vignette ${currentIndex + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                currentCase.scenario ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action / Question Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Required Clinical Action / Question:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentCase.question,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                  fontFamily: 'Poppins',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 Options
        const Text(
          'Select the Appropriate Clinical Response:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),

        for (int i = 0; i < currentCase.options.length; i++) ...[
          _OptionSelectCard(
            letter: String.fromCharCode(65 + i),
            text: currentCase.options[i],
            isSelected: selectedOption == i,
            onTap: () => controller.selectCaseOption(i),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 20),

        // Navigation Controls
        _QuestionNavigationButtons(
          currentIndex: currentIndex,
          total: total,
          hasSelectedAnswer: selectedOption != null,
          answeredCount: state.caseAnsweredCount,
          allAnswered: allAnswered,
          onPrevious: currentIndex > 0 ? controller.previousCase : null,
          onNext: currentIndex < total - 1 ? controller.nextCase : null,
          onSubmit: allAnswered ? controller.submitCaseScenarios : null,
          onAttemptIncompleteSubmit: _onAttemptIncompleteSubmit,
          onAttemptIncompleteNext: _onAttemptIncompleteNext,
          submitLabel: 'Submit Case Scenarios',
        ),

        const SizedBox(height: 16),

        // Direct Case Jump Pills
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(total, (i) {
            final isCurrent = i == currentIndex;
            final isAnswered =
                state.caseAnswers.containsKey(state.caseScenarios[i].id);
            final isMissing = _highlightUnanswered && !isAnswered;

            return InkWell(
              onTap: () => controller.goToCase(i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF0F766E)
                      : isMissing
                          ? const Color(0xFFFEE2E2)
                          : isAnswered
                              ? const Color(0xFFCCFBF1)
                              : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF0F766E)
                        : isMissing
                            ? const Color(0xFFDC2626)
                            : isAnswered
                                ? const Color(0xFF14B8A6)
                                : const Color(0xFFCBD5E1),
                    width: isMissing ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCurrent
                        ? Colors.white
                        : isMissing
                            ? const Color(0xFFB91C1C)
                            : isAnswered
                                ? const Color(0xFF115E59)
                                : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _LegendItem(
              color: Color(0xFFCCFBF1),
              borderColor: Color(0xFF14B8A6),
              label: 'Answered',
            ),
            const SizedBox(width: 14),
            _LegendItem(
              color: _highlightUnanswered
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFF1F5F9),
              borderColor: _highlightUnanswered
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFCBD5E1),
              label: 'Unanswered',
            ),
            const SizedBox(width: 14),
            const _LegendItem(
              color: Color(0xFF0F766E),
              borderColor: Color(0xFF0F766E),
              label: 'Current',
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// STAGE 5: FINAL SUMMARY SECTION
// ===========================================================================

class _FinalSummarySection extends ConsumerWidget {
  const _FinalSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followUpProvider);
    final controller = ref.read(followUpProvider.notifier);

    final mcqCorrect = state.mcqCorrectCount;
    final mcqTotal = state.mcqs.length;
    final caseCorrect = state.caseCorrectCount;
    final caseTotal = state.caseScenarios.length;

    final totalCorrect = state.totalCorrectCount;
    final totalQuestions = state.totalQuestionsCount;
    final totalPercentage = state.totalPercentage;

    final summaryReport = _buildSummaryReport(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mastery Header Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B2545), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0B2545),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ASSESSMENT COMPLETE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Follow-up Assessment Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'ICMR / DHR Retinopathy of Prematurity Guidelines',
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Overall Score Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium,
                        color: Color(0xFFD97706), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Score: $totalCorrect / $totalQuestions (${totalPercentage.round()}%)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Sectional Breakdown Cards
        Row(
          children: [
            Expanded(
              child: _SectionalCard(
                title: 'Part 1: MCQs',
                score: '$mcqCorrect / $mcqTotal',
                percentage: state.mcqPercentage,
                icon: Icons.quiz_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SectionalCard(
                title: 'Part 2: Case Scenarios',
                score: '$caseCorrect / $caseTotal',
                percentage: state.casePercentage,
                icon: Icons.medical_services_outlined,
                color: const Color(0xFF0F766E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Action Buttons: Share & Copy
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: summaryReport));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assessment summary copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Report'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(
                  summaryReport,
                  subject: '${state.shortName} STW Follow-up Assessment Summary',
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Navigation & Retake
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => confirmLeaveCondition(
                  context,
                  ref,
                  destinationRoute: '/disease-selection',
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Selection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => confirmLeaveCondition(
                  context,
                  ref,
                  destinationRoute: '/home',
                ),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Return to Home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.reset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retake All Questions & Scenarios'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            minimumSize: const Size(double.infinity, 46),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
        const SizedBox(height: 24),

        // Case Scenarios Review Header
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_outlined,
                size: 20, color: AppTheme.primaryNavy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Case Scenarios Review & Answers',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryNavy,
                      fontFamily: 'Poppins',
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        for (int i = 0; i < state.caseScenarios.length; i++) ...[
          _CaseFeedbackCard(
            caseNumber: i + 1,
            question: state.caseScenarios[i],
            userAnswerIndex: state.caseAnswers[state.caseScenarios[i].id],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  String _buildSummaryReport(FollowUpState state) {
    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln(
        'ICMR / DHR ${state.shortName.toUpperCase()} STW FOLLOW-UP ASSESSMENT REPORT');
    buffer.writeln('==============================================');
    buffer.writeln(
        'Overall Score: ${state.totalCorrectCount} / ${state.totalQuestionsCount} (${state.totalPercentage.round()}%)');
    buffer.writeln(
        'Part 1 (MCQs): ${state.mcqCorrectCount} / ${state.mcqs.length} (${state.mcqPercentage.round()}%)');
    buffer.writeln(
        'Part 2 (Cases): ${state.caseCorrectCount} / ${state.caseScenarios.length} (${state.casePercentage.round()}%)');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('MCQ BREAKDOWN:');
    for (int i = 0; i < state.mcqs.length; i++) {
      final q = state.mcqs[i];
      final ans = state.mcqAnswers[q.id];
      final isCorrect = ans == q.correctAnswerIndex;
      buffer.writeln(
          'Q${i + 1} (${q.category}): ${isCorrect ? "CORRECT" : "INCORRECT"} (Selected: ${ans != null ? String.fromCharCode(65 + ans) : "None"}, Correct: ${q.correctAnswerLetter})');
    }
    buffer.writeln('----------------------------------------------');
    buffer.writeln('CASE SCENARIOS BREAKDOWN:');
    for (int i = 0; i < state.caseScenarios.length; i++) {
      final c = state.caseScenarios[i];
      final ans = state.caseAnswers[c.id];
      final isCorrect = ans == c.correctAnswerIndex;
      buffer.writeln(
          'Case ${i + 1} (${c.category}): ${isCorrect ? "CORRECT" : "INCORRECT"} (Selected: ${ans != null ? String.fromCharCode(65 + ans) : "None"}, Correct: ${c.correctAnswerLetter})');
    }
    buffer.writeln('==============================================');
    return buffer.toString();
  }
}

// ===========================================================================
// REUSABLE COMPONENTS
// ===========================================================================

class _OptionSelectCard extends StatelessWidget {
  const _OptionSelectCard({
    required this.letter,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryNavy : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x120B2545),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ]
                : const [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryNavy : const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryNavy : const Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected ? AppTheme.primaryNavy : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionNavigationButtons extends StatelessWidget {
  const _QuestionNavigationButtons({
    required this.currentIndex,
    required this.total,
    required this.hasSelectedAnswer,
    required this.answeredCount,
    required this.allAnswered,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.onAttemptIncompleteSubmit,
    required this.onAttemptIncompleteNext,
    required this.submitLabel,
  });

  final int currentIndex;
  final int total;
  final bool hasSelectedAnswer;
  final int answeredCount;
  final bool allAnswered;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;
  final VoidCallback onAttemptIncompleteSubmit;
  final VoidCallback onAttemptIncompleteNext;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == total - 1;
    final bool isActionEnabled = isLast ? allAnswered : hasSelectedAnswer;
    final VoidCallback? actionCallback = isLast ? onSubmit : onNext;
    final VoidCallback disabledTapHandler = isLast
        ? onAttemptIncompleteSubmit
        : onAttemptIncompleteNext;

    Widget actionButton = FilledButton.icon(
      onPressed: isActionEnabled ? actionCallback : null,
      icon: Icon(
        isLast ? Icons.check_circle_outline : Icons.arrow_forward,
        size: 18,
      ),
      label: Text(isLast ? submitLabel : 'Next Question'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryNavy,
        disabledBackgroundColor: const Color(0xFF94A3B8),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (!isActionEnabled) {
      actionButton = GestureDetector(
        onTap: disabledTapHandler,
        behavior: HitTestBehavior.opaque,
        child: IgnorePointer(
          child: actionButton,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Answered Progress Tracker
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    allAnswered
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    size: 15,
                    color: allAnswered
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$answeredCount of $total answered',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: allAnswered
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF475569),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              if (!allAnswered)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    '${total - answeredCount} unanswered',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text(
                    'Ready to submit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: onPrevious ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: actionButton,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _ResultStatCard extends StatelessWidget {
  const _ResultStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionalCard extends StatelessWidget {
  const _SectionalCard({
    required this.title,
    required this.score,
    required this.percentage,
    required this.icon,
    required this.color,
  });

  final String title;
  final String score;
  final double percentage;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            score,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryNavy,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            '${percentage.round()}% accuracy',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionFeedbackCard extends StatelessWidget {
  const _QuestionFeedbackCard({
    required this.questionNumber,
    required this.question,
    required this.userAnswerIndex,
  });

  final int questionNumber;
  final FollowUpQuestion question;
  final int? userAnswerIndex;

  @override
  Widget build(BuildContext context) {
    final isCorrect = userAnswerIndex == question.correctAnswerIndex;
    final isUnanswered = userAnswerIndex == null;

    final badgeColor = isCorrect
        ? const Color(0xFF16A34A)
        : isUnanswered
            ? const Color(0xFF64748B)
            : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          width: isCorrect ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle
                          : isUnanswered
                              ? Icons.help_outline
                              : Icons.cancel,
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCorrect
                          ? 'CORRECT'
                          : isUnanswered
                              ? 'UNANSWERED'
                              : 'INCORRECT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q$questionNumber • ${question.category}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // User Selected Answer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCorrect
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check : Icons.close,
                  size: 16,
                  color: isCorrect
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userAnswerIndex != null
                        ? 'Your answer: ${String.fromCharCode(65 + userAnswerIndex!)}. ${question.options[userAnswerIndex!]}'
                        : 'No answer selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCorrect
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Correct Answer (if user got it wrong)
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correct answer: ${question.correctAnswerLetter}. ${question.correctAnswer}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // STW Clinical Rationale Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 14, color: AppTheme.primaryNavy),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CLINICAL RATIONALE (ICMR / DHR STW)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question.explanation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
                if (question.stwReference != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Source: ${question.stwReference}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseFeedbackCard extends StatelessWidget {
  const _CaseFeedbackCard({
    required this.caseNumber,
    required this.question,
    required this.userAnswerIndex,
  });

  final int caseNumber;
  final FollowUpQuestion question;
  final int? userAnswerIndex;

  @override
  Widget build(BuildContext context) {
    final isCorrect = userAnswerIndex == question.correctAnswerIndex;
    final isUnanswered = userAnswerIndex == null;

    final badgeColor = isCorrect
        ? const Color(0xFF16A34A)
        : isUnanswered
            ? const Color(0xFF64748B)
            : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          width: isCorrect ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle
                          : isUnanswered
                              ? Icons.help_outline
                              : Icons.cancel,
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCorrect
                          ? 'CORRECT ACTION'
                          : isUnanswered
                              ? 'NOT ANSWERED'
                              : 'SUBOPTIMAL ACTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Case $caseNumber • ${question.category}',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scenario Vignette snippet
          if (question.scenario != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                question.scenario!,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          Text(
            question.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // User Response
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCorrect
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCorrect
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check : Icons.close,
                  size: 16,
                  color: isCorrect
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userAnswerIndex != null
                        ? 'Your choice: ${String.fromCharCode(65 + userAnswerIndex!)}. ${question.options[userAnswerIndex!]}'
                        : 'No action selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCorrect
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'STW Guideline Action: ${question.correctAnswerLetter}. ${question.correctAnswer}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // STW Clinical Explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_outlined,
                        size: 14, color: AppTheme.primaryNavy),
                    SizedBox(width: 6),
                    Text(
                      'CLINICAL RATIONALE & RECOMMENDATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question.explanation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                    height: 1.45,
                  ),
                ),
                if (question.stwReference != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Source: ${question.stwReference}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
