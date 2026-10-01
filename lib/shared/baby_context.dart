import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/inputs.dart';

/// Details shared by both modules. Held in memory only — nothing is saved.
class Baby {
  const Baby({this.gaWeeks, this.gaDays = 0, this.birthWeightG, this.dob});

  final int? gaWeeks;
  final int gaDays;
  final int? birthWeightG;
  final DateTime? dob;

  bool get isEmpty => gaWeeks == null && birthWeightG == null && dob == null;

  Baby copyWith({
    int? Function()? gaWeeks,
    int? gaDays,
    int? Function()? birthWeightG,
    DateTime? Function()? dob,
  }) =>
      Baby(
        gaWeeks: gaWeeks != null ? gaWeeks() : this.gaWeeks,
        gaDays: gaDays ?? this.gaDays,
        birthWeightG: birthWeightG != null ? birthWeightG() : this.birthWeightG,
        dob: dob != null ? dob() : this.dob,
      );

  String describe() {
    final parts = [
      gaWeeks == null ? 'GA —' : 'GA $gaWeeks+$gaDays wk',
      birthWeightG == null ? 'BW —' : 'BW $birthWeightG g',
      if (dob != null) 'DOB ${dateFormat.format(dob!)}',
    ];
    return parts.join(' · ');
  }
}

class BabyNotifier extends Notifier<Baby> {
  @override
  Baby build() => const Baby();

  void setGaWeeks(int? v) => state = state.copyWith(gaWeeks: () => v);
  void setGaDays(int v) => state = state.copyWith(gaDays: v);
  void setBirthWeight(int? v) => state = state.copyWith(birthWeightG: () => v);
  void setDob(DateTime? v) => state = state.copyWith(dob: () => v);
  void clear() => state = const Baby();
}

final babyProvider = NotifierProvider<BabyNotifier, Baby>(BabyNotifier.new);

/// GA (weeks + days) and birth weight fields bound to [babyProvider].
class GaBwFields extends ConsumerWidget {
  const GaBwFields({super.key, this.showGa = true, this.bwHelper});

  final bool showGa;
  final String? bwHelper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(babyProvider);
    final n = ref.read(babyProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGa) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: NumberField(
                  label: 'Gestational age',
                  suffix: 'weeks',
                  value: baby.gaWeeks,
                  min: 22,
                  max: 44,
                  onChanged: n.setGaWeeks,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: NumberField(
                  label: '+ days',
                  suffix: 'd',
                  value: baby.gaDays,
                  min: 0,
                  max: 6,
                  onChanged: (v) => n.setGaDays(v ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        NumberField(
          label: 'Birth weight',
          suffix: 'g',
          value: baby.birthWeightG,
          min: 300,
          max: 6000,
          helper: bwHelper,
          onChanged: n.setBirthWeight,
        ),
      ],
    );
  }
}

/// Header card showing the current baby and a "New baby" action that
/// clears every module.
class BabyContextCard extends ConsumerWidget {
  const BabyContextCard({super.key, required this.onClearAll});

  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(babyProvider);
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.child_care_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Current baby (not saved)',
                      style: text.titleMedium),
                ),
                TextButton.icon(
                  onPressed: baby.isEmpty ? null : onClearAll,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('New baby'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const GaBwFields(),
            const SizedBox(height: 12),
            DateField(
              label: 'Date of birth',
              value: baby.dob,
              firstDate: DateTime.now().subtract(const Duration(days: 730)),
              lastDate: DateTime.now(),
              onChanged: ref.read(babyProvider.notifier).setDob,
            ),
            const SizedBox(height: 8),
            Text(
              'Shared by both modules. Cleared when the app is closed.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
