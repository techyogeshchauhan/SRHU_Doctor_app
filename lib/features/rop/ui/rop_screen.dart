import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/reference_view.dart';
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
        title: const Text('ROP Screening'),
        actions: [
          Semantics(
            button: true,
            label: 'Home overview',
            child: IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.push('/home'),
            ),
          ),
          Semantics(
            button: true,
            label: 'Open Retinopathy of Prematurity STW PDF',
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentRop,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text(
                'Source PDF',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => context.push(
                '/pdf-viewer',
                extra: {
                  'path': 'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
                  'title': 'Retinopathy of Prematurity (ROP)',
                },
              ),
            ),
          ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Opacity(
                  opacity: step > 0 ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: step == 0,
                    child: OutlinedButton.icon(
                      onPressed: n.back,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isLast)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: n.next,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        'Next: ${_stepTitles[step + 1]}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 96),
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
      appBar: AppBar(title: const Text('ROP reference')),
      body: ReferenceView(
        sections: ropReference,
        links: ropRelatedLinks,
        header: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRop.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppTheme.accentRop,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original STW PDF poster',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Official ICMR / DHR workflow poster',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Open Retinopathy of Prematurity STW PDF',
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '/pdf-viewer',
                        extra: {
                          'path': 'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
                          'title': 'Retinopathy of Prematurity (ROP)',
                        },
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentRop,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(96, 44),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
