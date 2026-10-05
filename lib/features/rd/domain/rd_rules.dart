/// Decision rules for the STW "Respiratory Distress in Neonates" (ICD-11 KB23).
///
/// Pure Dart, no Flutter imports, so every branch can be unit-tested and
/// reviewed independently of the UI. Gestational age thresholds use
/// completed weeks (e.g. 34+3 counts as 34 weeks).
library;

import 'sas.dart';

// ---------------------------------------------------------------------------
// Diagnosis
// ---------------------------------------------------------------------------

enum RdSign {
  rrAbove60('RR >60/min'),
  retractions('Chest retractions'),
  nasalFlaring('Nasal flaring'),
  grunting('Grunting');

  const RdSign(this.label);
  final String label;
}

/// "Presence of ANY ONE" of the signs.
bool meetsRdCriteria(Set<RdSign> signs) => signs.isNotEmpty;

/// "RR >60/min": a measured RR above this counts as the sign.
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
      // TO CONFIRM WITH SUPERVISOR: GA 34+3 weeks is currently treated as "<=34 weeks" (completed weeks).
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

  /// Whether the "<34 weeks" criterion (caffeine, surfactant) is met.
  /// With the birth-weight surrogate this is presumed and must be confirmed.
  bool get meetsBelow34OrSurrogate =>
      isBelow34 == true || (usesBwSurrogate && band == GaBand.upTo34);

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
      'support).'),
  notIndicated('Caffeine: not indicated (GA ≥34 weeks).'),
  confirmGa('Start caffeine citrate if GA is <34 weeks.');

  const CaffeineAdvice(this.text);
  final String text;
}

enum FeedingAdvice {
  directBreastfeed('Direct breastfeed (mild distress, stable).'),
  gastricTube('Gastric-tube feeds (moderate–severe distress or on CPAP), if stable.'),
  ivFluids('IV fluids; start enteral feeds once stable.');

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
            'START CPAP 5–6 cm H₂O (within 30 min of diagnosis/admission).',
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
  const RdInitialResult.pending(String this.pending) : plan = null;
  const RdInitialResult.ready(RdInitialPlan this.plan) : pending = null;

  final String? pending;
  final RdInitialPlan? plan;
}

