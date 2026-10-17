import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/offline_queue.dart';
import 'data/local/release_notes_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline-first local queue
  await OfflineQueue.instance.initialize();
  // Last release whose "What's New" was dismissed (uses the Hive set up above).
  await ReleaseNotesStore.instance.open();

  runApp(const ProviderScope(child: NeonatalStwApp()));
}
