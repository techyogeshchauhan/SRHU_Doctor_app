import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/stw_chunk.dart';
import '../domain/retriever/stw_retriever.dart';

/// Pure-Dart BM25 search engine with fuzzy matching, clinical synonym expansion,
/// and exact numerical/unit boosting over curated STW regions.
class Bm25Retriever implements StwRetriever {
  final String indexPath;
  final String synonymsPath;

  List<StwChunk> _chunks = [];
  Map<String, List<String>> _synonyms = {};

  // Inverted index: term -> Map<chunk_id, term_frequency>
  final Map<String, Map<String, int>> _invertedIndex = {};
  final Map<String, int> _docLengths = {};
  double _avgDocLength = 0.0;

  // BM25 tuning constants
  static const double kK1 = 1.2;
  static const double kB = 0.75;
  static const double kMinScoreThreshold = 2.4;

  Bm25Retriever({
    this.indexPath = 'assets/regions/regions.json',
    this.synonymsPath = 'assets/stw_index/clinical_synonyms.json',
    List<StwChunk>? initialChunks,
    Map<String, List<String>>? initialSynonyms,
  }) {
    if (initialChunks != null) {
      _chunks = initialChunks;
      if (initialSynonyms != null) {
        _synonyms = initialSynonyms;
      }
      _buildIndex();
    }
  }

  @override
  Future<void> initialize() async {
    if (_chunks.isNotEmpty) return; // already initialized (e.g. in tests)

    String? indexJson;
    try {
      indexJson = await rootBundle.loadString(indexPath);
    } catch (_) {
      // Fallback to stw_index.json if regions.json is not yet built
      indexJson = await rootBundle.loadString('assets/stw_index/stw_index.json');
    }

    final List<dynamic> rawChunks = jsonDecode(indexJson) as List<dynamic>;
    _chunks = rawChunks
        .map((e) => StwChunk.fromJson(e as Map<String, dynamic>))
        .toList();

    try {
      final synJson = await rootBundle.loadString(synonymsPath);
      final rawSyn = jsonDecode(synJson) as Map<String, dynamic>;
      _synonyms = rawSyn.map(
        (key, value) => MapEntry(
          key.toLowerCase(),
          (value as List<dynamic>)
              .map((e) => e.toString().toLowerCase())
              .toList(),
        ),
      );
    } catch (_) {
      _synonyms = {};
    }

    _buildIndex();
  }

  void _buildIndex() {
    _invertedIndex.clear();
    _docLengths.clear();

    int totalLength = 0;
    for (final chunk in _chunks) {
      final fullContent = [
        chunk.sectionTitle,
        chunk.text,
        chunk.keywords.join(' '),
        chunk.aliases.join(' '),
        chunk.exampleQuestions.join(' '),
        chunk.section ?? '',
      ].join(' ');

      final tokens = _tokenize(fullContent);
      _docLengths[chunk.chunkId] = tokens.length;
      totalLength += tokens.length;

      for (final t in tokens) {
        final termPosting = _invertedIndex.putIfAbsent(t, () => {});
        termPosting[chunk.chunkId] = (termPosting[chunk.chunkId] ?? 0) + 1;
      }
    }

    _avgDocLength = _chunks.isEmpty ? 1.0 : totalLength / _chunks.length;
  }

