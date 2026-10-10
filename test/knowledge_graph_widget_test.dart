import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/assessment_summary.dart';
import 'package:neonatal_stw/features/knowledge_graph/state/stw_regions.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/assessment_map_screen.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/node_details_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart'
    show HighlightTarget;
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'knowledge_graph_test.dart' show babyCtx;

class _Fixed extends AssessmentController {
  _Fixed(this.ctx);
  final ClinicalAssessmentContext ctx;

  @override
  AssessmentState build() => AssessmentState(context: ctx);
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

Future<void> _pump(WidgetTester tester, Size size, {String home = '/'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // regions.json is decoded off the main isolate; load it with real async
  // first so the fake-async test zone finds it cached.
  await tester.runAsync(() async {
    await loadStwRegions();
    await stwRegionTarget('rd_diagnostic_criteria');
  });
  final ctx = babyCtx();
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
    overrides: [assessmentProvider.overrideWith(() => _Fixed(ctx))],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

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
        'Why? opens the node graph of that finding at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _pump(tester, size);
      await _openWhy(tester, 'START CPAP');

      expect(find.byType(AssessmentMapScreen), findsOneWidget);
      expect(find.text('Graph view'), findsOneWidget);
      // Based on → STW rule → finding.
      expect(find.text('Gestation group'), findsOneWidget);
      expect(find.text('SAS total'), findsOneWidget);
      expect(
          find.text('§1.5 Algorithm: choosing initial support'), findsWidgets);
      expect(find.text('START CPAP'), findsWidgets);
      // Inputs behind a computed value stay closed until opened.
      expect(find.text('Gestational age (completed weeks)'), findsNothing);
    });
  }

  testWidgets('+N opens what a node is based on; − closes it', (tester) async {
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=rd.initialPlan');
    await _tap(tester, find.text('+2'));
    expect(find.text('Gestation group: based on'), findsOneWidget);
    expect(find.text('Gestational age (completed weeks)'), findsOneWidget);
    expect(find.text('32 weeks'), findsOneWidget);

    await _tap(tester, find.text('−'));
    expect(find.text('Gestational age (completed weeks)'), findsNothing);
  });

  testWidgets('node details: value, source, PDF highlight, related nodes',
      (tester) async {
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=rd.initialPlan');
    await _tap(tester, find.text('Gestation group'));

    expect(find.byType(NodeDetailsScreen), findsOneWidget);
    expect(find.text('Computed value'), findsOneWidget);
    expect(find.text('GA ≤34 weeks'), findsOneWidget);
    expect(find.text('ICMR/DHR STW: Respiratory Distress in Neonates'),
        findsOneWidget);
    // Verbatim box text from the PDF.
    await tester.scrollUntilVisible(find.text('Text in the STW PDF'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('If GA is uncertain'), findsOneWidget);
    // Related: the answers it is based on, and what it is used for.
    await tester.scrollUntilVisible(
        find.text('Gestational age (completed weeks)'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Used for'), findsOneWidget);

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
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=hypo.low');
    await _tap(tester, find.text('HOW TO MONITOR BLOOD GLUCOSE (BG)').first);
    expect(find.text('STW rule'), findsOneWidget);
    expect(find.text('40 mg/dL'), findsOneWidget);
    expect(find.text('< 45 mg/dL'), findsOneWidget);
    expect(find.text('✓ Met'), findsOneWidget);
    expect(find.textContaining('Measure BG using a point-of-care'),
        findsOneWidget);
  });

  testWidgets('a finding in related nodes switches the graph to it',
      (tester) async {
    await _pump(tester, const Size(412, 915),
        home: '/assessment-map?focus=rd.initialPlan');
    await _tap(tester, find.text('+2'));
    await _tap(tester, find.text('Gestational age (completed weeks)'));
    // GA leads to ROP findings too.
    final rop = find.text('Screening eligible — SCREEN FOR ROP');
    await tester.scrollUntilVisible(rop, 200,
        scrollable: find.byType(Scrollable).last);
    await _tap(tester, rop);
    expect(find.byType(NodeDetailsScreen), findsNothing);
    expect(
        find.text('ROP: Screening eligible — SCREEN FOR ROP'), findsOneWidget);
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
