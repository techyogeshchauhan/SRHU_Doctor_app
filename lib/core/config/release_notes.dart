/// "What's New" release notes shown once per release. Pure Dart.
///
/// To publish a release: add a [ReleaseNote] at the top of
/// [kAppReleaseNotes] and set [kCurrentAppVersion] to its version. Users see
/// the dialog once after opening or reloading the new build; redeploying the
/// same release does not show it again.
library;

class ReleaseNote {
  final String version; // e.g., "1.1.0"
  final String title; // e.g., "What's New in This Update"
  final String date; // e.g., "October 2026"
  final List<String> highlights;

  const ReleaseNote({
    required this.version,
    required this.title,
    required this.date,
    required this.highlights,
  });
}

/// Release whose notes this build shows. Independent of the build number,
/// which changes with every deploy.
const kCurrentAppVersion = '1.1.0';

/// Newest first.
const List<ReleaseNote> kAppReleaseNotes = [
  ReleaseNote(
    version: '1.1.0',
    title: 'Neonatal Triage & Sync Improvements',
    date: 'Oct 2026',
    highlights: [
      'Automated Triage workflow: Emergency classification is now computed live without manual category selection.',
      'Emergency Treatment Dashboard: Added direct TABC cards with automated fluid bolus calculation and highlighted STW PDF links.',
      'Fast-track sick baby mode: Instantly jump to examination, bypassing unnecessary history entry.',
      'Offline-first data sync: Background sync engine with exponential retry for clinical audit tracking.',
    ],
  ),
];

/// Compares dotted numeric versions ("1.10.0" > "1.9.2"); a missing part
/// counts as 0 and any build suffix ("+57") is ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
        for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0,
      ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}

/// Notes the user has not seen yet: releases after [lastSeen] up to
/// [current], newest first. All of them up to [current] when nothing was
/// seen before; none when [lastSeen] is [current] or newer.
List<ReleaseNote> releaseNotesSince(
  String? lastSeen, {
  String current = kCurrentAppVersion,
  List<ReleaseNote> notes = kAppReleaseNotes,
}) =>
    [
      for (final n in notes)
        if (compareVersions(n.version, current) <= 0 &&
            (lastSeen == null || compareVersions(n.version, lastSeen) > 0))
          n,
    ]..sort((a, b) => compareVersions(b.version, a.version));
