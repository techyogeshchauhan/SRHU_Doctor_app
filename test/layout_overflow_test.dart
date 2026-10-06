import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

import 'test_helpers.dart';

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
      expect(find.text('Clinical guidance for newborn care'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await _tap(tester, find.text('Continue'));

      // 2. Home Screen
      expect(find.text('TRIGIN'), findsOneWidget);
      expect(
        find.text('Based on History and Clinical Examination.'),
        findsOneWidget,
      );
      expect(find.text('Select any condition.'), findsOneWidget);

      // RD launch via condition selection
      await openStandaloneModule(tester, '/rd');
      expect(find.text('Signs of respiratory distress'), findsOneWidget);

      // Verify no "Source PDF" in RD module
      expect(find.text('Source PDF'), findsNothing);

      // Test tabs in RD
      await _tap(tester, find.text('Reassess'));
      expect(find.text('Current support & oxygenation'), findsOneWidget);

      // Test Reference tab
      await _tap(tester, find.text('Reference'));
      expect(find.text('DOs'), findsOneWidget);

      // Return to home screen via Home icon
      await _tap(tester, find.byIcon(Icons.home_rounded));
      expect(find.text('TRIGIN'), findsOneWidget);
      expect(
        find.text('Based on History and Clinical Examination.'),
        findsOneWidget,
      );

      // ROP launch via condition selection
      await openStandaloneModule(tester, '/rop');
      expect(find.text('Step 1 of 5: Eligibility'), findsOneWidget);

      // Verify no "Source PDF" in ROP module
      expect(find.text('Source PDF'), findsNothing);

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

      // Return to home screen via Home icon
      await _tap(tester, find.byIcon(Icons.home_rounded));
      if (find.text('Leave & Reset').evaluate().isNotEmpty) {
        await _tap(tester, find.text('Leave & Reset'));
      }
      expect(find.text('TRIGIN'), findsOneWidget);
      expect(
        find.text('Based on History and Clinical Examination.'),
        findsOneWidget,
      );
    });
  }
}
