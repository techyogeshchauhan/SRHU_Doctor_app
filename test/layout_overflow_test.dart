import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

Future<void> _pumpWith(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (find.byType(Scrollable).evaluate().isNotEmpty) {
    try {
      await tester.ensureVisible(f);
    } catch (_) {}
  }
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  const sizes = [
    Size(360, 640), // Small phone
    Size(412, 915), // Standard / tall phone
  ];

  for (final size in sizes) {
    testWidgets('Full flow validation at ${size.width}x${size.height}',
        (tester) async {
      await _pumpWith(tester, size: size);

      // 1. Landing Screen
      expect(find.textContaining('SRHU'), findsOneWidget);
      expect(find.textContaining('SRHU STW'), findsOneWidget);
      expect(find.text('Get Started →'), findsNWidgets(2));

      // Direct RD launch from landing card
      await _tap(tester, find.text('Respiratory Distress'));
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Test tabs in RD
      await _tap(tester, find.text('Reassess'));
      expect(find.text('Current support & oxygenation'), findsOneWidget);

      await _tap(tester, find.text('Reference'));
      expect(find.text('DOs'), findsOneWidget);

      // Return to landing screen
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();

      // Direct ROP launch from landing card
      await _tap(tester, find.text('Retinopathy of Prematurity'));
      expect(find.text('Step 1 of 5: Eligibility'), findsOneWidget);

      // Walk all 5 steps
      for (final nextLabel in [
        'Next: Timing',
        'Next: Prepare',
        'Next: Findings',
        'Next: Follow-up',
      ]) {
        await _tap(tester, find.text(nextLabel));
      }
      expect(find.text('Next ROP examination'), findsOneWidget);

      // Test Back button
      await _tap(tester, find.text('Back'));
      expect(find.text('Step 4 of 5: Findings'), findsOneWidget);

      // Pop back
      navigator.pop();
      await tester.pumpAndSettle();

      // Open Home screen via module's home icon
      await _tap(tester, find.text('Get Started →').first);
      await _tap(tester, find.byIcon(Icons.home_outlined));
      expect(find.text('Neonatal STW'), findsOneWidget);

      // Open About screen
      await _tap(tester, find.byIcon(Icons.info_outline));
      expect(find.text('About'), findsOneWidget);
    });
  }
}
