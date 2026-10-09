/// Answers a chatbot question with verbatim STW text, or asks back, or says
/// it is not covered. Pure Dart apart from the retriever.
///
/// 1. Understand: topic, intent, negation, values (query_analyzer.dart).
/// 2. Out of scope / no STW topic → not covered.
/// 3. Patient values → existing rule engines (case_router.dart).
/// 4. Otherwise rank boxes of the asked-about STW(s): keyword score +
///    intent match + negation, then a confidence gate: answer only when the
///    best box clearly wins; ask back when two are close; else not covered.
/// 5. Show only the box's verbatim segments that answer the question.
library;

import '../../data/bm25_retriever.dart';
import '../models/stw_chunk.dart';
import '../understanding/query_analyzer.dart';
import 'answer_composer.dart';
import 'case_router.dart';
import 'stw_answer.dart';

final _doseText = RegExp(
    r'\d\s*(mg|ml|l/min|cm h|mg/kg|doses?)', caseSensitive: false);
/// A time to act within (not a gestational age in weeks).
final _timeText = RegExp(
    r'\d\s*(-\s*\d+\s*)?(min\w*|hours?|h\b|days?)', caseSensitive: false);

bool _canAnswer(QueryAnalysis a, StwChunk c) {
  final text = c.segments.map((s) => s.text).join(' ');
  if (a.intents.contains(QueryIntent.dose) &&
      !a.intents.contains(QueryIntent.abbreviation) &&
      RegExp(r'\bdoses?\b|dosage|how much').hasMatch(a.normalized) &&
      !_doseText.hasMatch(text)) {
    return false;
  }
  if (_deadline.hasMatch(a.normalized) && !_timeText.hasMatch(text)) {
    return false;
  }
  return true;
}

final _deadline = RegExp(
    r'how soon|within how|how many (hours|minutes|days)|how long after|by when');

/// Intents answered by exactly one box per STW (DOs, DON'Ts, KPIs, ...).
const _singleBoxIntents = {
  'dos',
  'donts',
  'kpi',
  'prevention',
  'documentation',
  'followup',
  'abbreviation',
};

/// The one box of the question's STW(s) that answers a single-box intent
/// the question asks for (e.g. "good practices" → that STW's DOs).
StwChunk? _uniqueIntentBox(
  QueryAnalysis a,
  List<(StwChunk, double, double)> boxes,
) {
  final asked = {for (final i in a.intents) i.name}.intersection(_singleBoxIntents);
  if (asked.length != 1) return null;
  final hits = [
    for (final b in boxes)
      if (b.$1.intents.contains(asked.first)) b.$1,
  ];
  return hits.length == 1 ? hits.first : null;
}

/// Intents that pin the answer down (vs generic ones such as management).
const _specificIntents = {
  'dose',
  'contraindication',
  'wean',
  'stop',
  'escalate',
  'refer',
  'signs',
  'prevention',
  'dos',
  'donts',
  'kpi',
  'abbreviation',
  'documentation',
  'followup',
  'schedule',
};

/// "... for/in/with WORD": the condition or setting the question is about.
final _aboutCondition = RegExp(
  r'\b(?:for|in|with|during)\s+(?:a |an |the |my |this )?([a-z][a-z-]{3,})\b',
);

/// Population / setting words that never make a question out of scope.
const _genericWords = {
  'baby', 'babies', 'newborn', 'newborns', 'neonate', 'neonates', 'neonatal',
  'infant', 'infants', 'woman', 'women', 'mother', 'mothers', 'pregnancy',
  'pregnant', 'general', 'practice', 'india', 'hospital', 'facility',
  'nicu', 'sncu', 'ward', 'labour', 'labor', 'case', 'cases', 'details',
};

/// Boxes with identical content (the GA ≤34 and GA >34 moderate–severe
/// arrows both lead to START CPAP).
const _sameBox = {
  'rd_initial_preterm_cpap_caffeine': 'start_cpap',
  'rd_initial_term_moderate_severe_cpap': 'start_cpap',
};

class StwAnswerer {
  StwAnswerer(this.retriever, {this.thresholds = const AnswerThresholds()});

  final Bm25Retriever retriever;
  final AnswerThresholds thresholds;

  Set<String>? _vocabulary;

  /// Every word of the STW boxes (text, segments, titles, aliases, example
  /// questions).
  Set<String> _vocab() => _vocabulary ??= {
        for (final c in retriever.chunks)
          for (final t in [
            c.sectionTitle,
            c.text,
            ...c.aliases,
            ...c.exampleQuestions,
            for (final s in c.segments) s.display,
          ])
            for (final m in RegExp(r'[a-z]+').allMatches(
              t.toLowerCase().replaceAll('ﬁ', 'fi').replaceAll('ﬂ', 'fl'),
            ))
              m.group(0)!,
      };

  bool _known(String w) {
    if (w.contains('-')) return w.split('-').where((p) => p.isNotEmpty).every(_known);
    final v = _vocab();
    if (v.contains(w) || v.contains('${w}s')) return true;
    if (w.endsWith('s') && v.contains(w.substring(0, w.length - 1))) {
      return true;
    }
    if (w.length >= 6) {
      final stem = w.substring(0, w.length - 2);
      return v.any((x) => x.startsWith(stem));
    }
    return false;
  }

  /// A condition the STWs never mention ("dexamethasone for croup"): the
  /// question is about something else even if a drug name matches.
  String? _unknownCondition(QueryAnalysis a) {
    for (final m in _aboutCondition.allMatches(a.normalized)) {
      final w = m.group(1)!;
      if (_genericWords.contains(w) || _known(w)) continue;
      return w;
    }
    return null;
  }

