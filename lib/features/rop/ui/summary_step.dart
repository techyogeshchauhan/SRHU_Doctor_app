import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../follow_up/state/follow_up_controller.dart';
import '../domain/rop_rules.dart';
import '../state/rop_controller.dart';

// ---------------------------------------------------------------------------
// Step 5 — Follow-up plan & discharge-card summary
// ---------------------------------------------------------------------------

class SummaryStep extends ConsumerWidget {
  const SummaryStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ropProvider);
    final n = ref.read(ropProvider.notifier);
    final eligible = ref.watch(ropEligibilityProvider).eligible == true;
    final bothMayStop = ref.watch(ropBothMayStopProvider);
    final summary = ref.watch(ropSummaryProvider);
    final planMissing = s.nextExam == null || s.place.trim().isEmpty;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eligible && planMissing && !bothMayStop)
          const AlertBanner(
            tone: Tone.danger,
            text: 'DO NOT discharge/transfer an at-risk neonate without a '
                'documented ROP follow-up plan.',
          ),
        SectionCard(
          number: 1,
          title: 'Next ROP examination',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DateField(
                label: 'Date of next examination',
                value: s.nextExam,
                firstDate: now.subtract(const Duration(days: 30)),
                lastDate: now.add(const Duration(days: 365)),
                onChanged: n.setNextExam,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STW FOLLOW-UP GUIDANCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Usually every 1–3 weeks\n'
                      '• Posterior or progressive disease / suspected A-ROP may require review within 1 week or sooner\n'
                      '• Treatment-requiring ROP: treat within 48–72 hours of decision',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF334155),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PlaceField(initial: s.place, onChanged: n.setPlace),
            ],
          ),
        ),
        SectionCard(
          number: 2,
          title: 'Counselling',
          child: CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Family counselled on need for follow-up and risk of vision '
              'loss if screening is delayed',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            value: s.counselled,
            onChanged: (v) => n.setCounselled(v ?? false),
          ),
        ),
        SectionCard(
          number: 3,
          title: 'SNCU record identification (optional)',
          subtitle: 'Included in the clinical summary and discharge card',
          child: Column(
            children: [
              _TextInputField(
                initial: s.hospitalName,
                label: 'Hospital / Facility Name',
                hint: 'e.g. Himalayan Hospital SNCU',
                onChanged: n.setHospitalName,
              ),
              const SizedBox(height: 10),
              _TextInputField(
                initial: s.sncuNumber,
                label: 'SNCU Database / CR Number',
                hint: 'e.g. SNCU-2026-1042',
                onChanged: n.setSncuNumber,
              ),
            ],
          ),
        ),
        _SncuRecordTableCard(
          hospitalName: s.hospitalName,
          sncuNumber: s.sncuNumber,
          right: s.right,
          left: s.left,
          rightResult: s.right.isEmpty
              ? null
              : ref.watch(ropEyeResultProvider(Eye.right)),
          leftResult: s.left.isEmpty
              ? null
              : ref.watch(ropEyeResultProvider(Eye.left)),
        ),
        SectionCard(
          number: 4,
          title: 'Summary for discharge card',
          subtitle: 'Formatted per SNCU database record — copy or share this text',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 16, color: AppTheme.primaryNavy),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'SNCU OPHTHALMOLOGY RECORD SUMMARY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryNavy,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    SelectableText(
                      summary,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: summary));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Summary copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy summary'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share(
                        summary,
                        subject: 'ROP screening summary',
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Proceed to Follow-up Assessment'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceField extends StatefulWidget {
  const _PlaceField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<_PlaceField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Place of next examination',
        hintText: 'e.g. SNCU, District Hospital / ROP centre',
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _TextInputField extends StatefulWidget {
  const _TextInputField({
    required this.initial,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final String initial;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<_TextInputField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _SncuRecordTableCard extends StatelessWidget {
  const _SncuRecordTableCard({
    required this.hospitalName,
    required this.sncuNumber,
    required this.right,
    required this.left,
    required this.rightResult,
    required this.leftResult,
  });

  final String hospitalName;
  final String sncuNumber;
  final EyeFindings right;
  final EyeFindings left;
  final EyeIndication? rightResult;
  final EyeIndication? leftResult;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'SNCU Examination Record (Table)',
      subtitle: 'Standard format for neonatal ophthalmology register',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.tint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hospitalName.trim().isEmpty
                        ? 'SNCU / Neonatal Centre'
                        : hospitalName.trim(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  sncuNumber.trim().isEmpty ? 'SNCU: —' : 'SNCU: $sncuNumber',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 14,
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(
                    label: Text('Eye',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('Zone',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('Stage',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('Clock Hrs',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('Vessels',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('A-ROP',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
                DataColumn(
                    label: Text('Recommendation',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 11))),
              ],
              rows: [
                _buildEyeRow('OD (Right)', right, rightResult),
                _buildEyeRow('OS (Left)', left, leftResult),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildEyeRow(
      String eyeLabel, EyeFindings f, EyeIndication? result) {
    if (f.isEmpty) {
      return DataRow(cells: [
        DataCell(Text(eyeLabel,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
        const DataCell(Text('—', style: TextStyle(fontSize: 11))),
        const DataCell(Text('—', style: TextStyle(fontSize: 11))),
        const DataCell(Text('—', style: TextStyle(fontSize: 11))),
        const DataCell(Text('—', style: TextStyle(fontSize: 11))),
        const DataCell(Text('—', style: TextStyle(fontSize: 11))),
        const DataCell(Text('Not examined',
            style: TextStyle(fontSize: 11, color: AppTheme.mutedText))),
      ]);
    }
    final vesselText =
        f.plus ? 'PLUS' : (f.prePlus ? 'Pre-plus' : 'No plus');
    final stageText =
        f.stage == 0 ? 'No ROP' : (f.stage != null ? 'St ${f.stage}' : '—');
    final clockText = f.clockHours != null ? '${f.clockHours} hr' : '—';
    final actionText = result?.title ?? '—';

    return DataRow(cells: [
      DataCell(Text(eyeLabel,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
      DataCell(
          Text(f.zone?.label ?? '—', style: const TextStyle(fontSize: 11))),
      DataCell(Text(stageText, style: const TextStyle(fontSize: 11))),
      DataCell(Text(clockText, style: const TextStyle(fontSize: 11))),
      DataCell(Text(
        vesselText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: f.plus || f.prePlus ? FontWeight.w700 : FontWeight.normal,
          color: f.plus
              ? const Color(0xFFDC2626)
              : (f.prePlus ? const Color(0xFFD97706) : AppTheme.bodyText),
        ),
      )),
      DataCell(Text(
        f.aRop ? 'YES' : 'No',
        style: TextStyle(
          fontSize: 11,
          fontWeight: f.aRop ? FontWeight.w700 : FontWeight.normal,
          color: f.aRop ? const Color(0xFFDC2626) : AppTheme.bodyText,
        ),
      )),
      DataCell(Text(
        actionText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: (result?.needsTreatment ?? false)
              ? const Color(0xFFDC2626)
              : AppTheme.primaryNavy,
        ),
      )),
    ]);
  }
}
