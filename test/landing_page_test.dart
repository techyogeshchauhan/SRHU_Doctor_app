import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

Future<void> _pumpLanding(
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
  group('Landing Page Redesign Tests', () {
    testWidgets(
        'pumps landing page at 360x640: no overflow, two Get Started buttons exist, tapping each navigates to its module',
        (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await _pumpLanding(tester, size: const Size(360, 640));

        // Check for no overflow exceptions
        final overflowErrors = errors.where((e) =>
            e.exceptionAsString().contains('A RenderFlex overflowed by'));
        expect(overflowErrors, isEmpty,
            reason: 'Should have no overflow exceptions at 360x640');

        // Confirm app title and brand elements ("SRHU STW")
        expect(find.textContaining('SRHU'), findsOneWidget);
        expect(find.textContaining('SRHU STW'), findsOneWidget);
        expect(find.textContaining('STW'), findsWidgets);

        // Confirm two Get Started buttons exist
        final getStartedButtons = find.text('Get Started →');
        expect(getStartedButtons, findsNWidgets(2));

        // Tapping first button navigates to Respiratory Distress module
        await tester.tap(getStartedButtons.first);
        await tester.pumpAndSettle();
        expect(find.text('Signs of respiratory distress'), findsOneWidget);

        // Pop back to landing page
        final navigator =
            tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await tester.pumpAndSettle();

        // Tapping second button navigates to Retinopathy of Prematurity module
        await tester.tap(find.text('Get Started →').last);
        await tester.pumpAndSettle();
        expect(find.text('Step 1 of 5: Eligibility'), findsOneWidget);
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
      testWidgets('Landing page fits on one screen without overflow at ${size.width}x${size.height}',
          (tester) async {
        final errors = <FlutterErrorDetails>[];
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        try {
          await _pumpLanding(tester, size: size);

          final overflowErrors = errors.where((e) =>
              e.exceptionAsString().contains('A RenderFlex overflowed by'));
          expect(overflowErrors, isEmpty,
              reason: 'Should have zero overflow at ${size.width}x${size.height}');

          // Verify no Scrollable on the Landing Page root
          expect(find.byType(SingleChildScrollView), findsNothing);

          // Verify two Get Started buttons are visible
          expect(find.text('Get Started →'), findsNWidgets(2));

          // Verify Disclaimer and References links exist
          expect(find.text('Disclaimer'), findsOneWidget);
          expect(find.text('References'), findsOneWidget);
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    }

    testWidgets('Disclaimer opens modal bottom sheet with advisory text',
        (tester) async {
      await _pumpLanding(tester, size: const Size(360, 640));
      await tester.tap(find.text('Disclaimer'));
      await tester.pumpAndSettle();

      expect(find.text('STW Advisory Disclaimer'), findsOneWidget);
      expect(find.textContaining('This STW has been prepared'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('STW Advisory Disclaimer'), findsNothing);
    });

    testWidgets('References link navigates to References screen',
        (tester) async {
      await _pumpLanding(tester, size: const Size(360, 640));
      await tester.tap(find.text('References'));
      await tester.pumpAndSettle();

      expect(find.text('References'), findsOneWidget);
      expect(find.text('Original Standard Treatment Workflows'), findsOneWidget);
    });

    testWidgets('Landing page accommodates large text scale without overflow',
        (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await _pumpLanding(
          tester,
          size: const Size(360, 640),
          textScale: 1.3,
        );

        final overflowErrors = errors.where((e) =>
            e.exceptionAsString().contains('A RenderFlex overflowed by'));
        expect(overflowErrors, isEmpty,
            reason: 'Should not overflow with 1.3x text scale');
      } finally {
        FlutterError.onError = oldHandler;
      }
    });
  });
}
