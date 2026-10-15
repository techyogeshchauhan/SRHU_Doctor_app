import 'package:flutter/material.dart';
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
    show rdInitialPlanId, rdPresentId, rdRrKey;
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
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
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
    expect(find.textContaining('40 mg/dL'), findsOneWidget);
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