  List<String> _tokenize(String text) {
    // Preserve clinical tokens: numbers, decimals, units, comparison symbols
    final cleaned =
        text.toLowerCase().replaceAll(RegExp(r'[^\w\s\.\-%/<≥≤]'), ' ');
    final rawTokens = cleaned.split(RegExp(r'\s+'));
    return rawTokens.where((t) => t.length > 1 && !_isStopWord(t)).toList();
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'and', 'or', 'for', 'with', 'this', 'that', 'from', 'may',
      'are', 'not', 'any', 'all', 'per', 'one', 'has', 'been', 'was',
      'into', 'use', 'used', 'after', 'before', 'when', 'where', 'how',
      'who', 'can', 'must', 'should', 'will', 'than', 'then', 'their', 'what',
      'to', 'in', 'of', 'on', 'at', 'by', 'as', 'an', 'is', 'be', 'so',
      'do', 'does', 'did', 'have', 'had', 'it', 'its', 'which', 'about',
      'some', 'such', 'only', 'also', 'over', 'more', 'most', 'other',
      'hai', 'hain', 'mein', 'ko', 'se', 'ka', 'ki', 'ke', 'aur', 'kya',
      'bhi', 'par', 'karein', 'hona', 'hote', 'hoti', 'karna', 'karke',
      // Hinglish for 'should' / 'to do' (like 'should' and 'karna' above).
      'chahiye', 'karni'
    };
    return stopWords.contains(word);
  }

  /// Levenshtein distance for fuzzy matching of typos and spelling variations.
  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    final List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  List<String> _expandQueryWithSynonyms(String query) {
    final qLower = query.toLowerCase();
    final tokens = _tokenize(query);
    final expanded = <String>{...tokens};

    // 1. Clinical abbreviations and synonyms
    for (final entry in _synonyms.entries) {
      if (RegExp(r'\b' + RegExp.escape(entry.key) + r'\b').hasMatch(qLower)) {
        for (final alt in entry.value) {
          expanded.addAll(_tokenize(alt));
        }
      }
    }

    // 2. Specialized clinical keywords
    if (RegExp(r'\b(rds|rd)\b').hasMatch(qLower)) {
      expanded.addAll(['respiratory', 'distress']);
    }
    if (RegExp(r'\brop\b').hasMatch(qLower)) {
      expanded.addAll(['retinopathy', 'prematurity', 'retinal']);
    }
    if (RegExp(r'\bcaffeine\b').hasMatch(qLower)) {
      expanded.addAll(['citrate', 'caffeine citrate']);
    }
    if (RegExp(r'\b(sas|silverman)\b').hasMatch(qLower)) {
      expanded.addAll(['silverman', 'andersen', 'score', 'retractions', 'grunt']);
    }
    if (RegExp(r'\bsurfactant\b').hasMatch(qLower)) {
      expanded.addAll(['surfactant', 'peep', 'fio2']);
    }
    if (RegExp(r'\bcpap\b').hasMatch(qLower)) {
      expanded.addAll(['cpap', 'peep', 'pressure']);
    }
    if (RegExp(r'\blaser\b').hasMatch(qLower)) {
      expanded.addAll(['photocoagulation', 'laser']);
    }
    if (RegExp(r'\b(vegf|anti-vegf)\b').hasMatch(qLower)) {
      expanded.addAll(['anti-vegf', 'intravitreal', 'injection']);
    }

    // 3. Hinglish clinical concept mappings
    if (RegExp(r'\b(bacche|baccha|baby|newborn)\b').hasMatch(qLower)) {
      expanded.addAll(['neonate', 'preterm', 'infant']);
    }
    if (RegExp(r'\b(saans|sans)\b').hasMatch(qLower)) {
      expanded.addAll(['respiratory', 'breathing', 'distress']);
    }
    if (RegExp(r'\b(shuru|start|chalu)\b').hasMatch(qLower)) {
      expanded.addAll(['start', 'initiation', 'initial']);
    }
    if (RegExp(r'\b(rokna|roko|band|hatayein)\b').hasMatch(qLower)) {
      expanded.addAll(['stop', 'wean', 'termination']);
    }
    if (RegExp(r'\b(dawa|dawai|khuraak)\b').hasMatch(qLower)) {
      expanded.addAll(['dose', 'dosage', 'therapy']);
    }
    if (RegExp(r'\b(ilaj|upchaar)\b').hasMatch(qLower)) {
      expanded.addAll(['treatment', 'management', 'support']);
    }
    if (RegExp(r'\b(aankh|aankhein|eye)\b').hasMatch(qLower)) {
      expanded.addAll(['retinopathy', 'rop', 'eye']);
    }

    return expanded.toList();
  }

  @override
  Future<List<SearchResult>> search(String query, {int limit = 3}) async {
    if (_chunks.isEmpty) {
      await initialize();
    }
    return _rank(query, filter: true).take(limit).toList();
  }

  /// Every chunk with a positive keyword score, best first, without the
  /// relevance thresholds [search] applies. For callers that combine this
  /// score with other signals (topic, intent).
  Future<List<SearchResult>> scoreAll(String query) async {
    if (_chunks.isEmpty) {
      await initialize();
    }
    return _rank(query, filter: false);
  }

  /// Chunks loaded into the index (after [initialize]).
  List<StwChunk> get chunks => List.unmodifiable(_chunks);

  List<SearchResult> _rank(String query, {required bool filter}) {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) return [];

    final queryTokens = _expandQueryWithSynonyms(query);
    if (queryTokens.isEmpty) return [];

    final scores = <String, double>{};
    final matchedTokensMap = <String, Set<String>>{};
    final numDocs = _chunks.length;

    // 1. BM25 term weighting
    for (final term in queryTokens) {
      final posting = _invertedIndex[term];
      if (posting != null) {
        final docFreq = posting.length;
        final idf = log(1.0 + (numDocs - docFreq + 0.5) / (docFreq + 0.5));

        for (final entry in posting.entries) {
          final chunkId = entry.key;
          final freq = entry.value;
          final docLen = _docLengths[chunkId] ?? _avgDocLength.toInt();

          final tfNumerator = freq * (kK1 + 1.0);
          final tfDenominator =
              freq + kK1 * (1.0 - kB + kB * (docLen / _avgDocLength));
          final termScore = idf * (tfNumerator / tfDenominator);

          scores[chunkId] = (scores[chunkId] ?? 0.0) + termScore;
          matchedTokensMap.putIfAbsent(chunkId, () => {}).add(term);
        }
      } else if (term.length >= 4) {
        // Fuzzy match: check candidate vocabulary within Levenshtein distance 1
        for (final vocabTerm in _invertedIndex.keys) {
          if ((vocabTerm.length - term.length).abs() <= 1 &&
              _levenshtein(term, vocabTerm) <= 1) {
            final fPosting = _invertedIndex[vocabTerm]!;
            final docFreq = fPosting.length;
            final idf = log(1.0 + (numDocs - docFreq + 0.5) / (docFreq + 0.5));

            for (final entry in fPosting.entries) {
              final chunkId = entry.key;
              final freq = entry.value;
              final docLen = _docLengths[chunkId] ?? _avgDocLength.toInt();

              final tfNumerator = freq * (kK1 + 1.0);
              final tfDenominator =
                  freq + kK1 * (1.0 - kB + kB * (docLen / _avgDocLength));
              // Weight fuzzy match at 65% of exact match
              final termScore = 0.65 * idf * (tfNumerator / tfDenominator);

              scores[chunkId] = (scores[chunkId] ?? 0.0) + termScore;
              matchedTokensMap.putIfAbsent(chunkId, () => {}).add(vocabTerm);
            }
          }
        }
      }
    }

    // 2. Clinical domain boosting
    final scoredResults = <SearchResult>[];
    for (final chunk in _chunks) {
      double baseScore = scores[chunk.chunkId] ?? 0.0;
      if (baseScore <= 0.0) continue;

      final chunkTextLower =
          '${chunk.sectionTitle} ${chunk.text} ${chunk.aliases.join(" ")}'
              .toLowerCase();
      final questionsLower = chunk.exampleQuestions.join(' ').toLowerCase();

      // (a) Exact phrase match in title or text
      final rawTokens = _tokenize(query);
      for (final raw in rawTokens) {
        if (RegExp(r'\b' + RegExp.escape(raw) + r'\b').hasMatch(chunkTextLower)) {
          baseScore += 1.2;
        }
      }

      // (b) Exact boost for numbers, clinical cutoff markers, and units
      final criticalUnits = [
        '5-6 cm h2o', '4-5 cm h2o', '7-8 cm h2o', '5 cm h2o',
        '>60/min', '>60', '<34 weeks', '≤34 weeks', '>34 weeks', '<28 weeks',
        '<2000 g', '<2000g', '<1200 g', '<1200g', '34-36 weeks',
        '91-95%', 'fio2 >0.30', 'peep >6', '0.21',
        'zone i', 'zone ii', 'zone iii', 'zone 1', 'zone 2', 'zone 3',
        'stage 2', 'stage 3', 'stage 4', 'stage 5', 'plus disease',
        '48-72 hours', '4 weeks', '2-3 weeks', '45 weeks', 'pma 45',
        'phenylephrine 2.5%', 'tropicamide 0.5-0.8%', 'proparacaine 0.5%',
        '20d', '28d', 'caffeine citrate', 'surfactant', 'nasal prongs',
        'bubble cpap', 'a-rop', 'ap-rop'
      ];
      for (final marker in criticalUnits) {
        if (queryLower.contains(marker) &&
            (chunkTextLower.contains(marker) || questionsLower.contains(marker))) {
          baseScore += 4.5;
        }
      }

      // (c) Example questions direct alignment boost (super high precision for intent)
      for (final q in chunk.exampleQuestions) {
        final qToks = _tokenize(q);
        int sharedCount = 0;
        for (final rt in rawTokens) {
          if (qToks.contains(rt)) sharedCount++;
        }
        if (sharedCount >= 3 || (rawTokens.length <= 2 && sharedCount >= 2)) {
          baseScore += 5.0;
          break;
        }
      }

      // (d) Title match boost
      for (final raw in rawTokens) {
        if (RegExp(r'\b' + RegExp.escape(raw) + r'\b')
            .hasMatch(chunk.sectionTitle.toLowerCase())) {
          baseScore += 2.0;
        }
      }

      // (e) Algorithm / DOs / DON'Ts intent boost
      if ((queryLower.contains('algorithm') ||
              queryLower.contains('flowchart') ||
              queryLower.contains('steps') ||
              queryLower.contains('protocol')) &&
          chunk.type == 'algorithm') {
        baseScore += 2.5;
      }
      if ((queryLower.contains('do not') ||
              queryLower.contains("don't") ||
              queryLower.contains('avoid')) &&
          chunk.chunkId.contains('donts')) {
        baseScore += 6.0;
      } else if (RegExp(r'\bdo\b').hasMatch(queryLower) &&
          !queryLower.contains('do not') &&
          chunk.chunkId.contains('dos')) {
        baseScore += 4.0;
      }

      // Safety check: require at least one specific clinical match
      final matchedTokens = matchedTokensMap[chunk.chunkId] ?? {};
      const genericNonSpecific = {
        'treat', 'treatment', 'care', 'manage', 'management', 'give', 'given',
        'technique', 'procedure', 'method', 'approach', 'guideline', 'protocol',
        'how', 'what', 'when', 'who', 'where', 'why', 'can', 'should', 'must',
        'adult', 'infant', 'baby', 'child', 'doctor', 'patient'
      };
      final hasSpecificClinicalMatch =
          matchedTokens.any((t) => !genericNonSpecific.contains(t));

      // Precision check for multi-token queries
      final distinctQueryTokens = _tokenize(query);
      if (filter &&
          distinctQueryTokens.length >= 3 &&
          matchedTokens.length < 2) {
        continue;
      }

      if (!filter ||
          (baseScore >= kMinScoreThreshold && hasSpecificClinicalMatch)) {
        scoredResults.add(
          SearchResult(
            chunk: chunk,
            score: baseScore,
            matchedTokens: matchedTokens.toList(),
          ),
        );
      }
    }

    scoredResults.sort((a, b) => b.score.compareTo(a.score));
    return scoredResults;
  }

  /// Checks if a multi-part query requests dosage when the retrieved text lacks it.
  static String? checkMissingDosageNotice(String query, String retrievedText) {
    final qLower = query.toLowerCase();
    final asksForDosage = qLower.contains('dosage') ||
        qLower.contains('dose') ||
        qLower.contains('dosing') ||
        qLower.contains('khuraak');

    if (!asksForDosage) return null;

    final textLower = retrievedText.toLowerCase();
    // Check if retrieved text contains numerical weight-based dose pattern
    final hasWeightBasedDose = RegExp(
      r'\b\d+(?:\.\d+)?\s*(mg|mcg|µg|ml|iu)/(?:kg|dose|day)\b',
      caseSensitive: false,
    ).hasMatch(textLower);

    if (!hasWeightBasedDose) {
      return 'Dosage is not mentioned in the retrieved STW section.';
    }
    return null;
  }
}
