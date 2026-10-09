import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';

/// Golden retrieval queries for the ANCS and Neonatal Hypoglycemia STW
/// regions (English and Hinglish). Each must return the expected region at
/// top-1; out-of-scope queries must return nothing ("not covered").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Bm25Retriever retriever;
  late List<StwChunk> chunks;

  setUpAll(() async {
    final raw = jsonDecode(
      await File('assets/regions/regions.json').readAsString(),
    ) as List<dynamic>;
    chunks =
        raw.map((e) => StwChunk.fromJson(e as Map<String, dynamic>)).toList();
    final syn = jsonDecode(
      await File('assets/stw_index/clinical_synonyms.json').readAsString(),
    ) as Map<String, dynamic>;
    retriever = Bm25Retriever(
      initialChunks: chunks,
      initialSynonyms: syn.map(
        (k, v) => MapEntry(
          k.toLowerCase(),
          (v as List<dynamic>).map((e) => e.toString().toLowerCase()).toList(),
        ),
      ),
    );
  });

  const ancsQueries = {
    'ACS ka dose': 'ancs_drug_dose',
    'dexamethasone kitna dena hai': 'ancs_drug_dose',
    'What is the dose of dexamethasone for antenatal corticosteroids?':
        'ancs_drug_dose',
    'Why is dexamethasone preferred over betamethasone?': 'ancs_drug_dose',
    'Eligibility criteria for antenatal corticosteroids': 'ancs_eligibility',
    'PPROM me steroid de sakte hain?': 'ancs_eligibility',
    'At what gestational age should ACS be given?': 'ancs_when_to_give',
    'ACS kab dena chahiye?': 'ancs_when_to_give',
    'When should antenatal steroids not be given?': 'ancs_when_not_to_give',
    'Chorioamnionitis me ACS de sakte hain?': 'ancs_when_not_to_give',
    'Can a repeat course of ACS be given after 7 days?': 'ancs_repeat_course',
    'Kya dobara steroid course de sakte hain?': 'ancs_repeat_course',
    'Twins pregnancy me ACS de sakte hain?': 'ancs_special_situations',
    'ACS in diabetes in pregnancy': 'ancs_special_situations',
    'Where should ACS doses be documented? MCP card': 'ancs_documentation',
    'When to refer a pregnant woman for in-utero transfer?': 'ancs_referral',
    'Can a level I facility give the first dose of ACS before referral?':
        'ancs_referral',
    'ACS coverage KPI target': 'ancs_kpis',
    'Benefits of antenatal corticosteroids': 'ancs_introduction',
    'What is the full form of PPROM?': 'ancs_abbreviations',
  };

  const hypoQueries = {
    'BG 30 aur symptoms nahi, kya karein': 'hypo_asymptomatic_branch',
    'refractory hypoglycemia me kya dete hain': 'hypo_drugs_refractory',
    'Hydrocortisone dose for refractory hypoglycemia': 'hypo_drugs_refractory',
    'Which neonates should be screened for hypoglycemia?':
        'hypo_whom_to_screen',
    'Diabetic mother ke bacche ka sugar check karein?': 'hypo_whom_to_screen',
    'Blood glucose monitoring schedule for at-risk infants':
        'hypo_monitoring_schedule',
    'Sugar kitne ghante par check karna hai?': 'hypo_monitoring_schedule',
    'Should we wait for lab confirmation before treating low glucose?':
        'hypo_how_to_monitor',
    'Symptoms of neonatal hypoglycemia': 'hypo_symptoms',
    'Bacche me sugar kam hone ke lakshan kya hain?': 'hypo_symptoms',
    'Dextrose bolus dose for symptomatic hypoglycemia': 'hypo_symptomatic_branch',
    'BG below 25 mg/dL treatment': 'hypo_symptomatic_branch',
    'Feed ke 1 ghante baad sugar check karna hai?': 'hypo_recheck_1h',
    'How often to recheck BG after starting IV dextrose?': 'hypo_recheck_30min',
    'What is the maximum GIR?': 'hypo_increase_gir',
    'GIR kitna badhayein agar sugar low rahe?': 'hypo_increase_gir',
    'When to refer persistent hypoglycemia to higher centre?':
        'hypo_persistent_refractory',
    'How to wean GIR once euglycemic?': 'hypo_euglycemic_wean',
    'When to stop IV fluids in neonatal hypoglycemia?': 'hypo_stop_iv',
    'Maximum dextrose concentration through a peripheral vein':
        'hypo_practical_points',
    'How to prevent neonatal hypoglycemia?': 'hypo_prevention',
    'Should antibiotics be given for hypoglycemia?': 'hypo_donts',
    'Blood glucose screening coverage KPI': 'hypo_kpis',
    'Which babies with hypoglycemia need neurodevelopmental follow-up?':
        'hypo_neuro_followup',
  };

  for (final (name, queries) in [('ANCS', ancsQueries), ('Hypoglycemia', hypoQueries)]) {
    test('$name: every golden query returns the expected region at top-1',
        () async {
      expect(queries.length, greaterThanOrEqualTo(15));
      final failures = <String>[];
      for (final e in queries.entries) {
        final results = await retriever.search(e.key, limit: 3);
        final top = results.isEmpty ? 'NO RESULT' : results.first.chunk.chunkId;
        if (top != e.value) {
          failures.add('"${e.key}" -> $top (expected ${e.value}; top-3: '
              '${results.map((r) => r.chunk.chunkId).join(', ')})');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  test('out-of-scope queries return nothing (not covered)', () async {
    const outOfScope = [
      'How to treat adult hypertension with ACE inhibitors?',
      'What is the dose of insulin in diabetic ketoacidosis?',
      'Laparoscopic appendectomy surgical technique',
      'COVID-19 mRNA vaccine cold chain temperature',
      'Chemotherapy regimen for breast cancer',
      'How to bake chocolate cake',
      'Phototherapy threshold for neonatal jaundice',
      'Cricket match ka score kya hai?',
    ];
    for (final q in outOfScope) {
      expect(await retriever.search(q, limit: 3), isEmpty, reason: q);
    }
  });

  test('new regions: verbatim text, valid boxes, crops and page images exist',
      () {
    const docs = {
      'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
      'Neonatal_Hypoglycemia_8th_Oct.pdf',
    };
    final mine = chunks.where((c) => docs.contains(c.document)).toList();
    expect(mine.length, greaterThanOrEqualTo(30));
    for (final c in mine) {
      expect(c.text.trim(), isNotEmpty, reason: c.chunkId);
      final b = c.boundingBoxes.single;
      expect(b.x >= 0 && b.y >= 0 && b.x + b.width <= 1 && b.y + b.height <= 1,
          isTrue,
          reason: c.chunkId);
      expect(File(c.cropImage!).existsSync(), isTrue, reason: c.chunkId);
    }
    for (final d in docs) {
      expect(File('assets/pages/$d/1.webp').existsSync(), isTrue, reason: d);
      expect(File('assets/pdfs/$d').existsSync(), isTrue, reason: d);
    }
    // Hidden duplicate flowchart labels are not in the answer text.
    final gir = mine.singleWhere((c) => c.chunkId == 'hypo_increase_gir');
    expect(gir.text, isNot(contains('till max GIR')));
    expect(gir.text, contains('(maximum 12 mg/kg/min)'));
  });
}
