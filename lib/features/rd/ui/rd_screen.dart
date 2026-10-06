import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../../../shared/baby_context.dart';
import '../../../shared/reference_view.dart';
import '../domain/rd_rules.dart';
import '../state/rd_controller.dart';
import 'rd_results.dart';
import 'sas_calculator.dart';

class RdScreen extends ConsumerStatefulWidget {
  const RdScreen({super.key});

  @override
  ConsumerState<RdScreen> createState() => _RdScreenState();
}

class _RdScreenState extends ConsumerState<RdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = ResponsiveSplit.isWide(context);
    Widget? bar;
    if (!wide && _tabs.index == 0) {
      final r = ref.watch(rdInitialProvider);
      bar = RecommendationBar(
        tone: initialTone(r),
        title: initialTitle(r),
        detail: RdPlanView(result: r),
      );
    } else if (!wide && _tabs.index == 1) {
      final o = ref.watch(rdReassessProvider);
      bar = RecommendationBar(
        tone: reassessTone(o.status),
        title: o.title,
        detail: ReassessView(outcome: o),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'Respiratory Distress'),
        actions: [
          const BackToHomeButton(iconOnly: true),
          const AppRefreshButton(),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Clear RD assessment',
            child: IconButton(
              tooltip: 'Clear RD assessment',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => ref.read(rdProvider.notifier).reset(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Assess'),
            Tab(icon: Icon(Icons.autorenew), text: 'Reassess'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Reference'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _AssessTab(),
          _ReassessTab(),
          ReferenceView(
            sections: rdReference,
            links: rdRelatedLinks,
          ),
        ],
      ),
      bottomNavigationBar: bar,
    );
  }
}

// ---------------------------------------------------------------------------
// Assess tab
// ---------------------------------------------------------------------------

