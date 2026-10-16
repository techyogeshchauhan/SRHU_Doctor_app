/// Decision rules for the STW "Respiratory Distress in Neonates" (ICD-11 KB23).
///
/// Pure Dart, no Flutter imports, so every branch can be unit-tested and
/// reviewed independently of the UI. Gestational age thresholds use
/// completed weeks, preserving the existing GA convention for the unchanged
/// ≤34 / >34-week split in the updated PDF.
library;

import 'sas.dart';

// ---------------------------------------------------------------------------
// Diagnosis
// ---------------------------------------------------------------------------

enum RdSign {
  rrAbove60('RR ≥60/min'),
  retractions('Chest retractions'),
  nasalFlaring('Nasal flaring'),
  grunting('Grunting');

  const RdSign(this.label);
  final String label;
}

/// "Presence of ANY ONE" of the signs.
bool meetsRdCriteria(Set<RdSign> signs) => signs.isNotEmpty;

/// "RR ≥60/min": a measured RR at or above this counts as the sign.
const int rrThresholdPerMin = 60;

// ---------------------------------------------------------------------------
// Gestation
// ---------------------------------------------------------------------------

/// Birth weight at or below which an uncertain-GA baby is treated as ≤34 weeks.
const int bwSurrogateThresholdG = 1800;

enum GaBand { upTo34, above34 }

class Gestation {
  const Gestation({
    this.gaKnown = true,
    this.gaWeeks,
    this.gaDays = 0,
    this.birthWeightG,
  });

  final bool gaKnown;
  final int? gaWeeks;
  final int gaDays;
  final int? birthWeightG;

  /// True when GA is uncertain and birth weight is used as the surrogate.
  bool get usesBwSurrogate => !gaKnown && birthWeightG != null;

  GaBand? get band {
    if (gaKnown) {
      final w = gaWeeks;
      if (w == null) return null;
      return w <= 34 ? GaBand.upTo34 : GaBand.above34;
    }
    final bw = birthWeightG;
    if (bw == null) return null;
    return bw <= bwSurrogateThresholdG ? GaBand.upTo34 : GaBand.above34;
  }

  /// `true`/`false` when GA is known, `null` when GA is uncertain.
  bool? get isBelow34 {
    final w = gaWeeks;
    if (!gaKnown || w == null) return null;
    return w < 34;
  }

  String describe() {
    if (gaKnown) {
      return gaWeeks == null ? 'GA not entered' : 'GA $gaWeeks+$gaDays wk';
    }
    return birthWeightG == null
        ? 'GA uncertain, BW not entered'
        : 'GA uncertain, BW $birthWeightG g';
  }
}

// ---------------------------------------------------------------------------
// Initial plan
// ---------------------------------------------------------------------------

enum RespSupport {
  none('No respiratory support'),
  nasalO2('Nasal-prong O₂'),
  cpap('CPAP');

  const RespSupport(this.label);
  final String label;
}

enum CaffeineAdvice {
  indicated('Start caffeine citrate (<34 weeks requiring respiratory '
      'support), as per protocol.'),
  notIndicated(
      'STW caffeine criterion (<34 weeks requiring respiratory support) not met.'),
  confirmGa('Start caffeine citrate if GA is <34 weeks.');

  const CaffeineAdvice(this.text);
  final String text;
}

enum FeedingAdvice {
  directBreastfeed('Direct breastfeed (mild distress, stable).'),
  gastricTube(
      'OG feeds when appropriate on CPAP, if stable; decompress stomach.'),
  ivFluids(
      'Withhold feeds; give IV fluids for severe RD, recurrent apnoea, poor perfusion or abdominal concerns.');

  const FeedingAdvice(this.text);
  final String text;
}

class RdInitialPlan {
  const RdInitialPlan({
    required this.support,
    required this.severity,
    required this.caffeine,
    required this.feeding,
    required this.ivFluidReasons,
    required this.why,
    required this.avoid,
  });

  final RespSupport support;

  /// Null when SAS is incomplete (allowed for GA ≤34, where CPAP applies to
  /// any distress).
  final RdSeverity? severity;
  final CaffeineAdvice caffeine;
  final FeedingAdvice feeding;
  final List<String> ivFluidReasons;
  final List<String> why;
  final List<String> avoid;

