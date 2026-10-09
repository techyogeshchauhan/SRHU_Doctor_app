import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

import 'test_helpers.dart';

Future<void> _pumpAppAt(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('Landing & Home Screen Tests', () {
    testWidgets(
        'Landing shows headline, text, and Continue button navigating to Home at 360x640',
        (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await _pumpAppAt(tester, size: const Size(360, 640));

        // 1. Landing Screen checks
        expect(find.text('Clinical guidance for newborn care'), findsOneWidget);
        expect(
          find.text(
            'Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows.',
          ),
          findsOneWidget,
        );
        final continueBtn = find.text('Continue');
        expect(continueBtn, findsOneWidget);

        // Tap Continue to navigate to Home
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        // 2. Home Screen checks
        expect(find.text('TRIGIN'), findsOneWidget);
        expect(
          find.text('Based on History and Clinical Examination.'),
          findsOneWidget,
        );
        expect(find.text('Select any condition.'), findsOneWidget);
        expect(find.textContaining('Selected:'), findsNothing);
        expect(find.text('STW Respiratory Distress'), findsOneWidget);

        // Selecting Respiratory Distress opens the RD module
        await openStandaloneModule(tester, '/rd');
        expect(find.text('Signs of respiratory distress'), findsOneWidget);

        // Return to home
        await tester.tap(find.byIcon(Icons.home_rounded));
        await tester.pumpAndSettle();

        // Selecting ROP opens the ROP module
        await openStandaloneModule(tester, '/rop');
        expect(find.text('Step 1 of 5: Eligibility'), findsOneWidget);

        // Return to home
        await tester.tap(find.byIcon(Icons.home_rounded));
        await tester.pumpAndSettle();

        // Check for no overflow exceptions
        final overflowErrors = errors.where((e) =>
            e.exceptionAsString().contains('A RenderFlex overflowed by'));
        expect(overflowErrors, isEmpty,
            reason: 'Should have no overflow exceptions');
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    for (final size in [
      const Size(320, 568), // iPhone SE 1st gen / ultra-compact
      const Size(360, 640), // Standard compact
      const Size(360, 740), // Mid-size phone
      const Size(412, 915), // Tall modern phone
    ]) {
      testWidgets(
          'Landing and Home screens fit without overflow at ${size.width}x${size.height}',
          (tester) async {
        final errors = <FlutterErrorDetails>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        try {
          await _pumpAppAt(tester, size: size);

          // Landing screen fits
          expect(find.byType(SingleChildScrollView), findsNothing);
          expect(find.text('Continue'), findsOneWidget);

          var overflowErrors = errors.where((e) =>
              e.exceptionAsString().contains('A RenderFlex overflowed by'));
          expect(overflowErrors, isEmpty,
              reason:
                  'Landing should have zero overflow at ${size.width}x${size.height}');

          // Navigate to Home screen
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          // Home screen fits
          expect(find.text('TRIGIN'), findsOneWidget);
          expect(
            find.text('Based on History and Clinical Examination.'),
            findsOneWidget,
          );
          expect(find.text('Select any condition.'), findsOneWidget);
          expect(find.text('Disclaimer'), findsOneWidget);
          expect(find.text('References'), findsOneWidget);

          overflowErrors = errors.where((e) =>
              e.exceptionAsString().contains('A RenderFlex overflowed by'));
          expect(overflowErrors, isEmpty,
              reason:
                  'Home should have zero overflow at ${size.width}x${size.height}');
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    }

    testWidgets(
        'Disclaimer opens modal bottom sheet with advisory text on Home',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(360, 640));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disclaimer'));
      await tester.pumpAndSettle();

      expect(find.text('STW Advisory Disclaimer'), findsOneWidget);
      expect(find.textContaining('This STW has been prepared'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('STW Advisory Disclaimer'), findsNothing);
    });

    testWidgets('References link navigates to References screen from Home',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(360, 640));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('References'));
      await tester.pumpAndSettle();

      expect(find.text('References'), findsOneWidget);
      expect(
          find.text('Original Standard Treatment Workflows'), findsOneWidget);
    });

    testWidgets(
        'Landing and Home screens accommodate large text scale without overflow',
        (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await _pumpAppAt(
          tester,
          size: const Size(360, 640),
          textScale: 1.3,
        );

        var overflowErrors = errors.where((e) =>
            e.exceptionAsString().contains('A RenderFlex overflowed by'));
        expect(overflowErrors, isEmpty,
            reason: 'Landing should not overflow with 1.3x text scale');

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        overflowErrors = errors.where((e) =>
            e.exceptionAsString().contains('A RenderFlex overflowed by'));
        expect(overflowErrors, isEmpty,
            reason: 'Home should not overflow with 1.3x text scale');
      } finally {
        FlutterError.onError = oldHandler;
      }
    });

    testWidgets(
        'Home layout adheres to TRIGIN heading, condition cards, and button rules',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(360, 640));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 1. Heading check
      expect(find.text('TRIGIN'), findsOneWidget);
      expect(
        find.text('Based on History and Clinical Examination.'),
        findsOneWidget,
      );
      expect(find.text('Select any condition.'), findsOneWidget);

      // 2. Selection counter and checkboxes present
      expect(find.textContaining('Selected:'), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(14));
      expect(find.text('STW Respiratory Distress'), findsOneWidget);
      expect(find.text('STW ROP'), findsOneWidget);
      expect(find.text('Reference'), findsWidgets);

      // 3. Status badges: 4 available, 10 awaiting STW
      expect(find.text('Available'), findsNWidgets(4));
      expect(find.text('Awaiting STW'), findsNWidgets(10));
    });

    testWidgets(
        'Landing displays all 5 institutional partners with accessible semantics',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(1024, 768));

      // Section headings
      expect(
        find.text('Trusted By Leading Medical & Research Institutions'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Developed with support, expertise, and collaboration from leading medical and research institutions.',
        ),
        findsOneWidget,
      );

      // All 5 short names
      expect(find.text('ICMR'), findsOneWidget);
      expect(find.text('SRHU'), findsOneWidget);
      expect(find.text('AIIMS Delhi'), findsOneWidget);
      expect(find.text('PGIMER'), findsOneWidget);
      expect(find.text('GMCH'), findsOneWidget);

      // All 5 accessible semantics labels
      expect(
        find.bySemanticsLabel('Indian Council of Medical Research (ICMR) Logo'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Swami Rama Himalayan University (SRHU) Logo'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            'All India Institute of Medical Sciences Delhi Logo'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            'Postgraduate Institute of Medical Education and Research Chandigarh Logo'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            'Government Medical College and Hospital Chandigarh Logo'),
        findsOneWidget,
      );

      // ICMR is featured first, above the other four
      final icmrCenter = tester.getCenter(find.text('ICMR'));
      final srhuCenter = tester.getCenter(find.text('SRHU'));
      final aiimsCenter = tester.getCenter(find.text('AIIMS Delhi'));
      final pgiCenter = tester.getCenter(find.text('PGIMER'));
      final gmchCenter = tester.getCenter(find.text('GMCH'));

      expect(icmrCenter.dy, lessThan(srhuCenter.dy));

      // SRHU, AIIMS Delhi, PGIMER, GMCH share one row, left to right
      expect(srhuCenter.dy, equals(aiimsCenter.dy));
      expect(aiimsCenter.dy, equals(pgiCenter.dy));
      expect(pgiCenter.dy, equals(gmchCenter.dy));
      expect(srhuCenter.dx, lessThan(aiimsCenter.dx));
      expect(aiimsCenter.dx, lessThan(pgiCenter.dx));
      expect(pgiCenter.dx, lessThan(gmchCenter.dx));

      // ICMR logo is larger than the other partner logos
      final icmrLogo = tester.getSize(find
          .bySemanticsLabel('Indian Council of Medical Research (ICMR) Logo'));
      final srhuLogo = tester.getSize(
          find.bySemanticsLabel('Swami Rama Himalayan University (SRHU) Logo'));
      expect(icmrLogo.height, greaterThan(srhuLogo.height));

      // Partner logos sit at the top of the screen; the poster image is gone
      expect(icmrCenter.dy, lessThan(768 / 3));
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/landingpageimage.png'),
        findsNothing,
      );
    });

    testWidgets('Header displays ICMR logo on Home, RD, and ROP screens',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(360, 640));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Home Screen header has ICMR logo
      expect(
        find.bySemanticsLabel('ICMR Logo'),
        findsOneWidget,
      );

      // Navigate to Respiratory Distress module
      await openStandaloneModule(tester, '/rd');
      expect(
        find.bySemanticsLabel('ICMR Logo'),
        findsOneWidget,
      );

      // Return to Home
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();

      // Navigate to ROP module
      await openStandaloneModule(tester, '/rop');
      expect(
        find.bySemanticsLabel('ICMR Logo'),
        findsOneWidget,
      );
    });
  });
}
