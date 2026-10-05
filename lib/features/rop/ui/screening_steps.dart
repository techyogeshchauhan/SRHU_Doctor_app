import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../../../shared/baby_context.dart';
import '../domain/rop_rules.dart';
import '../state/rop_controller.dart';

// ---------------------------------------------------------------------------
// Step 1 — Whom to screen
// ---------------------------------------------------------------------------

class EligibilityStep extends ConsumerWidget {
  const EligibilityStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(babyProvider);
    final s = ref.watch(ropProvider);
    final e = ref.watch(ropEligibilityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ropIntro, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        const SectionCard(
          number: 1,
          title: 'Gestation & birth weight',
          child: GaBwFields(),
        ),
        if (riskFactorsRelevant(baby.gaWeeks))
          SectionCard(
            number: 2,
            title: 'Risk factors (GA 34–36 weeks)',
            subtitle: 'Any one makes the baby eligible',
            child: CheckList<RopRiskFactor>(
              items: [for (final r in RopRiskFactor.values) (r, r.label)],
              selected: s.risks,
              onChanged: ref.read(ropProvider.notifier).setRisks,
            ),
          ),
        switch (e.eligible) {
          true => ResultCard(
              tone: Tone.warning,
              title: 'SCREEN FOR ROP',
              actions: ropArrangeScreening,
              why: e.reasons,
            ),
          false => ResultCard(
              tone: Tone.success,
              title: 'Not eligible per STW screening criteria',
              why: e.reasons,
            ),
          null => ResultCard(
              tone: Tone.info,
              title: 'Eligibility pending',
              actions: e.reasons,
            ),
        },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — When to screen
// ---------------------------------------------------------------------------

class TimingStep extends ConsumerWidget {
  const TimingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(babyProvider);
    final s = ref.watch(ropProvider);
    final timing = ref.watch(ropTimingProvider);
    final eligible = ref.watch(ropEligibilityProvider).eligible == true;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          number: 1,
          title: 'Date of birth',
          child: DateField(
            label: 'Date of birth',
            value: baby.dob,
            firstDate: now.subtract(const Duration(days: 730)),
            lastDate: now,
            onChanged: ref.read(babyProvider.notifier).setDob,
          ),
        ),
        if (timing != null) ...[
          SectionCard(
            number: 2,
            title: 'Age today',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Postnatal age: ${timing.postnatalAgeDays} days '
                  '(${formatWeeksDays(timing.postnatalAgeDays)})',
                  style: text.bodyLarge,
                ),
                if (baby.gaWeeks != null)
                  Text(
                    'PMA: ${formatWeeksDays(pmaDays(
                      gaWeeks: baby.gaWeeks!,
                      gaDays: baby.gaDays,
                      dob: baby.dob!,
                      onDate: now,
                    ))}',
                    style: text.bodyLarge,
                  ),
              ],
            ),
          ),
          ResultCard(
            tone: switch (timing.status) {
              FirstScreenStatus.overdue => Tone.danger,
              FirstScreenStatus.notYetDue => Tone.info,
            },
            title: timing.status == FirstScreenStatus.overdue
                ? 'First screen OVERDUE — screen ASAP'
                : 'First screen due by ${dateFormat.format(timing.dueBy)}',
            actions: [
              if (timing.windowStart != null)
                'Window: ${dateFormat.format(timing.windowStart!)} – '
                    '${dateFormat.format(timing.dueBy)} (2–3 weeks)',
              if (timing.status != FirstScreenStatus.overdue)
                timing.status.label,
            ],
            why: [timing.ruleText],
          ),
        ] else
          const AlertBanner(
            tone: Tone.info,
            text: 'Enter date of birth to calculate the first-screen date.',
          ),
        SectionCard(
          number: 3,
          title: 'Is follow-up after discharge assured?',
          child: RadioChoiceGroup<FollowUpAssured>(
            horizontal: true,
            value: s.followUp,
            onChanged: ref.read(ropProvider.notifier).setFollowUp,
            options: [
              for (final f in FollowUpAssured.values) ChoiceOption(f, f.label),
            ],
          ),
        ),
        if (eligible &&
            (s.followUp == FollowUpAssured.no ||
                s.followUp == FollowUpAssured.uncertain))
          const AlertBanner(
            tone: Tone.warning,
            text: 'Follow-up uncertain → screen BEFORE DISCHARGE even if not '
                'yet due.',
          ),
        const ResultCard(
          tone: Tone.info,
          title: 'Repeat screens',
          actions: [
            'As advised by the ROP-trained ophthalmologist according to '
                'retinal findings, usually every 1–3 weeks.',
            'Posterior or progressive disease / suspected A-ROP may require '
                'review within 1 week or sooner.',
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Prepare & how to screen
// ---------------------------------------------------------------------------

class PrepareStep extends ConsumerWidget {
  const PrepareStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ropProvider);
    final n = ref.read(ropProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          number: 1,
          title: 'Prepare to screen',
          subtitle: 'Checklist (not saved)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckList<int>(
                items: [
                  for (var i = 0; i < ropPrepareChecklist.length; i++)
                    (i, ropPrepareChecklist[i]),
                ],
                selected: s.prepDone,
                onChanged: n.setPrepDone,
              ),
              const SizedBox(height: 8),
              const DilationTimer(),
            ],
          ),
        ),
        SectionCard(
          number: 2,
          title: 'How to screen',
          child: CheckList<int>(
            items: [
              for (var i = 0; i < ropHowToScreenChecklist.length; i++)
                (100 + i, ropHowToScreenChecklist[i]),
            ],
            selected: s.prepDone,
            onChanged: n.setPrepDone,
          ),
        ),
        SectionCard(
          number: 3,
          title: 'Anterior segment & media checklist (SNCU form)',
          subtitle: 'Verify before indirect ophthalmoscopy',
          child: CheckList<int>(
            items: const [
              (200, 'Pupils adequately dilated (≥ 6–7 mm, unreactive to light)'),
              (201, 'Cornea and anterior chamber clear, no haziness'),
              (202, 'Lens and ocular media clear for fundus visualization'),
              (203, 'Baby swaddled and stable (temperature and SpO₂ monitored)'),
            ],
            selected: s.prepDone,
            onChanged: n.setPrepDone,
          ),
        ),
      ],
    );
  }
}

