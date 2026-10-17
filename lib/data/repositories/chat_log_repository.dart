import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/offline_queue.dart';

/// Repository for logging chatbot questions, extractive answers, and PDF source references.
class ChatLogRepository {
  ChatLogRepository({OfflineQueue? queue})
      : _queue = queue ?? OfflineQueue.instance;

  final OfflineQueue _queue;

  /// Id of the last logged turn, so the clinician's next action (opening
  /// the cited STW box, starting an assessment) can refer to it.
  String? get lastChatLogId => _lastChatLogId;
  String? _lastChatLogId;

  /// Logs an extractive chatbot conversation turn strictly grounded in ICMR STWs.
  ///
  /// [context] is the clinical state when the question was asked (selected
  /// topics, triage category, flags); structured values only. Returns the
  /// id of the log.
  Future<String> logChatQuery({
    String? sessionId,
    required String query,
    required String answer,
    required List<String> matchedChunkIds,
    Map<String, dynamic>? sourceMetadata,
    required bool found,
    String? regionId,
    String? retrieverType,
    Map<String, Object?>? context,
  }) async {
    final activeSessionId = sessionId ?? _queue.currentSessionId;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _queue.generateUuid();
    _lastChatLogId = id;

    await _queue.enqueue(
      table: 'chat_logs',
      action: 'insert',
      payload: {
        'id': id,
        'session_id': activeSessionId,
        'user_query': query,
        'extracted_answer': answer,
        'matched_chunk_ids': matchedChunkIds,
        'source_metadata': sourceMetadata ?? <String, dynamic>{},
        'found': found,
        if (regionId != null) 'region_id': regionId,
        if (retrieverType != null) 'retriever_type': retrieverType,
        if (context != null) 'context': storable(context),
        'created_at': now,
      },
    );
    return id;
  }
}

/// Global provider for [ChatLogRepository].
final chatLogRepositoryProvider = Provider<ChatLogRepository>((ref) {
  return ChatLogRepository();
});
