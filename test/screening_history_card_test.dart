import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/screening_session_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf')))
        .load();
  });

  for (final width in [320.0, 360.0, 900.0]) {
    for (final textScale in [1.0, 1.8]) {
      testWidgets('history is padded and responsive at $width / $textScale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var now = DateTime(2026, 10, 15, 14, 9, 56);
        final repo = ScreeningSyncRepository(
            queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')),
            now: () => now);
        addTearDown(repo.dispose);
        for (final code in ['rop', 'respiratory_distress', 'hypoglycemia']) {
          await repo.startAssessmentSession({code});
          await repo.startDiseaseScreening(code);
          now = now.add(const Duration(seconds: 39));
          await repo.completeScreening(code);
        }
        const captureKey = ValueKey('history-preview');
        await tester.pumpWidget(ProviderScope(
          overrides: [screeningSyncRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme:
                AppTheme.light(), // Includes the shared zero ListTile padding.
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: const RepaintBoundary(
              key: captureKey,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AvailableDiseaseCount(showListed: true),
                      ScreeningHistoryCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Time taken: 00:39'), findsNothing);
        await tester.tap(find.text('Previous screenings'));
        await tester.pumpAndSettle();
        expect(find.text('Time taken: 00:39'), findsNWidgets(3));
        expect(find.text('Started:'), findsNWidgets(3));
        expect(find.text('Completed:'), findsNWidgets(3));
        final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
        expect(tile.tilePadding,
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8));
        expect(tile.shape, const Border());
        expect(tile.collapsedShape, const Border());
        final card = tester
            .getRect(find.byKey(const ValueKey('screening-history-card')));
        for (final (index, timing) in repo.timings.indexed) {
          expect(
              tester
                  .widget<Text>(find
                      .byKey(ValueKey('screening-history-index-${timing.id}')))
                  .data,
              '${index + 1}.');
          final entry = tester
              .getRect(find.byKey(ValueKey('screening-history-${timing.id}')));
          expect(entry.left, greaterThanOrEqualTo(card.left + 16));
          expect(entry.right, lessThanOrEqualTo(card.right - 16));
        }
        expect(tester.takeException(), isNull);

        // Optional visual QA artifacts; not checked into source control.
        if (const bool.fromEnvironment('CAPTURE_SCREENING_HISTORY') &&
            textScale == 1) {
          final boundary = tester
              .renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('tmp/ui/screening_history_${width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Previous screenings'));
        await tester.pumpAndSettle();
        expect(find.text('Time taken: 00:39'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
