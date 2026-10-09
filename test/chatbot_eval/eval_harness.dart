// Evaluation harness for the STW chatbot (see test/chatbot_eval/queries.json).
//
// A pipeline maps a question to an [EvalOutcome]: an answer (region + the
// verbatim lines shown), a clarification ("Did you mean…?") or not-covered.
// Scoring is strict about safety: an answer from a region not listed for the
// question counts as WRONG; asking back or abstaining is never "wrong".
import 'dart:convert';
import 'dart:io';

import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';

enum OutcomeKind { answer, clarify, notCovered }

class EvalOutcome {
  const EvalOutcome.answer(this.regionId, this.lines)
      : kind = OutcomeKind.answer;
  const EvalOutcome.clarify([this.regionId])
      : kind = OutcomeKind.clarify,
        lines = const [];
  const EvalOutcome.notCovered()
      : kind = OutcomeKind.notCovered,
        regionId = null,
        lines = const [];

  final OutcomeKind kind;
  final String? regionId;
  final List<String> lines;
}

class EvalCase {
  EvalCase(Map<String, dynamic> j)
      : query = j['q'] as String,
        expect = j['expect'] as String,
        regions = [...?(j['regions'] as List?)?.cast<String>()],
        lines = [...?(j['lines'] as List?)?.cast<String>()],
        tags = [...?(j['tags'] as List?)?.cast<String>()];

  final String query;
  final String expect; // answer | clarify | not_covered
  final List<String> regions;
  final List<String> lines;
  final List<String> tags;
}

enum Verdict { correct, clarified, missed, wrong }

class EvalReport {
  final results = <(EvalCase, EvalOutcome, Verdict)>[];

  int count(Verdict v, [bool Function(EvalCase)? where]) => results
      .where((r) => r.$3 == v && (where?.call(r.$1) ?? true))
      .length;

  int total([bool Function(EvalCase)? where]) =>
      results.where((r) => where?.call(r.$1) ?? true).length;

  double rate(Verdict v, [bool Function(EvalCase)? where]) {
    final n = total(where);
    return n == 0 ? 0 : count(v, where) / n;
  }

  String summary() {
    final b = StringBuffer();
    String row(String name, bool Function(EvalCase)? where) {
      final n = total(where);
      String pct(Verdict v) =>
          '${(rate(v, where) * 100).toStringAsFixed(1)}%'.padLeft(6);
      return '${name.padRight(14)} n=${n.toString().padLeft(3)}  '
          'correct ${pct(Verdict.correct)}  wrong ${pct(Verdict.wrong)}  '
          'clarify ${pct(Verdict.clarified)}  missed ${pct(Verdict.missed)}';
    }

    b.writeln(row('ALL', null));
    for (final tag in [
      'en',
      'hinglish',
      'negated',
      'case',
      'lookalike',
      'oos',
      'trap',
    ]) {
      b.writeln(row(tag, (c) => c.tags.contains(tag)));
    }
    b.writeln(row('in-scope', (c) => c.expect != 'not_covered'));
    return b.toString();
  }

  String failures({bool wrongOnly = false}) {
    final b = StringBuffer();
    for (final (c, o, v) in results) {
      if (v == Verdict.correct) continue;
      if (wrongOnly && v != Verdict.wrong) continue;
      b.writeln('  [${v.name}] "${c.query}" -> ${o.kind.name}'
          '${o.regionId == null ? '' : ' ${o.regionId}'}'
          '  (expected ${c.expect} ${c.regions.join('|')})');
    }
    return b.toString();
  }
}

List<EvalCase> loadEvalCases([String file = 'queries.json']) {
  final raw = jsonDecode(
    File('test/chatbot_eval/$file').readAsStringSync(),
  ) as List<dynamic>;
  return [for (final j in raw) EvalCase(j as Map<String, dynamic>)];
}

List<StwChunk> loadRegions() {
  final raw = jsonDecode(
    File('assets/regions/regions.json').readAsStringSync(),
  ) as List<dynamic>;
  return [for (final j in raw) StwChunk.fromJson(j as Map<String, dynamic>)];
}

Map<String, List<String>> loadSynonyms() {
  final raw = jsonDecode(
    File('assets/stw_index/clinical_synonyms.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return raw.map(
    (k, v) => MapEntry(
      k.toLowerCase(),
      (v as List<dynamic>).map((e) => e.toString().toLowerCase()).toList(),
    ),
  );
}

Verdict judge(EvalCase c, EvalOutcome o) {
  switch (c.expect) {
    case 'not_covered':
      return switch (o.kind) {
        OutcomeKind.notCovered => Verdict.correct,
        OutcomeKind.clarify => Verdict.clarified,
        OutcomeKind.answer => Verdict.wrong,
      };
    case 'clarify':
      return switch (o.kind) {
        OutcomeKind.clarify => Verdict.correct,
        OutcomeKind.notCovered => Verdict.missed,
        OutcomeKind.answer =>
          c.regions.contains(o.regionId) ? Verdict.clarified : Verdict.wrong,
      };
    default: // answer
      switch (o.kind) {
        case OutcomeKind.notCovered:
          return Verdict.missed;
        case OutcomeKind.clarify:
          return Verdict.clarified;
        case OutcomeKind.answer:
          if (!c.regions.contains(o.regionId)) return Verdict.wrong;
          final shown = o.lines.join('\n');
          final linesOk = c.lines.every(shown.contains);
          // Right box but the expected line is not among those shown.
          return linesOk ? Verdict.correct : Verdict.clarified;
      }
  }
}

Future<EvalReport> runEval(
  Future<EvalOutcome> Function(String query) pipeline, {
  String file = 'queries.json',
}) async {
  final report = EvalReport();
  for (final c in loadEvalCases(file)) {
    final o = await pipeline(c.query);
    report.results.add((c, o, judge(c, o)));
  }
  return report;
}
