import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/home/home_screen.dart';
import 'package:neonatal_stw/features/landing/ui/landing_screen.dart';
import 'package:neonatal_stw/features/rd/ui/rd_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';
import 'package:neonatal_stw/features/references/ui/references_screen.dart';
import 'package:neonatal_stw/features/rop/ui/rop_screen.dart';

Widget _buildTestApp({
  String initialLocation = '/references',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/rd',
        builder: (_, __) => const RdScreen(),
      ),
      GoRoute(
        path: '/rop',
        builder: (_, __) => const RopScreen(),
      ),
      GoRoute(
        path: '/rop/reference',
        builder: (_, __) => const RopReferenceScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: '/references',
        builder: (_, __) => const ReferencesScreen(),
      ),
      GoRoute(
        path: '/pdf-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final path = state.uri.queryParameters['path'] ??
              extra?['path'] as String? ??
              '';
          final title = state.uri.queryParameters['title'] ??
              extra?['title'] as String? ??
              'STW Document';
          return PdfViewerScreen(
            assetPath: path,
            title: title,
            // Mock PDF rendering for headless widget test environment
            customViewerBuilder: (ctx) => Center(
              child: Text('Mock PDF Viewer: $title'),
            ),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('References screen displays two STW cards and cited sources',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
    await tester.pumpAndSettle();

    // 1. Verify screen title and section headers
    expect(find.text('References'), findsOneWidget);
    expect(find.text('Original Standard Treatment Workflows'), findsOneWidget);

    // 2. Verify RD and ROP cards
    expect(find.text('Respiratory Distress in Neonates'), findsWidgets);
    expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);

    // Small subtitles with ICD codes
    expect(
      find.textContaining('ICD-11 KB23 · ICMR / DHR · August 2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ICD-11 9B71.3 · ICMR / DHR · August 2026'),
      findsOneWidget,
    );

    // Two "View PDF" buttons
    expect(find.text('View PDF'), findsNWidgets(2));

    // 3. Verify cited sources section
    expect(find.text('Sources cited in the STWs'), findsOneWidget);
    expect(
      find.textContaining('National Neonatology Forum India'),
      findsWidgets,
    );
    expect(
      find.textContaining('nhm.gov.in'),
      findsOneWidget,
    );

    // 4. Verify disclaimer (scroll down in ListView)
    final disclaimerHeader = find.text('Disclaimer (from the STW)');
    await tester.scrollUntilVisible(disclaimerHeader, 200);
    expect(disclaimerHeader, findsOneWidget);
    expect(
      find.textContaining('This STW has been prepared by national experts'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Tapping RD "View PDF" navigates to viewer screen and can return',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
    await tester.pumpAndSettle();

    final viewPdfButtons = find.text('View PDF');
    expect(viewPdfButtons, findsNWidgets(2));

    // Tap first card (Respiratory Distress)
    await tester.tap(viewPdfButtons.first);
    await tester.pumpAndSettle();

    // Verify viewer screen opened with mock viewer
    expect(find.byType(PdfViewerScreen), findsOneWidget);
    expect(
      find.text('Mock PDF Viewer: Respiratory Distress in Neonates'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);

    // Tap Back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Back on References screen
    expect(find.text('References'), findsOneWidget);
    expect(find.byType(PdfViewerScreen), findsNothing);
  });

  testWidgets(
      'Tapping ROP "View PDF" navigates to viewer screen with ROP title',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
    await tester.pumpAndSettle();

    final viewPdfButtons = find.text('View PDF');
    expect(viewPdfButtons, findsNWidgets(2));

    // Tap second card (Retinopathy of Prematurity)
    await tester.tap(viewPdfButtons.last);
    await tester.pumpAndSettle();

    // Verify viewer screen opened with ROP title
    expect(find.byType(PdfViewerScreen), findsOneWidget);
    expect(
      find.text('Mock PDF Viewer: Retinopathy of Prematurity (ROP)'),
      findsOneWidget,
    );

    // Tap Back
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('References'), findsOneWidget);
  });

  testWidgets('Home screen contains References link and navigates correctly',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/home'));
    await tester.pumpAndSettle();

    final refLink = find.text('References');
    expect(refLink, findsOneWidget);

    await tester.tap(refLink);
    await tester.pumpAndSettle();

    expect(find.text('References'), findsOneWidget);
    expect(find.text('Original Standard Treatment Workflows'), findsOneWidget);
  });

  testWidgets('Home screen contains View source PDF links',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/home'));
    await tester.pumpAndSettle();

    final pdfLinks = find.text('View source PDF →');
    expect(pdfLinks, findsNWidgets(2));

    await tester.tap(pdfLinks.first);
    await tester.pumpAndSettle();

    expect(find.byType(PdfViewerScreen), findsOneWidget);
    expect(
      find.text('Mock PDF Viewer: Respiratory Distress in Neonates'),
      findsOneWidget,
    );
  });

  testWidgets('RD screen has no Source PDF button',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/rd'));
    await tester.pumpAndSettle();

    expect(find.text('Source PDF'), findsNothing);
  });

  testWidgets('ROP screen has no Source PDF button',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/rop'));
    await tester.pumpAndSettle();

    expect(find.text('Source PDF'), findsNothing);
  });
}
