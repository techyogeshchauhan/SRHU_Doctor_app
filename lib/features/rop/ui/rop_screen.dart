import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/reference_view.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../follow_up/state/follow_up_controller.dart';
import '../state/rop_controller.dart';
import 'findings_step.dart';
import 'screening_steps.dart';
import 'summary_step.dart';

const _stepTitles = [
  'Eligibility',
  'Timing',
  'Prepare',
  'Findings',
  'Follow-up',
];

class RopScreen extends ConsumerWidget {
  const RopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(ropProvider.select((s) => s.step));
    final n = ref.read(ropProvider.notifier);
    final isLast = step == RopController.stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'ROP Screening'),
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
            label: 'ROP reference',
            child: IconButton(
              tooltip: 'ROP reference',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () => context.push('/rop/reference'),
            ),
          ),
          Semantics(
            button: true,
            label: 'Clear ROP screening',
            child: IconButton(
              tooltip: 'Clear ROP screening',
              icon: const Icon(Icons.restart_alt),
              onPressed: n.reset,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: _StepBar(current: step, onTap: n.goTo),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            key: PageStorageKey('rop-step-$step'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                switch (step) {
                  0 => const EligibilityStep(),
                  1 => const TimingStep(),
                  2 => const PrepareStep(),
                  3 => const FindingsStep(),
                  _ => const SummaryStep(),
                },
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => confirmLeaveCondition(
                    context,
                    ref,
                    destinationRoute: '/disease-selection',
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 15),
                  label: const Text('Back to Selection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                if (step > 0)
                  OutlinedButton.icon(
                    onPressed: n.back,
                    icon: const Icon(Icons.arrow_back, size: 15),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                if (!isLast)
                  FilledButton.icon(
                    onPressed: n.next,
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: Text(
                      'Next: ${_stepTitles[step + 1]}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
                else
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(followUpProvider.notifier)
                          .initForCondition(
                            NeonatalCondition.rop,
                            startImmediately: true,
                          );
                      context.push('/follow-up-assessment');
                    },
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: const Text(
                      'Next: MCQs',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.current, required this.onTap});

  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Step ${current + 1} of ${_stepTitles.length}: ${_stepTitles[current]}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(((current + 1) / _stepTitles.length) * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (current + 1) / _stepTitles.length,
          minHeight: 3,
          backgroundColor: const Color(0xFFE2E8F0),
          color: AppTheme.primaryNavy,
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (var i = 0; i < _stepTitles.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${i + 1}. ${_stepTitles[i]}'),
                    selected: i == current,
                    onSelected: (_) => onTap(i),
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      color: i == current ? Colors.white : AppTheme.primaryNavy,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RopReferenceScreen extends StatelessWidget {
  const RopReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'ROP Reference'),
        actions: const [
          BackToHomeButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: const ReferenceView(
        sections: ropReference,
        links: ropRelatedLinks,
      ),
    );
  }
}
