import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
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

    OfflineQueue onlineQueue() => OfflineQueue(
          sessionBoxName: sessionBox,
          queueBoxName: queueBox,
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
    });

    test('a rejected item is dropped and later items still sync', () async {
      adapter.statusFor = (path) => path.contains('/bad/') ? 400 : 200;
      await enqueueStatus('bad');
      await enqueueStatus('good');
      await settle();
      expect(adapter.paths, contains('/screenings/good/status'));
      expect(queue.pendingCount, equals(0));
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
