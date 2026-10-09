/// Picks the verbatim segments of an STW box that answer the question.
/// Never writes text: it only selects among the box's own segments.
library;

import '../models/stw_chunk.dart';
import '../understanding/query_analyzer.dart';

const _ignore = {
  'what', 'which', 'when', 'how', 'why', 'who', 'whom', 'is', 'are', 'the',
  'a', 'an', 'of', 'in', 'on', 'for', 'to', 'and', 'or', 'be', 'should',
  'can', 'do', 'does', 'did', 'with', 'baby', 'newborn', 'neonate',
  'neonates', 'babies', 'newborns', 'stw', 'rop', 'acs', 'rd', 'give',
  'given', 'it', 'this', 'that', 'there', 'any', 'my', 'we', 'i', 'after',
  'before', 'about', 'need', 'needed', 'mean', 'means', 'per',
};

Iterable<String> _words(String s) => RegExp(r"[a-z0-9]+(?:[./+-][a-z0-9]+)*")
    .allMatches(s.toLowerCase().replaceAll('₂', '2').replaceAll('ﬁ', 'fi')
        .replaceAll('ﬂ', 'fl'))
    .map((m) => m.group(0)!);

bool _matches(String word, Set<String> segWords) {
  if (segWords.contains(word)) return true;
  if (word.length < 5) return false;
  final stem = word.substring(0, word.length - 2);
  return segWords.any((w) => w.length >= 5 && w.startsWith(stem));
}

final _doseCue = RegExp(
    r'\d\s*(mg|ml|g\b|l/min|cm h|kg|%|doses?|hours?|weeks?)',
    caseSensitive: false);

/// Segments of [region] to show for [a]. [focus] adds words a case answer
/// must prefer (e.g. "34" for "Routine use at ≥34 weeks").
List<StwSegment> composeAnswer(
  StwChunk region,
  QueryAnalysis a, {
  Set<String> focus = const {},
}) {
  final segs = [
    for (final s in region.segments)
      if (!s.header) s,
  ];
  if (segs.isEmpty) return [StwSegment(region.text)];
  if (segs.length <= 2 && focus.isEmpty) return segs;

  final queryWords = {
    for (final w in _words(a.normalized))
      if (!_ignore.contains(w)) w,
  };

  double score(StwSegment s) {
    final segWords = _words(s.display).toSet();
    var sc = 0.0;
    for (final w in queryWords) {
      if (_matches(w, segWords)) sc += RegExp(r'^\d').hasMatch(w) ? 1.5 : 1;
    }
    for (final f in focus) {
      if (s.display.toLowerCase().contains(f.toLowerCase())) sc += 3;
    }
    if (a.intents.contains(QueryIntent.dose) && _doseCue.hasMatch(s.text)) {
      sc += 1.5;
    }
    if (a.negated && RegExp(r'\bnot\b', caseSensitive: false).hasMatch(s.text)) {
      sc += 1;
    }
    for (final abbr in a.abbreviationCandidates) {
      if (s.text.toLowerCase().startsWith('$abbr:')) sc += 6;
    }
    return sc;
  }

  final scored = [for (final s in segs) (s, score(s))];
  final best = scored.map((e) => e.$2).fold<double>(0, (m, v) => v > m ? v : m);
  if (best < 1) return segs;
  final cut = best * 0.6 < 1 ? 1.0 : best * 0.6;
  final picked = [
    for (final (s, sc) in scored)
      if (sc >= cut) s,
  ];
  return picked.length > 4 ? picked.take(4).toList() : picked;
}
