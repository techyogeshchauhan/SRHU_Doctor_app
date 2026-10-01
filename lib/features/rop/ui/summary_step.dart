import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
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
          title: 'Summary for discharge card',
          subtitle: 'Nothing is stored — copy or share this text',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 16, color: AppTheme.primaryNavy),
                        SizedBox(width: 6),
                        Text(
                          'CLINICAL SUMMARY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                            letterSpacing: 0.5,
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
