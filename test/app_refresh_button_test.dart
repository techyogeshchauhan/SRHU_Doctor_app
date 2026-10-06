import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/widgets/app_refresh_button.dart';

void main() {
  group('AppRefreshButton Tests', () {
    testWidgets('AppRefreshButton renders with tooltip and triggers callback',
        (tester) async {
      bool refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AppRefreshButton(
                  onRefresh: () {
                    refreshed = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AppRefreshButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.tap(find.byType(AppRefreshButton));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });

    testWidgets('AppRefreshButton is present on Landing Screen and Home Screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();

      // On Landing Screen
      expect(find.byType(AppRefreshButton), findsOneWidget);

      // Navigate to Home Screen
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // On Home Screen
      expect(find.byType(AppRefreshButton), findsOneWidget);
    });
  });
}