/// Counts mydriatic doses and times the 10-minute interval between them.
/// In-session only; resets if the step is left.
class DilationTimer extends StatefulWidget {
  const DilationTimer({super.key});

  static const interval = Duration(minutes: 10);
  static const maxDoses = 3;

  @override
  State<DilationTimer> createState() => _DilationTimerState();
}

class _DilationTimerState extends State<DilationTimer> {
  int _doses = 0;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  void _giveDose() {
    _timer?.cancel();
    setState(() {
      _doses++;
      _remaining = _doses < DilationTimer.maxDoses
          ? DilationTimer.interval
          : Duration.zero;
    });
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _remaining -= const Duration(seconds: 1);
          if (_remaining <= Duration.zero) {
            _remaining = Duration.zero;
            t.cancel();
          }
        });
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _doses = 0;
      _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final waiting = _remaining > Duration.zero;
    final done = _doses >= DilationTimer.maxDoses;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dilating drops: dose $_doses of 2–3',
                      style: text.titleSmall),
                  Text(
                    waiting
                        ? 'Next dose in $mm:$ss'
                        : done
                            ? 'All doses given'
                            : _doses == 0
                                ? 'Tap when the first dose is instilled'
                                : 'Next dose due now',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            if (_doses > 0)
              IconButton(
                tooltip: 'Reset',
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
              ),
            FilledButton.tonal(
              onPressed: waiting || done ? null : _giveDose,
              child: Text(_doses == 0 ? 'Dose 1 given' : 'Dose ${_doses + 1}'),
            ),
          ],
        ),
      ),
    );
  }
}
