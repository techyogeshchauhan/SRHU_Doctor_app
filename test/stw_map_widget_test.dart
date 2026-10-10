import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/knowledge_graph/state/stw_map_provider.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/stw_map_details_screen.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/stw_map_link.dart';
import 'package:neonatal_stw/features/knowledge_graph/ui/stw_map_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart'
    show HighlightTarget;
import 'package:neonatal_stw/shared/pdf_navigation.dart';

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

Future<void> _pump(
  WidgetTester tester,
  String location, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The assets are decoded off the main isolate; load them with real async
  // first so the fake-async test zone finds them cached.
  await tester.runAsync(() async {
    await loadStwMap();
    await stwRegionTarget('rd_diagnostic_criteria');
  });
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(
      path: '/stw-map',
      builder: (_, s) => StwMapScreen(
        focus: s.uri.queryParameters['focus'],
        reference: s.uri.queryParameters['ref'],
        file: s.uri.queryParameters['file'],
      ),
    ),
    GoRoute(
      path: '/pdf-viewer',
      builder: (_, s) => _PdfProbe(s.extra as Map<String, dynamic>?),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Finder _bubble(String id) => find.byKey(ValueKey('bubble:$id'));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(320, 568), Size(412, 915), Size(1280, 800)]) {
    testWidgets(
        'overview: every STW as a bubble at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _pump(tester, '/stw-map', size: size);
      for (final t in [
        'respiratoryDistress',
        'ancs',
        'hypoglycemia',
        'rop',
        'sepsis',
      ]) {
        expect(_bubble('hub:$t'), findsOneWidget, reason: t);
      }
      expect(find.text('Tap a circle to open it'), findsOneWidget);
      expect(_bubble('box:hypo_whom_to_screen'), findsNothing);
    });
  }

  testWidgets('tapping an STW expands its boxes; tapping again collapses',
      (tester) async {
    await _pump(tester, '/stw-map');
    await _tap(tester, _bubble('hub:hypoglycemia'));
    expect(_bubble('box:hypo_whom_to_screen'), findsOneWidget);
    expect(find.text('All STWs'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);

    await _tap(tester, _bubble('hub:hypoglycemia'));
    expect(_bubble('box:hypo_whom_to_screen'), findsNothing);
  });

  testWidgets('tapping a box fans out what it drives; again collapses',
      (tester) async {
    await _pump(tester, '/stw-map?focus=hypoglycemia');
    await _tap(tester, _bubble('box:hypo_whom_to_screen'));
    expect(find.text('Risk factors present'), findsOneWidget);
    expect(find.text('Mentions: STW Sepsis'), findsOneWidget);

    await _tap(tester, _bubble('box:hypo_whom_to_screen'));
    expect(find.text('Risk factors present'), findsNothing);
  });

  testWidgets('"All STWs" returns to the overview', (tester) async {
    await _pump(tester, '/stw-map?focus=hypo_whom_to_screen');
    await _tap(tester, find.text('All STWs'));
    expect(_bubble('box:hypo_whom_to_screen'), findsNothing);
    expect(_bubble('hub:rop'), findsOneWidget);
  });

  testWidgets('the card opens details and the PDF, highlighted',
      (tester) async {
    await _pump(tester, '/stw-map?focus=hypo_whom_to_screen');
    expect(find.text('WHOM TO SCREEN FOR HYPOGLYCEMIA'), findsWidgets);

    await _tap(tester, find.text('Details'));
    expect(find.byType(StwMapDetailsScreen), findsOneWidget);
    expect(find.textContaining('Infants of diabetic mothers (IDM)'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('PDF'));
    expect(
      find.text('PDF assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf '
          'region=hypo_whom_to_screen'),
      findsOneWidget,
    );
  });

  testWidgets('a topic without an approved STW lists where it is mentioned',
      (tester) async {
    await _pump(tester, '/stw-map?focus=sepsis');
    final link = find.text('STW Respiratory Distress: REASSESS FREQUENTLY');
    expect(link, findsOneWidget);
    expect(find.textContaining('Awaiting STW'), findsWidgets);

    await _tap(tester, _bubble('hub:sepsis>linkin:rd-sepsis'));
    expect(
        find.textContaining('draft, awaiting clinical review'), findsOneWidget);
    await _tap(tester, find.text('Details'));
    expect(
        find.text('Draft: this link between STWs is awaiting clinical review.'),
        findsOneWidget);

    // From the link back to its box in the map.
    final fromTile = find.text('REASSESS FREQUENTLY');
    await tester.scrollUntilVisible(fromTile, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(fromTile.last);
    await tester.pumpAndSettle();
    final show = find.text('Show in the map');
    await tester.scrollUntilVisible(show, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(find.byType(StwMapDetailsScreen), findsNothing);
    expect(_bubble('box:rd_reassessment_sepsis'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);
  });

  testWidgets('an MCQ citation opens its box', (tester) async {
    await _pump(
      tester,
      StwMapLinkButton.location(
        reference: 'ICMR/DHR STW "Antenatal Corticosteroids for Preterm '
            'Birth" (August 2026), WHEN TO GIVE REPEAT COURSE',
      ),
    );
    expect(_bubble('box:ancs_repeat_course'), findsOneWidget);
    expect(find.text('WHEN TO GIVE REPEAT COURSE'), findsWidgets);
  });

  testWidgets('an unknown box with a PDF file opens that STW', (tester) async {
    await _pump(
      tester,
      StwMapLinkButton.location(
        focus: 'not_a_box',
        file: 'retinopathy_of_prematurity_stw.pdf',
      ),
    );
    expect(_bubble('box:rop_whom_to_screen'), findsOneWidget);
    expect(find.text('STW ROP'), findsOneWidget);
  });

  testWidgets('search finds boxes and questions', (tester) async {
    await _pump(tester, '/stw-map', size: const Size(360, 740));
    await _tap(tester, find.text('Search & list'));
    await tester.enterText(find.byType(TextField), 'surfactant');
    await tester.pumpAndSettle();
    expect(find.text('SURFACTANT'), findsOneWidget);
    await _tap(tester, find.text('SURFACTANT'));
    expect(find.byType(StwMapDetailsScreen), findsOneWidget);
  });
}
