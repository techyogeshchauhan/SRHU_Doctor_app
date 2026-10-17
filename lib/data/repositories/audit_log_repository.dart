import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/offline_queue.dart';

/// Clickstream / navigation audit trail: screen views, button taps, STW PDF
/// boxes opened and assessment page changes, each tied to the current
/// session. Events are saved to the offline queue and synced in batches.
///
/// Logging never blocks or fails the UI: [log] returns at once and errors
/// are dropped. Event data must be structured values (ids, codes, counts),
/// never free text typed by the clinician.
class AuditLog {
  AuditLog({OfflineQueue? queue, DateTime Function()? now})
      : _queue = queue ?? OfflineQueue.instance,
        _now = now ?? DateTime.now;

  /// Shared instance for code without a Riverpod ref (router, PDF links).
  static final AuditLog instance = AuditLog();

  final OfflineQueue _queue;
  final DateTime Function() _now;
  String? _screen;

  /// Location of the last screen view, sent with every event.
  String? get currentScreen => _screen;

  /// Records [type] with [data] on the current screen.
  void log(String type, [Map<String, Object?> data = const {}]) {
    final payload = <String, dynamic>{
      'id': _queue.generateUuid(),
      'session_id': _queue.currentSessionId,
      'type': type,
      'screen': _screen,
      'data': storable(data),
      'occurred_at': _now().toUtc().toIso8601String(),
    };
    unawaited(
      _queue
          .enqueue(table: 'audit_events', action: 'insert', payload: payload)
          .catchError((Object _) {}),
    );
  }

  /// A screen was shown; repeated views of the same location are ignored.
  void screenView(String location) {
    if (location == _screen) return;
    final from = _screen;
    _screen = location;
    log('screen_view', {if (from != null) 'from': from});
  }

  /// A button was tapped.
  void tap(String button, [Map<String, Object?> data = const {}]) =>
      log('tap', {'button': button, ...data});

  /// An STW PDF was opened, highlighting [regionId] when given; [origin]
  /// says which card, finding or page the link was on.
  void stwPdfOpened({
    required String asset,
    String? regionId,
    String? origin,
  }) =>
      log('stw_pdf_opened', {
        'asset': asset,
        if (regionId != null) 'regionId': regionId,
        if (origin != null) 'origin': origin,
      });
}

final auditLogProvider = Provider<AuditLog>((_) => AuditLog.instance);