RdInitialResult initialPlan({
  required Set<RdSign> signs,
  required Gestation gestation,
  required SasScore sas,
  bool severeDistress = false,
  bool recurrentApnea = false,
  bool poorPerfusion = false,
  bool abdominalSigns = false,
}) {
  if (!meetsRdCriteria(signs)) {
    return const RdInitialResult.pending(
      'Tick at least one sign of respiratory distress '
      '(RR >60/min, chest retractions, nasal flaring or grunting).',
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
    support = RespSupport.nasalO2;
    why.add('GA >34 weeks with mild RD (SAS ${sas.total} ≤3) '
        '→ nasal-prong oxygen.');
  }

  final CaffeineAdvice caffeine;
  if (gestation.isBelow34 == true) {
    caffeine = CaffeineAdvice.indicated;
    why.add('GA <34 weeks on respiratory support → start caffeine citrate.');
  } else if (gestation.usesBwSurrogate && band == GaBand.upTo34) {
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
  } else if (support == RespSupport.cpap || severity == RdSeverity.moderateSevere) {
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

enum SepsisTrigger {
  perinatalRisk('Perinatal risk factors'),
  systemicIllness('Systemic illness'),
  worseningDistress('Worsening distress'),
  risingFio2('Rising FiO₂');

  const SepsisTrigger(this.label);
  final String label;
}

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
    this.sepsisTriggers = const {},
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
  final Set<SepsisTrigger> sepsisTriggers;

  /// FiO₂ as an integer percentage, avoiding floating-point comparisons.
  int get fio2Percent => (fio2 * 100).round();
}

enum ReassessStatus {
  incomplete,
  cpapFailure,
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

/// Surfactant criteria: <34 weeks on CPAP needing PEEP >6 cm H₂O AND
/// FiO₂ >0.30 to keep SpO₂ 91–95%.
bool meetsSurfactantCriteria(ReassessInput i) =>
    i.support == RespSupport.cpap &&
    i.gestation.meetsBelow34OrSurrogate &&
    i.peep > 6 &&
    i.fio2Percent > 30;

/// Next weaning step on CPAP: FiO₂ first to 0.21, then PEEP down in
/// 1 cm H₂O steps to 4–5 cm H₂O, then stop.
List<String> cpapWeanSteps({required int peep, required double fio2}) {
  if ((fio2 * 100).round() > 21) {
    return [
      'Wean FiO₂ first (now ${fio2.toStringAsFixed(2)}) towards 0.21, '
          'keeping SpO₂ 91–95%.',
      'Keep PEEP at $peep cm H₂O until FiO₂ is 0.21.',
    ];
  }
  if (peep > 5) {
    return [
      'FiO₂ is 0.21 → reduce CPAP by 1 cm H₂O: $peep → ${peep - 1} cm H₂O.',
      'Continue stepwise reduction to 4–5 cm H₂O.',
    ];
  }
  return [
    'FiO₂ 0.21 and PEEP $peep cm H₂O → stop CPAP when stable.',
    'Continue SpO₂ monitoring for 24 h after stopping.',
  ];
}

ReassessOutcome reassess(ReassessInput i) {
  final spo2 = i.spo2;
  final sasTotal = i.sas.isComplete ? i.sas.total : null;
  final prev = i.previousSasTotal;

  final alerts = <String>[
    if (spo2 != null && spo2 > spo2TargetHigh && i.support != RespSupport.none)
      'SpO₂ above target range (91–95%).',
    if (i.sepsisTriggers.isNotEmpty || i.risingO2Need)
      'Consider sepsis (see STW: Sepsis in Neonates).',
  ];

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
          'Refer urgently for mechanical ventilation / higher-level care.',
          'Do NOT delay mechanical ventilation or referral.',
          if (meetsSurfactantCriteria(i))
            'Surfactant criteria are also met — consider surfactant.',
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
      title: 'SURFACTANT indicated',
      actions: const [
        'Administer surfactant (STW: within 2 hours).',
        'Continue CPAP; titrate FiO₂ to SpO₂ 91–95%.',
        'Reassess frequently.',
      ],
      why: [
        i.gestation.isBelow34 == true
            ? 'GA <34 weeks on CPAP'
            : 'GA uncertain, BW ≤$bwSurrogateThresholdG g on CPAP '
                '(confirm GA <34 weeks)',
        'PEEP ${i.peep} cm H₂O (>6)',
        'FiO₂ ${i.fio2.toStringAsFixed(2)} (>0.30)',
      ],
      alerts: alerts,
    );
  }

  // 3. Not improving / worsening.
  final notImproving = <String>[
    if (sasTotal != null && prev != null && sasTotal > prev)
      'SAS increasing ($prev → $sasTotal)'
    else if (sasTotal != null && (prev == null || sasTotal == prev) && sasTotal >= 4)
      'SAS persisting at $sasTotal (≥4)',
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
          if (i.peep < peepMax)
            'Increase PEEP stepwise: ${i.peep} → ${i.peep + 1} cm H₂O '
                '(up to 7–8 cm H₂O).'
          else
            'PEEP already at $peepMax cm H₂O — if no response, treat as '
                'CPAP failure and refer.',
          'Titrate FiO₂ to target SpO₂ 91–95%.',
          'Look for/treat underlying cause.',
          'Consider surfactant if criteria met '
              '(<34 wk, PEEP >6 cm H₂O and FiO₂ >0.30).',
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
        'Titrate oxygen to keep SpO₂ 91–95%.',
        'Look for/treat underlying cause.',
        'Consider sepsis if risk factors or triggers present.',
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
  final spo2InTarget =
      spo2 >= spo2TargetLow && spo2 <= spo2TargetHigh;
  final improving = sasDecreasing && spo2InTarget && i.comfortableBreathing;
  if (improving) {
    return ReassessOutcome(
      status: ReassessStatus.improving,
      title: 'IMPROVING — wean support',
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
      'Reassess frequently: clinical status, SAS, SpO₂, FiO₂ requirement.',
    ],
    why: ['SAS $sasTotal, SpO₂ $spo2%'],
    alerts: alerts,
  );
}