class _AssessTab extends ConsumerWidget {
  const _AssessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rdProvider);
    final n = ref.read(rdProvider.notifier);
    final gestation = ref.watch(rdGestationProvider);
    final result = ref.watch(rdInitialProvider);
    final isRd = meetsRdCriteria(s.signs);
    const needRd = 'Tick at least one sign of respiratory distress first.';

    return ResponsiveSplit(
      result: RdPlanView(result: result),
      form: [
        SectionCard(
          number: 1,
          title: 'Signs of respiratory distress',
          subtitle: 'Presence of ANY ONE',
          trailing: StatusChip(
            tone: isRd ? Tone.warning : Tone.info,
            label: isRd ? 'RD present' : 'No RD',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberField(
                label: 'Respiratory rate (optional)',
                suffix: '/min',
                value: s.rr,
                min: 0,
                max: 150,
                helper: 'Ticks "RR >60/min" automatically',
                onChanged: n.setRr,
              ),
              const SizedBox(height: 4),
              CheckList<RdSign>(
                items: [for (final x in RdSign.values) (x, x.label)],
                selected: s.signs,
                onChanged: n.setSigns,
              ),
            ],
          ),
        ),
        SectionCard(
          number: 2,
          title: 'Immediate actions',
          subtitle: 'Checklist (not saved)',
          enabled: isRd,
          disabledHint: needRd,
          child: CheckList<int>(
            items: [
              for (var i = 0; i < rdImmediateActions.length; i++)
                (i, rdImmediateActions[i]),
            ],
            selected: s.immediateDone,
            onChanged: n.setImmediateDone,
          ),
        ),
        SectionCard(
          number: 3,
          title: 'Gestation',
          enabled: isRd,
          disabledHint: needRd,
          trailing: gestation.band == null
              ? null
              : StatusChip(
                  tone: Tone.info,
                  label: gestation.band == GaBand.upTo34
                      ? 'GA ≤34 wk'
                      : 'GA >34 wk',
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioChoiceGroup<bool>(
                horizontal: true,
                value: s.gaKnown,
                onChanged: n.setGaKnown,
                options: const [
                  ChoiceOption(true, 'GA known'),
                  ChoiceOption(false, 'GA uncertain'),
                ],
              ),
              const SizedBox(height: 12),
              GaBwFields(
                showGa: s.gaKnown,
                bwHelper: s.gaKnown
                    ? null
                    : 'BW ≤$bwSurrogateThresholdG g is used as an operational '
                        'surrogate for GA ≤34 weeks',
              ),
            ],
          ),
        ),
        SectionCard(
          number: 4,
          title: 'Silverman-Andersen Score',
          subtitle: 'Select one grade per item',
          enabled: isRd,
          disabledHint: needRd,
          child: SasCalculator(
            score: s.sas,
            onGrade: n.setSasGrade,
            onClear: n.clearSas,
          ),
        ),
        SectionCard(
          number: 5,
          title: 'Other findings',
          subtitle: 'Decide IV fluids vs enteral feeds',
          enabled: isRd,
          disabledHint: needRd,
          child: CheckList<String>(
            items: const [
              ('severe', 'Severe distress (clinician judgement)'),
              ('apnea', 'Recurrent apnea'),
              ('perfusion', 'Poor perfusion (e.g. prolonged CRT)'),
              ('abdomen', 'Abdominal signs'),
            ],
            selected: {
              if (s.severeDistress) 'severe',
              if (s.recurrentApnea) 'apnea',
              if (s.poorPerfusion) 'perfusion',
              if (s.abdominalSigns) 'abdomen',
            },
            onChanged: (v) => n.setIvFlags(
              severe: v.contains('severe'),
              apnea: v.contains('apnea'),
              perfusion: v.contains('perfusion'),
              abdomen: v.contains('abdomen'),
            ),
          ),
        ),
        if (!ResponsiveSplit.isWide(context))
          SectionCard(
            number: 6,
            title: 'Recommendation',
            child: RdPlanView(result: result),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reassess tab
// ---------------------------------------------------------------------------

class _ReassessTab extends ConsumerWidget {
  const _ReassessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(rdProvider);
    final n = ref.read(rdProvider.notifier);
    final support = ref.watch(rdCurrentSupportProvider);
    final outcome = ref.watch(rdReassessProvider);
    final initialPending = ref.watch(rdInitialProvider).plan == null;
    final onCpap = support == RespSupport.cpap;

    return ResponsiveSplit(
      result: ReassessView(outcome: outcome),
      form: [
        if (initialPending)
          const AlertBanner(
            tone: Tone.info,
            text: 'Tip: complete the Assess tab first. Current support is '
                'then pre-selected from the initial plan.',
          ),
        SectionCard(
          number: 1,
          title: 'Current support & oxygenation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioChoiceGroup<RespSupport>(
                value: support,
                onChanged: n.setSupport,
                options: const [
                  ChoiceOption(RespSupport.cpap, 'CPAP'),
                  ChoiceOption(RespSupport.nasalO2, 'Nasal-prong O₂',
                      subtitle: '0.5–1 L/min'),
                  ChoiceOption(RespSupport.none, 'Off respiratory support',
                      subtitle: 'After weaning'),
                ],
              ),
              if (onCpap) ...[
                const SizedBox(height: 12),
                IntStepper(
                  label: 'PEEP',
                  suffix: 'cm H₂O',
                  value: s.peep,
                  min: peepMin,
                  max: peepMax,
                  onChanged: n.setPeep,
                ),
                const SizedBox(height: 8),
                Fio2Slider(value: s.fio2, onChanged: n.setFio2),
              ],
              const SizedBox(height: 12),
              NumberField(
                label: 'SpO₂',
                suffix: '%',
                value: s.spo2,
                min: 50,
                max: 100,
                helper: 'Target 91–95%',
                onChanged: n.setSpo2,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Comfortable breathing'),
                subtitle: const Text('Required for improving / weaning per STW'),
                value: s.comfortableBreathing,
                onChanged: (v) => n.setComfortableBreathing(v ?? false),
              ),
            ],
          ),
        ),
        SectionCard(
          number: 2,
          title: 'Repeat SAS',
          subtitle: s.previousSasTotal == null
              ? 'No earlier SAS to compare'
              : 'Previous SAS: ${s.previousSasTotal}',
          child: SasCalculator(
            score: s.reSas,
            previousTotal: s.previousSasTotal,
            onGrade: n.setReSasGrade,
          ),
        ),
        SectionCard(
          number: 3,
          title: 'Warning signs',
          child: CheckList<String>(
            items: [
              ('rising', 'Rising oxygen need'),
              ('apnea', 'Recurrent apnea / bradycardia'),
              ('fatigue', 'Fatigue'),
              ('shock', 'Shock'),
              ('deterioration', 'Clinical deterioration'),
              if (onCpap)
                ('hypoxemia',
                    'Persistent hypoxemia / high FiO₂ despite optimised CPAP'),
            ],
            selected: {
              if (s.risingO2Need) 'rising',
              if (s.apneaBrady) 'apnea',
              if (s.fatigue) 'fatigue',
              if (s.shock) 'shock',
              if (s.deterioration) 'deterioration',
              if (s.persistentHypoxemia && onCpap) 'hypoxemia',
            },
            onChanged: (v) => n.setWarnings(
              risingO2Need: v.contains('rising'),
              apneaBrady: v.contains('apnea'),
              fatigue: v.contains('fatigue'),
              shock: v.contains('shock'),
              deterioration: v.contains('deterioration'),
              persistentHypoxemia: v.contains('hypoxemia'),
            ),
          ),
        ),
        SectionCard(
          number: 4,
          title: 'Sepsis triggers',
          subtitle: 'Any one → consider sepsis',
          child: CheckList<SepsisTrigger>(
            items: [for (final t in SepsisTrigger.values) (t, t.label)],
            selected: s.sepsisTriggers,
            onChanged: n.setSepsisTriggers,
          ),
        ),
        if (!ResponsiveSplit.isWide(context))
          SectionCard(
            number: 5,
            title: 'Recommendation',
            child: ReassessView(outcome: outcome),
          ),
        if (s.sasHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'SAS trend this session: '
              '${[
                if (s.sas.isComplete) s.sas.total,
                ...s.sasHistory,
              ].join(' → ')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        FilledButton.icon(
          onPressed: s.reSas.isComplete ? n.recordReassessment : null,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Record SAS & start next reassessment'),
        ),
      ],
    );
  }
}