  Future<StwAnswer> answer(String query) async {
    final a = analyzeQuery(query);
    if (a.normalized.isEmpty || a.outOfScope != null || a.topics.isEmpty) {
      return StwAnswer.notCovered(a);
    }
    await retriever.initialize();
    if (_unknownCondition(a) != null) return StwAnswer.notCovered(a);
    final byId = {for (final c in retriever.chunks) c.chunkId: c};

    final route = routeCase(a);
    switch (route) {
      case CaseAnswer(:final regionId, :final inputs, :final focus,
            :final reviewNote):
        final region = byId[regionId];
        if (region != null) {
          return StwAnswer.answer(
            analysis: a,
            region: region,
            lines: composeAnswer(region, a, focus: focus),
            caseSummary: CaseSummary(inputs: inputs, reviewNote: reviewNote),
          );
        }
      case CaseAsk(:final prompt, :final optionIds):
        return StwAnswer.clarify(
          analysis: a,
          prompt: prompt,
          options: [
            for (final id in optionIds)
              if (byId[id] != null) byId[id]!,
          ],
        );
      case null:
        break;
    }

    var ranked = await rank(a);
    // Only boxes that can answer this kind of question: a dose question
    // needs a box with a dose, "how soon" needs a box with a time.
    final answerable = [
      for (final r in ranked)
        if (_canAnswer(a, r.$1)) r,
    ];
    if (answerable.isNotEmpty) ranked = answerable;
    if (ranked.isEmpty) return StwAnswer.notCovered(a);
    final structural = _uniqueIntentBox(a, ranked) == ranked.first.$1;
    if (!structural && ranked.first.$3 < thresholds.minKeywordScore) {
      return StwAnswer.notCovered(a);
    }
    final top = ranked.first;
    final second = ranked
        .skip(1)
        .where((r) =>
            _sameBox[r.$1.chunkId] == null ||
            _sameBox[r.$1.chunkId] != _sameBox[top.$1.chunkId])
        .firstOrNull;
    final margin = top.$2 - (second?.$2 ?? 0);
    if (top.$2 >= thresholds.answerScore && margin >= thresholds.margin) {
      return StwAnswer.answer(
        analysis: a,
        region: top.$1,
        lines: composeAnswer(top.$1, a),
        confidence: top.$2,
      );
    }
    if (top.$2 >= thresholds.clarifyScore) {
      return StwAnswer.clarify(
        analysis: a,
        prompt: 'Which of these do you mean?',
        options: [top.$1, if (second != null) second.$1],
        confidence: top.$2,
      );
    }
    return StwAnswer.notCovered(a);
  }

  /// Boxes of the question's STW(s), best first: (box, combined score,
  /// raw keyword score).
  Future<List<(StwChunk, double, double)>> rank(QueryAnalysis a) async {
    final results = await retriever.scoreAll('${a.normalized} ${a.raw}');
    final inTopic = [
      for (final r in results)
        if (a.topics.contains(topicOfDocument(r.chunk.document))) r,
    ];
    if (inTopic.isEmpty) return const [];
    final maxScore = inTopic.first.score;
    final queryIntents = {for (final i in a.intents) i.name};
    final specific = {
      ..._specificIntents,
      // "How soon / within how many hours" asks for a time.
      if (_deadline.hasMatch(a.normalized)) 'timing',
    };
    final unique = _uniqueIntentBox(a, [
      for (final r in inTopic) (r.chunk, 0.0, r.score),
    ]);

    double combined(StwChunk c, double keyword) {
      var s = keyword / maxScore;
      final intents = c.intents.toSet();
      final shared = intents.intersection(queryIntents);
      if (identical(c, unique)) s += 0.8;
      if (shared.any(specific.contains)) {
        s += 0.6;
      } else if (shared.isNotEmpty) {
        s += 0.3;
      } else if (queryIntents.isNotEmpty) {
        s -= 0.3;
      }
      for (final only in const ['kpi', 'abbreviation']) {
        if (intents.contains(only) && !queryIntents.contains(only)) s -= 0.6;
      }
      final negBox =
          intents.contains('contraindication') || intents.contains('donts');
      if (a.negated) {
        s += negBox ? 0.5 : -0.25;
      } else if (intents.length == 1 &&
          intents.contains('contraindication') &&
          (queryIntents.contains('timing') ||
              queryIntents.contains('criteria'))) {
        // "When to give" must not land on "When NOT to give".
        s -= 0.4;
      }
      if (a.intents.contains(QueryIntent.abbreviation) &&
          intents.contains('abbreviation') &&
          c.segments.any((g) => a.abbreviationCandidates
              .any((abbr) => g.text.toLowerCase().startsWith('$abbr:')))) {
        s += 1.0;
      }
      return s;
    }

    final ranked = [
      for (final r in inTopic) (r.chunk, combined(r.chunk, r.score), r.score),
    ]..sort((x, y) => y.$2.compareTo(x.$2));
    return ranked;
  }
}

/// Confidence gate. Tuned on test/chatbot_eval/queries.json for precision:
/// asking back is preferred over a wrong answer.
class AnswerThresholds {
  const AnswerThresholds({
    this.minKeywordScore = 3.0,
    this.answerScore = 1.0,
    this.margin = 0.2,
    this.clarifyScore = 0.6,
  });

  /// Minimum raw keyword score of the best box (else not covered).
  final double minKeywordScore;

  /// Minimum combined score to answer.
  final double answerScore;

  /// Minimum lead over the next different box to answer.
  final double margin;

  /// Minimum combined score to ask back instead of "not covered".
  final double clarifyScore;
}