  bool get ivFluids => ivFluidReasons.isNotEmpty;

  List<String> get supportActions => switch (support) {
        RespSupport.cpap => const [
            'START CPAP 5–6 cm H₂O (within 30 min of identification of indication).',
            'Use blended O₂; titrate FiO₂ to maintain SpO₂ 91–95%.',
          ],
        RespSupport.nasalO2 => const [
            'Nasal-prong oxygen 0.5–1 L/min.',
            'Titrate to SpO₂ 91–95% with continuous pulse oximetry.',
          ],
        RespSupport.none => const [],
      };
}

/// Either a plan, or a message saying which input is still needed.
class RdInitialResult {
  const RdInitialResult.pending(String this.pending, {this.emergency = false})
      : plan = null;
  const RdInitialResult.ready(RdInitialPlan this.plan)
      : pending = null,
        emergency = false;

  final String? pending;
  final RdInitialPlan? plan;
  final bool emergency;
}

RdInitialResult initialPlan({
  required Set<RdSign> signs,
  required Gestation gestation,
  required SasScore sas,
  int? initialSpo2,
  bool emergency = false,
  bool severeDistress = false,
  bool recurrentApnea = false,
  bool poorPerfusion = false,
  bool abdominalSigns = false,
}) {
  if (emergency) {
    return const RdInitialResult.pending(
      'Apnoea/gasping, poor effort or shock: stabilize immediately; ventilate when indicated.',
      emergency: true,
    );
  }
  if (!meetsRdCriteria(signs)) {
    return const RdInitialResult.pending(
      'Tick at least one sign of respiratory distress '
      '(RR ≥60/min, chest retractions, nasal flaring or grunting).',
    );
  }
  final band = gestation.band;
  if (band == null) {
    return RdInitialResult.pending(
      gestation.gaKnown
          ? 'Enter gestational age.'
          : 'Enter birth weight (used as surrogate when GA is uncertain).',
    );
  }
  final severity = sas.severity;
  if (band == GaBand.above34 && severity == null) {
    return RdInitialResult.pending(
      'GA >34 weeks: grade all 5 SAS items to decide between CPAP and '
      'nasal-prong oxygen (${sas.gradedCount}/5 graded).',
    );
  }

  final why = <String>[];
  if (gestation.usesBwSurrogate) {
    why.add(
      'GA uncertain → birth weight ${gestation.birthWeightG} g used as '
      'operational surrogate (≤$bwSurrogateThresholdG g ≈ GA ≤34 wk).',
    );
  }

  final RespSupport support;
  if (band == GaBand.upTo34) {
    support = RespSupport.cpap;
    why.add('GA ≤34 weeks with any respiratory distress → START CPAP.');
  } else if (severity!.isModerateOrSevere) {
    support = RespSupport.cpap;
    why.add('GA >34 weeks with moderate–severe RD (SAS ${sas.total} ≥4) '
        '→ START CPAP.');
  } else {
    if (initialSpo2 == null) {
      return const RdInitialResult.pending(
        'Mild RD with GA >34 weeks: enter SpO₂; nasal-prong oxygen is indicated only if SpO₂ <91%.',
      );
    }
    support =
        initialSpo2 < spo2TargetLow ? RespSupport.nasalO2 : RespSupport.none;
    why.add('GA >34 weeks with mild RD (SAS ${sas.total} ≤3) '
        '→ nasal-prong oxygen only if SpO₂ <91% (measured $initialSpo2%).');
  }

  final CaffeineAdvice caffeine;
  if (gestation.isBelow34 == true && support != RespSupport.none) {
    caffeine = CaffeineAdvice.indicated;
    why.add('GA <34 weeks on respiratory support → start caffeine citrate.');
  } else if (!gestation.gaKnown) {
    caffeine = CaffeineAdvice.confirmGa;
  } else {
    caffeine = CaffeineAdvice.notIndicated;
  }

  final ivReasons = <String>[
    if (severeDistress) 'Severe distress (clinician judgement)',
    if (recurrentApnea) 'Recurrent apnea',
    if (poorPerfusion) 'Poor perfusion',
    if (abdominalSigns) 'Abdominal signs',
  ];

  final FeedingAdvice feeding;
  if (ivReasons.isNotEmpty) {
    feeding = FeedingAdvice.ivFluids;
  } else if (support == RespSupport.cpap ||
      severity == RdSeverity.moderateSevere) {
    feeding = FeedingAdvice.gastricTube;
  } else {
    feeding = FeedingAdvice.directBreastfeed;
  }

  final avoid = <String>[
    'Do not give unmonitored supplemental oxygen.',
    if (severity == RdSeverity.mild)
      'Do not perform routine CBC, CRP, chest X-ray or blood gas in '
          'uncomplicated mild RD.',
    if (ivReasons.isEmpty)
      'Do not give IV fluids, antibiotics, or blood products routinely.',
  ];

  return RdInitialResult.ready(RdInitialPlan(
    support: support,
    severity: severity,
    caffeine: caffeine,
    feeding: feeding,
    ivFluidReasons: ivReasons,
    why: why,
    avoid: avoid,
  ));
}

