import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';
import 'package:neonatal_stw/features/chatbot/domain/retriever/stw_retriever.dart';

void main() {
  group('Goal A Safety Layer: STW Chatbot Retrieval & Grounding Tests', () {
    late Bm25Retriever retriever;
    late List<StwChunk> allChunks;

    setUpAll(() async {
      final indexFile = File('assets/stw_index/stw_index.json');
      expect(indexFile.existsSync(), isTrue,
          reason: 'assets/stw_index/stw_index.json must exist');

      final rawIndex = jsonDecode(await indexFile.readAsString()) as List<dynamic>;
      allChunks = rawIndex
          .map((e) => StwChunk.fromJson(e as Map<String, dynamic>))
          .toList();

      final synFile = File('assets/stw_index/clinical_synonyms.json');
      expect(synFile.existsSync(), isTrue,
          reason: 'assets/stw_index/clinical_synonyms.json must exist');

      final rawSyn = jsonDecode(await synFile.readAsString()) as Map<String, dynamic>;
      final synonyms = rawSyn.map(
        (key, value) => MapEntry(
          key.toLowerCase(),
          (value as List<dynamic>).map((e) => e.toString().toLowerCase()).toList(),
        ),
      );

      retriever = Bm25Retriever(
        initialChunks: allChunks,
        initialSynonyms: synonyms,
      );
    });

    test('1. Every chunk has non-empty text, valid page, and valid normalized bboxes', () {
      expect(allChunks.length, greaterThanOrEqualTo(30));

      for (final chunk in allChunks) {
        expect(chunk.chunkId.isNotEmpty, isTrue);
        expect(chunk.document.isNotEmpty, isTrue);
        expect(chunk.page, equals(1));
        expect(chunk.sectionTitle.isNotEmpty, isTrue);
        expect(chunk.text.trim().isNotEmpty, isTrue);
        expect(chunk.boundingBoxes.isNotEmpty, isTrue,
            reason: '${chunk.chunkId} must have at least 1 bounding box');

        for (final bbox in chunk.boundingBoxes) {
          expect(bbox.x, inInclusiveRange(0.0, 1.0));
          expect(bbox.y, inInclusiveRange(0.0, 1.0));
          expect(bbox.width, inInclusiveRange(0.0, 1.0));
          expect(bbox.height, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    // 22 Sample clinical queries across RD and ROP workflows
    final clinicalQueries = <String, String>{
      'CPAP in preterm neonates ≤34 weeks': 'rd_initial_preterm_cpap_caffeine',
      'caffeine citrate loading dose 20 mg/kg': 'rd_initial_preterm_cpap_caffeine',
      'surfactant therapy criteria PEEP >6 FiO2 >0.30': 'rd_surfactant_indication',
      'Silverman Andersen score grading criteria': 'rd_sas_scoring_guide',
      'nasal prong oxygen 0.5-1 L/min in term mild distress': 'rd_initial_term_mild_nasal_o2',
      'CPAP failure recurrent apnea shock urgent referral': 'rd_cpap_failure_referral',
      'wean CPAP in 1 cm H2O steps to 4-5 cm H2O': 'rd_outcome_improving_weaning',
      'optimize CPAP increase PEEP stepwise up to 7-8': 'rd_outcome_not_improving_optimize_cpap',
      'respiratory distress diagnostic criteria RR >60 grunting': 'rd_diagnostic_criteria',
      'TABC temperature airway breathing circulation immediate actions': 'rd_immediate_actions',
      'clinical DOs assess SAS start CPAP early': 'rd_clinical_dos',
      'clinical DONTs do not give 100% unblended oxygen sedatives': 'rd_clinical_donts',
      'Whom to screen for ROP criteria gestation <34 weeks': 'rop_whom_to_screen',
      'ROP screening eligibility birth weight <2000 g': 'rop_whom_to_screen',
      'When to screen for ROP first screen by 4 weeks': 'rop_when_to_screen',
      'Prepare to screen withhold feeds 1 hour dilate pupils': 'rop_prepare_to_screen',
      'How to screen indirect ophthalmoscopy 28D lens': 'rop_how_to_screen',
      'Treatment indications for ROP Zone I plus disease': 'rop_treatment_indications',
      'Laser photocoagulation and anti-VEGF injection': 'rop_treatment_options',
      'When to stop ROP screening retina fully vascularised': 'rop_when_to_stop',
      'Key performance indicators ROP screening coverage': 'rop_kpis',
      'Prevention of ROP antenatal corticosteroids safe oxygen therapy': 'rop_prevention',
    };

    test('2. 22 clinical queries return the expected target chunk at top-1', () async {
      for (final entry in clinicalQueries.entries) {
        final query = entry.key;
        final expectedChunkId = entry.value;

        final results = await retriever.search(query, limit: 3);
        expect(results.isNotEmpty, isTrue,
            reason: 'Query "$query" must return at least one result');

        final topChunkId = results.first.chunk.chunkId;
        expect(topChunkId, equals(expectedChunkId),
            reason: 'For query "$query", expected top-1 to be "$expectedChunkId" but got "$topChunkId" (score: ${results.first.score})');
      }
    });

    test('3. Out-of-scope medical and non-medical queries return empty / below threshold', () async {
      const outOfScopeQueries = [
        'How to treat adult hypertension with ACE inhibitors?',
        'What is the dose of insulin in diabetic ketoacidosis?',
        'Laparoscopic appendectomy surgical technique',
        'COVID-19 mRNA vaccine cold chain temperature',
        'Chemotherapy regimen for breast cancer',
        'How to bake chocolate cake',
      ];

      for (final q in outOfScopeQueries) {
        final results = await retriever.search(q, limit: 3);
        expect(results.isEmpty, isTrue,
            reason: 'Out-of-scope query "$q" must return empty results (triggering "${StwRetriever.notCoveredMessage}")');
      }
    });
  });
}
