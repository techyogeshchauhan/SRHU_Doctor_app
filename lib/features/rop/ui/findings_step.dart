import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../domain/rop_rules.dart';
import '../state/rop_controller.dart';

Tone eyeTone(EyeAction a) => switch (a) {
      EyeAction.incomplete => Tone.info,
      EyeAction.urgentTreatment => Tone.danger,
      EyeAction.surgeryReferral => Tone.danger,
      EyeAction.treat => Tone.treat,
      EyeAction.observe => Tone.warning,
      EyeAction.mayStop => Tone.success,
    };

// ---------------------------------------------------------------------------
// Step 4 — Findings per eye
// ---------------------------------------------------------------------------

class FindingsStep extends ConsumerStatefulWidget {
  const FindingsStep({super.key});

  @override
  ConsumerState<FindingsStep> createState() => _FindingsStepState();
}

class _FindingsStepState extends ConsumerState<FindingsStep> {
  Eye _eye = Eye.right;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(ropProvider);
    final n = ref.read(ropProvider.notifier);
    final right = ref.watch(ropEyeResultProvider(Eye.right));
    final left = ref.watch(ropEyeResultProvider(Eye.left));
    final anyTreatment = right.needsTreatment || left.needsTreatment;
    final antiVegf = s.right.priorAntiVegf || s.left.priorAntiVegf;
    final pma65 = ref.watch(ropPma65DateProvider);
    final now = DateTime.now();
    final other = _eye == Eye.right ? Eye.left : Eye.right;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateField(
          label: 'Examination date',
          value: ref.watch(ropExamDateProvider),
          firstDate: now.subtract(const Duration(days: 730)),
          lastDate: now,
          onChanged: n.setExamDate,
        ),
        const SizedBox(height: 12),
        SegmentedButton<Eye>(
          segments: [
            for (final e in Eye.values)
              ButtonSegment(
                value: e,
                label: Text(e.label),
                icon: Icon(
                  ref.watch(ropEyeResultProvider(e)).action ==
                          EyeAction.incomplete
                      ? Icons.radio_button_unchecked
                      : Icons.check_circle,
                ),
              ),
          ],
          selected: {_eye},
          onSelectionChanged: (v) => setState(() => _eye = v.first),
        ),
        const SizedBox(height: 12),
        _EyeForm(
          // Rebuild fresh widgets when switching eyes.
          key: ValueKey(_eye),
          eye: _eye,
          findings: s.eye(_eye),
          onChanged: (f) => n.updateEye(_eye, f),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: s.eye(_eye).isEmpty
                  ? null
                  : () => n.copyEye(from: _eye),
              icon: const Icon(Icons.copy_all),
              label: Text('Same findings for ${other.label.split(' ').first} eye'),
            ),
            TextButton.icon(
              onPressed: s.eye(_eye).isEmpty
                  ? null
                  : () => n.updateEye(_eye, const EyeFindings()),
              icon: const Icon(Icons.clear),
              label: const Text('Clear this eye'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Result', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (eye, r) in [(Eye.right, right), (Eye.left, left)])
          ResultCard(
            tone: eyeTone(r.action),
            title: '${eye.label}: ${r.title}',
            actions: [if (r.followUp != null) r.followUp!],
            why: r.why,
          ),
        if (anyTreatment)
          const ResultCard(
            tone: Tone.treat,
            title: 'Treat urgently — within 48–72 h of decision',
            actions: ropTreatmentOptions,
          ),
        if (antiVegf)
          AlertBanner(
            tone: Tone.warning,
            text: 'After anti-VEGF: follow up at least until '
                '$antiVegfFollowUpPmaWeeks weeks PMA'
                '${pma65 == null ? ' (enter GA and DOB to calculate the date)' : ' — ${dateFormat.format(pma65)}'}.',
          ),
      ],
    );
  }
}

class _EyeForm extends StatelessWidget {
  const _EyeForm({
    super.key,
    required this.eye,
    required this.findings,
    required this.onChanged,
  });

  final Eye eye;
  final EyeFindings findings;
  final ValueChanged<EyeFindings> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = findings;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(s, style: text.titleSmall),
        );

    return SectionCard(
      title: '${eye.label} findings',
      subtitle: 'Entered by / with the ROP-trained ophthalmologist',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('Zone'),
          RadioChoiceGroup<RopZone>(
            horizontal: true,
            value: f.zone,
            onChanged: (z) => onChanged(f.copyWith(zone: () => z)),
            options: [for (final z in RopZone.values) ChoiceOption(z, z.label)],
          ),
          label('Stage'),
          RadioChoiceGroup<int>(
            horizontal: true,
            value: f.stage,
            onChanged: (st) => onChanged(f.copyWith(stage: () => st)),
            options: [
              const ChoiceOption(0, 'No ROP'),
              for (var st = 1; st <= 5; st++) ChoiceOption(st, 'Stage $st'),
            ],
          ),
          label('Plus disease'),
          RadioChoiceGroup<bool>(
            horizontal: true,
            value: f.plus,
            onChanged: (p) => onChanged(f.copyWith(plus: p)),
            options: const [
              ChoiceOption(false, 'No plus'),
              ChoiceOption(true, 'Plus present'),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Aggressive ROP (A-ROP) suspected'),
            value: f.aRop,
            onChanged: (v) => onChanged(f.copyWith(aRop: v)),
          ),
          SwitchListTile(
            title: const Text('Progressive disease since last exam'),
            value: f.progressive,
            onChanged: (v) => onChanged(f.copyWith(progressive: v)),
          ),
          SwitchListTile(
            title: const Text('Previously treated with anti-VEGF'),
            value: f.priorAntiVegf,
            onChanged: (v) => onChanged(f.copyWith(
              priorAntiVegf: v,
              reactivationOrPar: v ? f.reactivationOrPar : false,
            )),
          ),
          if (f.priorAntiVegf)
            SwitchListTile(
              title: const Text('Reactivation / significant PAR'),
              value: f.reactivationOrPar,
              onChanged: (v) => onChanged(f.copyWith(reactivationOrPar: v)),
            ),
          label('Retina status'),
          RadioChoiceGroup<RetinaStatus>(
            value: f.status,
            onChanged: (st) => onChanged(f.copyWith(status: () => st)),
            options: [
              for (final st in RetinaStatus.values) ChoiceOption(st, st.label),
            ],
          ),
        ],
      ),
    );
  }
}
