@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/chat_log_repository.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_rules.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/state/chatbot_provider.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_rules.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';

import 'assessment_test_utils.dart';
import 'chatbot_eval/eval_harness.dart';

/// End to end: the app's real screening flows and chatbot, through the real
/// offline queue and API client, into the real REST API and MongoDB; then
/// reads MongoDB back (via the API) and checks nothing was lost or changed.
///
/// Needs a running API. Against an in-memory MongoDB (or `--atlas`: the
/// Atlas cluster from server/.env, database stw_neo_e2e):
///   cd server && node scripts/e2e_server.js 4100 [--atlas]
///   E2E_API_URL=http://127.0.0.1:4100 flutter test test/e2e_mongo_sync_test.dart
/// E2E_API_KEY defaults to API_KEY in build.env (the server's write key).
void main() {
  final apiUrl = Platform.environment['E2E_API_URL'] ?? '';
  final apiKey = Platform.environment['E2E_API_KEY'] ?? _buildEnvApiKey();

  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test blocks real HTTP by default; this test needs it.
  HttpOverrides.global = null;

  test('screenings and chat queries are stored in MongoDB', () async {
    final tempDir = Directory.systemTemp.createTempSync('stw_e2e_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final queue = OfflineQueue(
      sessionBoxName: 'e2e_session_$stamp',
      queueBoxName: 'e2e_queue_$stamp',
      apiClient: ApiClient(baseUrl: apiUrl, apiKey: apiKey),
    );
    await queue.initialize(customPath: tempDir.path);
    final screeningRepo = ScreeningSyncRepository(queue: queue);
    final chatRepo = ChatLogRepository(queue: queue);
    final container = ProviderContainer(overrides: [
      screeningSyncRepositoryProvider.overrideWithValue(screeningRepo),
      chatLogRepositoryProvider.overrideWithValue(chatRepo),
      assessmentTodayProvider.overrideWithValue(testToday),
      stwRetrieverProvider.overrideWithValue(Bm25Retriever(
        initialChunks: loadRegions(),
        initialSynonyms: loadSynonyms(),
      )),
    ]);
    addTearDown(() async {
      container.dispose();
      await queue.dispose();
      tempDir.deleteSync(recursive: true);
    });

    // ---- Chat before any screening: must still get a session -----------
    final chat = container.read(chatbotNotifierProvider.notifier);
    await chat.sendQuery('Symptoms of neonatal hypoglycemia');
    final chatOnlySession = await screeningRepo.ensureSession();

    // ---- Screenings: every module, page by page as the UI does ----------
    final scenarios = <NeonatalCondition, Map<String, Object?>>{
      NeonatalCondition.respiratoryDistress: {
        rdSignsKey: <Object>{'grunting'},
        gaKnownKey: true,
        gaWeeksKey: 30,
        for (final i in SasItem.values) rdSasKey(i): 1,
        rdReassessNowKey: false,
      },
      NeonatalCondition.rop: {
        gaKnownKey: true,
        gaWeeksKey: 30,
        birthWeightKey: 1400,
        dobKey: testToday.subtract(const Duration(days: 10)),
        ropFollowUpAssuredKey: 'yes',
        ropExamDoneKey: false,
      },
      NeonatalCondition.ancs: {
        ancsGaWeeksKey: 30,
        ancsGaDaysKey: 2,
        ancsCausesKey: <Object>{AncsCause.pprom.name},
        ancsGaAccurateKey: true,
        ancsInfectionKey: false,
        ancsChildbirthCareKey: true,
        ancsNewbornCareKey: true,
        ancsPreviousCourseKey: AncsPreviousCourse.none.name,
        ancsLevel2Key: true,
      },
      NeonatalCondition.hypoglycemia: {
        hypoRiskKey: <Object>{HypoRisk.preterm.name},
        hypoBgKey: 30,
        hypoSymptomsKey: <Object>{HypoSymptom.jitteriness.name},
        hypoIvNowKey: true,
        hypoGirKey: 6,
        hypoIvBgKey: 60,
        hypoEuglycemicKey: true,
        hypoToleratingFeedsKey: true,
      },
    };

    final controller = container.read(assessmentProvider.notifier);
    final engine = container.read(assessmentEngineProvider);
    // disease code -> question id -> value sent; and the findings shown.
    final sentResponses = <String, Map<String, Object?>>{};
    final shownFindings = <String, List<String>>{};
    // One session per assessment.
    final sessionOf = <String, String>{};

    for (final MapEntry(key: condition, value: answers) in scenarios.entries) {
      final code = diseaseCodeOf(condition);
      controller.start({condition}, forceReset: true);
      sessionOf[code] = await screeningRepo.ensureSession();
      final sent = sentResponses[code] = {};
      for (var page = 0; page < 40; page++) {
        final state = container.read(assessmentProvider);
        final group = state.currentGroup;
        if (group == null) break;
        // Answering can reveal more questions on the same page.
        final answered = <String>{};
        for (var more = true; more;) {
          more = false;
          final ctx = container.read(assessmentProvider).context;
          for (final rq in engine.pageQuestions(ctx, group)) {
            final q = rq.question;
            if (!answers.containsKey(q.variable) || !answered.add(q.id)) {
              continue;
            }
            controller.answer(q.id, answers[q.variable]);
            if (isSyncableQuestion(q)) sent[q.id] = answers[q.variable];
            more = true;
          }
        }
        expect(state.currentGroup, group);
        final before = container.read(assessmentProvider);
        expect(engine.canConfirm(before.context, group), isTrue,
            reason: '$code: page "$group" needs answers for '
                '${engine.pageQuestions(before.context, group).map((r) => r.id).toList()}');
        controller.confirmPage();
      }
      final done = container.read(assessmentProvider);
      expect(done.isComplete, isTrue, reason: '$code did not complete');
      shownFindings[code] = [
        for (final f in done.context.findingsFor(condition)) f.title,
      ];
    }

    // ---- Follow-up MCQs (attached to the last screening of that module) --
    final followUp = FollowUpController(syncRepo: screeningRepo)
      ..initForCondition(NeonatalCondition.hypoglycemia,
          startImmediately: true);
    for (var i = 0; i < followUp.state.mcqs.length; i++) {
      followUp
        ..goToMcq(i)
        ..selectMcqOption(0);
    }
    expect(followUp.submitMcqs(), isTrue);
    final mcqCount = followUp.state.mcqs.length;

    // ---- Chatbot: answered, ask-back + chip, case, not covered ----------
    for (final q in [
      'How soon must CPAP be started?',
      'Baby glucose 32 mg/dL, no symptoms, what next?',
      'Phototherapy threshold for neonatal jaundice',
    ]) {
      await chat.sendQuery(q);
    }
    final clarify = container
        .read(chatbotNotifierProvider)
        .messages
        .firstWhere((m) => m.answer?.kind == AnswerKind.clarify);
    chat.chooseOption(clarify, clarify.answer!.options.first);
    final botMessages = [
      for (final m in container.read(chatbotNotifierProvider).messages)
        if (!m.isUser) m,
    ];

    // ---- Wait for the queue to drain -------------------------------------
    // The app queues in the background (not awaited): wait for the
    // repository's chain, then for the queue to stay empty for a second.
    await screeningRepo.ensureSession();
    final sw = Stopwatch()..start();
    var emptyFor = 0;
    while (emptyFor < 5 && sw.elapsed.inSeconds < 60) {
      await queue.flush();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      emptyFor = queue.pendingCount == 0 ? emptyFor + 1 : 0;
    }
    expect(queue.pendingCount, 0, reason: 'queue did not drain');

    // ---- Read back from MongoDB ------------------------------------------
    final dio = Dio(BaseOptions(
      baseUrl: apiUrl,
      headers: {'x-api-key': apiKey},
    ));
    Future<Map<String, dynamic>> session(String id) async =>
        Map<String, dynamic>.from((await dio.get('/sessions/$id')).data as Map);
    Future<List<Map<String, dynamic>>> list(String path, String id) async => [
          for (final d in (await dio
                  .get(path, queryParameters: {'sessionId': id}))
              .data as List)
            Map<String, dynamic>.from(d as Map),
        ];

    expect(sessionOf.values.toSet(), hasLength(scenarios.length),
        reason: 'one session per assessment');
    final chatOnly = await session(chatOnlySession);
    expect(chatOnly['selectedConditions'], isEmpty);
    expect(chatOnly['status'], 'completed',
        reason: 'closed by the next assessment');
    expect(chatOnly['endedAt'], isNotNull);

    final screenings = <Map<String, dynamic>>[];
    final report = StringBuffer();
    for (final code in sentResponses.keys) {
      final s = await session(sessionOf[code]!);
      expect(s['selectedConditions'], [code], reason: '$code session');
      expect(s['status'], 'completed', reason: '$code session');
      expect(s['endedAt'], isNotNull, reason: '$code session');
      final docs = await list('/screenings', sessionOf[code]!);
      screenings.addAll(docs);
      expect(docs, hasLength(1), reason: '$code screening count');
      expect(docs.single['diseaseCode'], code);
      final doc = docs.single;
      final stored = {
        for (final r in doc['responses'] as List)
          (r as Map)['questionId'] as String: r['value'],
      };
      final sent = sentResponses[code]!;
      expect(stored.keys.toSet(), sent.keys.toSet(), reason: '$code responses');
      for (final MapEntry(:key, :value) in sent.entries) {
        expect(jsonEncode(stored[key]), jsonEncode(storable(value)),
            reason: '$code $key');
      }
      expect(doc['status'], 'completed', reason: code);
      expect(doc['completedAt'], isNotNull, reason: code);
      final findings = [
        for (final f in doc['findings'] as List) (f as Map)['title'],
      ];
      expect(findings, shownFindings[code], reason: '$code findings');
      report.writeln('$code (session ${sessionOf[code]!.substring(0, 8)}): '
          '${stored.length} responses, '
          '${findings.length} findings, status ${doc['status']}, '
          '${(doc['mcqAttempts'] as List).length} MCQ attempts');
    }
    final hypoDoc =
        screenings.firstWhere((s) => s['diseaseCode'] == 'hypoglycemia');
    expect(hypoDoc['mcqAttempts'] as List, hasLength(mcqCount));

    // The first chat belongs to the chat-only session, the rest to the
    // session of the last assessment (still current).
    final firstLogs = await list('/chat-logs', chatOnlySession);
    final laterLogs = await list('/chat-logs', sessionOf['hypoglycemia']!);
    expect(firstLogs, hasLength(1));
    expect(laterLogs, hasLength(botMessages.length - 1));
    final chatLogs = [...firstLogs, ...laterLogs];
    for (final m in botMessages) {
      final log = chatLogs.firstWhere(
        (l) => l['extractedAnswer'] == m.text,
        orElse: () => fail('no chat log for answer "${m.text}"'),
      );
      expect(log['found'], m.answer?.kind == AnswerKind.answer);
      expect(log['retrieverType'], 'stw_answerer_v1:${m.answer!.kind.name}');
      expect(log['regionId'], m.answer!.region?.chunkId);
      final region = m.answer!.region;
      if (region == null) {
        expect(log['source'], isNull, reason: 'no made-up source');
      } else {
        expect(log['source'], {
          'document': region.document,
          'page': region.page,
          'section': region.sectionTitle
        });
      }
    }
    final queries = {for (final l in chatLogs) l['userQuery']};
    report.writeln('chat: ${chatLogs.length} logs for queries $queries');
    // ignore: avoid_print
    print('\n=== Stored in MongoDB ===\n$report');
  }, skip: apiUrl.isEmpty ? 'set E2E_API_URL to run' : false);
}

/// API_KEY from build.env (the app's write key), else the development key.
String _buildEnvApiKey() {
  final file = File('build.env');
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      if (line.startsWith('API_KEY=')) return line.substring(8).trim();
    }
  }
  return 'stw_dev_client_key_12345';
}
