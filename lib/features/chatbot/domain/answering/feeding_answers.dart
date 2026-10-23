/// Selects complete source cards, never composes new clinical recommendations.
library;

import '../../../feeding/domain/feeding_rules.dart';
import '../understanding/query_analyzer.dart';

String? feedingAnswerRegion(QueryAnalysis a) {
  if (a.topics.length != 1 || !a.topics.contains(StwTopic.feeding)) {
    return null;
  }
  final n = a.normalized;
  if (a.intents.contains(QueryIntent.abbreviation)) {
    return 'feeding_abbreviations';
  }
  if (a.intents.contains(QueryIntent.kpi)) {
    return 'feeding_kpis';
  }
  if (a.intents.contains(QueryIntent.dos)) {
    return 'feeding_dos';
  }
  if (RegExp(
          r'gastric residual|abdominal girth|monitor|growth chart|intergrowth')
      .hasMatch(n)) {
    return 'feeding_monitoring';
  }
  if (a.intents.contains(QueryIntent.donts)) {
    return 'feeding_donts';
  }
  if (RegExp(r'poor weight gain|fortifi').hasMatch(n)) {
    return 'feeding_poor_gain';
  }
  if (RegExp(r'vitamin d').hasMatch(n)) {
    return 'feeding_vitamin_d';
  }
  if (RegExp(r'\biron\b').hasMatch(n)) {
    return 'feeding_iron';
  }
  if (RegExp(r'calcium|phosphorus|phosphate|\balp\b').hasMatch(n)) {
    return 'feeding_minerals';
  }
  if (RegExp(r'\bzinc\b|duplication|count nutrients').hasMatch(n)) {
    return 'feeding_supplement_review';
  }
  if (RegExp(
          r'milk source|donor milk|mother.?s own milk|colostrum|express|\blmu\b')
      .hasMatch(n)) {
    return 'feeding_milk';
  }
  if (RegExp(r'feeding route|route of feeding|og feeds|oral difficulty')
      .hasMatch(n)) {
    return 'feeding_route';
  }
  if (RegExp(r'iv.*(type|sodium|potassium|dextrose)|kcl|maintenance fluid')
      .hasMatch(n)) {
    return 'feeding_iv_type';
  }
  if (RegExp(r'taper|transition|iv volume').hasMatch(n)) {
    return 'feeding_iv_review';
  }
  if (RegExp(r'total fluid|daily fluid|day of life').hasMatch(n)) {
    return 'feeding_fluids';
  }
  if (RegExp(r'frequency|hourly|volume per feed|full feeds').hasMatch(n)) {
    return 'feeding_plan_notes';
  }
  if (RegExp(r'contraindicat|unstable|stability|bilious|bloody stool')
      .hasMatch(n)) {
    return 'feeding_stability';
  }
  if (RegExp(r'start|advance|aedf|redf').hasMatch(n)) {
    final e = a.entities;
    // No antenatal finding is inferred from its absence in the question.
    final flow =
        RegExp(r'no (antenatal )?(aedf|redf)|without (antenatal )?(aedf|redf)')
                .hasMatch(n)
            ? false
            : RegExp(r'with (antenatal )?(aedf|redf)|(aedf|redf) present')
                    .hasMatch(n)
                ? true
                : null;
    final plan = feedingStart(
        birthGaWeeks: e.gaComparator == null ? e.gaWeeks : null,
        birthWeightG: e.weightG,
        aedf: flow);
    return switch (plan) {
      FeedingStart.standard => 'feeding_standard',
      FeedingStart.aedf => 'feeding_aedf',
      FeedingStart.verySmall => 'feeding_small',
      null => null,
    };
  }
  return null;
}
