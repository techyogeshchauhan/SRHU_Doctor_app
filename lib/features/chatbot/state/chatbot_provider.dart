import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/chat_log_repository.dart';
import '../../../data/repositories/screening_sync_repository.dart';
import '../data/bm25_retriever.dart';
import '../domain/answering/answer_composer.dart';
import '../domain/answering/stw_answer.dart';
import '../domain/answering/stw_answerer.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/stw_chunk.dart';

/// Keyword retriever over the STW regions (assets/regions/regions.json).
final stwRetrieverProvider = Provider<Bm25Retriever>((ref) {
  return Bm25Retriever();
});

/// Understands the question and answers with verbatim STW lines.
final stwAnswererProvider = Provider<StwAnswerer>((ref) {
  return StwAnswerer(ref.watch(stwRetrieverProvider));
});

/// State for the Clinical Chatbot.
class ChatbotState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatbotState({
    required this.messages,
    this.isLoading = false,
    this.error,
  });

  ChatbotState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// StateNotifier that handles questions and grounded answers.
class ChatbotNotifier extends StateNotifier<ChatbotState> {
  final StwAnswerer _answerer;
  final Future<void> Function(String query, StwAnswer answer, String text)?
      onMessageLogged;

  ChatbotNotifier(
    this._answerer, {
    this.onMessageLogged,
  }) : super(const ChatbotState(messages: []));

  /// Sends a user question and answers it from the STWs.
  Future<void> sendQuery(String queryText) async {
    final trimmed = queryText.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage.user(text: trimmed);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final answer = await _answerer.answer(trimmed);
      _addBotAnswer(trimmed, answer);
    } catch (e) {
      final errorMsg = ChatMessage.notCovered();
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// The user picked [option] from an ask-back message: show that box's
  /// lines for the original question.
  void chooseOption(ChatMessage clarifyMessage, StwChunk option) {
    final asked = clarifyMessage.answer;
    if (asked == null || asked.kind != AnswerKind.clarify) return;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.user(text: option.sectionTitle)],
    );
    _addBotAnswer(
      asked.analysis.raw,
      StwAnswer.answer(
        analysis: asked.analysis,
        region: option,
        lines: composeAnswer(option, asked.analysis),
      ),
    );
  }

  void _addBotAnswer(String query, StwAnswer answer) {
    final botMsg = ChatMessage.fromAnswer(answer);
    state = state.copyWith(
      messages: [...state.messages, botMsg],
      isLoading: false,
    );
    onMessageLogged?.call(query, answer, botMsg.text).catchError((_) {});
  }

  /// Clears chat history.
  void clearHistory() {
    state = const ChatbotState(messages: []);
  }
}

/// Provider for Chatbot StateNotifier.
final chatbotNotifierProvider =
    StateNotifierProvider<ChatbotNotifier, ChatbotState>((ref) {
  final answerer = ref.watch(stwAnswererProvider);
  final chatRepo = ref.watch(chatLogRepositoryProvider);
  final syncRepo = ref.watch(screeningSyncRepositoryProvider);
  return ChatbotNotifier(
    answerer,
    onMessageLogged: (query, answer, text) async {
      final region = answer.region;
      // Chat can come before any screening: create the session if needed,
      // so every log belongs to one.
      final sessionId = await syncRepo.ensureSession();
      await chatRepo.logChatQuery(
        sessionId: sessionId,
        query: query,
        answer: text,
        matchedChunkIds: [
          if (region != null) region.chunkId,
          for (final o in answer.options) o.chunkId,
        ],
        regionId: region?.chunkId,
        retrieverType: 'stw_answerer_v1:${answer.kind.name}',
        sourceMetadata: region != null
            ? {
                'document': region.document,
                'page': region.page,
                'section': region.sectionTitle,
                'bounding_boxes': region.boundingBoxes
                    .map((b) => {
                          'x': b.x,
                          'y': b.y,
                          'width': b.width,
                          'height': b.height,
                        })
                    .toList(),
              }
            : null,
        found: answer.kind == AnswerKind.answer,
      );
    },
  );
});
