import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

import 'test_helpers.dart';

Future<void> _pumpToSelection(
  WidgetTester tester, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Continue'));
  await tapVisible(tester, find.text('Get Started →'));
}

Future<void> _select(WidgetTester tester, List<String> titles) async {
  for (final t in titles) {
    await tapVisible(tester, find.widgetWithText(CheckboxListTile, t));
  }
  await tapVisible(tester, find.text('Continue'));
}

bool _checked(WidgetTester tester, String title) => tester
    .widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, title).first)
    .value!;

FilledButton _button(WidgetTester tester, String label) => tester.widget(
    find.ancestor(of: find.text(label), matching: find.byType(FilledButton)));

Future<void> _continue(WidgetTester tester) =>
    tapVisible(tester, find.text('Continue'));

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final f = find.widgetWithText(TextField, label);
  await tester.ensureVisible(f);
  await tester.enterText(f, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selection lists all 14 topics; Continue disabled at 0',
      (tester) async {
    await _pumpToSelection(tester);
    expect(find.text('Selected: 0'), findsOneWidget);
    expect(_button(tester, 'Continue').onPressed, isNull);
    for (final d in conditionDefinitions) {
      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, d.title),
        100,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tapVisible(tester, find.widgetWithText(CheckboxListTile, 'Sepsis'));
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(_button(tester, 'Continue').onPressed, isNotNull);
  });

  testWidgets('RD + ROP: shared GA asked once, both pathways in one summary',
      (tester) async {
    await _pumpToSelection(tester);
    await _select(tester, ['Respiratory Distress', 'ROP']);

    // Shared baby details first, asked once for both workflows.
    expect(find.text('Baby details'), findsOneWidget);
    expect(find.text('Asked once, used by: Respiratory Distress · ROP'),
        findsWidgets);
    await tapVisible(tester, find.text('GA known'));
    expect(
        find.widgetWithText(TextField, 'Gestational age (completed weeks) *'),
        findsOneWidget);
    expect(_button(tester, 'Continue').onPressed, isNull);
    await _enter(tester, 'Gestational age (completed weeks) *', '32');
    await _enter(tester, 'Birth weight', '1600');

    // GA 32 makes the baby ROP-eligible, so DOB appears on the same page.
    expect(find.text('Date of birth *'), findsOneWidget);
    await tapVisible(tester, find.text('Date of birth *'));
    await tapVisible(tester, find.text('OK'));
    await _continue(tester);

    // RD pathway.
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    await tapVisible(tester, find.text('Grunting'));
    await _continue(tester);
    expect(find.text('Silverman-Andersen Score'), findsOneWidget);
    for (final label in [
      '1 · Lag on inspiration',
      '1 · Minimal',
      '1 · Heard with stethoscope',
    ]) {
      await tapVisible(tester, find.text(label));
    }
    await tapVisible(tester, find.text('1 · Just visible').first);
    await tapVisible(tester, find.text('1 · Just visible').last);
    await _continue(tester);
    expect(find.text('Other findings'), findsOneWidget);
    await _continue(tester);
    await tapVisible(tester, find.text('Not now — initial assessment only'));
    await _continue(tester);

    // ROP pathway (eligible): GA is not asked again.
    expect(find.text('Screening timing'), findsOneWidget);
    expect(find.text('Baby details'), findsNothing);
    await tapVisible(tester, find.text('Yes'));
    await _continue(tester);
    await tapVisible(tester, find.text('Not yet'));
    await _continue(tester);
    expect(find.text('Next ROP examination'), findsOneWidget);
    await _continue(tester);

    // Combined summary.
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    // Baby details card and the ROP discharge card both show it.
    expect(find.textContaining('GA 32+0 wk · BW 1600 g', skipOffstage: false),
        findsNWidgets(2));
    for (final title in [
      'Respiratory distress criteria met',
      'START CPAP',
      'Moderate–severe RD (SAS 5)',
      'Screening eligible — SCREEN FOR ROP',
    ]) {
      expect(find.text(title, skipOffstage: false), findsOneWidget,
          reason: title);
    }
    expect(
        find.text('Selected for assessment — not diagnoses'), findsOneWidget);
  });

  testWidgets('Back keeps the selection; removing ROP removes its questions',
      (tester) async {
    await _pumpToSelection(tester);
    await _select(tester, ['Respiratory Distress', 'ROP']);
    expect(find.text('Baby details'), findsOneWidget);

    // Back on the first page returns to selection, ticks intact.
    await tapVisible(tester, find.text('Back'));
    expect(find.text('Selected: 2'), findsOneWidget);
    expect(_checked(tester, 'Respiratory Distress'), isTrue);
    expect(_checked(tester, 'ROP'), isTrue);

    await tapVisible(tester, find.widgetWithText(CheckboxListTile, 'ROP'));
    await _continue(tester);
    // RD alone starts with its own criteria; GA only if RD is present.
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
    expect(find.text('Baby details'), findsNothing);

    // No signs → criteria not met; nothing else is asked.
    await _continue(tester);
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('Respiratory distress criteria not met'), findsOneWidget);
    expect(find.text('ROP'), findsNothing);

    // Back from the summary returns to the last page.
    await tapVisible(tester, find.text('Back'));
    expect(find.text('Signs of respiratory distress'), findsOneWidget);
  });

  testWidgets('pending topic: no questions, placeholder in summary',
      (tester) async {
    await _pumpToSelection(tester);
    await _select(tester, ['Hypoglycemia']);
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text(pendingStwMessage), findsOneWidget);
    expect(find.text('Coming soon'), findsWidgets);
  });

  testWidgets('question pages fit a 320x568 phone', (tester) async {
    await _pumpToSelection(tester, size: const Size(320, 568));
    await _select(tester, ['Respiratory Distress']);
    await tapVisible(tester, find.text('Nasal flaring'));
    await _continue(tester);
    expect(find.text('Baby details'), findsOneWidget);
    await tapVisible(tester, find.text('GA uncertain'));
    await _enter(tester, 'Birth weight *', '1500');
    await _continue(tester);
    expect(find.text('Silverman-Andersen Score'), findsOneWidget);
  });
}
