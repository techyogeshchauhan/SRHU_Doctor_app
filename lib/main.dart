import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/offline_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline-first local queue
  await OfflineQueue.instance.initialize();

  runApp(const ProviderScope(child: NeonatalStwApp()));
}
