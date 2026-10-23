import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/data/disease_follow_up_registry.dart';
import 'package:neonatal_stw/features/follow_up/data/rd_follow_up_data.dart';
import 'package:neonatal_stw/features/follow_up/domain/follow_up_models.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_map.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/stw_region.dart';

import 'test_helpers.dart';

void main() {
  test(
      'all 20 RD questions, choices, bold answer keys and explanations match DOCX extraction',
      () {
    final source = jsonDecode(
            File('test/fixtures/rd_follow_up_source.json').readAsStringSync())
        as Map;
    final expected = source['questions'] as List;
    final questions = [...rdFollowUpMcqs, ...rdFollowUpCaseScenarios];
    expect(rdFollowUpMcqs, hasLength(10));
    expect(rdFollowUpCaseScenarios, hasLength(10));
    expect(questions.map((q) => q.id).toSet(), hasLength(20));
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final original = expected[i] as Map;
      // The case vignette and final question are separate UI fields. Removing
      // whitespace permits the source's missing space before Q19's last sentence.
      String compact(String s) => s.replaceAll(RegExp(r'\s'), '');
      expect(
          compact([if (q.scenario != null) q.scenario!, q.question].join(' ')),
          compact(original['question'] as String),
          reason: q.id);
      expect(q.options, original['options'], reason: q.id);
      expect(q.correctAnswerIndex, original['correctAnswerIndex'],
          reason: q.id);
      expect(q.explanation, original['explanation'], reason: q.id);
      expect(q.disease, NeonatalCondition.respiratoryDistress);
      expect(q.questionType,
          i < 10 ? QuestionType.mcq : QuestionType.caseScenario);
      expect(q.stwReference,
          contains('MCQs RD.docx Section ${i < 10 ? 1 : 2} Q${i + 1}'));
    }
  });

  test('each RD answer reference resolves to an existing RD STW Map box', () {
    final regions = <String, StwRegionInfo>{
      for (final r
          in jsonDecode(File('assets/regions/regions.json').readAsStringSync())
              as List)
        r['id'] as String: StwRegionInfo(
          id: r['id'] as String,
          document: r['document'] as String,
          page: r['page'] as int? ?? 1,
          text: readableStwText(r['text'] as String),
        ),
    };
    final map = buildStwMap(
        regions: regions,
        data: StwMapData.fromJson(
          jsonDecode(File('assets/knowledge_graph/stw_map.json')
              .readAsStringSync()) as Map<String, dynamic>,
        ));
    for (final q in [...rdFollowUpMcqs, ...rdFollowUpCaseScenarios]) {
      expect(map.resolveReference(q.stwReference!), startsWith('rd_'),
          reason: q.id);
    }
  });

  test('RD scoring, incomplete submission, retake, reset and disease isolation',
      () {
    final c = FollowUpController();
    addTearDown(c.dispose);
    c.initForCondition(NeonatalCondition.respiratoryDistress,
        startImmediately: true);
    expect(c.state.mcqs, same(rdFollowUpMcqs));
    expect(c.submitMcqs(), isFalse);
    for (var i = 0; i < 10; i++) {
      c.goToMcq(i);
      c.selectMcqOption(i == 0 ? 0 : c.state.currentMcq.correctAnswerIndex);
    }
    expect(c.submitMcqs(), isTrue);
    expect(c.state.mcqCorrectCount, 9);
    expect(c.state.mcqPercentage, 90);
    c.proceedToCaseScenarios();
    expect(c.submitCaseScenarios(), isFalse);
    for (var i = 0; i < 10; i++) {
      c.goToCase(i);
      c.selectCaseOption(c.state.currentCase.correctAnswerIndex);
    }
    expect(c.submitCaseScenarios(), isTrue);
    expect(c.state.stage, FollowUpStage.finalSummary);
    expect(c.state.totalCorrectCount, 19);
    expect(c.state.totalPercentage, 95);
    c.retakeMcqs();
    expect(c.state.mcqAnswers, isEmpty);
    expect(c.state.caseAnswers, hasLength(10));
    c.reset();
    expect(c.state.mcqAnswers, isEmpty);
    expect(c.state.caseAnswers, isEmpty);
    c.initForCondition(NeonatalCondition.rop);
    expect(c.state.mcqs, hasLength(8));
    expect(
        c.state.mcqs.every((q) => q.disease == NeonatalCondition.rop), isTrue);
    expect(hasFollowUpForCondition(NeonatalCondition.sepsis), isFalse);
  });

  for (final size in [const Size(360, 800), const Size(1280, 900)]) {
    testWidgets(
        'RD screening to all 20 questions, feedback and results at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();
      await goToHome(tester);
      await tapVisible(tester, find.text('STW Respiratory Distress'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);
      await tapVisible(tester, find.text('Respiratory Distress in Neonates'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(find.text('Clinical Assessment Summary'), findsOneWidget);
      await tapVisible(tester, find.text('Next: MCQs'));
      final container =
          ProviderScope.containerOf(tester.element(find.text('MCQ 1 OF 10')));
      for (var i = 0; i < 10; i++) {
        expect(find.text('MCQ ${i + 1} OF 10'), findsOneWidget);
        final q = rdFollowUpMcqs[i];
        await tapVisible(tester, find.text(q.correctAnswer));
        await tapVisible(
            tester, find.text(i == 9 ? 'Submit Assessment' : 'Next Question'));
      }
      expect(container.read(followUpProvider).mcqCorrectCount, 10);
      expect(find.text('10 / 10'), findsOneWidget);
      await tapVisible(
          tester, find.text('Proceed to Case Scenarios (10 Cases)').first);
      for (var i = 0; i < 10; i++) {
        final q = rdFollowUpCaseScenarios[i];
        expect(find.text(q.scenario!), findsOneWidget);
        expect(find.text(q.question), findsOneWidget);
        await tapVisible(tester, find.text(q.correctAnswer));
        await tapVisible(tester,
            find.text(i == 9 ? 'Submit Case Scenarios' : 'Next Question'));
      }
      expect(
          container.read(followUpProvider).stage, FollowUpStage.finalSummary);
      expect(container.read(followUpProvider).totalCorrectCount, 20);
      expect(
          find.text('Respiratory Distress in Neonates · Follow-up Assessment'),
          findsOneWidget);
      expect(find.textContaining('Retinopathy'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
