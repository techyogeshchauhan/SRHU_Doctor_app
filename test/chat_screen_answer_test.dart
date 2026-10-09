import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/data/repositories/chat_log_repository.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/state/chatbot_provider.dart';
import 'package:neonatal_stw/features/chatbot/ui/chat_screen.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

import 'chatbot_eval/eval_harness.dart';

class _Log {
  final String query;
  final String retrieverType;
  final String? regionId;
  final bool found;
  _Log(this.query, this.retrieverType, this.regionId, this.found);
}

class _RecordingLogRepository implements ChatLogRepository {
  final logs = <_Log>[];

  @override
  Future<void> logChatQuery({
    String? sessionId,
    required String query,
    required String answer,
    required List<String> matchedChunkIds,
    Map<String, dynamic>? sourceMetadata,
    required bool found,
    String? regionId,
    String? retrieverType,
  }) async {
    logs.add(_Log(query, retrieverType!, regionId, found));
  }
}

/// The chat screen shows the answerer's verbatim lines, asks back with
/// chips, routes case questions and says "not covered" out of scope.
void main() {
  late Bm25Retriever retriever;
  late _RecordingLogRepository logRepo;

  setUp(() {
    retriever = Bm25Retriever(
      initialChunks: loadRegions(),
      initialSynonyms: loadSynonyms(),
    );
    logRepo = _RecordingLogRepository();
  });

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
        GoRoute(
          path: '/disease-selection',
          builder: (_, state) => Text(
            'selection: ${(state.extra as Map)['condition']}',
          ),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        stwRetrieverProvider.overrideWithValue(retriever),
        chatLogRepositoryProvider.overrideWithValue(logRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ask(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('answer shows verbatim lines, full box collapsed', (tester) async {
    const q = 'Symptoms of neonatal hypoglycemia';
    final expected = await StwAnswerer(retriever).answer(q);
    expect(expected.kind, AnswerKind.answer);

    await pumpChat(tester);
    await ask(tester, q);

    for (final line in expected.lines) {
      expect(find.textContaining(line.text, findRichText: true), findsWidgets);
    }
    expect(find.text(expected.region!.sectionTitle), findsOneWidget);
    expect(find.text('Show full STW box'), findsOneWidget);
    expect(find.text('View in PDF'), findsOneWidget);
    expect(find.text('Start full assessment'), findsNothing);

    expect(logRepo.logs.single.retrieverType, 'stw_answerer_v1:answer');
    expect(logRepo.logs.single.regionId, expected.region!.chunkId);
    expect(logRepo.logs.single.found, isTrue);
  });

  testWidgets('ask-back chips answer from the chosen box', (tester) async {
    const q = 'How soon must CPAP be started?';
    final expected = await StwAnswerer(retriever).answer(q);
    expect(expected.kind, AnswerKind.clarify,
        reason: 'pick another ask-back query if tuning changed this one');
    final option = expected.options.first;

    await pumpChat(tester);
    await ask(tester, q);

    expect(find.text('Did you mean…'), findsOneWidget);
    expect(find.text('View in PDF'), findsNothing);
    await tester.tap(find.widgetWithText(ActionChip, option.sectionTitle).first);
    await tester.pumpAndSettle();

    expect(find.text('View in PDF'), findsOneWidget);
    expect(find.text('Show full STW box'), findsOneWidget);
    expect([for (final l in logRepo.logs) l.retrieverType], [
      'stw_answerer_v1:clarify',
      'stw_answerer_v1:answer',
    ]);
    expect(logRepo.logs.last.query, q);
    expect(logRepo.logs.last.regionId, option.chunkId);
  });

  testWidgets('case question echoes values and offers the assessment',
      (tester) async {
    const q = 'Baby glucose 32 mg/dL, no symptoms, what next?';
    final expected = await StwAnswerer(retriever).answer(q);
    expect(expected.kind, AnswerKind.answer);
    expect(expected.caseSummary, isNotNull);

    await pumpChat(tester);
    await ask(tester, q);

    expect(
      find.text('Read from your question: ${expected.caseSummary!.inputs}'),
      findsOneWidget,
    );
    await tester.tap(find.text('Start full assessment'));
    await tester.pumpAndSettle();
    expect(find.text('selection: ${NeonatalCondition.hypoglycemia}'),
        findsOneWidget);
  });

  testWidgets('out of scope says not covered', (tester) async {
    await pumpChat(tester);
    await ask(tester, 'Phototherapy threshold for neonatal jaundice');

    expect(find.text('Out of Scope'), findsOneWidget);
    expect(
      find.text('This information is not covered in the approved STW documents.'),
      findsOneWidget,
    );
    expect(logRepo.logs.single.retrieverType, 'stw_answerer_v1:notCovered');
    expect(logRepo.logs.single.found, isFalse);
  });
}
