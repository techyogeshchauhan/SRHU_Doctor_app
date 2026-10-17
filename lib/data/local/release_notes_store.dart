import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Remembers, on this device, the last release whose notes were dismissed
/// (IndexedDB on web, a file on mobile), so "What's New" is shown once per
/// release, not on every visit or reload.
class ReleaseNotesStore {
  ReleaseNotesStore({this.boxName = 'stw_app_prefs_box'});

  static final ReleaseNotesStore instance = ReleaseNotesStore();

  static const _lastSeenKey = 'last_seen_release_notes_version';

  final String boxName;
  Box<dynamic>? _box;

  /// False until [open] succeeds (e.g. in widget tests, or when browser
  /// storage is blocked); the dialog is then not shown at all.
  bool get isAvailable => _box?.isOpen ?? false;

  /// Opens the box. Hive must already be initialised (done by
  /// `OfflineQueue.initialize`). Never throws.
  Future<void> open() async {
    try {
      _box = await Hive.openBox<dynamic>(boxName);
    } catch (e) {
      if (kDebugMode) debugPrint('[ReleaseNotesStore] Storage unavailable: $e');
    }
  }

  String? get lastSeenVersion =>
      isAvailable ? _box!.get(_lastSeenKey) as String? : null;

  Future<void> markSeen(String version) async {
    if (isAvailable) await _box!.put(_lastSeenKey, version);
  }

  Future<void> close() async => _box?.close();
}
