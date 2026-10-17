import 'package:flutter/material.dart';

import '../../data/local/release_notes_store.dart';
import '../config/release_notes.dart';
import '../theme.dart';

/// Shows "What's New" when this build's release has not been seen on this
/// device, then remembers it once dismissed (button, tap outside or Back).
/// Does nothing when local storage is unavailable, so it can never show on
/// every visit.
Future<void> showReleaseNotesIfNew(
  BuildContext context, {
  ReleaseNotesStore? store,
  String current = kCurrentAppVersion,
  List<ReleaseNote> notes = kAppReleaseNotes,
}) async {
  final s = store ?? ReleaseNotesStore.instance;
  if (!s.isAvailable) return;
  final unseen = releaseNotesSince(s.lastSeenVersion,
      current: current, notes: notes);
  if (unseen.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => ReleaseNotesDialog(notes: unseen),
  );
  await s.markSeen(current);
}

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({super.key, required this.notes});

  /// Newest first.
  final List<ReleaseNote> notes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dialog(
      key: const ValueKey('release-notes-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.new_releases_outlined,
                        color: AppTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "What's New",
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, n) in notes.indexed) ...[
                        if (i > 0) const Divider(height: 24),
                        _NoteSection(note: n),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('release-notes-dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Version ${note.version} · ${note.date}',
          style: text.bodySmall?.copyWith(color: AppTheme.mutedText),
        ),
        const SizedBox(height: 10),
        for (final h in note.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h,
                    style: text.bodyMedium?.copyWith(
                      color: AppTheme.bodyText,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
