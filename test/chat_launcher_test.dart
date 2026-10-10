import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/chatbot/ui/chat_screen.dart';

final _launcher = find.byKey(const Key('chat-launcher'));

void main() {
  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets(
        'floating chatbot button on every screen, opens the chat, hidden '
        'there (${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();
      expect(_launcher, findsOneWidget, reason: 'landing page');

      await tester.tap(find.text('Continue').first);
      await tester.pumpAndSettle();
      expect(find.text('Triaging'), findsOneWidget);
      expect(_launcher, findsOneWidget, reason: 'home');

      await tester.tap(_launcher);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(); // the button refreshes after the route change
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(_launcher, findsNothing, reason: 'hidden on the chat screen');
    });
  }

  testWidgets('it can be dragged and snaps to the nearer side', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();

    final before = tester.getCenter(_launcher);
    expect(before.dx, greaterThan(180), reason: 'starts on the right');
    await tester.drag(_launcher, const Offset(-250, -120));
    await tester.pumpAndSettle();
    final after = tester.getCenter(_launcher);
    expect(after.dx, lessThan(180), reason: 'snapped to the left');
    expect(after.dy, lessThan(before.dy), reason: 'moved up');
  });
}