// ---------------------------------------------------------------------------
// Reassessment loop
// ---------------------------------------------------------------------------

const int spo2TargetLow = 91;
const int spo2TargetHigh = 95;
const int peepMin = 4;
const int peepMax = 8;

class ReassessInput {
  const ReassessInput({
    required this.gestation,
    required this.support,
    this.peep = 5,
    this.fio2 = 0.21,
    this.spo2,
    this.previousSasTotal,
    this.sas = const SasScore(),
    this.risingO2Need = false,
    this.recurrentApneaBrady = false,
    this.fatigue = false,
    this.shock = false,
    this.deterioration = false,
    this.persistentHypoxemia = false,
    this.comfortableBreathing = false,
    this.suspectedWorseningRds = false,
    this.stableOrReducingSupport = false,
  });

  final Gestation gestation;
  final RespSupport support;

  /// CPAP pressure in cm H₂O (only meaningful on CPAP).
  final int peep;

  /// Fraction of inspired oxygen, 0.21–1.00 (only meaningful on CPAP).
  final double fio2;
  final int? spo2;

  /// SAS total at the previous assessment, used for the trend.
  final int? previousSasTotal;
  final SasScore sas;
  final bool risingO2Need;
  final bool recurrentApneaBrady;
  final bool fatigue;
  final bool shock;
  final bool deterioration;

  /// Doctor's judgement: persistent hypoxemia / high FiO₂ despite optimised CPAP.
  final bool persistentHypoxemia;

  /// Clinical finding: comfortable breathing (required for "improving" per STW).
  final bool comfortableBreathing;
  final bool suspectedWorseningRds;
  final bool stableOrReducingSupport;

  /// FiO₂ as an integer percentage, avoiding floating-point comparisons.
  int get fio2Percent => (fio2 * 100).round();
}

enum ReassessStatus {
  incomplete,
  cpapFailure,
  emergency,
  surfactant,
  notImproving,
  improving,
  stable,
  offSupport,
}

class ReassessOutcome {
  const ReassessOutcome({
    required this.status,
    required this.title,
    this.actions = const [],
    this.why = const [],
    this.alerts = const [],
  });

  final ReassessStatus status;
  final String title;
  final List<String> actions;
  final List<String> why;

  /// Side banners that apply regardless of status (SpO₂ above target, sepsis).
  final List<String> alerts;
}

/// Early rescue requires every criterion in the updated source PDF.
bool meetsSurfactantCriteria(ReassessInput i) =>
    i.suspectedWorseningRds &&
    i.support == RespSupport.cpap &&
    i.gestation.isBelow34 == true &&
    i.peep >= 6 &&
    i.fio2 > 0.30;

const rdMonitoringActions = [
  'Monitor SpO₂ continuously while on oxygen/CPAP.',
  'Reassess clinical status, SAS and FiO₂ requirement within 15–30 min of starting/changing support.',
  'Reassess at least 1 hourly while on respiratory support; immediately if any worsening.',
];

