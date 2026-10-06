import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

/// Opens the standalone RD (`/rd`) or ROP (`/rop`) screen from Home.
///
/// Since the dynamic assessment replaced the condition-by-condition flow,
/// these screens are no longer linked from the UI; their routes still exist
/// and their behaviour is tested here.
Future<void> openStandaloneModule(WidgetTester tester, String route) async {
  final element = tester.element(find.byType(Navigator).first);
  GoRouter.of(element).push(route);
  await tester.pumpAndSettle();
}
