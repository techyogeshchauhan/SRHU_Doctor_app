import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/assessment_summary.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart'
    show hypoLowId;
import 'package:neonatal_stw/features/knowledge_graph/domain/bubble_graph.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/kg_graph.dart';
import 'package:neonatal_stw/features/knowledge_graph/domain/reasoning.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart'
    show
        rdInitialPlanId,
        rdPresentId,
        rdRrKey,
        rdInitialSpo2Key,
        rdReassessNowKey,
        rdSupportKey,
        rdPeepKey,
        rdFio2Key,
        rdSpo2Key,
        rdWarningsKey,
        rdSasKey,
        rdReSasKey;
import 'package:neonatal_stw/features/rd/domain/sas.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/knowledge_graph/state/stw_regions.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/assessment_map_screen.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/bubble_graph_view.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/node_details_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart'
    show HighlightTarget;
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'assessment_test_utils.dart' show walk;
import 'knowledge_graph_test.dart' show babyCtx;

class _Fixed extends AssessmentController {
  _Fixed(this.ctx);
  final ClinicalAssessmentContext ctx;

  @override
  AssessmentState build() => AssessmentState(context: ctx);

  void setContext(ClinicalAssessmentContext next) {
    state = AssessmentState(context: next);
  }
}

/// Stand-in for the PDF viewer: shows what it was asked to open.
class _PdfProbe extends StatelessWidget {
  const _PdfProbe(this.extra);
  final Map<String, dynamic>? extra;

  @override
  Widget build(BuildContext context) {
    final target = extra?['highlightTarget'] as HighlightTarget?;
    return Scaffold(
      body: Text('PDF ${extra?['path']} region=${target?.regionId}'),
    );
  }
}

