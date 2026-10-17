import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/audit_log_repository.dart';
import 'package:neonatal_stw/data/repositories/chat_log_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_finding.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient Unit Tests', () {
    test('isConfigured is false when baseUrl or apiKey are empty', () {
      final client = ApiClient(baseUrl: '', apiKey: '');
      expect(client.isConfigured, isFalse);
    });

    test('isConfigured is true when both baseUrl and apiKey are provided', () {
      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        apiKey: 'test_key_123',
      );
      expect(client.isConfigured, isTrue);
      expect(client.dio.options.headers['x-api-key'], equals('test_key_123'));
      expect(client.dio.options.baseUrl, equals('http://localhost:3000'));
    });
  });

  group('OfflineQueue and Repository Tests', () {
    late Directory tempDir;
    late OfflineQueue queue;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_queue_test_');
      queue = OfflineQueue(
        sessionBoxName: 'test_session_box_${DateTime.now().microsecondsSinceEpoch}',
        queueBoxName: 'test_queue_box_${DateTime.now().microsecondsSinceEpoch}',
        apiClient: ApiClient(baseUrl: '', apiKey: ''),
      );
      await queue.initialize(customPath: tempDir.path);
    });

    tearDown(() async {
      await queue.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generateUuid produces valid UUID v4', () {
      final uuid1 = queue.generateUuid();
      final uuid2 = queue.generateUuid();
      expect(uuid1, isNotEmpty);
      expect(uuid2, isNotEmpty);
      expect(uuid1, isNot(equals(uuid2)));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
            .hasMatch(uuid1),
        isTrue,
      );
    });

    test('persists session ID and active screenings', () async {
      expect(queue.currentSessionId, isNull);

      final sessionId = queue.generateUuid();
      await queue.setSessionId(sessionId);
      expect(queue.currentSessionId, equals(sessionId));

      final token = queue.getOrCreateSessionToken();
      expect(token, isNotEmpty);
      expect(queue.getOrCreateSessionToken(), equals(token));

      await queue.setActiveScreening('respiratory_distress', 'scr_123');
      expect(queue.getActiveScreenings()['respiratory_distress'], equals('scr_123'));

      await queue.clearActiveScreenings();
      expect(queue.getActiveScreenings(), isEmpty);
    });

    test('enqueues items to local storage with pending count', () async {
      expect(queue.pendingCount, equals(0));

      await queue.enqueue(
        table: 'screenings',
        action: 'put',
        payload: {
          'id': 'scr_1',
          'sessionId': 'sess_1',
          'diseaseCode': 'rop',
        },
      );

      expect(queue.pendingCount, equals(1));
    });

    test('enqueue stores sets and dates in Hive/JSON-safe form', () async {
      await queue.enqueue(
        table: 'screening_responses',
        action: 'upsert',
        customId: 'k',
        payload: {
          'value': <Object>{'grunting', 'flaring'},
          'when': DateTime.utc(2026, 9, 1),
        },
      );
      expect(queue.pendingCount, equals(1));
      expect(
        storable({
          'a': <Object>{1, 2},
          'b': DateTime.utc(2026, 9, 1),
        }),
        equals({
          'a': [1, 2],
          'b': '2026-09-01T00:00:00.000Z',
        }),
      );
    });

    test('isSyncableQuestion keeps dates and free text on the device', () {
      expect(isSyncableQuestion(qDob), isFalse);
      expect(isSyncableQuestion(qRopSncuNo), isFalse);
      expect(isSyncableQuestion(qBirthWeight), isTrue);
      expect(isSyncableQuestion(qGaKnown), isTrue);
    });

    test('completed screenings are not marked abandoned and are not reused',
        () async {
      final repo = ScreeningSyncRepository(queue: queue);
      final first = await repo.startDiseaseScreening('rop');
      await repo.completeScreening('rop');

      final before = queue.pendingCount;
      await repo.abandonActiveScreenings();
      expect(queue.pendingCount, equals(before));

      final second = await repo.startDiseaseScreening('rop');
      expect(second, isNot(equals(first)));
    });

    test('recordFindings keeps one pending snapshot per screening', () async {
      final repo = ScreeningSyncRepository(queue: queue);
      await repo.startDiseaseScreening('rop');
      await repo.recordFindings(diseaseCode: 'rop', findings: const []);
      final after = queue.pendingCount;
      await repo.recordFindings(diseaseCode: 'rop', findings: const []);
      expect(queue.pendingCount, equals(after));
    });

    test('concurrent screening starts share one session and screening',
        () async {
      final repo = ScreeningSyncRepository(queue: queue);
      final ids = await Future.wait([
        repo.startDiseaseScreening('rop'),
        repo.startDiseaseScreening('rop'),
        repo.startDiseaseScreening('respiratory_distress'),
      ]);
      expect(ids[0], equals(ids[1]));
      // One session + two screenings.
      expect(queue.pendingCount, equals(3));
    });

    test('diseaseCodeOf maps conditions to database codes', () {
      expect(diseaseCodeOf(NeonatalCondition.respiratoryDistress), equals('respiratory_distress'));
      expect(diseaseCodeOf(NeonatalCondition.rop), equals('rop'));
      expect(diseaseCodeOf(NeonatalCondition.thermalCare), equals('thermal_care'));
      expect(diseaseCodeOf(NeonatalCondition.fluidsAndFeeds), equals('fluids_and_feeds'));
      expect(diseaseCodeOf(NeonatalCondition.dischargeAndFollowUp), equals('discharge_and_follow_up'));
    });
  });

  group('OfflineQueue flush', () {
    late Directory tempDir;
    late OfflineQueue queue;
    late _FakeAdapter adapter;
    late String sessionBox;
    late String queueBox;

    late String deadBox;

    OfflineQueue onlineQueue({String? version, int maxDeadLetters = 500}) =>
        OfflineQueue(
          sessionBoxName: sessionBox,
          queueBoxName: queueBox,
          deadLetterBoxName: deadBox,
          version: version,
          maxDeadLetters: maxDeadLetters,
          apiClient: ApiClient(
            baseUrl: 'http://test',
            apiKey: 'k',
            dio: Dio(BaseOptions(baseUrl: 'http://test'))
              ..httpClientAdapter = adapter,
          ),
        );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_flush_test_');
      adapter = _FakeAdapter();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      sessionBox = 'flush_session_$stamp';
      queueBox = 'flush_queue_$stamp';
      deadBox = 'flush_dead_$stamp';
      queue = onlineQueue();
      await queue.initialize(customPath: tempDir.path);
    });

    tearDown(() async {
      await queue.dispose();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<void> enqueueStatus(String id) => queue.enqueue(
          table: 'disease_screenings',
          action: 'patch_status',
          payload: {'id': id, 'progress_state': 'completed'},
        );

    Future<void> settle() async {
      for (var i = 0; i < 100 && (adapter.inFlight || queue.pendingCount > 0); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    test('sends items in enqueue order, not Hive key order', () async {
      // Queue while offline (unconfigured client), then reopen online.
      await queue.dispose();
      final offline = OfflineQueue(
        sessionBoxName: sessionBox,
        queueBoxName: queueBox,
        apiClient: ApiClient(baseUrl: '', apiKey: ''),
      );
      await offline.initialize(customPath: tempDir.path);
      // Keys deliberately sort opposite to enqueue order.
      for (final id in ['c', 'b']) {
        await offline.enqueue(
          table: 'disease_screenings',
          action: 'patch_status',
          customId: 'z$id',
          payload: {'id': id, 'progress_state': 'completed'},
        );
      }
      await offline.dispose();

      queue = onlineQueue();
      adapter.hold = true;
      await queue.initialize(customPath: tempDir.path);
      await settle();
      // Sequence numbers continue after a restart.
      await queue.enqueue(
        table: 'disease_screenings',
        action: 'patch_status',
        customId: 'za',
        payload: {'id': 'a', 'progress_state': 'completed'},
      );
      adapter.hold = false;
      await settle();
      await queue.flush();
      await settle();
      expect(adapter.paths, equals([
        '/screenings/c/status',
        '/screenings/b/status',
        '/screenings/a/status',
      ]));
      expect(queue.pendingCount, equals(0));
    });

    test('one session per assessment: opened with its conditions, closed once',
        () async {
      final repo = ScreeningSyncRepository(queue: queue);
      final first = await repo.startAssessmentSession({'rop', 'ancs'});
      await repo.startDiseaseScreening('rop');
      await repo.endAssessmentSession(); // Home / Exit: unfinished
      await repo.endAssessmentSession(); // nothing left to close
      expect(queue.currentSessionId, isNull);
      final second = await repo.startAssessmentSession({'hypoglycemia'});
      expect(second, isNot(first));
      await settle();

      Object? body(String method, String path) => adapter.requests
          .firstWhere((r) => r.$1 == method && r.$2 == path)
          .$3;
      final created = body('POST', '/sessions') as Map;
      expect(created['_id'], first);
      expect(created['selectedConditions'], ['ancs', 'rop']);
      final closes = [
        for (final r in adapter.requests)
          if (r.$1 == 'PATCH' && r.$2 == '/sessions/$first') r.$3 as Map,
      ];
      expect(closes, hasLength(1), reason: 'closed exactly once');
      expect(closes.single.keys, unorderedEquals(['status', 'endedAt']));
      expect(closes.single['status'], 'abandoned');
      expect(
        adapter.requests.where((r) =>
            r.$1 == 'PATCH' && r.$2.endsWith('/status') &&
            (r.$3 as Map)['status'] == 'abandoned'),
        hasLength(1),
        reason: 'the unfinished ROP screening',
      );
    });

    test('completing every screening completes the session', () async {
      final repo = ScreeningSyncRepository(queue: queue);
      final session = await repo.startAssessmentSession({'rop'});
      await repo.startDiseaseScreening('rop');
      await repo.completeScreening('rop');
      await repo.endAssessmentSession(); // must not overwrite the end time
      await settle();

      final closes = [
        for (final r in adapter.requests)
          if (r.$1 == 'PATCH' && r.$2 == '/sessions/$session') r.$3 as Map,
      ];
      expect(closes, hasLength(1));
      expect(closes.single['status'], 'completed');
      expect(queue.pendingCount, 0);
      // Successfully sent API writes are removed, but timing history remains.
      expect(queue.getScreeningTimings().single['completedAt'], isNotNull);
      expect(queue.getScreeningTimings().single['durationMs'], isNonNegative);
    });

    test('items queued before an app restart sync with their nested data',
        () async {
      // Offline (unconfigured client): everything stays in Hive.
      await queue.dispose();
      final offline = OfflineQueue(
        sessionBoxName: sessionBox,
        queueBoxName: queueBox,
        apiClient: ApiClient(baseUrl: '', apiKey: ''),
      );
      await offline.initialize(customPath: tempDir.path);
      final repo = ScreeningSyncRepository(queue: offline);
      await repo.startAssessmentSession({'triage'});
      final screeningId = await repo.startDiseaseScreening('triage');
      await repo.recordResponse(
        diseaseCode: 'triage',
        questionId: 'triage_emergency_signs',
        value: {'apnea', 'shock'},
      );
      await repo.recordFindings(diseaseCode: 'triage', findings: const [
        ClinicalFinding(
          id: 'triage.shock',
          topic: NeonatalCondition.triage,
          content: FindingContent(
            category: FindingCategory.treatment,
            level: FindingLevel.urgent,
            title: 'Shock',
            actions: ['Consider inotropes early.'],
            why: ['Shock selected'],
          ),
          source: SourceReference.triage('SPECIFIC MANAGEMENT WORKFLOWS'),
        ),
      ]);
      await ChatLogRepository(queue: offline).logChatQuery(
        query: 'shock fluid bolus',
        answer: 'IV NS 10 mL/kg.',
        matchedChunkIds: ['triage_shock'],
        sourceMetadata: {
          'document': 'Triage',
          'page': 1,
          'section': 'SHOCK',
          'bounding_boxes': [
            {'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.1},
          ],
        },
        found: true,
      );
      repo.dispose();
      await offline.dispose();

      // App restart: Hive now reads every entry back from disk.
      queue = onlineQueue();
      await queue.initialize(customPath: tempDir.path);
      await settle();
      await queue.flush();
      await settle();

      expect(queue.pendingCount, 0, reason: 'nothing dropped or stuck');
      Object? body(String method, String path) => adapter.requests
          .firstWhere((r) => r.$1 == method && r.$2 == path,
              orElse: () => fail('$method $path was never sent'))
          .$3;

      final findings =
          (body('PUT', '/screenings/$screeningId/findings') as Map)['findings']
              as List;
      expect(findings, hasLength(1));
      final finding = findings.single as Map;
      expect(finding['title'], 'Shock');
      expect(finding['severity'], 'urgent');
      expect(finding['recommendations'], {
        'actions': ['Consider inotropes early.'],
        'why': ['Shock selected'],
      });

      final response = body(
          'PUT', '/screenings/$screeningId/responses/triage_emergency_signs');
      expect((response as Map)['value'], unorderedEquals(['apnea', 'shock']));

      final chat = body('POST', '/chat-logs') as Map;
      expect(chat['source'], {'document': 'Triage', 'page': 1, 'section': 'SHOCK'});
      expect(chat['chunkIds'], ['triage_shock']);
    });

    test('a rejected item is kept aside and later items still sync',
        () async {
      adapter.statusFor = (path) => path.contains('/bad/') ? 400 : 200;
      await enqueueStatus('bad');
      await enqueueStatus('good');
      await settle();
      expect(adapter.paths, contains('/screenings/good/status'));
      expect(queue.pendingCount, equals(0));

      expect(queue.deadLetterCount, 1, reason: 'not deleted without a trace');
      final kept = queue.deadLetters.single;
      expect(kept['reason'], 'HTTP 400');
      expect(kept['app_version'], isNotEmpty);
      expect((kept['entry'] as Map)['payload'], {
        'id': 'bad',
        'progress_state': 'completed',
      });
    });

    test('a rejected screening keeps its answers; replay restores the order',
        () async {
      final repo = ScreeningSyncRepository(queue: queue);
      await repo.startAssessmentSession({'triage'});
      // The server rejects the screening, so its answer then gets 404.
      var serverFixed = false;
      adapter.statusFor = (path) {
        if (serverFixed) return 200;
        if (RegExp(r'^/screenings/[^/]+$').hasMatch(path)) return 400;
        if (path.contains('/responses/')) return 404;
        return 200;
      };
      final screeningId = await repo.startDiseaseScreening('triage');
      await repo.recordResponse(
        diseaseCode: 'triage',
        questionId: 'triage_spo2',
        value: 88,
      );
      await settle();
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 2);
      expect(queue.deadLetters.map((d) => d['reason']),
          unorderedEquals(['HTTP 400', 'HTTP 404']));

      serverFixed = true;
      adapter.paths.clear();
      expect(await queue.requeueDeadLetters(), 2);
      await settle();
      expect(queue.deadLetterCount, 0);
      expect(adapter.paths, [
        '/screenings/$screeningId',
        '/screenings/$screeningId/responses/triage_spo2',
      ]);
      repo.dispose();
    });

    test('a device-side failure is kept too (not only server rejections)',
        () async {
      // No screening id: building the request fails on the device.
      await queue.enqueue(
        table: 'screening_findings',
        action: 'replace',
        payload: {'findings': <Object>[]},
      );
      await settle();
      expect(queue.pendingCount, 0);
      expect(queue.deadLetters.single['reason'], contains('TypeError'));
    });

    test('kept writes are retried once after an app update', () async {
      await queue.dispose();
      queue = onlineQueue(version: '1.0.0');
      await queue.initialize(customPath: tempDir.path);
      adapter.statusFor = (_) => 400;
      await enqueueStatus('x');
      await settle();
      expect(queue.deadLetterCount, 1);
      await queue.dispose();

      // Same version: not retried.
      adapter.statusFor = (_) => 200;
      adapter.paths.clear();
      queue = onlineQueue(version: '1.0.0');
      await queue.initialize(customPath: tempDir.path);
      await settle();
      expect(adapter.paths, isEmpty);
      expect(queue.deadLetterCount, 1);
      await queue.dispose();

      // Updated app: retried and, now accepted, gone.
      queue = onlineQueue(version: '1.0.1');
      await queue.initialize(customPath: tempDir.path);
      await settle();
      expect(adapter.paths, ['/screenings/x/status']);
      expect(queue.deadLetterCount, 0);
    });

    test('a newer write of the same record replaces a kept failed one',
        () async {
      adapter.statusFor = (_) => 400;
      await queue.enqueue(
        table: 'screening_findings',
        action: 'replace',
        customId: 's1_findings',
        payload: {'screening_id': 's1', 'findings': <Object>[]},
      );
      await settle();
      expect(queue.deadLetterCount, 1);

      adapter.statusFor = (_) => 200;
      await queue.enqueue(
        table: 'screening_findings',
        action: 'replace',
        customId: 's1_findings',
        payload: {'screening_id': 's1', 'findings': <Object>[]},
      );
      await settle();
      expect(queue.deadLetterCount, 0,
          reason: 'replaying the old snapshot would overwrite the new one');
      expect(await queue.requeueDeadLetters(), 0);
    });

    test('kept writes are capped; the oldest are discarded', () async {
      await queue.dispose();
      queue = onlineQueue(maxDeadLetters: 2);
      await queue.initialize(customPath: tempDir.path);
      adapter.statusFor = (_) => 400;
      for (final id in ['old', 'mid', 'new']) {
        await enqueueStatus(id);
        await settle();
      }
      expect(queue.deadLetterCount, 2);
      expect(
        queue.deadLetters.map((d) => ((d['entry'] as Map)['payload'] as Map)['id']),
        ['mid', 'new'],
      );
    });

    test('retry backoff doubles after each failure, up to the maximum', () {
      final q = OfflineQueue(
        retryDelay: const Duration(seconds: 30),
        maxRetryDelay: const Duration(minutes: 15),
        apiClient: ApiClient(baseUrl: '', apiKey: ''),
      );
      expect(q.retryDelayFor(1), const Duration(seconds: 30));
      expect(q.retryDelayFor(2), const Duration(minutes: 1));
      expect(q.retryDelayFor(3), const Duration(minutes: 2));
      expect(q.retryDelayFor(5), const Duration(minutes: 8));
      expect(q.retryDelayFor(6), const Duration(minutes: 15));
      expect(q.retryDelayFor(40), const Duration(minutes: 15));
    });

    test('a transient failure marks the record failed and schedules a retry',
        () async {
      adapter.hold = true;
      await enqueueStatus('offline');
      await settle();
      final entry = queue.pendingEntries.single;
      expect(entry['status'], 'failed');
      expect(entry['retries'], greaterThanOrEqualTo(1));
      expect(entry['last_attempt_at'], isNotNull);
      expect(queue.status.phase, SyncPhase.waitingToRetry);
      expect(queue.status.pending, 1);
      expect(queue.status.nextRetryAt, isNotNull);

      // Back online: the next flush sends it and the queue is clear.
      adapter.hold = false;
      await queue.flush();
      await settle();
      expect(queue.pendingEntries, isEmpty);
      expect(queue.status.allSynced, isTrue);
      expect(queue.status.phase, SyncPhase.idle);
      expect(queue.status.lastSyncedAt, isNotNull);
    });

    test('status stream reports pending records, then all synced', () async {
      adapter.hold = true;
      final seen = <SyncStatus>[];
      final sub = queue.statusStream.listen(seen.add);
      await enqueueStatus('a');
      await settle();
      adapter.hold = false;
      await queue.flush();
      await settle();
      // Stream events are delivered asynchronously.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen.any((s) => s.pending == 1), isTrue);
      expect(seen.any((s) => s.phase == SyncPhase.syncing), isTrue);
      expect(seen.last.pending, 0);
    });

    test('consecutive audit events are sent as one batch, in order', () async {
      adapter.hold = true;
      final audit = AuditLog(queue: queue);
      audit.screenView('/workflow');
      audit.tap('next_step');
      audit.stwPdfOpened(
        asset: 'assets/pdfs/Triage_13-10-26.pdf',
        regionId: 'triage_shock',
        origin: 'triage_card:shock',
      );
      await settle();
      await enqueueStatus('after');
      await settle();
      adapter.hold = false;
      adapter.requests.clear();
      adapter.paths.clear();
      await queue.flush();
      await settle();

      expect(adapter.paths, ['/audit-events', '/screenings/after/status']);
      final events =
          ((adapter.requests.first.$3 as Map)['events'] as List).cast<Map>();
      expect(events.map((e) => e['type']),
          ['screen_view', 'tap', 'stw_pdf_opened']);
      expect(events[1]['screen'], '/workflow');
      expect(events[1]['data'], {'button': 'next_step'});
      expect(events[2]['data'], {
        'asset': 'assets/pdfs/Triage_13-10-26.pdf',
        'regionId': 'triage_shock',
        'origin': 'triage_card:shock',
      });
      for (final e in events) {
        expect(e['_id'], isA<String>());
        expect(e['occurredAt'], isA<String>());
      }
      expect(queue.pendingCount, 0);
    });

    test('a rejected audit batch is retried one by one; others still sync',
        () async {
      adapter.statusFor = (path) => path == '/audit-events' ? 400 : 200;
      final audit = AuditLog(queue: queue);
      audit.tap('a');
      audit.tap('b');
      await enqueueStatus('next');
      await settle();
      expect(adapter.paths.where((p) => p == '/audit-events').length,
          greaterThanOrEqualTo(2));
      expect(adapter.paths, contains('/screenings/next/status'));
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 2);
    });

    test('clinical decisions and chat context reach their endpoints', () async {
      await queue.enqueue(
        table: 'clinical_decisions',
        action: 'replace',
        customId: 's1_decision',
        payload: {
          'screening_id': 's1',
          'decision': {
            'category': 'EMERGENCY',
            'triggers': ['HR 210/min (>200/min)'],
          },
          'recorded_at': '2026-10-17T10:00:00.000Z',
        },
      );
      await ChatLogRepository(queue: queue).logChatQuery(
        query: 'shock bolus',
        answer: 'IV NS 10 mL/kg',
        matchedChunkIds: const ['triage_shock'],
        found: true,
        context: const {
          'selected': ['triage'],
          'triage': {'category': 'EMERGENCY'},
        },
      );
      await settle();

      final decision = adapter.requests
          .singleWhere((r) => r.$2 == '/screenings/s1/decision')
          .$3 as Map;
      expect(decision['decision'],
          {'category': 'EMERGENCY', 'triggers': ['HR 210/min (>200/min)']});
      expect(decision['recordedAt'], '2026-10-17T10:00:00.000Z');
      final chat =
          adapter.requests.singleWhere((r) => r.$2 == '/chat-logs').$3 as Map;
      expect(chat['context'], {
        'selected': ['triage'],
        'triage': {'category': 'EMERGENCY'},
      });
    });

    test('an auth failure keeps the item and stops the pass', () async {
      adapter.statusFor = (_) => 401;
      await enqueueStatus('first');
      await enqueueStatus('second');
      await settle();
      expect(queue.pendingCount, equals(2));
      expect(adapter.paths, isNot(contains('/screenings/second/status')));
    });
  });
}

/// Answers every request with [statusFor]; while [hold] is set, requests
/// fail as a network error so items stay queued.
class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  /// (method, path, body) of every request sent.
  final List<(String, String, Object?)> requests = [];
  int Function(String path) statusFor = (_) => 200;
  bool hold = false;
  bool inFlight = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (hold) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'held',
      );
    }
    inFlight = true;
    try {
      paths.add(options.path);
      requests.add((options.method, options.path, options.data));
      return ResponseBody.fromString(
        '{}',
        statusFor(options.path),
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    } finally {
      inFlight = false;
    }
  }

  @override
  void close({bool force = false}) {}
}
