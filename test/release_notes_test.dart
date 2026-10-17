import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neonatal_stw/core/config/release_notes.dart';
import 'package:neonatal_stw/core/widgets/release_notes_dialog.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart' show appVersion;
import 'package:neonatal_stw/data/local/release_notes_store.dart';

/// In-memory store, so widget tests need no file I/O.
class _MemoryStore extends ReleaseNotesStore {
  _MemoryStore({this.available = true, this.seen});

  final bool available;
  String? seen;

  @override
  bool get isAvailable => available;

  @override
  String? get lastSeenVersion => seen;

  @override
  Future<void> markSeen(String version) async => seen = version;
}

const _notes = [
  ReleaseNote(
    version: '1.2.0',
    title: 'Next release',
    date: 'Nov 2026',
    highlights: ['Future highlight'],
  ),
  ReleaseNote(
    version: '1.1.0',
    title: 'Triage release',
    date: 'Oct 2026',
    highlights: ['Triage highlight', 'Sync highlight'],
  ),
  ReleaseNote(
    version: '1.0.0',
    title: 'First release',
    date: 'Sep 2026',
    highlights: ['First highlight'],
  ),
];

void main() {
  group('versions', () {
    test('compare numerically, ignoring build numbers', () {
      expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('1.1.0+57', '1.1.0+3'), 0);
      expect(compareVersions('0.9.9', '1.0.0'), lessThan(0));
    });

    test('unseen notes: everything up to current on first visit', () {
      expect(
          releaseNotesSince(null, current: '1.1.0', notes: _notes)
              .map((n) => n.version),
          ['1.1.0', '1.0.0']);
    });

    test('unseen notes: only newer releases after an update', () {
      expect(
          releaseNotesSince('1.0.0', current: '1.1.0', notes: _notes)
              .map((n) => n.version),
          ['1.1.0']);
      expect(releaseNotesSince('1.1.0', current: '1.1.0', notes: _notes),
          isEmpty);
      // Rolled back to an older build: nothing is shown again.
      expect(releaseNotesSince('1.2.0', current: '1.1.0', notes: _notes),
          isEmpty);
    });

    test('pubspec, APP_VERSION fallback and release notes share a version',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final name = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true)
          .firstMatch(pubspec)!
          .group(1);
      expect(name, kCurrentAppVersion,
          reason: 'pubspec.yaml version must match kCurrentAppVersion');
      // Default used by runs without --dart-define=APP_VERSION.
      expect(appVersion.split('+').first, kCurrentAppVersion);
    });

    test('this build has notes for its release, newest first', () {
      expect(kAppReleaseNotes.first.version, kCurrentAppVersion);
      final versions = kAppReleaseNotes.map((n) => n.version).toList();
      expect(versions.toSet(), hasLength(versions.length));
      for (var i = 1; i < kAppReleaseNotes.length; i++) {
        expect(compareVersions(versions[i - 1], versions[i]), greaterThan(0));
      }
      for (final n in kAppReleaseNotes) {
        expect(n.highlights, isNotEmpty, reason: n.version);
      }
    });
  });

  test('the seen version survives closing and reopening storage', () async {
    final dir = await Directory.systemTemp.createTemp('release_notes_test_');
    addTearDown(() => dir.delete(recursive: true));
    Hive.init(dir.path);
    final box = 'prefs_${DateTime.now().microsecondsSinceEpoch}';

    final first = ReleaseNotesStore(boxName: box);
    await first.open();
    expect(first.isAvailable, isTrue);
    expect(first.lastSeenVersion, isNull);
    await first.markSeen('1.1.0');
    await first.close();

    final reopened = ReleaseNotesStore(boxName: box);
    await reopened.open();
    expect(reopened.lastSeenVersion, '1.1.0');
    await reopened.close();
  });

  group('dialog', () {
    Future<void> openApp(WidgetTester tester, ReleaseNotesStore store,
        {String current = '1.1.0'}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showReleaseNotesIfNew(context,
                    store: store, current: current, notes: _notes),
                child: const Text('open app'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open app'));
      await tester.pumpAndSettle();
    }

    Finder dialog() => find.byKey(const ValueKey('release-notes-dialog'));

    testWidgets('shows once, then not again after it is dismissed',
        (tester) async {
      final store = _MemoryStore(seen: '1.0.0');
      await openApp(tester, store);
      expect(dialog(), findsOneWidget);
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('Triage release'), findsOneWidget);
      expect(find.text('Version 1.1.0 · Oct 2026'), findsOneWidget);
      expect(find.text('Sync highlight'), findsOneWidget);
      expect(find.text('First release'), findsNothing);
      expect(find.text('Next release'), findsNothing);
      expect(store.seen, '1.0.0', reason: 'not seen until dismissed');

      await tester.tap(find.byKey(const ValueKey('release-notes-dismiss')));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(store.seen, '1.1.0');

      // Reload: nothing shown.
      await openApp(tester, store);
      expect(dialog(), findsNothing);

      // Next release deployed: shown again.
      await openApp(tester, store, current: '1.2.0');
      expect(find.text('Next release'), findsOneWidget);
    });

    testWidgets('tapping outside also counts as seen', (tester) async {
      final store = _MemoryStore();
      await openApp(tester, store);
      expect(dialog(), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(dialog(), findsNothing);
      expect(store.seen, '1.1.0');
    });

    testWidgets('never shows when storage is unavailable', (tester) async {
      await openApp(tester, _MemoryStore(available: false));
      expect(dialog(), findsNothing);
    });

    testWidgets('fits a phone and a desktop window', (tester) async {
      for (final size in const [Size(320, 568), Size(1280, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ReleaseNotesDialog(notes: kAppReleaseNotes)),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        // The visible card, not the full-screen Dialog wrapper.
        final card = find
            .descendant(of: dialog(), matching: find.byType(Material))
            .first;
        expect(tester.getSize(card).width,
            lessThanOrEqualTo(size.width < 480 ? size.width : 480));
      }
    });
  });
}
