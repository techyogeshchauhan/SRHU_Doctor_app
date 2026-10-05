import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/rop/ui/rop_screen.dart';

import 'test_helpers.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  bool tapContinue = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  if (tapContinue && find.text('Continue').evaluate().isNotEmpty) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
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
  testWidgets('home shows the workflow entry card', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Neonatal Care Workflows'), findsOneWidget);
    expect(find.text('Get Started →'), findsOneWidget);
  });

  testWidgets('RD: GA 30 + grunting → START CPAP + caffeine in the bar',
      (tester) async {
    await _pumpApp(tester);
    await openModuleFromHome(tester, 'Respiratory Distress');

    await _tap(tester, find.text('Grunting'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Gestational age'), '30');
    await tester.pumpAndSettle();

    // Sticky recommendation bar at the bottom.
    expect(find.text('START CPAP 5–6 cm H₂O + caffeine'), findsWidgets);
  });

  testWidgets('RD: GA 37, all SAS grade 0 → nasal O₂', (tester) async {
    await _pumpApp(tester);
    await openModuleFromHome(tester, 'Respiratory Distress');

    await _tap(tester, find.text('Nasal flaring'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Gestational age'), '37');
    await tester.pumpAndSettle();

    for (final label in [
      '0 · Synchronized',
      '0 · No retractions',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    // Xiphoid, nares and grunt share the "0 · None" label.
    for (var i = 0; i < 3; i++) {
      final none = find.text('0 · None');
      await tester.scrollUntilVisible(none.at(i), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(none.at(i));
      await tester.pumpAndSettle();
    }
    expect(find.text('Nasal-prong O₂ 0.5–1 L/min'), findsWidgets);
  });

  testWidgets('ROP wizard walks through all steps without errors',
      (tester) async {
    await _pumpApp(tester);
    await openModuleFromHome(tester, 'ROP');

    await tester.enterText(
        find.widgetWithText(TextField, 'Gestational age'), '30');
    await tester.pumpAndSettle();
    // Scoped to the ROP screen: the workflow step beneath it also shows
    // the eligibility result.
    expect(
        find.descendant(
          of: find.byType(RopScreen, skipOffstage: false),
          matching: find.text('SCREEN FOR ROP', skipOffstage: false),
          skipOffstage: false,
        ),
        findsOneWidget);

    for (final next in ['Next: Timing', 'Next: Prepare', 'Next: Findings',
        'Next: Follow-up']) {
      await _tap(tester, find.text(next));
    }
    expect(
        find.textContaining('NEXT ROP EXAMINATION: NOT DOCUMENTED',
            findRichText: true),
        findsOneWidget);
    expect(find.textContaining('DO NOT discharge'), findsOneWidget);
  });

  testWidgets('ROP findings: Zone II stage 3 + plus → treatment-requiring',
      (tester) async {
    await _pumpApp(tester);
    await openModuleFromHome(tester, 'ROP');
    await _tap(tester, find.text('4. Findings'));

    final scroll = find.byType(Scrollable).last;
    for (final label in ['Zone II', 'Stage 3', 'Plus present']) {
      await tester.scrollUntilVisible(find.text(label), 150, scrollable: scroll);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(find.text('Right eye (OD): Treatment-requiring ROP'), findsOneWidget);
    expect(find.text('Treat urgently — within 48–72 h of decision'),
        findsOneWidget);

    // Scroll to and toggle ICROP3 Quick Guide without type cast or PageStorage errors
    final icropGuide = find.text('ICROP3 Classification Quick Guide');
    await tester.scrollUntilVisible(icropGuide, 200, scrollable: scroll);
    expect(icropGuide, findsOneWidget);
    await tester.tap(icropGuide);
    await tester.pumpAndSettle();
    expect(find.textContaining('Stage 1 (Demarcation line)'), findsOneWidget);
    await tester.tap(icropGuide);
    await tester.pumpAndSettle();
    expect(find.textContaining('Stage 1 (Demarcation line)'), findsNothing);
  });

  testWidgets('tablet layout renders side-by-side without overflow',
      (tester) async {
    await _pumpApp(tester, size: const Size(1280, 800));
    await openModuleFromHome(tester, 'Respiratory Distress');
    expect(find.text('Recommendation pending'), findsOneWidget);
  });

  testWidgets('renders at 360x640 small phone without overflow', (tester) async {
    await _pumpApp(tester, size: const Size(360, 640), tapContinue: false);
    // Landing page
    expect(find.text('Clinical guidance for newborn care'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Continue to navigate to Home
    await _tap(tester, find.text('Continue'));
    expect(find.text('Neonatal Care Workflows'), findsOneWidget);
    expect(find.text('Get Started →'), findsOneWidget);

    // Open RD via condition selection
    await openModuleFromHome(tester, 'Respiratory Distress');
    expect(find.text('Signs of respiratory distress'), findsOneWidget);

    // Switch to Reassess tab
    await _tap(tester, find.text('Reassess'));
    expect(find.text('Current support & oxygenation'), findsOneWidget);

    // Open Home via Home icon in RD screen
    await _tap(tester, find.byIcon(Icons.home_outlined));
    expect(find.text('Neonatal Care Workflows'), findsOneWidget);
  });

  testWidgets('renders at 412x915 standard phone without overflow', (tester) async {
    await _pumpApp(tester, size: const Size(412, 915), tapContinue: false);
    expect(find.text('Clinical guidance for newborn care'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await _tap(tester, find.text('Continue'));
    expect(find.text('Neonatal Care Workflows'), findsOneWidget);
    expect(find.text('Get Started →'), findsOneWidget);
    await openModuleFromHome(tester, 'Respiratory Distress');
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    await _tap(tester, find.byIcon(Icons.home_outlined));
    expect(find.text('Neonatal Care Workflows'), findsOneWidget);
  });
}
