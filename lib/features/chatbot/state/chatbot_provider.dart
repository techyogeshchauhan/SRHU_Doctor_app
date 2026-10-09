import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/chat_log_repository.dart';
import '../data/bm25_retriever.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/stw_chunk.dart';
import '../domain/retriever/stw_retriever.dart';

/// Provider for the abstract STW Retriever.
final stwRetrieverProvider = Provider<StwRetriever>((ref) {
  final retriever = Bm25Retriever();
  return retriever;
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

/// StateNotifier that handles searching and grounded message generation.
class ChatbotNotifier extends StateNotifier<ChatbotState> {
  final StwRetriever _retriever;
  final Future<void> Function(String query, String answer, SearchResult? result)?
      onMessageLogged;

  ChatbotNotifier(
    this._retriever, {
    this.onMessageLogged,
  }) : super(const ChatbotState(messages: []));

  /// Sends a user question and retrieves grounded STW text.
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
      final results = await _retriever.search(trimmed, limit: 1);
      final ChatMessage botMsg;

      if (results.isNotEmpty) {
        final missingNotice = Bm25Retriever.checkMissingDosageNotice(
          trimmed,
          results.first.chunk.text,
        );
        botMsg = ChatMessage.bot(
          result: results.first,
          missingNotice: missingNotice,
        );
      } else {
        botMsg = ChatMessage.notCovered();
      }

      state = state.copyWith(
        messages: [...state.messages, botMsg],
        isLoading: false,
      );

      // Async audit log callback (for database persistence in Step B)
      if (onMessageLogged != null) {
        onMessageLogged!(
          trimmed,
          botMsg.text,
          results.isNotEmpty ? results.first : null,
        ).catchError((_) {});
      }
    } catch (e) {
      final errorMsg = ChatMessage.notCovered();
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clears chat history.
  void clearHistory() {
    state = const ChatbotState(messages: []);
  }
}

/// Provider for Chatbot StateNotifier.
final chatbotNotifierProvider =
    StateNotifierProvider<ChatbotNotifier, ChatbotState>((ref) {
  final retriever = ref.watch(stwRetrieverProvider);
  final chatRepo = ref.watch(chatLogRepositoryProvider);
  return ChatbotNotifier(
    retriever,
    onMessageLogged: (query, answer, result) async {
      await chatRepo.logChatQuery(
        query: query,
        answer: answer,
        matchedChunkIds: result != null ? [result.chunk.chunkId] : [],
        sourceMetadata: result != null
            ? {
                'document': result.chunk.document,
                'page': result.chunk.page,
                'section': result.chunk.sectionTitle,
                'bounding_boxes': result.chunk.boundingBoxes
                    .map((b) => {
                          'x': b.x,
                          'y': b.y,
                          'width': b.width,
                          'height': b.height,
                        })
                    .toList(),
              }
            : null,
        found: result != null,
      );
    },
  );
});

