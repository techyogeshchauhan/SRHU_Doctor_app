import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/api_client.dart';

/// Manages offline-first storage and background sync to MongoDB Atlas REST API.
///
/// Features:
/// 1. Every write is saved locally first into Hive (IndexedDB on Web, binary on mobile).
/// 2. Unsynced writes queue up with client-generated UUIDs.
/// 3. Listens to connectivity changes via `connectivity_plus`.
/// 4. Flushes to REST API backend with exponential backoff on network availability.
/// 5. Stores active session token and screening mappings for offline continuity.
class OfflineQueue {
  OfflineQueue({
    this.sessionBoxName = 'stw_session_box',
    this.queueBoxName = 'stw_sync_queue_box',
    this.retryDelay = const Duration(seconds: 30),
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  static final OfflineQueue instance = OfflineQueue();

  final String sessionBoxName;
  final String queueBoxName;

  /// Wait before retrying after a transient failure (network, 5xx, 429).
  final Duration retryDelay;
  final ApiClient _apiClient;

  static const _uuid = Uuid();

  Box<dynamic>? _sessionBox;
  Box<dynamic>? _queueBox;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;
  Timer? _retryTimer;

  /// Set when a flush is requested while one is running; the running flush
  /// then makes another pass so new items are not left waiting.
  bool _flushAgain = false;

  /// Enqueue order. Hive returns keys sorted, not in insertion order, so each
  /// entry carries this sequence number and [flush] sends in that order.
  int _nextSeq = 0;

  /// Initializes local Hive storage and connectivity listener.
  Future<void> initialize({String? customPath}) async {
    try {
      if (customPath != null) {
        Hive.init(customPath);
      } else {
        await Hive.initFlutter();
      }
      _sessionBox = await Hive.openBox<dynamic>(sessionBoxName);
      _queueBox = await Hive.openBox<dynamic>(queueBoxName);
      for (final raw in _queueBox!.values) {
        final seq = raw is Map ? raw['seq'] : null;
        if (seq is int && seq >= _nextSeq) _nextSeq = seq + 1;
      }

      _connectivitySub = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        final hasConnection =
            results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          flush();
        }
      });

      // Attempt flush on startup
      flush();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineQueue] Local storage init error: $e');
      }
    }
  }

  /// Generates a new random UUID v4.
  String generateUuid() => _uuid.v4();

  // ---------------------------------------------------------------------------
  // Session Persistence
  // ---------------------------------------------------------------------------

  /// Retrieves or restores the current session ID.
  String? get currentSessionId =>
      (_sessionBox != null && _sessionBox!.isOpen)
          ? _sessionBox!.get('current_session_id') as String?
          : null;

  /// Sets the active session ID.
  Future<void> setSessionId(String sessionId) async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      await _sessionBox!.put('current_session_id', sessionId);
      await _sessionBox!.delete('current_session_closed');
    }
  }

  /// Forgets the current session; the next screening or chat opens a new one.
  Future<void> clearSessionId() async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      await _sessionBox!.delete('current_session_id');
      await _sessionBox!.delete('current_session_closed');
    }
  }

  /// Whether the current session was already closed (its end time is set).
  bool get isSessionClosed =>
      (_sessionBox != null && _sessionBox!.isOpen) &&
      _sessionBox!.get('current_session_closed') == true;

  Future<void> markSessionClosed() async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      await _sessionBox!.put('current_session_closed', true);
    }
  }

  /// Retrieves the stored session token or creates one if not present.
  String getOrCreateSessionToken() {
    if (_sessionBox == null || !_sessionBox!.isOpen) return generateUuid();
    var token = _sessionBox!.get('session_token') as String?;
    if (token == null || token.isEmpty) {
      token = generateUuid();
      _sessionBox!.put('session_token', token);
    }
    return token;
  }

  /// Maps active disease screenings (disease_code -> screening_id).
  Map<String, String> getActiveScreenings() {
    if (_sessionBox == null || !_sessionBox!.isOpen) return <String, String>{};
    final raw = _sessionBox!.get('active_screenings');
    if (raw is Map) {
      return Map<String, String>.from(raw);
    }
    return <String, String>{};
  }

  Future<void> setActiveScreening(String diseaseCode, String screeningId) async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      final current = getActiveScreenings();
      current[diseaseCode] = screeningId;
      await _sessionBox!.put('active_screenings', current);
    }
  }

  Future<void> clearActiveScreenings() async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      await _sessionBox!.delete('active_screenings');
      await _sessionBox!.delete('completed_screenings');
    }
  }

  /// Disease codes of active screenings already marked completed.
  Set<String> getCompletedScreenings() {
    if (_sessionBox == null || !_sessionBox!.isOpen) return <String>{};
    final raw = _sessionBox!.get('completed_screenings');
    return raw is List ? raw.map((e) => e.toString()).toSet() : <String>{};
  }

  Future<void> markScreeningCompleted(String diseaseCode) async {
    if (_sessionBox != null && _sessionBox!.isOpen) {
      final current = getCompletedScreenings()..add(diseaseCode);
      await _sessionBox!.put('completed_screenings', current.toList());
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Operations
  // ---------------------------------------------------------------------------

  /// Enqueues an operation to local storage and attempts immediate sync.
  Future<void> enqueue({
    required String table,
    required String action, // 'upsert' | 'insert' | 'patch_status'
    required Map<String, dynamic> payload,
    String? customId,
  }) async {
    final id = customId ?? generateUuid();
    final entry = <String, dynamic>{
      'id': id,
      'seq': _nextSeq++,
      'table': table,
      'action': action,
      'payload': storable(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retries': 0,
      'is_synced': false,
    };

    if (_queueBox != null && _queueBox!.isOpen) {
      await _queueBox!.put(id, entry);
    }

    // Try background sync immediately
    flush();
  }

  /// Returns count of pending unsynced queue operations.
  int get pendingCount =>
      (_queueBox != null && _queueBox!.isOpen) ? _queueBox!.length : 0;

  /// Flushes pending queue items to MongoDB Atlas REST API in enqueue order.
  ///
  /// A transient failure (network, 5xx, 429, auth) stops the pass and keeps
  /// the item for the next trigger. A permanent failure (rejected payload,
  /// missing screening, unencodable data) drops the item, so one bad entry
  /// cannot block everything queued after it.
  Future<void> flush() async {
    if (_isFlushing) {
      _flushAgain = true;
      return;
    }
    if (_queueBox == null || !_queueBox!.isOpen || _queueBox!.isEmpty) {
      return;
    }
    if (!_apiClient.isConfigured) {
      // Offline-only mode or missing keys: keep records safely stored in local queue.
      return;
    }

    _isFlushing = true;
    try {
      do {
        _flushAgain = false;
        if (!await _flushPass()) {
          // Retry later even if nothing new is queued meanwhile.
          _retryTimer ??= Timer(retryDelay, () {
            _retryTimer = null;
            flush();
          });
          break;
        }
      } while (_flushAgain);
    } finally {
      _isFlushing = false;
    }
  }

  /// One pass over the queue. Returns false when stopped by a transient error.
  Future<bool> _flushPass() async {
    final box = _queueBox;
    if (box == null || !box.isOpen) return false;

    final pending = <(dynamic, Map<String, dynamic>)>[];
    for (final key in List<dynamic>.from(box.keys)) {
      final raw = box.get(key);
      if (raw is Map) {
        pending.add((key, Map<String, dynamic>.from(raw)));
      } else {
        await box.delete(key);
      }
    }
    pending.sort((a, b) => _compareEntries(a.$2, b.$2));

    for (final (key, entry) in pending) {
      if (!box.isOpen) return false;
      final table = entry['table'] as String? ?? '';
      try {
        await _syncItem(
          table,
          entry['action'] as String? ?? '',
          Map<String, dynamic>.from(entry['payload'] as Map? ?? const {}),
        );
        await _deleteIfUnchanged(box, key, entry);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[OfflineQueue] Sync failed for $table ($key): $e');
        }
        if (!isRetryableSyncError(e)) {
          // Can never succeed as queued; drop it and keep going.
          await _deleteIfUnchanged(box, key, entry);
          continue;
        }
        final current = box.get(key);
        if (current is Map && current['seq'] == entry['seq']) {
          await box.put(key, {
            ...Map<String, dynamic>.from(current),
            'retries': (entry['retries'] as int? ?? 0) + 1,
          });
        }
        return false;
      }
    }
    return true;
  }

  /// Enqueue order; entries queued before sequence numbers existed sort
  /// first, by time.
  static int _compareEntries(Map<String, dynamic> a, Map<String, dynamic> b) {
    final bySeq = (a['seq'] as int? ?? -1).compareTo(b['seq'] as int? ?? -1);
    if (bySeq != 0) return bySeq;
    return (a['created_at'] as String? ?? '')
        .compareTo(b['created_at'] as String? ?? '');
  }

  /// Deletes [key] unless it was overwritten (same customId, newer value)
  /// while its previous value was being sent.
  static Future<void> _deleteIfUnchanged(
    Box<dynamic> box,
    dynamic key,
    Map<String, dynamic> sent,
  ) async {
    final current = box.get(key);
    if (current is Map && current['seq'] != sent['seq']) return;
    await box.delete(key);
  }

  Future<void> _syncItem(
    String table,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (table) {
      case 'sessions':
      case 'clinical_sessions':
        if (action == 'patch') {
          // Only the fields the API accepts (the local payload also holds
          // the id, which is in the URL).
          final id = payload['id'] as String;
          await _apiClient.patchSession(id, {
            if (payload['status'] != null) 'status': payload['status'],
            if (payload['ended_at'] != null) 'endedAt': payload['ended_at'],
          });
        } else {
          await _apiClient.createSession({
            '_id': payload['id'] ?? payload['_id'],
            'sessionToken': payload['session_token'] ?? payload['sessionToken'] ?? '',
            'facilityName': payload['facility_name'] ?? payload['facilityName'],
            'platform': payload['platform'] ?? 'unknown',
            'appVersion': payload['app_version'] ?? payload['appVersion'] ?? '0.1.0+1',
            'status': payload['status'] ?? 'in_progress',
            if (payload['selected_conditions'] is List)
              'selectedConditions': payload['selected_conditions'],
            if (payload['created_at'] != null) 'createdAt': payload['created_at'],
          });
        }
        break;

      case 'screenings':
      case 'disease_screenings':
        final screeningId = (payload['id'] ?? payload['_id']) as String;
        final progressState = payload['progress_state'] ?? payload['progressState'] ?? payload['status'];
        if (action == 'patch_status' || progressState == 'completed' || progressState == 'abandoned') {
          final status = (progressState ?? 'completed') as String;
          final completedAt = (payload['completed_at'] ?? payload['completedAt']) as String?;
          await _apiClient.patchScreeningStatus(
            screeningId,
            status,
            completedAt: completedAt,
          );
        } else {
          await _apiClient.putScreening(screeningId, {
            'sessionId': payload['session_id'] ?? payload['sessionId'],
            'diseaseCode': payload['disease_code'] ?? payload['diseaseCode'],
            'progressState': payload['progress_state'] ?? payload['progressState'] ?? 'in_progress',
            'isEligible': payload['is_eligible'] ?? payload['isEligible'],
            'status': payload['status'] ?? payload['progress_state'] ?? 'in_progress',
            if (payload['started_at'] != null) 'startedAt': payload['started_at'],
            if (payload['completed_at'] != null) 'completedAt': payload['completed_at'],
          });
        }
        break;

      case 'responses':
      case 'screening_responses':
        final sId = (payload['screening_id'] ?? payload['screeningId']) as String;
        final qId = (payload['question_id'] ?? payload['questionId']) as String;
        final responseData = payload['response_data'];
        final val = (responseData is Map && responseData.containsKey('value'))
            ? responseData['value']
            : (payload['value'] ?? payload['responseData']);

        await _apiClient.putResponse(
          screeningId: sId,
          questionId: qId,
          data: {
            'value': val,
            if (payload['unit'] != null) 'unit': payload['unit'],
            if (payload['input_mode'] != null) 'inputMode': payload['input_mode'],
            if (payload['answered_at'] != null) 'answeredAt': payload['answered_at'],
          },
        );
        break;

      case 'findings':
      case 'clinical_findings':
        final sId = (payload['screening_id'] ?? payload['screeningId']) as String;
        List<Map<String, dynamic>> findingsList;

        if (payload.containsKey('findings') && payload['findings'] is List) {
          findingsList = List<Map<String, dynamic>>.from(payload['findings'] as List);
        } else {
          findingsList = [
            {
              'type': payload['finding_type'] ?? payload['type'] ?? 'primary',
              'title': payload['finding_title'] ?? payload['title'] ?? 'Finding',
              'severity': payload['severity_grade'] ?? payload['severity'] ?? 'moderate',
              'recommendations': payload['recommendations'] ?? <String>[],
              if (payload['stw_reference'] != null || payload['stwReference'] != null)
                'stwReference': payload['stw_reference'] ?? payload['stwReference'],
              if (payload['generated_at'] != null) 'generatedAt': payload['generated_at'],
            }
          ];
        }
        await _apiClient.postFindings(sId, findingsList);
        break;

      case 'screening_findings':
        // Full snapshot of the screening's current findings; replaces any
        // earlier snapshot so re-completing does not duplicate them.
        await _apiClient.replaceFindings(
          payload['screening_id'] as String,
          List<Map<String, dynamic>>.from(payload['findings'] as List),
        );
        break;

      case 'mcq_attempts':
        final sId = (payload['screening_id'] ?? payload['screeningId']) as String;
        await _apiClient.postMcqAttempt(sId, {
          'questionId': payload['question_id'] ?? payload['questionId'],
          'selectedOption': payload['selected_option'] ?? payload['selectedOption'],
          'isCorrect': payload['is_correct'] ?? payload['isCorrect'],
          if (payload['answered_at'] != null) 'answeredAt': payload['answered_at'],
        });
        break;

      case 'chat_logs':
        // Only answers have a source box; "not covered" and "did you mean"
        // logs send null rather than a made-up document.
        final rawSource = payload['source_metadata'] ?? payload['source'];
        final sourceMap = rawSource is Map && rawSource['document'] != null
            ? {
                'document': rawSource['document'].toString(),
                'page': rawSource['page'] is int ? rawSource['page'] : 1,
                if (rawSource['section'] != null)
                  'section': rawSource['section'].toString(),
              }
            : null;

        final chunkList = <String>[];
        if (payload['matched_chunk_ids'] is List) {
          chunkList.addAll((payload['matched_chunk_ids'] as List).map((e) => e.toString()));
        } else if (payload['chunkIds'] is List) {
          chunkList.addAll((payload['chunkIds'] as List).map((e) => e.toString()));
        }

        await _apiClient.postChatLog({
          '_id': payload['id'] ?? payload['_id'],
          if (payload['session_id'] != null || payload['sessionId'] != null)
            'sessionId': payload['session_id'] ?? payload['sessionId'],
          'userQuery': payload['user_query'] ?? payload['userQuery'] ?? '',
          'extractedAnswer': payload['extracted_answer'] ?? payload['extractedAnswer'] ?? '',
          if (payload['region_id'] != null || payload['regionId'] != null)
            'regionId': payload['region_id'] ?? payload['regionId'],
          'chunkIds': chunkList,
          'source': sourceMap,
          'found': payload['found'] ?? true,
          'retrieverType': payload['retriever_type'] ?? payload['retrieverType'] ?? 'bm25_pure_dart',
          if (payload['created_at'] != null) 'createdAt': payload['created_at'],
        });
        break;

      default:
        if (kDebugMode) {
          debugPrint('[OfflineQueue] Unknown sync table: $table');
        }
    }
  }

  /// Closes resources (used in tests/app exit).
  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _connectivitySub?.cancel();
    await _sessionBox?.close();
    await _queueBox?.close();
  }
}

/// Converts [value] to types both Hive and JSON can hold: sets and other
/// iterables become lists, dates become UTC ISO-8601 strings, anything else
/// unknown becomes its string form.
Object? storable(Object? value) => switch (value) {
      null || bool() || num() || String() => value,
      DateTime() => value.toUtc().toIso8601String(),
      Map() => <String, dynamic>{
          for (final e in value.entries) e.key.toString(): storable(e.value),
        },
      Iterable() => [for (final v in value) storable(v)],
      _ => value.toString(),
    };

/// Whether a failed sync may succeed later unchanged. Network problems,
/// server errors, rate limiting and auth/config problems are retried; a
/// rejected payload (400/404/422) or a failure to build the request is not.
bool isRetryableSyncError(Object error) {
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.badResponse => switch (error.response?.statusCode ?? 0) {
        401 || 403 || 408 || 429 => true,
        final s => s >= 500,
      },
    DioExceptionType.unknown => false,
    _ => true,
  };
}
