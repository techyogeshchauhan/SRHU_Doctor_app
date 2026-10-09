/// Routes questions that carry patient values ("BG 30, no symptoms",
/// "ACS at 35 weeks") through the app's existing, tested STW rule engines.
/// Pure Dart. No clinical logic of its own: every decision below is a call
/// to hypo_rules / ancs_rules / rd_rules / sas / rop_rules. A missing value
/// is asked for, never assumed.
library;

import '../../../ancs/domain/ancs_rules.dart';
import '../../../hypoglycemia/domain/hypo_rules.dart';
import '../../../rd/domain/rd_rules.dart';
import '../../../rd/domain/sas.dart';
import '../../../rop/domain/rop_rules.dart';
import '../understanding/query_analyzer.dart';

sealed class CaseRoute {
  const CaseRoute();
}

/// Answer from [regionId], preferring segments that mention [focus].
class CaseAnswer extends CaseRoute {
  const CaseAnswer(
    this.regionId,
    this.inputs, {
    this.focus = const {},
    this.reviewNote,
  });
  final String regionId;
  final String inputs;
  final Set<String> focus;
  final String? reviewNote;
}

/// A value the rules need is missing: ask for it.
class CaseAsk extends CaseRoute {
  const CaseAsk(this.prompt, this.optionIds);
  final String prompt;
  final List<String> optionIds;
}

