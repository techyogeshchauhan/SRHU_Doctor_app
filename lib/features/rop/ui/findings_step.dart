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
        const SizedBox(height: 16),
        const _Icrop3ReferenceCard(),
      ],
    );
  }
}

enum VascularStatus {
  noPlus('No plus'),
  prePlus('Pre-plus'),
  plus('Plus disease');

  const VascularStatus(this.label);
  final String label;
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

    final vascularStatus = f.plus
        ? VascularStatus.plus
        : (f.prePlus ? VascularStatus.prePlus : VascularStatus.noPlus);

    return SectionCard(
      title: '${eye.label} findings',
      subtitle: 'Entered by / with the ROP-trained ophthalmologist (ICROP3)',
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
          label('Vascular abnormality (ICROP3 plus spectrum)'),
          RadioChoiceGroup<VascularStatus>(
            horizontal: true,
            value: vascularStatus,
            onChanged: (v) => onChanged(f.copyWith(
              plus: v == VascularStatus.plus,
              prePlus: v == VascularStatus.prePlus,
            )),
            options: const [
              ChoiceOption(VascularStatus.noPlus, 'No plus'),
              ChoiceOption(VascularStatus.prePlus, 'Pre-plus'),
              ChoiceOption(VascularStatus.plus, 'Plus present'),
            ],
          ),
          if (f.prePlus)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '• Pre-plus: abnormal vessel tortuosity/dilation insufficient for plus disease. Monitor closely within 1 week.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (f.plus)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '• Plus disease: marked dilation and tortuosity in Zone I. Treatment trigger if in Zone I or Zone II stage 2–3.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          label('Extent of disease (Clock hours 1–12)'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: (f.clockHours ?? 0).toDouble(),
                  min: 0,
                  max: 12,
                  divisions: 12,
                  label: (f.clockHours == null || f.clockHours == 0)
                      ? 'Not specified'
                      : '${f.clockHours} clock hrs',
                  onChanged: (v) {
                    final intVal = v.round();
                    onChanged(f.copyWith(
                        clockHours: () => intVal == 0 ? null : intVal));
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (f.clockHours != null && f.clockHours! > 0)
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (f.clockHours != null && f.clockHours! > 0)
                        ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  (f.clockHours == null || f.clockHours == 0)
                      ? 'Not set'
                      : '${f.clockHours} hr${f.clockHours == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (f.clockHours != null && f.clockHours! > 0)
                        ? AppTheme.primaryBlue
                        : AppTheme.mutedText,
                  ),
                ),
              ),
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

class _Icrop3ReferenceCard extends StatefulWidget {
  const _Icrop3ReferenceCard();

  @override
  State<_Icrop3ReferenceCard> createState() => _Icrop3ReferenceCardState();
}

class _Icrop3ReferenceCardState extends State<_Icrop3ReferenceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ICROP3 Classification Quick Guide',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          'International Classification of ROP (3rd Edition)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: AppTheme.dividerColor, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcrop3Row(
                    'Zones',
                    '• Zone I: Inner circle centred on optic disc, radius = 2 × disc-to-fovea distance.\n'
                    '• Zone II: Extends from Zone I to nasal ora serrata.\n'
                    '• Posterior Zone II: Begins at Zone I margin and extends 2 disc diameters into Zone II.\n'
                    '• Zone III: Remaining temporal crescent of retina.\n'
                    '• "Notch": 1–2 clock hours incursion by ROP lesion into a more posterior zone.',
                  ),
                  const SizedBox(height: 10),
                  _buildIcrop3Row(
                    'Stages',
                    '• Stage 1 (Demarcation line): Thin flat white line at vascular-avascular juncture.\n'
                    '• Stage 2 (Ridge): Demarcation line gains volume with height and width.\n'
                    '• Stage 3 (Extraretinal proliferation): Neovascularization extending from ridge into vitreous.\n'
                    '• Stage 4 (Partial RD): 4A = Fovea attached; 4B = Fovea detached.\n'
                    '• Stage 5 (Total RD): 5A = Optic disc visible; 5B = Disc not visible; 5C = 5B with anterior segment changes.',
                  ),
                  const SizedBox(height: 10),
                  _buildIcrop3Row(
                    'Plus Spectrum',
                    '• Continuous spectrum: Normal → Pre-plus → Plus disease.\n'
                    '• Pre-plus: Abnormal dilation/tortuosity insufficient for plus (warrants close observation within 1 week).\n'
                    '• Plus: Severe dilation and tortuosity in Zone I (treatment trigger in Zone I, or Zone II stage 2–3).',
                  ),
                  const SizedBox(height: 10),
                  _buildIcrop3Row(
                    'A-ROP',
                    '• Aggressive ROP: Rapid, severe progression without typical sequential stages 1–3. Located in posterior Zone I / Zone II. Requires URGENT treatment.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcrop3Row(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