/// Use the PDF's trial-off window without adding pressure decrements.
List<String> cpapWeanSteps({required int peep, required double fio2}) {
  if (peep == 5 && fio2 >= 0.21 && fio2 <= 0.25) {
    return const [
      'Trial off CPAP only when stable: comfortable breathing, no significant apnoea and low oxygen requirement; on CPAP 5 cm H₂O and FiO₂ 0.21–0.25.',
      'Monitor SpO₂ for 24 h after stopping.',
    ];
  }
  return const [
    'Wean when stable: comfortable breathing; no significant apnoea; low oxygen requirement.',
    'Reduce FiO₂, then CPAP as per protocol.',
    'Trial off when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25.',
    'Monitor SpO₂ for 24 h after stopping.',
  ];
}

ReassessOutcome reassess(ReassessInput i) {
  final spo2 = i.spo2;
  final sasTotal = i.sas.isComplete ? i.sas.total : null;
  final prev = i.previousSasTotal;

  final alerts = <String>[
    if (spo2 != null && spo2 > spo2TargetHigh && i.support != RespSupport.none)
      'SpO₂ above target range (91–95%).',
  ];

  if (i.support != RespSupport.cpap &&
      (i.recurrentApneaBrady || i.shock || i.fatigue)) {
    return ReassessOutcome(
      status: ReassessStatus.emergency,
      title: 'ESCALATE SUPPORT PROMPTLY',
      actions: const [
        'Stabilize immediately; ventilate when indicated.',
        'Escalate support; intubate/ventilate when indicated; stabilize and refer urgently.',
      ],
      alerts: alerts,
    );
  }

  // Off support: monitor, restart if distress recurs.
  if (i.support == RespSupport.none) {
    final recurring = <String>[
      if (spo2 != null && spo2 < spo2TargetLow) 'SpO₂ $spo2% (<91%)',
      if (sasTotal != null && sasTotal >= 4) 'SAS $sasTotal (≥4)',
      if (i.recurrentApneaBrady) 'Recurrent apnea/bradycardia',
      if (i.fatigue || i.shock || i.deterioration)
        'Fatigue, shock or deterioration',
    ];
    if (recurring.isNotEmpty) {
      return ReassessOutcome(
        status: ReassessStatus.notImproving,
        title: 'Distress recurring off support',
        actions: const [
          'Restart respiratory support as per the algorithm (Assess tab).',
          'Look for/treat underlying cause.',
        ],
        why: recurring,
        alerts: alerts,
      );
    }
    return ReassessOutcome(
      status: ReassessStatus.offSupport,
      title: 'Off respiratory support',
      actions: const ['Continue SpO₂ monitoring for 24 h after stopping CPAP.'],
      alerts: alerts,
    );
  }

  // 1. CPAP failure.
  if (i.support == RespSupport.cpap) {
    final failure = <String>[
      if (i.persistentHypoxemia) 'Persistent hypoxemia / high FiO₂ requirement',
      if (i.recurrentApneaBrady) 'Recurrent apnea/bradycardia',
      if (i.shock) 'Shock',
      if (i.fatigue) 'Fatigue',
    ];
    if (failure.isNotEmpty) {
      return ReassessOutcome(
        status: ReassessStatus.cpapFailure,
        title: 'CPAP FAILURE — refer urgently',
        actions: [
          'Escalate support; intubate/ventilate when indicated; stabilize and refer urgently.',
          'Do NOT delay mechanical ventilation or referral.',
          if (meetsSurfactantCriteria(i))
            'Early rescue surfactant criteria also met; give promptly when indicated without delaying escalation.',
        ],
        why: failure,
        alerts: alerts,
      );
    }
  }

  // 2. Surfactant.
  if (meetsSurfactantCriteria(i)) {
    return ReassessOutcome(
      status: ReassessStatus.surfactant,
      title: 'EARLY RESCUE SURFACTANT indicated',
      actions: const [
        'Give early rescue surfactant promptly when indicated—before established CPAP failure.',
        'Continue CPAP; titrate FiO₂ to SpO₂ 91–95%.',
        ...rdMonitoringActions,
      ],
      why: [
        'GA <34 weeks on CPAP',
        'Suspected worsening RDS in a preterm neonate <34 weeks',
        'CPAP ${i.peep} cm H₂O (≥6)',
        'FiO₂ ${i.fio2.toStringAsFixed(2)} (>0.30)',
      ],
      alerts: alerts,
    );
  }

  // 3. Not improving / worsening.
  final notImproving = <String>[
    if (sasTotal != null && prev != null && sasTotal > prev)
      'SAS increasing ($prev → $sasTotal)'
    else if (sasTotal != null &&
        (prev != null && sasTotal == prev) &&
        sasTotal > 0)
      'SAS persisting at $sasTotal',
    if (spo2 != null && spo2 < spo2TargetLow) 'SpO₂ $spo2% (<91%)',
    if (i.risingO2Need) 'Rising oxygen need',
    // On CPAP these were already handled as CPAP failure.
    if (i.recurrentApneaBrady) 'Recurrent apnea/bradycardia',
    if (i.fatigue || i.shock) 'Fatigue or shock',
    if (i.deterioration) 'Clinical deterioration',
  ];
  if (notImproving.isNotEmpty) {
    if (i.support == RespSupport.cpap) {
      return ReassessOutcome(
        status: ReassessStatus.notImproving,
        title: 'NOT IMPROVING — optimise CPAP',
        actions: [
          'Increase CPAP up to 7–8 cm H₂O; titrate FiO₂.',
          'Titrate FiO₂ to target SpO₂ 91–95%.',
          'Check prongs, circuit and delivered pressure.',
          'Exclude pneumothorax (transillumination, X-ray).',
          'Consider sepsis (Refer to sepsis STW).',
          'Consider early rescue surfactant: suspected worsening RDS, GA <34 weeks, CPAP ≥6 cm H₂O and FiO₂ >0.30.',
          ...rdMonitoringActions,
        ],
        why: notImproving,
        alerts: alerts,
      );
    }
    // Nasal-prong O₂. Show STW NOT IMPROVING/WORSENING content as written.
    return ReassessOutcome(
      status: ReassessStatus.notImproving,
      title: 'NOT IMPROVING / WORSENING',
      actions: const [
        'If on nasal-prong oxygen with rising oxygen need or distress: START CPAP.',
        'Check prongs, circuit and delivered pressure.',
        'Increase CPAP up to 7–8 cm H₂O; titrate FiO₂.',
        'Exclude pneumothorax (transillumination, X-ray).',
        'Consider sepsis (Refer to sepsis STW); consider surfactant.',
        ...rdMonitoringActions,
      ],
      why: notImproving,
      alerts: alerts,
    );
  }

  // Remaining statuses need SpO₂ and a complete SAS.
  if (spo2 == null || sasTotal == null) {
    return ReassessOutcome(
      status: ReassessStatus.incomplete,
      title: 'Enter SpO₂ and grade all 5 SAS items',
      alerts: alerts,
    );
  }

  // 4. Improving (per STW: decreasing SAS AND SpO₂ 91–95% on stable/reducing support AND comfortable breathing).
  final sasDecreasing = prev != null && sasTotal < prev;
  final spo2InTarget = spo2 >= spo2TargetLow && spo2 <= spo2TargetHigh;
  final improving = sasDecreasing &&
      spo2InTarget &&
      i.comfortableBreathing &&
      i.stableOrReducingSupport;
  if (improving) {
    return ReassessOutcome(
      status: ReassessStatus.improving,
      title: 'IMPROVING — assess stability for weaning',
      actions: i.support == RespSupport.cpap
          ? cpapWeanSteps(peep: i.peep, fio2: i.fio2)
          : const [
              'Titrate/wean oxygen to keep SpO₂ 91–95%.',
              'Continue SpO₂ monitoring.',
            ],
      why: [
        'SAS decreasing ($prev → $sasTotal)',
        'SpO₂ $spo2% (target 91–95%)',
        'Comfortable breathing',
      ],
      alerts: alerts,
    );
  }

  return ReassessOutcome(
    status: ReassessStatus.stable,
    title: 'Stable — continue current support',
    actions: const [
      'Continue current support; titrate to SpO₂ 91–95%.',
      ...rdMonitoringActions,
    ],
    why: ['SAS $sasTotal, SpO₂ $spo2%'],
    alerts: alerts,
  );
}
