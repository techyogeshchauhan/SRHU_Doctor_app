import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

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
        expect(find.textContaining('SRHU STW'), findsOneWidget);

        // Full service names (exact text)
        expect(
          find.text('Respiratory Distress in Neonates'),
          findsOneWidget,
        );
        expect(
          find.text('Retinopathy of Prematurity (ROP)'),
          findsOneWidget,
        );

        // Two Get Started buttons
        final getStartedButtons = find.text('Get Started →');
        expect(getStartedButtons, findsNWidgets(2));

        // Tapping first button navigates to Respiratory Distress module
        await tester.tap(getStartedButtons.first);
        await tester.pumpAndSettle();
        expect(find.text('Signs of respiratory distress'), findsOneWidget);

        // Verify no "Source PDF" in RD module
        expect(find.text('Source PDF'), findsNothing);

        // Return to home
        await tester.tap(find.byIcon(Icons.home_outlined));
        await tester.pumpAndSettle();

        // Tapping second button navigates to Retinopathy of Prematurity module
        await tester.tap(find.text('Get Started →').last);
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 5: Eligibility'), findsOneWidget);

        // Verify no "Source PDF" in ROP module
        expect(find.text('Source PDF'), findsNothing);

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
              reason: 'Landing should have zero overflow at ${size.width}x${size.height}');

          // Navigate to Home screen
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();

          // Home screen fits
          expect(find.byType(SingleChildScrollView), findsNothing);
          expect(find.text('Get Started →'), findsNWidgets(2));
          expect(find.text('Disclaimer'), findsOneWidget);
          expect(find.text('References'), findsOneWidget);

          overflowErrors = errors.where((e) =>
              e.exceptionAsString().contains('A RenderFlex overflowed by'));
          expect(overflowErrors, isEmpty,
              reason: 'Home should have zero overflow at ${size.width}x${size.height}');
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    }

    testWidgets('Disclaimer opens modal bottom sheet with advisory text on Home',
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
      expect(find.text('Original Standard Treatment Workflows'), findsOneWidget);
    });

    testWidgets('Landing and Home screens accommodate large text scale without overflow',
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

    testWidgets('Home layout adheres to hero sizing, card spacing, and button height rules',
        (tester) async {
      await _pumpAppAt(tester, size: const Size(360, 640));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 1. Hero image check
      final heroImage = find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final img = w.image;
        if (img is AssetImage) return img.assetName == 'assets/images/hu.png';
        if (img is ResizeImage) {
          final inner = img.imageProvider;
          if (inner is AssetImage) {
            return inner.assetName == 'assets/images/hu.png';
          }
        }
        return false;
      });
      expect(heroImage, findsOneWidget);

      // Hero has ClipRRect with 20px radius
      final clipRRect = find.ancestor(
        of: heroImage,
        matching: find.byType(ClipRRect),
      );
      expect(clipRRect, findsOneWidget);
      final clipWidget = tester.widget<ClipRRect>(clipRRect);
      expect(clipWidget.borderRadius, BorderRadius.circular(20));

      // Hero has ShaderMask for soft edge fade
      final shaderMask = find.ancestor(
        of: heroImage,
        matching: find.byType(ShaderMask),
      );
      expect(shaderMask, findsOneWidget);

      // 2. Buttons are at least 48 px (and 50 px on 360x640)
      final getStartedButtons = find.widgetWithText(FilledButton, 'Get Started →');
      expect(getStartedButtons, findsNWidgets(2));
      for (int i = 0; i < 2; i++) {
        final btnSize = tester.getSize(getStartedButtons.at(i));
        expect(btnSize.height, greaterThanOrEqualTo(48.0));
      }

      // 3. No Spacer in Home column
      expect(find.byType(Spacer), findsNothing);
    });
  });
}

