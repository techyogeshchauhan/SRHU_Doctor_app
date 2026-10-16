import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';
import 'package:neonatal_stw/features/chatbot/domain/models/stw_chunk.dart';
import 'package:neonatal_stw/features/chatbot/state/chatbot_provider.dart';
import 'package:neonatal_stw/features/chatbot/ui/chat_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'chatbot_eval/eval_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> catalog(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  test('every curated region, sentence, and fallback chunk stays synchronized',
      () {
    final regions = catalog('assets/regions/regions.json');
    final index = catalog('assets/stw_index/stw_index.json');
    expect(index.length, regions.length);
    final byId = {for (final i in index) i['chunk_id']: i};
    expect(byId.length, index.length);
    for (final r in regions) {
      final fallback = byId[r['id']]!;
      for (final field in r.keys) {
        expect(fallback[field], r[field], reason: '${r['id']}: $field');
      }
      final region = StwChunk.fromJson(r);
      final other = StwChunk.fromJson(fallback);
      expect(other.toJson(), region.toJson());
      expect(File(region.cropImage!).existsSync(), isTrue);
      expect(r['pw'], greaterThan(0));
      expect(r['ph'], greaterThan(0));
      for (final segment in region.segments) {
        expect(segment.boundingBoxes, isNotEmpty,
            reason: '${region.chunkId}: ${segment.text}');
        if (segment.label != null) {
          expect(segment.labelBoundingBoxes, isNotEmpty,
              reason: '${region.chunkId}: ${segment.label}');
        }
        for (final b in [
          ...segment.boundingBoxes,
          ...segment.labelBoundingBoxes
        ]) {
          expect(b.x, greaterThanOrEqualTo(0));
          expect(b.y, greaterThanOrEqualTo(0));
          expect(b.width, inExclusiveRange(0, 0.98));
          expect(b.height, inExclusiveRange(0, 0.98));
          expect(b.x + b.width, lessThanOrEqualTo(1));
          expect(b.y + b.height, lessThanOrEqualTo(1));
        }
      }
    }
  });

  test('KMC rows and hypoglycemia table exclude neighboring sections', () {
    final regions = {for (final c in loadRegions()) c.chunkId: c};
    final followup = regions['kmc_followup']!.boundingBoxes.single;
    final donts = regions['kmc_donts']!.boundingBoxes.single;
    expect(followup.y + followup.height, lessThan(donts.y));
    final schedule = regions['hypo_monitoring_schedule']!.boundingBoxes.single;
    final screening = regions['hypo_whom_to_screen']!.boundingBoxes.single;
    expect(schedule.y, greaterThan(screening.y + screening.height));
    // The KPI box must end above the next, unrelated green triage banner.
    final kpi = regions['triage_kpis']!.boundingBoxes.single;
    expect(kpi.y + kpi.height, lessThan(1400 / 1633.68));
  });

  for (final (query, id, text) in [
    (
      'What is weaned first, FiO2 or CPAP pressure?',
      'rd_outcome_improving_weaning',
      'Reduce FiO'
    ),
    (
      'Should antibiotics be started for low sugar?',
      'hypo_donts',
      'antibiotics'
    ),
    (
      'Initial CPAP pressure in preterm ≤34 weeks',
      'rd_initial_preterm_cpap_caffeine',
      'CPAP 5'
    ),
    (
      'Which screenings are included in KMC follow-up?',
      'kmc_followup',
      'ROP screening'
    ),
    (
      'Baby 26 weeks, when is the first ROP screen?',
      'rop_when_to_screen',
      '2-3 weeks'
    ),
    ('What is the full form of PPROM?', 'ancs_abbreviations', 'PPROM:'),
  ]) {
    test('PDF indication frames the cited section: $query', () async {
      final retriever = Bm25Retriever(
          initialChunks: loadRegions(), initialSynonyms: loadSynonyms());
      final answer = await StwAnswerer(retriever).answer(query);
      expect(answer.kind, AnswerKind.answer);
      expect(answer.region!.chunkId, id);
      expect(answer.lines.any((s) => s.text.contains(text)), isTrue);
      final target = stwChunkTarget(answer.region!);
      final parent = (await stwRegionTarget(id))!;
      expect(target.document, parent.document);
      expect(target.page, parent.page);
      expect(target.normalizedBboxes, parent.normalizedBboxes);
      expect(target.normalizedBboxes, hasLength(1));
      for (final b in target.normalizedBboxes) {
        expect(
            parent.normalizedBboxes.single.inflate(0.00001).contains(b.topLeft),
            isTrue);
        expect(
            parent.normalizedBboxes.single
                .inflate(0.00001)
                .contains(b.bottomRight),
            isTrue);
      }
      if (id == 'rd_initial_preterm_cpap_caffeine') {
        // Match the complete green START CPAP card in the reference PDF,
        // rather than framing just its CPAP sentence or caffeine line.
        expect(
            target.normalizedBboxes.single.left, closeTo(22 / 841.89, 0.000001));
        expect(target.normalizedBboxes.single.right,
            closeTo(532 / 841.89, 0.000001));
        expect(answer.lines.any((s) => s.text.contains('caffeine')), isFalse);
      }
    });
  }

  testWidgets(
      '360px chat PDF button opens one section frame without a notification',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final retriever = Bm25Retriever(
        initialChunks: loadRegions(), initialSynonyms: loadSynonyms());
    final notifier = ChatbotNotifier(StwAnswerer(retriever));
    HighlightTarget? opened;
    final router = GoRouter(initialLocation: '/chat', routes: [
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(
          path: '/pdf-viewer',
          builder: (_, state) {
            opened = (state.extra as Map)['highlightTarget'] as HighlightTarget;
            return PdfViewerScreen(
              assetPath: state.uri.queryParameters['path']!,
              title: opened!.sectionTitle!,
              highlightTarget: opened,
            );
          }),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      chatbotNotifierProvider.overrideWith((ref) => notifier),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.enterText(find.byType(TextField),
        'Which screenings are included in KMC follow-up?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final answer = notifier.state.messages.last.answer!;
    await tester.ensureVisible(find.text('View in PDF'));
    await tester.tap(find.text('View in PDF'));
    await tester.pumpAndSettle();
    expect(opened!.regionId, 'kmc_followup');
    expect(opened!.normalizedBboxes,
        stwChunkTarget(answer.region!).normalizedBboxes);
    expect(opened!.normalizedBboxes, hasLength(1));
    expect(opened!.normalizedBboxes.every((b) => b.bottom < 0.478), isTrue);
    await tester.runAsync(() => precacheImage(
          const AssetImage('assets/pages/KMC-13-10-2026.pdf/1.webp'),
          tester.element(find.byType(PdfViewerScreen)),
        ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss Banner (keeps highlight visible)'),
        findsNothing);
    expect(find.byIcon(Icons.highlight_alt_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'viewer centers all evidence and stays aligned after rotation and zoom',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const target = HighlightTarget(
        document: 'KMC-13-10-2026.pdf',
        page: 1,
        normalizedBboxes: [
          Rect.fromLTWH(0.2, 0.48, 0.3, 0.03),
          Rect.fromLTWH(0.2, 0.64, 0.3, 0.03)
        ],
        sectionTitle: 'Selected source evidence');
    const captureKey = ValueKey('capture');
    await tester.pumpWidget(const MaterialApp(
        home: RepaintBoundary(
      key: captureKey,
      child: PdfViewerScreen(
          assetPath: kmcPdfAsset, title: kmcPdfTitle, highlightTarget: target),
    )));
    await tester.runAsync(() => precacheImage(
          const AssetImage('assets/pages/KMC-13-10-2026.pdf/1.webp'),
          tester.element(find.byType(PdfViewerScreen)),
        ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    Finder overlay() => find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_CuratedHighlightPainter');

    void expectCentered() {
      final page = tester.getRect(overlay());
      final viewport = tester.getRect(find.byType(InteractiveViewer));
      final center = page.top + page.height * 0.575;
      final visibleCenter = viewport.center.dy;
      expect(center, closeTo(visibleCenter, 2));
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_PDF_EVIDENCE')) return;
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('tmp/pdfs/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    expectCentered();
    await capture('viewer_360');
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expectCentered();
    await capture('viewer_landscape');
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    for (final zoom in [1.0, 2.0, 3.5]) {
      viewer.transformationController!.value =
          Matrix4.diagonal3Values(zoom, zoom, 1);
      await tester.pump();
      final paint = tester.widget<CustomPaint>(overlay()).painter!;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(zoom);
      const size = Size(320, 640);
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
      paint.paint(canvas, size);
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(
          () => picture.toImage((320 * zoom).ceil(), (640 * zoom).ceil())))!;
      final data = (await tester.runAsync(() => image.toByteData()))!;
      // The original frame sits just outside the source section, with the
      // same red stroke / white halo at every zoom (both scale with the PDF).
      final x = (0.35 * 320 * zoom).round();
      final y = ((0.48 * 640 - 6) * zoom).round();
      final width = image.width;
      final offset = (y * width + x) * 4;
      expect(data.getUint8(offset), greaterThan(150));
      expect(data.getUint8(offset + 1), lessThan(150));
      // Beyond the small white halo, the unselected page stays dimmed.
      final outside = ((y - (6 * zoom).ceil()) * width + x) * 4;
      expect(data.getUint8(outside), inInclusiveRange(180, 190));
      image.dispose();
      picture.dispose();
    }
    expect(tester.takeException(), isNull);
  });
}
