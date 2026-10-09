import '../models/stw_chunk.dart';

/// Abstract interface for STW content retrieval.
/// Allows swapping between local pure-Dart BM25 and future server-side retrieval.
abstract class StwRetriever {
  /// Initializes the index and resources.
  Future<void> initialize();

  /// Searches for chunks relevant to the user's clinical query.
  /// Returns top scored results (empty list if below threshold).
  Future<List<SearchResult>> search(String query, {int limit = 3});

  /// The standard fall-back response when no matching information is found in STWs.
  static const String notCoveredMessage =
      'This information is not covered in the approved STW documents.';
}
