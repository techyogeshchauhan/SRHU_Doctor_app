import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scrolls [f] into view (when inside a scrollable), then taps it.
Future<void> tapVisible(WidgetTester tester, Finder f) async {
  if (find.byType(Scrollable).evaluate().isNotEmpty) {
    try {
      await tester.ensureVisible(f);
    } catch (_) {}
  }
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// From Home: Get Started → select only [conditionTitle] → Continue →
/// its workflow step → open the existing module screen.
Future<void> openModuleFromHome(
  WidgetTester tester,
  String conditionTitle,
) async {
  await tapVisible(tester, find.text('Get Started →'));
  if (find.text('Selected: 0').evaluate().isEmpty) {
    await tapVisible(tester, find.text('Clear all'));
  }
  await tapVisible(tester, find.text(conditionTitle));
  await tapVisible(tester, find.text('Continue'));
  await tapVisible(tester, find.text('Next: $conditionTitle'));
  await tapVisible(tester, find.text('Open $conditionTitle workflow'));
}
