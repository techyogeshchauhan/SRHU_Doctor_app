import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../domain/rd_rules.dart';

// ---------------------------------------------------------------------------
// Initial plan
// ---------------------------------------------------------------------------

String initialTitle(RdInitialResult r) {
  final p = r.plan;
  if (p == null) return r.pending!;
  return switch (p.support) {
    RespSupport.cpap => 'START CPAP 5–6 cm H₂O'
        '${p.caffeine == CaffeineAdvice.indicated ? ' + caffeine' : ''}',
    RespSupport.nasalO2 => 'Nasal-prong O₂ 0.5–1 L/min',
    RespSupport.none => 'No respiratory support',
  };
}

Tone initialTone(RdInitialResult r) =>
    r.plan == null ? Tone.info : Tone.warning;

class RdPlanView extends StatelessWidget {
  const RdPlanView({super.key, required this.result});

  final RdInitialResult result;

  @override
  Widget build(BuildContext context) {
    final p = result.plan;
    if (p == null) {
      return ResultCard(
        tone: Tone.info,
        badge: 'Status',
        title: 'Recommendation pending',
        actions: [result.pending!],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Immediate actions
        const ResultCard(
          tone: Tone.info,
          badge: 'Immediate actions',
          title: 'Immediate actions (TABC & stabilization)',
          actions: [
            'Assess and stabilize TABC (temperature, airway, breathing, circulation)',
            'Admit to SNCU/NICU',
            'Provide thermal care',
            'Attach pulse oximeter',
            'Monitor HR, RR, SpO₂ and CRT; grade severity using SAS',
          ],
        ),

        // 2. Respiratory support
        ResultCard(
          tone: Tone.warning,
          badge: 'Respiratory support',
          title: initialTitle(result),
          actions: [
            ...p.supportActions,
            switch (p.caffeine) {
              CaffeineAdvice.indicated =>
                'Start caffeine citrate (<34 weeks requiring respiratory '
                    'support).',
              CaffeineAdvice.confirmGa =>
                'Start caffeine citrate if GA is <34 weeks.',
              CaffeineAdvice.notIndicated =>
                'Caffeine: not indicated (GA ≥34 weeks).',
            },
            'Reassess frequently: clinical status, SAS, SpO₂, FiO₂ '
                'requirement (Reassess tab).',
          ],
          why: p.why,
        ),

        // Feeding / IV Fluids
        ResultCard(
          tone: p.ivFluids ? Tone.warning : Tone.info,
          badge: p.ivFluids ? 'IV Fluids' : 'Feeding',
          title: p.ivFluids ? 'IV fluids' : 'Feeding',
          actions: [p.feeding.text],
          why: p.ivFluidReasons,
        ),

        // 3. Do
        const ResultCard(
          tone: Tone.success,
          badge: 'Do',
          title: 'Recommended practices (STW DOs)',
          actions: [
            'Assess severity using SAS and monitor SpO₂ continuously.',
            'Maintain SpO₂ 91%–95%.',
            'Start CPAP within 30 minutes.',
            'Administer surfactant within 2 hours.',
          ],
        ),

        // 4. Don't
        ResultCard(
          tone: Tone.danger,
          badge: "Don't",
          title: 'Avoid (STW DON’Ts)',
          actions: p.avoid,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reassessment
// ---------------------------------------------------------------------------

Tone reassessTone(ReassessStatus s) => switch (s) {
      ReassessStatus.incomplete => Tone.info,
      ReassessStatus.cpapFailure => Tone.danger,
      ReassessStatus.surfactant => Tone.treat,
      ReassessStatus.notImproving => Tone.warning,
      ReassessStatus.improving => Tone.success,
      ReassessStatus.stable => Tone.info,
      ReassessStatus.offSupport => Tone.success,
    };

class ReassessView extends StatelessWidget {
  const ReassessView({super.key, required this.outcome});

  final ReassessOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in outcome.alerts)
          AlertBanner(
            tone: a.startsWith('Consider sepsis') ? Tone.treat : Tone.warning,
            text: a,
          ),
        ResultCard(
          tone: reassessTone(outcome.status),
          badge: 'Reassessment Action',
          title: outcome.title,
          actions: outcome.actions,
          why: outcome.why,
        ),
      ],
    );
  }
}