String _join(List<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(' · ');

CaseRoute? routeCase(QueryAnalysis a) {
  final e = a.entities;
  if (!e.hasPatientValue && !e.glucoseLow) return null;
  if (a.topics.contains(StwTopic.hypo)) {
    final r = _hypo(a);
    if (r != null) return r;
  }
  if (a.topics.contains(StwTopic.ancs)) {
    final r = _ancs(a);
    if (r != null) return r;
  }
  if (a.topics.contains(StwTopic.rd)) {
    final r = _rd(a);
    if (r != null) return r;
  }
  if (a.topics.contains(StwTopic.rop)) {
    final r = _rop(a);
    if (r != null) return r;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Hypoglycemia (hypo_rules.dart)
// ---------------------------------------------------------------------------

String? _symptomText(bool? s) =>
    s == null ? null : (s ? 'symptoms present' : 'no symptoms');

CaseRoute? _hypo(QueryAnalysis a) {
  final e = a.entities;

  // On IV glucose: re-check while on a known GIR.
  if (e.onIv && e.gir != null && (e.bg != null || e.glucoseNormal)) {
    final outcome = hypoIvOutcome(
      gir: e.gir,
      // "Sugar normal" is read as euglycemic (BG ≥45 mg/dL).
      bg: e.bg ?? hypoThresholdMgDl,
      euglycemic24h: e.euglycemic24h,
      toleratingFeeds: e.feedingWell,
    )!;
    final inputs = _join([
      'GIR ${e.gir} mg/kg/min',
      e.bg != null ? 'BG ${e.bg} mg/dL' : 'blood glucose normal',
      if (e.euglycemic24h) 'euglycemic for 24 hours',
      if (e.feedingWell) 'tolerating feeds',
    ]);
    return switch (outcome) {
      HypoIvOutcome.increaseGir => CaseAnswer('hypo_increase_gir', inputs),
      HypoIvOutcome.maxGirReached => CaseAnswer(
          'hypo_increase_gir',
          inputs,
          focus: const {'maximum 12'},
        ),
      HypoIvOutcome.awaitEuglycemia24h ||
      HypoIvOutcome.wean =>
        CaseAnswer('hypo_euglycemic_wean', inputs),
      HypoIvOutcome.stopIv ||
      HypoIvOutcome.stopCriteriaNotMet =>
        CaseAnswer('hypo_stop_iv', inputs),
      HypoIvOutcome.girBelowStw => CaseAnswer(
          'hypo_stop_iv',
          inputs,
          reviewNote: 'A GIR below 4 mg/kg/min is not addressed by the STW.',
        ),
    };
  }

  // 1-hour re-check after supervised feeding.
  if (e.afterFeed && e.bg != null) {
    final outcome = hypoRecheckOutcome(e.bg, e.symptomatic == true)!;
    return CaseAnswer(
      'hypo_recheck_1h',
      _join(['1-hour re-check BG ${e.bg} mg/dL', _symptomText(e.symptomatic)]),
      focus: {
        outcome == HypoRecheckOutcome.continueFeeds
            ? 'Continue feeds'
            : 'Start IV glucose infusion',
      },
    );
  }

  final bg = e.bg;
  if (bg != null) {
    if (bg >= hypoThresholdMgDl) {
      return CaseAnswer(
        'hypo_flowchart_entry',
        _join(['BG $bg mg/dL', _symptomText(e.symptomatic)]),
        reviewNote: 'The flowchart starts at BG <45 mg/dL; the STW gives no '
            'other action for BG ≥45 mg/dL than the monitoring schedule.',
      );
    }
    if (e.symptomatic == null && bg >= hypoSevereThresholdMgDl) {
      return CaseAsk(
        'BG $bg mg/dL is below 45 mg/dL. Are any of the listed symptoms or '
        'signs present (stupor, lethargy, limpness; jitteriness, tremors, '
        'convulsions; cyanosis, apnoea or tachypnoea; weak or high-pitched '
        'cry; unable to feed)?',
        const ['hypo_asymptomatic_branch', 'hypo_symptomatic_branch'],
      );
    }
    // Only whether any symptom is present matters for the branch.
    final branch = hypoBranch(
      bg,
      e.symptomatic == true ? {HypoSymptom.values.first} : {},
    )!;
    final inputs = _join(['BG $bg mg/dL', _symptomText(e.symptomatic)]);
    return branch == HypoBranch.ivGlucose
        ? CaseAnswer('hypo_symptomatic_branch', inputs)
        : CaseAnswer('hypo_asymptomatic_branch', inputs);
  }

  // "Sugar is low, what to do?" without a value.
  if (e.glucoseLow &&
      e.symptomatic == null &&
      a.intents.contains(QueryIntent.management)) {
    return const CaseAsk(
      'Please share the blood glucose value (mg/dL) and whether any '
      'symptoms or signs are present — the STW branch depends on both.',
      ['hypo_asymptomatic_branch', 'hypo_symptomatic_branch'],
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// ANCS (ancs_rules.dart)
// ---------------------------------------------------------------------------

CaseRoute? _ancs(QueryAnalysis a) {
  final e = a.entities;
  if (e.repeatCourseGiven) {
    return const CaseAnswer(
      'ancs_when_not_to_give',
      'a repeat course has already been given',
      focus: {'More than one repeat course'},
    );
  }
  if (e.infection) {
    return CaseAnswer(
      'ancs_when_not_to_give',
      _join([
        if (e.gaWeeks != null && e.gaComparator == null) 'GA ${e.gaWeeks} weeks',
        'clinical chorioamnionitis / systemic infection',
      ]),
      focus: const {'chorioamnionitis'},
    );
  }
  final weeks = e.gaComparator == null ? e.gaWeeks : null;
  if (weeks != null) {
    final r = evaluateAncs(AncsInput(gaWeeks: weeks));
    final inputs = _join([
      'GA $weeks weeks',
      if (e.causes.isNotEmpty) e.causes.join(', '),
      if (e.daysSincePreviousCourse != null)
        'previous course ${e.daysSincePreviousCourse} days ago',
    ]);
    if (r.decision == AncsDecision.doNotGive) {
      return CaseAnswer('ancs_when_not_to_give', inputs, focus: const {'34'});
    }
    if (!ancsGaInWindow(weeks)) {
      return CaseAnswer('ancs_when_to_give', inputs);
    }
    if (e.daysSincePreviousCourse != null) {
      return CaseAnswer('ancs_repeat_course', inputs,
          focus: const {'7 days'});
    }
    // In the window: the decision needs all five criteria.
    return CaseAnswer('ancs_eligibility', inputs);
  }
  if (e.daysSincePreviousCourse != null) {
    return CaseAnswer(
      'ancs_repeat_course',
      'previous course ${e.daysSincePreviousCourse} days ago',
      focus: const {'7 days'},
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// Respiratory distress (rd_rules.dart, sas.dart)
// ---------------------------------------------------------------------------

GaBand? _rdBand(QueryEntities e) {
  if (e.term) return GaBand.above34;
  final w = e.gaWeeks;
  if (w == null) return null;
  if (e.gaComparator == '>' && w >= 34) return GaBand.above34;
  if (e.gaComparator != null) return null;
  return Gestation(gaWeeks: w).band;
}

CaseRoute? _rd(QueryAnalysis a) {
  final e = a.entities;
  final band = _rdBand(e);
  final ga = e.gaWeeks == null
      ? (e.term ? 'term' : null)
      : e.gaComparator == '>'
          ? 'GA >${e.gaWeeks} weeks'
          : e.gaComparator == null
              ? 'GA ${e.gaWeeks} weeks'
              : null;
  if (e.peep != null && e.fio2Percent != null) {
    return CaseAnswer(
      'rd_surfactant_indication',
      _join([ga, 'PEEP ${e.peep} cm H₂O', 'FiO₂ ${e.fio2Percent!.round()}%']),
    );
  }
  if (band == null) return null;
  final sas = e.sas;
  if (sas != null) {
    final severity = RdSeverity.fromTotal(sas);
    final inputs = _join([ga, 'SAS $sas (${severity.label})']);
    if (band == GaBand.upTo34) {
      return CaseAnswer('rd_initial_preterm_cpap_caffeine', inputs);
    }
    return severity.isModerateOrSevere
        ? CaseAnswer('rd_initial_term_moderate_severe_cpap', inputs)
        : CaseAnswer('rd_initial_term_mild_nasal_o2', inputs);
  }
  if (band == GaBand.above34 && e.severityWord != null) {
    final inputs = _join([
      ga ?? 'GA >34 weeks',
      e.severityWord == 'mild' ? 'mild distress' : 'moderate–severe distress',
    ]);
    return e.severityWord == 'mild'
        ? CaseAnswer('rd_initial_term_mild_nasal_o2', inputs)
        : CaseAnswer('rd_initial_term_moderate_severe_cpap', inputs);
  }
  if (band == GaBand.upTo34 &&
      (a.intents.contains(QueryIntent.management) ||
          RegExp(r'grunt|distress|retraction|flaring').hasMatch(a.normalized))) {
    return CaseAnswer('rd_initial_preterm_cpap_caffeine', ga ?? '');
  }
  if (band == GaBand.above34 &&
      a.intents.contains(QueryIntent.management)) {
    return const CaseAsk(
      'For GA >34 weeks the STW decides by the Silverman-Andersen score. '
      'What is the SAS (0–10)?',
      ['rd_initial_term_mild_nasal_o2', 'rd_initial_term_moderate_severe_cpap'],
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// ROP (rop_rules.dart)
// ---------------------------------------------------------------------------

CaseRoute? _rop(QueryAnalysis a) {
  final e = a.entities;
  final weeks = e.gaComparator == null ? e.gaWeeks : null;
  if (weeks == null && e.weightG == null) return null;
  final inputs = _join([
    if (weeks != null) 'GA $weeks weeks',
    if (e.weightG != null) 'birth weight ${e.weightG} g',
  ]);
  final asksWhen = a.intents.contains(QueryIntent.timing) ||
      a.intents.contains(QueryIntent.schedule);
  if (asksWhen && !a.normalized.contains('need')) {
    final early = (weeks != null && weeks < 28) ||
        (e.weightG != null && e.weightG! < 1200);
    return CaseAnswer(
      'rop_when_to_screen',
      inputs,
      focus: {early ? '2-3 weeks' : 'By 4 weeks'},
    );
  }
  final eligibility = ropEligibility(gaWeeks: weeks, birthWeightG: e.weightG);
  return CaseAnswer(
    'rop_whom_to_screen',
    eligibility.eligible == true
        ? '$inputs — meets: ${eligibility.reasons.join('; ')}'
        : inputs,
  );
}
