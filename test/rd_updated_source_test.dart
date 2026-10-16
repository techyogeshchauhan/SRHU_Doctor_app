import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';
import 'package:neonatal_stw/features/rd/state/rd_controller.dart';
import 'package:neonatal_stw/features/rd/ui/rd_screen.dart';
import 'package:neonatal_stw/shared/baby_context.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart';
import 'chatbot_eval/eval_harness.dart';

SasScore score(int n) {
  final values = <SasItem, int>{};
  for (final item in SasItem.values) {
    values[item] = n.clamp(0, 2);
    n -= values[item]!;
  }
  return SasScore(values);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RR 59, 60 and 61 agree in standalone and guided assessment', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (final rr in [59, 60, 61]) {
      container.read(rdProvider.notifier).setRr(rr);
      expect(meetsRdCriteria(container.read(rdProvider).signs), rr >= 60);
      expect(evalCtx({rd}, {rdRrKey: rr}).hasFinding(rdPresentId), rr >= 60);
    }
  });

  test('all initial GA/SAS/oxygen branches follow the revised PDF', () {
    for (final weeks in [28, 33, 34, 35, 40]) {
      for (final days in [0, 1, 6]) {
        for (var sas = 0; sas <= 10; sas++) {
          for (final spo2 in [90, 91, 95]) {
            final g = Gestation(gaWeeks: weeks, gaDays: days);
            final plan = initialPlan(
                    signs: {RdSign.grunting},
                    gestation: g,
                    sas: score(sas),
                    initialSpo2: spo2)
                .plan!;
            final needsCpap = weeks <= 34 || sas >= 4;
            expect(
                plan.support,
                needsCpap
                    ? RespSupport.cpap
                    : spo2 < 91
                        ? RespSupport.nasalO2
                        : RespSupport.none,
                reason: '$weeks+$days SAS $sas SpO2 $spo2');
            expect(plan.caffeine == CaffeineAdvice.indicated, weeks < 34);
          }
        }
      }
    }
  });

  test('missing mild-RD SpO2 stays pending; emergency advice needs no GA/SAS',
      () {
    expect(
        initialPlan(
                signs: {RdSign.grunting},
                gestation: const Gestation(gaWeeks: 37),
                sas: score(2))
            .pending,
        contains('enter SpO₂'));
    final urgent = evalCtx({rd}, {rdEmergencyKey: true});
    expect(findingIds(urgent), contains('rd.emergency'));
    expect(
        urgent.findings
            .firstWhere((f) => f.id == 'rd.emergency')
            .actions
            .join(),
        contains('ventilate when indicated'));
    expect(findingIds(urgent), isNot(contains(rdInitialPlanId)));
  });

  test('early rescue requires all criteria, including CPAP exactly 6', () {
    for (final ga in [33, 34, 35]) {
      for (final peep in [5, 6, 7, 8]) {
        for (final fio2 in [0.30, 0.3001, 0.31, 0.40]) {
          for (final suspected in [false, true]) {
            for (final support in RespSupport.values) {
              final i = ReassessInput(
                  gestation: Gestation(gaWeeks: ga),
                  support: support,
                  peep: peep,
                  fio2: fio2,
                  suspectedWorseningRds: suspected);
              expect(
                  meetsSurfactantCriteria(i),
                  ga < 34 &&
                      peep >= 6 &&
                      fio2 > 0.30 &&
                      suspected &&
                      support == RespSupport.cpap);
            }
          }
        }
      }
    }
    expect(
        meetsSurfactantCriteria(const ReassessInput(
            gestation: Gestation(gaKnown: false, birthWeightG: 1200),
            support: RespSupport.cpap,
            peep: 6,
            fio2: 0.4,
            suspectedWorseningRds: true)),
        isFalse);
  });

  test('failure takes priority over surfactant and does not delay ventilation',
      () {
    final o = reassess(const ReassessInput(
        gestation: Gestation(gaWeeks: 30),
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.4,
        suspectedWorseningRds: true,
        persistentHypoxemia: true));
    expect(o.status, ReassessStatus.cpapFailure);
    expect(o.actions.join(), contains('intubate/ventilate when indicated'));
    for (final support in RespSupport.values) {
      final o = reassess(ReassessInput(
          gestation: const Gestation(), support: support, shock: true));
      expect(
          o.status,
          support == RespSupport.cpap
              ? ReassessStatus.cpapFailure
              : ReassessStatus.emergency);
    }
  });

  test('nasal oxygen worsening starts CPAP and excludes pneumothorax', () {
    final o = reassess(const ReassessInput(
        gestation: Gestation(gaWeeks: 37),
        support: RespSupport.nasalO2,
        risingO2Need: true));
    expect(o.status, ReassessStatus.notImproving);
    expect(o.actions.join(), contains('START CPAP'));
    expect(o.actions.join(), contains('pneumothorax'));
    expect(o.actions.join(), contains('sepsis'));
  });

  test(
      'improving requires stable/reducing support and trial off uses 5 / 0.21–0.25',
      () {
    for (final stable in [false, true]) {
      final o = reassess(ReassessInput(
          gestation: const Gestation(gaWeeks: 35),
          support: RespSupport.cpap,
          sas: score(1),
          previousSasTotal: 4,
          spo2: 93,
          comfortableBreathing: true,
          stableOrReducingSupport: stable,
          peep: 5,
          fio2: 0.25));
      expect(o.status == ReassessStatus.improving, stable);
      if (stable) expect(o.actions.first, startsWith('Trial off'));
    }
    for (final fio2 in [0.21, 0.25, 0.26]) {
      expect(cpapWeanSteps(peep: 5, fio2: fio2).first.startsWith('Trial off'),
          fio2 <= 0.25);
    }
    expect(cpapWeanSteps(peep: 4, fio2: 0.21).first,
        isNot(startsWith('Trial off')));
    expect(rdMonitoringActions.join(), contains('15–30 min'));
    expect(rdMonitoringActions.join(), contains('1 hourly'));
  });

  test(
      'guided assessment walks mild, CPAP, rescue, worsening and weaning paths',
      () {
    for (final spo2 in [90, 91]) {
      final w = walk({
        rd
      }, {
        rdRrKey: 60,
        gaKnownKey: true,
        gaWeeksKey: 37,
        rdInitialSpo2Key: spo2,
        for (final item in SasItem.values) rdSasKey(item): 0,
        rdReassessNowKey: false
      });
      expect(w.pages.length, lessThan(15));
      expect(w.ctx.hasFinding(rdInitialPlanId), isTrue);
      expect(
          w.ctx.findings.firstWhere((f) => f.id == rdInitialPlanId).title,
          spo2 < 91
              ? 'Nasal-prong oxygen 0.5–1 L/min'
              : 'Mild RD: monitor; oxygen only if SpO₂ <91%');
    }
    final baseline = <String, Object?>{
      rdRrKey: 60,
      gaKnownKey: true,
      gaWeeksKey: 30,
      rdInitialSpo2Key: 90,
      for (final i in SasItem.values) rdSasKey(i): 1,
      rdReassessNowKey: true,
      rdSupportKey: 'cpap',
      rdPeepKey: 6,
      rdFio2Key: 31,
      rdSpo2Key: 93,
      rdSuspectedRdsKey: true,
      for (final i in SasItem.values) rdReSasKey(i): 0
    };
    expect(
        walk({rd}, baseline)
            .ctx
            .hasFinding(rdReassessId(ReassessStatus.surfactant)),
        isTrue);
    final wean = walk({
      rd
    }, {
      ...baseline,
      rdFio2Key: 25,
      rdPeepKey: 5,
      rdSuspectedRdsKey: false,
      rdComfortableKey: true,
      rdStableSupportKey: true
    });
    expect(wean.ctx.hasFinding(rdReassessId(ReassessStatus.improving)), isTrue);
    final reset =
        recordRdReassessment(wean.ctx.answers, wean.ctx.completedQuestions)!;
    expect(reset.answers.containsKey(rdSuspectedRdsKey), isFalse);
    expect(reset.answers.containsKey(rdStableSupportKey), isFalse);
  });

  final answerer = StwAnswerer(Bm25Retriever(
      initialChunks: loadRegions(), initialSynonyms: loadSynonyms()));
  for (final (query, id, phrases) in [
    (
      'Respiratory distress diagnostic criteria',
      'rd_diagnostic_criteria',
      ['RR ≥60/min']
    ),
    (
      'When should early rescue surfactant be given?',
      'rd_surfactant_indication',
      [
        'Suspected worsening RDS',
        '<34 weeks',
        'CPAP ≥6',
        'FiO₂ >0.30',
        'before established CPAP failure'
      ]
    ),
    (
      'PEEP and FiO2 thresholds for giving surfactant',
      'rd_surfactant_indication',
      ['Suspected worsening RDS', 'CPAP ≥6']
    ),
    (
      'How often should respiratory distress be reassessed?',
      'rd_reassessment_sepsis',
      ['15–30 min', '1 hourly']
    ),
    (
      'Mild RD nasal prong oxygen indication',
      'rd_initial_term_mild_nasal_o2',
      ['If SpO₂ <91%']
    ),
    (
      'When can CPAP be stopped?',
      'rd_outcome_improving_weaning',
      ['CPAP 5 cm', '0.21–0.25']
    ),
    (
      'Respiratory distress KPI continuous pulse oximetry coverage',
      'rd_kpis',
      ['documented', 'All neonates receiving oxygen or CPAP']
    ),
    (
      'Nasal oxygen rising oxygen need or distress what next?',
      'rd_outcome_not_improving_optimize_cpap',
      ['Start CPAP']
    ),
  ]) {
    test('updated chatbot evidence: $query', () async {
      final a = await answerer.answer(query);
      expect(a.kind, AnswerKind.answer,
          reason: '${a.kind} ${a.prompt} ${a.region?.chunkId}');
      expect(a.region!.chunkId, id);
      final text = a.lines.map((s) => s.text).join(' ');
      for (final phrase in phrases) {
        expect(text, contains(phrase));
      }
      expect(text, isNot(contains('within 2 hours')));
      expect((await stwRegionTarget(id))!.document,
          'respiratory_distress_neonates_stw.pdf');
    });
  }

  test('all RD source assets share the supplied revision and matching fallback',
      () {
    final regions =
        (jsonDecode(File('assets/regions/regions.json').readAsStringSync())
                as List)
            .where((r) => r['id'].startsWith('rd_'))
            .toList();
    final index = {for (final c in loadRegions()) c.chunkId: c};
    expect(regions.length, 20);
    for (final r in regions) {
      expect(
          r['source_revision'], 'Respiratory_Distress_STW_Final 15-10-26.pdf');
      expect(index[r['id']]!.document, 'respiratory_distress_neonates_stw.pdf');
    }
    expect(
        File('assets/pdfs/Respiratory distress in neonates_New.pdf')
            .existsSync(),
        isFalse);
  });

  testWidgets(
      'standalone RD at 360px accepts RR60 and shows the updated oxygen decision',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Shared baby state and standalone RD must use the same source rules.
    container.read(babyProvider.notifier).setGaWeeks(37);
    final n = container.read(rdProvider.notifier);
    n.setRr(60);
    n.setInitialSpo2(91);
    for (final item in SasItem.values) {
      n.setSasGrade(item, 0);
    }
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: RdScreen())));
    await tester.pumpAndSettle();
    expect(
        find.text('Mild RD: monitor; oxygen only if SpO₂ <91%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
