import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/local/offline_queue.dart';
import '../theme.dart';

/// Live state of the offline sync queue.
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => OfflineQueue.instance.statusStream,
);

String _records(int n) => n == 1 ? '1 record' : '$n records';

/// One-line description of [s], used as tooltip and dialog text.
String describeSyncStatus(SyncStatus s) {
  final main = switch (s.phase) {
    SyncPhase.localOnly => s.pending == 0
        ? 'Saved on this device (sync is not configured)'
        : '${_records(s.pending)} saved on this device (sync is not '
            'configured)',
    SyncPhase.syncing => 'Syncing ${_records(s.pending)}…',
    _ when s.pending == 0 => 'All records synced',
    SyncPhase.waitingToRetry =>
      '${_records(s.pending)} waiting to sync (offline; retrying'
          '${s.nextRetryAt == null ? '' : ' at ${DateFormat('HH:mm').format(s.nextRetryAt!)}'})',
    SyncPhase.idle => '${_records(s.pending)} waiting to sync',
  };
  return s.failed == 0
      ? main
      : '$main · ${_records(s.failed)} rejected by the server, kept on this '
          'device';
}

/// AppBar icon: cloud done when everything is synced, cloud queue with the
/// pending count while offline, cloud sync while sending. Tap for details
/// and "Sync now".
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider).valueOrNull ??
        OfflineQueue.instance.status;
    final (icon, color) = switch (s.phase) {
      SyncPhase.syncing => (Icons.cloud_sync_outlined, AppTheme.primaryBlue),
      SyncPhase.localOnly => (Icons.cloud_off_outlined, AppTheme.mutedText),
      _ when s.pending == 0 && s.failed == 0 =>
        (Icons.cloud_done_outlined, const Color(0xFF15803D)),
      _ when s.pending == 0 => (Icons.cloud_done_outlined, const Color(0xFFB45309)),
      _ => (Icons.cloud_queue_rounded, const Color(0xFFB45309)),
    };
    final text = describeSyncStatus(s);

    return Semantics(
      button: true,
      label: 'Sync status: $text',
      excludeSemantics: true,
      child: IconButton(
        key: const ValueKey('sync-status-indicator'),
        tooltip: text,
        onPressed: () => _showDetails(context),
        icon: Badge(
          isLabelVisible: s.pending > 0,
          label: Text(s.pending > 99 ? '99+' : '${s.pending}'),
          backgroundColor: color,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final s = ref.watch(syncStatusProvider).valueOrNull ??
              OfflineQueue.instance.status;
          final last = s.lastSyncedAt;
          return AlertDialog(
            title: const Text('Data sync'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(describeSyncStatus(s), key: const ValueKey('sync-status-text')),
                const SizedBox(height: 8),
                Text(
                  last == null
                      ? 'No record sent yet in this app session.'
                      : 'Last sent: ${DateFormat('dd MMM yyyy · HH:mm:ss').format(last)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every screening is saved on this device first and sent '
                  'automatically when the internet is available.',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              if (s.phase != SyncPhase.localOnly && s.pending > 0)
                FilledButton.icon(
                  key: const ValueKey('sync-now'),
                  onPressed: s.phase == SyncPhase.syncing
                      ? null
                      : OfflineQueue.instance.flush,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Sync now'),
                ),
            ],
          );
        },
      ),
    );
  }
}
