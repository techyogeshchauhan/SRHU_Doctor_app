import '../answering/stw_answer.dart';
import 'stw_chunk.dart';

/// A message in the STW Clinical Chatbot interface.
class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final SearchResult? searchResult;
  final bool isNotCovered;
  final String? missingNotice;

  /// Understood answer: verbatim lines, ask-back options or not covered.
  final StwAnswer? answer;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.searchResult,
    this.isNotCovered = false,
    this.missingNotice,
    this.answer,
  });

  /// Creates a user message.
  factory ChatMessage.user({
    required String text,
    String? id,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      isUser: true,
      text: text,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Creates a bot message grounded in an STW chunk.
  factory ChatMessage.bot({
    required SearchResult result,
    String? id,
    DateTime? timestamp,
    String? missingNotice,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      isUser: false,
      text: result.chunk.text,
      timestamp: timestamp ?? DateTime.now(),
      searchResult: result,
      isNotCovered: false,
      missingNotice: missingNotice,
    );
  }

  /// Creates a bot fallback message when no relevant STW chunk was found.
  factory ChatMessage.notCovered({
    String? id,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      isUser: false,
      text: 'This information is not covered in the approved STW documents.',
      timestamp: timestamp ?? DateTime.now(),
      isNotCovered: true,
    );
  }

  /// Creates a bot message from an [StwAnswer].
  factory ChatMessage.fromAnswer(
    StwAnswer answer, {
    String? id,
    DateTime? timestamp,
  }) {
    final text = switch (answer.kind) {
      AnswerKind.answer => answer.lines.map((l) => l.display).join('\n'),
      AnswerKind.clarify => answer.prompt ?? 'Which of these do you mean?',
      AnswerKind.notCovered =>
        'This information is not covered in the approved STW documents.',
    };
    return ChatMessage(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      isUser: false,
      text: text,
      timestamp: timestamp ?? DateTime.now(),
      isNotCovered: answer.kind == AnswerKind.notCovered,
      answer: answer,
    );
  }
}
