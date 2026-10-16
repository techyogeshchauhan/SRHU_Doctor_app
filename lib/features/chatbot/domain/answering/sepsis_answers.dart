/// Source-card selection only; answers are complete, source-backed segments.
library;

import '../../../sepsis/domain/sepsis_rules.dart';
import '../understanding/query_analyzer.dart';
import 'case_router.dart';

num? _gestation(String n) {
  final m =
      RegExp(r'\b(\d{1,2}(?:\.\d+)?)(?:\s*\+\s*(\d))?\s*(?:weeks?|wks?|wk)\b')
          .firstMatch(n);
  if (m == null ||
      RegExp(r'(above|below|over|under|more than|less than|[<>]=?)\s*$')
          .hasMatch(n.substring(0, m.start))) {
    return null;
  }
  if (RegExp(r'^\s*old\b').hasMatch(n.substring(m.end))) return null;
  final suffix =
      RegExp(r'^\s*(?:\+|and)?\s*(\d)\s*days?').firstMatch(n.substring(m.end));
  final days = num.tryParse(m.group(2) ?? suffix?.group(1) ?? '0')!;
  if (days > 6) return null;
  return num.parse(m.group(1)!) + days / 7;
}

num? _birthWeight(String n) {
  final m = RegExp(
          r'\b(?:birth weight|bw)\s*(?:is|of|=|:)?\s*(\d+(?:\.\d+)?)\s*(kg|g|gm|grams?)\b')
      .firstMatch(n);
  if (m == null) return null;
  return num.parse(m.group(1)!) * (m.group(2) == 'kg' ? 1000 : 1);
}

CaseRoute? routeSepsisQuestion(QueryAnalysis a) {
  if (a.topics.length != 1 || !a.topics.contains(StwTopic.sepsis)) return null;
  final n = a.normalized;
  final yellow = RegExp(r'\b(one|1|two|2|three|3) yellow flags?').firstMatch(n);
  final red = RegExp(r'\b(any|one|1|two|2) red flags?').hasMatch(n);
  if ((yellow != null || red) && !a.negated) {
    final count = switch (yellow?.group(1)) {
      'one' || '1' => 1,
      'two' || '2' => 2,
      'three' || '3' => 3,
      _ => 0
    };
    final c = classifySepsis(
        redFlags: red ? 1 : 0,
        yellowFlags: count,
        gestationWeeks: _gestation(
            a.raw.toLowerCase().replaceAll('≤', '<=').replaceAll('≥', '>=')),
        birthWeightG: _birthWeight(n));
    switch (c) {
      case SepsisClassification.highProbability:
        return const CaseAnswer(
            'sepsis_high_probability', 'Recorded red/yellow flag criterion');
      case SepsisClassification.observe:
        return const CaseAnswer('sepsis_observation',
            'One yellow flag; gestation >32 weeks; birth weight ≥1500 g');
      case SepsisClassification.overlap:
        return const CaseAsk(
            'These inputs match both PDF boxes: one yellow flag with gestation >32 weeks and birth weight <1500 g. The PDF does not state precedence; clinical review is required.',
            ['sepsis_high_probability', 'sepsis_observation']);
      case SepsisClassification.incomplete:
        return const CaseAsk(
            'For one yellow flag, what are the gestation at birth and birth weight? The PDF uses ≤32 weeks or <1500 g for high probability, and >32 weeks for observation.',
            ['sepsis_high_probability', 'sepsis_observation']);
      case SepsisClassification.noListedCriterion:
        break;
    }
  }
  String? card;
  if (a.intents.contains(QueryIntent.kpi)) {
    card = 'kpis';
  } else if (a.intents.contains(QueryIntent.abbreviation)) {
    card = 'abbreviations';
  } else if (a.intents.contains(QueryIntent.donts) ||
      RegExp(r'crp|procalcitonin').hasMatch(n)) {
    card = 'donts';
  } else if (a.intents.contains(QueryIntent.dos)) {
    card = 'dos';
  } else if (RegExp(r'prevent|hand hygiene|asepsis|housekeeping').hasMatch(n)) {
    card = 'prevention';
  } else if (RegExp(r'video|related information|youtu').hasMatch(n)) {
    card = 'related_information';
  } else if (RegExp(r'observ|at.risk|suspect sepsis|4.?6|48.?72').hasMatch(n)) {
    card = 'observation';
  } else if (RegExp(r'5.day|day 5|five.day|5 days').hasMatch(n) &&
      !RegExp(r'duration|positive|meningitis|pneumonia|symptomatic')
          .hasMatch(n)) {
    card = 'review_day5';
  } else if (RegExp(r'24.?48|early stop').hasMatch(n)) {
    card = 'early_stopping';
  } else if (RegExp(
          r'duration|how long|how many days|meningitis|pneumonia|culture positive|positive.*culture|symptomatic.*day|asymptomatic')
      .hasMatch(n)) {
    card = 'duration';
  } else if (RegExp(r'worsen|upgrade|new red|red flag.*after').hasMatch(n)) {
    card = 'review_worsened';
  } else if (RegExp(r'improv|still present').hasMatch(n)) {
    card = 'review_improving';
  } else if (RegExp(r'disappear|recover|stop antibiotic').hasMatch(n)) {
    card = 'review_disappeared';
  } else if (RegExp(r'48.*review|review.*48|48.hour').hasMatch(n)) {
    return const CaseAsk('Which signs are present at the 48-hour review?', [
      'sepsis_review_disappeared',
      'sepsis_review_improving',
      'sepsis_review_worsened'
    ]);
  } else if (RegExp(r'seizure').hasMatch(n)) {
    card = 'seizure';
  } else if (RegExp(
          r'maternal|mother|pprom|liquor|chorioamnionitis|membranes|pv examination')
      .hasMatch(n)) {
    card = RegExp(r'liquor|chorioamnionitis').hasMatch(n)
        ? 'red_flags'
        : 'maternal_risks';
  } else if (RegExp(r'red flags?|sclerema').hasMatch(n)) {
    card = 'red_flags';
  } else if (RegExp(
          r'yellow|signs|symptoms|fast breath|\brr\b|\bhr\b|tachycardia|hypothermia|fever')
      .hasMatch(n)) {
    card = 'yellow_signs';
  } else if (RegExp(r'observ|at.risk|suspect sepsis|4.?6|48.?72').hasMatch(n)) {
    card = 'observation';
  } else if (RegExp(r'within|1 hour|first.*dose|before.*antibiotic|how soon')
      .hasMatch(n)) {
    card = 'dos';
  } else if (RegExp(
          r'probability|treat|antibiotic|indicat|blood culture|lumbar puncture|\blp\b|supportive|investigat|criteria')
      .hasMatch(n)) {
    card = 'high_probability';
  } else if (RegExp(r'assess|screen|admission').hasMatch(n)) {
    card = 'assessment';
  }
  return card == null
      ? null
      : CaseAnswer('sepsis_$card', 'Sepsis STW source guidance');
}