Future<_Fixed> _pump(
  WidgetTester tester,
  Size size, {
  String home = '/',
  ClinicalAssessmentContext? context,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // regions.json is decoded off the main isolate; load it with real async
  // first so the fake-async test zone finds it cached.
  await tester.runAsync(() async {
    await loadStwRegions();
    await stwRegionTarget('rd_diagnostic_criteria');
  });
  final ctx = context ?? babyCtx();
  late final _Fixed controller;
  final router = GoRouter(initialLocation: home, routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: ListView(children: const [AssessmentSummaryView()]),
      ),
    ),
    GoRoute(
      path: '/assessment-map',
      builder: (_, s) => AssessmentMapScreen(
        focusFindingId: s.uri.queryParameters['focus'],
      ),
    ),
    GoRoute(
      path: '/pdf-viewer',
      builder: (_, s) => _PdfProbe(s.extra as Map<String, dynamic>?),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      assessmentProvider.overrideWith(() => controller = _Fixed(ctx)),
    ],
    child: RepaintBoundary(
      key: const ValueKey('assessment-map-capture'),
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

Finder _bubble(String id) => find.byKey(ValueKey('bubble:$id'));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openWhy(WidgetTester tester, String findingTitle) async {
  final card = find.ancestor(
    of: find.text(findingTitle),
    matching: find.byType(FindingCard),
  );
  await _tap(
      tester, find.descendant(of: card.first, matching: find.text('Why?')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      ('Inter', 'assets/fonts/Inter-Regular.ttf'),
      ('Poppins', 'assets/fonts/Poppins-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  for (final size in const [Size(1280, 800), Size(320, 568)]) {
    testWidgets(
        'dense CPAP failure evidence stays separate and reachable at $size',
        (tester) async {
      final ctx = walk({
        NeonatalCondition.respiratoryDistress
      }, {
        rdRrKey: 70,
        gaKnownKey: true,
        gaWeeksKey: 30,
        rdInitialSpo2Key: 90,
        for (final item in SasItem.values) rdSasKey(item): 1,
        rdReassessNowKey: true,
        rdSupportKey: 'cpap',
        rdPeepKey: 6,
        rdFio2Key: 40,
        rdSpo2Key: 88,
        rdWarningsKey: <Object>{'hypoxemia'},
        for (final item in SasItem.values) rdReSasKey(item): 2,
      }).ctx;
      final graph = buildAssessmentBubbleGraph(
          context: ctx, trees: ReasoningBuilder(ctx).explainAll());
      final finding = graph.byId('finding:rd.reassess.cpapFailure')!;
      expect(finding.children.length, greaterThan(20));
      await _pump(tester, size,
          context: ctx, home: '/assessment-map?focus=rd.reassess.cpapFailure');
      final seen = <String>{};
      for (var page = 0; page < 30; page++) {
        final visible = finding.children
            .where((b) => _bubble(b.id).evaluate().isNotEmpty)
            .toList();
        expect(visible, isNotEmpty);
        expect(visible.length, lessThanOrEqualTo(size.width >= 1000 ? 8 : 4));
        final bounds = <Rect>[];
        final canvas = tester.getRect(find.byType(InteractiveViewer));
        for (final b in visible) {
          seen.add(b.id);
          final label = find.byKey(ValueKey('bubble-label:${b.id}'));
          expect(label, findsOneWidget);
          final rect = tester
              .getRect(_bubble(b.id))
              .expandToInclude(tester.getRect(label));
          for (final other in bounds) {
            expect(rect.overlaps(other), isFalse,
                reason: 'Evidence labels overlap on page $page');
          }
          bounds.add(rect);
          expect(canvas.inflate(1).contains(rect.topLeft), isTrue,
              reason: '${b.label}: clipped at top/left: $rect canvas $canvas');
          expect(canvas.inflate(1).contains(rect.bottomRight), isTrue,
              reason:
                  '${b.label}: clipped at bottom/right: $rect canvas $canvas');
        }
        if (page == 0) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('assessment-map-capture')));
          await tester.runAsync(() async {
            final snapshot = await boundary.toImage();
            final bytes =
                await snapshot.toByteData(format: ui.ImageByteFormat.png);
            final path =
                '${Directory.systemTemp.path}/stw-graph-fixed-${size.width.toInt()}.png';
            await File(path).writeAsBytes(bytes!.buffer.asUint8List());
            snapshot.dispose();
          });
        }
        final next = tester
            .widget<IconButton>(find.byKey(const ValueKey('evidence-next')));
        if (next.onPressed == null) break;
        await tester.tap(find.byKey(const ValueKey('evidence-next')));
        await tester.pumpAndSettle();
      }
      expect(seen, finding.children.map((b) => b.id).toSet());
      await tester.tap(find.byKey(const ValueKey('evidence-previous')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(320, 568), Size(412, 915), Size(1280, 800)]) {
    testWidgets(
        'Why? opens the Home bubble graph for that finding at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _pump(tester, size);
      await _openWhy(tester, 'START CPAP');

      expect(find.byType(AssessmentMapScreen), findsOneWidget);
      expect(find.byType(BubbleGraphView), findsOneWidget);
      expect(find.text('Graph view'), findsOneWidget);
      expect(_bubble('hub:respiratoryDistress'), findsOneWidget);
      expect(_bubble('finding:rd.initialPlan'), findsOneWidget);
      expect(find.text('START CPAP'), findsWidgets);
    });
  }

  testWidgets('graph includes only selected conditions and current results',
      (tester) async {
    final partial = walk(
      {NeonatalCondition.respiratoryDistress},
      {rdRrKey: 50},
    ).ctx;
    final controller = await _pump(
      tester,
      const Size(412, 915),
      home: '/assessment-map',
      context: partial,
    );

    expect(_bubble('hub:respiratoryDistress'), findsOneWidget);
    expect(_bubble('hub:rop'), findsNothing);
    expect(_bubble('hub:hypoglycemia'), findsNothing);
    expect(_bubble('box:rd_diagnostic_criteria'), findsNothing);

    await _tap(tester, _bubble('hub:respiratoryDistress'));
    expect(find.text('Respiratory distress criteria not met'), findsOneWidget);

    controller.setContext(
      walk(
        {NeonatalCondition.respiratoryDistress},
        {rdRrKey: 70},
      ).ctx,
    );
    await tester.pumpAndSettle();
    expect(_bubble('hub:rop'), findsNothing);
    expect(_bubble('finding:$rdPresentId'), findsOneWidget);

    controller.setContext(babyCtx());
    await tester.pumpAndSettle();
    expect(_bubble('hub:rop'), findsOneWidget);
    expect(_bubble('hub:hypoglycemia'), findsOneWidget);
  });

  testWidgets('assessment list uses the shared STW presentation order',
      (tester) async {
    await _pump(tester, const Size(1280, 900), home: '/assessment-map');
    await _tap(tester, find.text('List view'));
    final scroller = find.byType(Scrollable).first;
    final offsets = <double>[];
    for (final title in [
      'STW Hypoglycemia',
      'STW Respiratory Distress',
      'STW ROP'
    ]) {
      final header = find.text(title);
      await tester.scrollUntilVisible(header, 250, scrollable: scroller);
      await tester.pumpAndSettle();
      expect(header, findsOneWidget);
      final position = tester.state<ScrollableState>(scroller).position;
      offsets.add(tester.getTopLeft(header).dy + position.pixels);
    }
    expect(offsets[0], lessThan(offsets[1]));
    expect(offsets[1], lessThan(offsets[2]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('live finding details retain values, source and PDF highlight',
      (tester) async {
    final ctx = babyCtx();
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=rd.initialPlan');
    final trees = ReasoningBuilder(ctx).explainAll();
    final graph = buildAssessmentBubbleGraph(context: ctx, trees: trees);
    final initialPlan = graph
        .hubOf(NeonatalCondition.respiratoryDistress)!
        .children
        .singleWhere((b) => b.item?.finding?.id == rdInitialPlanId);
    final gestation = initialPlan.children
        .singleWhere((b) => b.item?.label == 'Gestation group');
    await _tap(tester, _bubble(gestation.id));
    await _tap(tester, find.text('Details'));

    expect(find.byType(NodeDetailsScreen), findsOneWidget);
    expect(find.text('Gestation group'), findsWidgets);
    expect(find.textContaining('GA ≤34 weeks'), findsWidgets);
    expect(find.text('ICMR/DHR STW: Respiratory Distress in Neonates'),
        findsOneWidget);
    // Verbatim box text from the PDF.
    await tester.scrollUntilVisible(find.text('Text in the STW PDF'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('If GA is uncertain'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Open in PDF (highlighted)'), -200,
        scrollable: find.byType(Scrollable).last);
    await _tap(tester, find.text('Open in PDF (highlighted)'));
    expect(
      find.text('PDF assets/pdfs/respiratory_distress_neonates_stw.pdf '
          'region=rd_algorithm_overview'),
      findsOneWidget,
    );
  });

  testWidgets('rule details show your value, threshold and result',
      (tester) async {
    final ctx = babyCtx();
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=hypo.low');
    final trees = ReasoningBuilder(ctx).explainAll();
    final graph = buildAssessmentBubbleGraph(context: ctx, trees: trees);
    final lowGlucose = graph
        .hubOf(NeonatalCondition.hypoglycemia)!
        .children
        .singleWhere((b) => b.item?.finding?.id == hypoLowId);
    final rule =
        lowGlucose.children.singleWhere((b) => b.item?.kind == KgKind.rule);
    await _tap(tester, _bubble(rule.id));
    await _tap(tester, find.text('Details'));
    expect(find.byType(NodeDetailsScreen), findsOneWidget);
    expect(find.text('STW rule'), findsOneWidget);
    expect(find.textContaining('40 mg/dL'), findsWidgets);
    expect(find.textContaining('45 mg/dL'), findsWidgets);
    expect(find.text('✓ Met'), findsOneWidget);
    expect(find.textContaining('Measure BG using a point-of-care'),
        findsOneWidget);
  });

  testWidgets('list view: shared answers and topics', (tester) async {
    await _pump(tester, const Size(360, 740), home: '/assessment-map');
    await _tap(tester, find.text('List view'));
    expect(find.text('Answers used by more than one topic'), findsOneWidget);
    expect(
      find.text('Gestational age (completed weeks):  32 weeks',
          findRichText: true),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('STW ROP'), 200,
        scrollable: find.byType(Scrollable).last);
  });
}
