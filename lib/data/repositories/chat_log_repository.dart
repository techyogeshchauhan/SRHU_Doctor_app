import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/offline_queue.dart';

/// Repository for logging chatbot questions, extractive answers, and PDF source references.
class ChatLogRepository {
  ChatLogRepository({OfflineQueue? queue})
      : _queue = queue ?? OfflineQueue.instance;

  final OfflineQueue _queue;

  /// Logs an extractive chatbot conversation turn strictly grounded in ICMR STWs.
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
    final activeSessionId = sessionId ?? _queue.currentSessionId;
    final now = DateTime.now().toUtc().toIso8601String();

    await _queue.enqueue(
      table: 'chat_logs',
      action: 'insert',
      payload: {
        'id': _queue.generateUuid(),
        'session_id': activeSessionId,
        'user_query': query,
        'extracted_answer': answer,
        'matched_chunk_ids': matchedChunkIds,
        'source_metadata': sourceMetadata ?? <String, dynamic>{},
        'found': found,
        if (regionId != null) 'region_id': regionId,
        if (retrieverType != null) 'retriever_type': retrieverType,
        'created_at': now,
      },
    );
  }
}

/// Global provider for [ChatLogRepository].
final chatLogRepositoryProvider = Provider<ChatLogRepository>((ref) {
  return ChatLogRepository();
});
