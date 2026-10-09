import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Bm25Retriever retriever;
  late List<StwChunk> chunks;

  setUpAll(() async {
    final file = File('assets/regions/regions.json');
    expect(file.existsSync(), isTrue, reason: 'assets/regions/regions.json must exist');
    final jsonStr = await file.readAsString();
    final List<dynamic> raw = jsonDecode(jsonStr) as List<dynamic>;
    chunks = raw.map((e) => StwChunk.fromJson(e as Map<String, dynamic>)).toList();

    Map<String, List<String>> synonyms = {};
    final synFile = File('assets/stw_index/clinical_synonyms.json');
    if (synFile.existsSync()) {
      final synJson = jsonDecode(await synFile.readAsString()) as Map<String, dynamic>;
      synonyms = synJson.map(
        (key, value) => MapEntry(
          key.toLowerCase(),
          (value as List<dynamic>).map((e) => e.toString().toLowerCase()).toList(),
        ),
      );
    }

    retriever = Bm25Retriever(
      initialChunks: chunks,
      initialSynonyms: synonyms,
    );
  });

  group('Golden 40-Query Retrieval Test (English & Hinglish)', () {
    final testCases = <Map<String, String>>[
      // 1-10: Preterm CPAP, Caffeine, Surfactant, SAS
      {
        'query': 'Initial CPAP pressure in preterm ≤34 weeks',
        'expected': 'rd_initial_preterm_cpap_caffeine',
      },
      {
        'query': 'Preterm baby <=34 weeks ko CPAP kitne pressure par start karein?',
        'expected': 'rd_initial_preterm_cpap_caffeine',
      },
      {
        'query': 'Caffeine citrate indication and dosage',
        'expected': 'rd_initial_preterm_cpap_caffeine',
      },
      {
        'query': 'Preterm neonate mein caffeine citrate kab shuru karni chahiye?',
        'expected': 'rd_initial_preterm_cpap_caffeine',
      },
      {
        'query': 'Surfactant criteria on CPAP',
        'expected': 'rd_surfactant_indication',
      },
      {
        'query': 'Surfactant therapy kab dete hain preterm baby ko?',
        'expected': 'rd_surfactant_indication',
      },
      {
        'query': 'FiO2 cutoff for surfactant administration',
        'expected': 'rd_surfactant_indication',
      },
      {
        'query': 'Silverman-Andersen score parameters',
        'expected': 'rd_sas_scoring_guide',
      },
      {
        'query': 'Silverman score ke 5 parameters kya hote hain?',
        'expected': 'rd_sas_scoring_guide',
      },
      {
        'query': 'How to calculate SAS score in neonates?',
        'expected': 'rd_sas_scoring_guide',
      },

      // 11-20: CPAP failure, Diagnosis, Immediate actions, Term support
      {
        'query': 'CPAP failure and urgent referral criteria',
        'expected': 'rd_cpap_failure_referral',
      },
      {
        'query': 'CPAP fail kab mana jata hai newborn baby mein?',
        'expected': 'rd_cpap_failure_referral',
      },
      {
        'query': 'Persistent hypoxemia on FiO2 >0.60 referral',
        'expected': 'rd_cpap_failure_referral',
      },
      {
        'query': 'Diagnostic criteria for neonatal respiratory distress',
        'expected': 'rd_diagnostic_criteria',
      },
      {
        'query': 'Bacche mein respiratory distress ke kya lakshan hote hain?',
        'expected': 'rd_diagnostic_criteria',
      },
      {
        'query': 'Respiratory rate >60 in newborn',
        'expected': 'rd_diagnostic_criteria',
      },
      {
        'query': 'Immediate actions for neonatal respiratory distress TABC',
        'expected': 'rd_immediate_actions',
      },
      {
        'query': 'TABC stabilization steps in SNCU',
        'expected': 'rd_immediate_actions',
      },
      {
        'query': 'Distress wale bacche ka blood sugar aur temperature stabilization',
        'expected': 'rd_immediate_actions',
      },
      {
        'query': 'Initial CPAP for GA >34 weeks with moderate-severe distress SAS ≥4',
        'expected': 'rd_initial_term_moderate_severe_cpap',
      },

      // 21-30: Mild distress, Weaning, Optimization, Clinical DOs/DON'Ts, ROP Whom to Screen
      {
        'query': 'Term baby with SAS 4 management',
        'expected': 'rd_initial_term_moderate_severe_cpap',
      },
      {
        'query': 'Initial support for GA >34 weeks with mild distress SAS ≤3',
        'expected': 'rd_initial_term_mild_nasal_o2',
      },
      {
        'query': 'Nasal prong oxygen 0.5-1 L/min in term neonate',
        'expected': 'rd_initial_term_mild_nasal_o2',
      },
      {
        'query': 'How to wean CPAP and oxygen in neonates',
        'expected': 'rd_outcome_improving_weaning',
      },
      {
        'query': 'Baby ko CPAP se kaise wean karein?',
        'expected': 'rd_outcome_improving_weaning',
      },
      {
        'query': 'Steps to optimize CPAP when baby is not improving',
        'expected': 'rd_outcome_not_improving_optimize_cpap',
      },
      {
        'query': 'Agar CPAP par baby improve na ho toh PEEP kitna badhayein?',
        'expected': 'rd_outcome_not_improving_optimize_cpap',
      },
      {
        'query': 'Clinical DOs for neonatal respiratory distress',
        'expected': 'rd_clinical_dos',
      },
      {
        'query': 'Clinical DON\'Ts in neonatal respiratory distress',
        'expected': 'rd_clinical_donts',
      },
      {
        'query': 'Whom to screen for ROP',
        'expected': 'rop_whom_to_screen',
      },

      // 31-40: ROP Timing, Treatment, Preparation, Technique, Stop
      {
        'query': 'ROP screening kin baccho mein karni chahiye?',
        'expected': 'rop_whom_to_screen',
      },
      {
        'query': 'Gestation <34 weeks and birth weight <2000 g screening criteria',
        'expected': 'rop_whom_to_screen',
      },
      {
        'query': 'When to do first ROP screening',
        'expected': 'rop_when_to_screen',
      },
      {
        'query': 'ROP ki pehli screening kab karni chahiye?',
        'expected': 'rop_when_to_screen',
      },
      {
        'query': 'Screening timing for infant <28 weeks or <1200 g',
        'expected': 'rop_when_to_screen',
      },
      {
        'query': 'Treatment indications for ROP ICROP criteria',
        'expected': 'rop_treatment_indications',
      },
      {
        'query': 'Zone I and Zone II plus disease treatment urgency',
        'expected': 'rop_treatment_indications',
      },
      {
        'query': 'Treatment options for ROP laser and anti-VEGF',
        'expected': 'rop_treatment_options',
      },
      {
        'query': 'Pupil dilation drops for ROP phenylephrine tropicamide',
        'expected': 'rop_prepare_to_screen',
      },
      {
        'query': 'When to stop ROP screening criteria',
        'expected': 'rop_when_to_stop',
      },
    ];

    test('Achieves >= 90% Top-1 accuracy and >= 95% Top-3 accuracy across 40 clinical queries', () async {
      int top1Count = 0;
      int top3Count = 0;
      final failures = <String>[];

      for (int i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        final query = tc['query']!;
        final expected = tc['expected']!;

        final results = await retriever.search(query, limit: 3);

        if (results.isEmpty) {
          failures.add('Q#${i + 1} "$query" -> NO RESULTS (Expected $expected)');
          continue;
        }

        final top1 = results.first.chunk.chunkId;
        final top3Ids = results.map((r) => r.chunk.chunkId).toList();

        if (top1 == expected) {
          top1Count++;
        } else {
          failures.add('Q#${i + 1} "$query" -> Top-1 was $top1 (Expected $expected, Rank: ${top3Ids.indexOf(expected) + 1})');
        }

        if (top3Ids.contains(expected)) {
          top3Count++;
        }
      }

      final top1Acc = (top1Count / testCases.length) * 100;
      final top3Acc = (top3Count / testCases.length) * 100;

      // Print accuracy report
      // ignore: avoid_print
      print('\n======================================================');
      // ignore: avoid_print
      print('GOLDEN 40-QUERY CLINICAL RETRIEVAL REPORT');
      // ignore: avoid_print
      print('Total Queries Evaluated: ${testCases.length}');
      // ignore: avoid_print
      print('Top-1 Accuracy: ${top1Acc.toStringAsFixed(1)}% ($top1Count/${testCases.length})');
      // ignore: avoid_print
      print('Top-3 Accuracy: ${top3Acc.toStringAsFixed(1)}% ($top3Count/${testCases.length})');
      if (failures.isNotEmpty) {
        // ignore: avoid_print
        print('\nDiscrepancies:');
        for (final f in failures) {
          // ignore: avoid_print
          print('  - $f');
        }
      }
      // ignore: avoid_print
      print('======================================================\n');

      expect(top1Acc, greaterThanOrEqualTo(90.0),
          reason: 'Top-1 accuracy must be >= 90%');
      expect(top3Acc, greaterThanOrEqualTo(95.0),
          reason: 'Top-3 accuracy must be >= 95%');
    });

    test('Multi-part query completeness check flags missing dosage notice', () {
      const q = 'Caffeine citrate indication and dosage';
      const retrievedText =
          'START CPAP\nCPAP 5–6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91–95%\nStart caffeine citrate in neonates <34 weeks who require respiratory support';

      final notice = Bm25Retriever.checkMissingDosageNotice(q, retrievedText);
      expect(notice, isNotNull);
      expect(notice, equals('Dosage is not mentioned in the retrieved STW section.'));
    });

    test('Single-part query without dosage request does not flag notice', () {
      const q = 'Caffeine citrate indication';
      const retrievedText =
          'Start caffeine citrate in neonates <34 weeks who require respiratory support';

      final notice = Bm25Retriever.checkMissingDosageNotice(q, retrievedText);
      expect(notice, isNull);
    });
  });
}
