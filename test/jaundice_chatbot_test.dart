import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';
import 'package:neonatal_stw/features/chatbot/domain/understanding/query_analyzer.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_content.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_map.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_region.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = jsonDecode(File('assets/regions/regions.json').readAsStringSync())
      as List;
  final answerer = StwAnswerer(Bm25Retriever(
      initialChunks: raw.map((r) => StwChunk.fromJson(r)).toList()));

  test('jaundice questions return whole verbatim Jaundice STW boxes', () async {
    for (final (query, suffix) in [
      ('What is serious jaundice?', 'serious'),
      (
        'Which jaundice signs are listed for intensive phototherapy?',
        'serious'
      ),
      ('Kramer zones for jaundice', 'kramer'),
      ('When to measure TSB in jaundice?', 'needs_tsb'),
      ('When to stop phototherapy?', 'stop_pt'),
      ('Exchange transfusion volume', 'optimal_ebt'),
      ('How to give optimal phototherapy?', 'optimal_pt'),
      ('Investigations for neonatal jaundice', 'investigation'),
      ('Jaundice discharge advice', 'discharge'),
      ('Risk factors for neonatal jaundice', 'risk_factors'),
      ('Can sunlight be used for jaundice?', 'donts'),
      ('Phenobarbitone for jaundice?', 'donts'),
      ('Jaundice in a 33 week baby', 'scope'),
    ]) {
      final a = await answerer.answer(query);
      expect(a.kind, AnswerKind.answer, reason: query);
      expect(a.region?.chunkId, 'jaundice_$suffix', reason: query);
      expect(a.lines.map((l) => l.text), jaundiceEvidence['jaundice_$suffix'],
          reason: query);
    }
  });

  test('general treatment starts at the flowchart question; no cut-offs',
      () async {
    for (final q in ['Neonatal jaundice treatment', 'piliya ka ilaj kya hai']) {
      final a = await answerer.answer(q);
      expect(a.kind, AnswerKind.clarify, reason: q);
      expect(a.options.map((o) => o.chunkId), contains('jaundice_serious'));
    }
    for (final q in [
      'Phototherapy threshold for neonatal jaundice',
      'What is the phototherapy cutoff at 48 hours?',
      'Bilirubin level for exchange transfusion',
    ]) {
      expect((await answerer.answer(q)).kind, AnswerKind.notCovered, reason: q);
    }
  });

  test('explicit triage questions keep the Triage box', () async {
    final a = await answerer
        .answer('What does the triage STW recommend for serious jaundice?');
    expect(a.region?.chunkId, 'triage_jaundice');
  });

  test('case values: RR, Kramer zone, age, signs, kg; TSB is not BG', () {
    final e = analyzeQuery(
            '36+2 wk, 2.4 kg, 30 hrs old, RR 70/min, grunting, no flaring, '
            'jaundice up to legs, lethargic, TSB 18 mg/dL')
        .entities;
    expect(e.gaWeeks, 36);
    expect(e.gaDays, 2);
    expect(e.weightG, 2400);
    expect(e.ageHours, 30);
    expect(e.rr, 70);
    expect(e.rdSigns, {'grunting'});
    expect(e.jaundice, isTrue);
    expect(e.kramerZone, 4);
    expect(e.abeSigns, {'lethargy'});
    expect(e.tsb, 18);
    expect(e.bg, isNull);
    expect(analyzeQuery('BG 40 mg/dl').entities.bg, 40);
    expect(analyzeQuery('chest retractions').entities.kramerZone, isNull);
    expect(analyzeQuery('HR 150 bpm').entities.rr, isNull);
  });

  test('STW map shows the Jaundice STW with its boxes', () {
    final regions = {
      for (final r in raw)
        r['id'] as String: StwRegionInfo(
            id: r['id'],
            document: r['document'],
            page: r['page'],
            text: r['text'])
    };
    final graph = StwMapData.fromJson(jsonDecode(
        File('assets/knowledge_graph/stw_map.json').readAsStringSync()));
    final map = buildStwMap(regions: regions, data: graph);
    expect(map.roots.where((r) => r.topic == NeonatalCondition.jaundice),
        hasLength(1));
    for (final id in jaundiceEvidence.keys) {
      expect(graph.headings[id], jaundiceHeadings[id], reason: id);
    }
    // The Triage box's "Refer to STW on neonatal jaundice" now has a target.
    expect(graph.links.where((l) => l.id == 'triage-jaundice').single.to,
        NeonatalCondition.jaundice);
  });
}
