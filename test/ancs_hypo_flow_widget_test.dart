import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';

import 'test_helpers.dart';

Future<void> _pumpToSelection(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  if (find.text('Continue').evaluate().isNotEmpty) {
    await tapVisible(tester, find.text('Continue'));
  }
}

Future<void> _openCard(WidgetTester tester, String topic, String card) async {
  await _pumpToSelection(tester);
  await tapVisible(tester, find.text(topic));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue').first);
  expect(find.text('Available Clinical Workflows'), findsOneWidget);
  await tapVisible(tester, find.text(card));
}

Future<void> _continue(WidgetTester tester) =>
    tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final f = find.widgetWithText(TextField, label);
  await tester.ensureVisible(f);
  await tester.enterText(f, value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'ANCS: eligible woman → GIVE ACS summary (pregnant woman, no baby line) '
      'and ANCS MCQs offered', (tester) async {
    await _openCard(
        tester, 'STW ANCS', 'Antenatal Corticosteroids for Preterm Birth');

    expect(find.text('Gestational age'), findsOneWidget);
    await _enter(tester, 'Gestational age (completed weeks) *', '30');
    await _enter(tester, '+ days *', '2');
    await _continue(tester);

    expect(find.text('High likelihood of preterm birth within the next 7 days'),
        findsOneWidget);
    await tapVisible(tester, find.text('PPROM without clinical infection'));
    await _continue(tester);

    expect(find.text('Eligibility criteria 2–5'), findsOneWidget);
    await tapVisible(tester, find.text('Yes').at(0));
    await tapVisible(tester, find.text('Absent'));
    await tapVisible(tester, find.text('Yes').at(1));
    await tapVisible(tester, find.text('Yes').at(2));
    await _continue(tester);

    await tapVisible(tester, find.text('No previous ACS course'));
    await _continue(tester);
    await _continue(tester); // Special situations: none
    await tapVisible(tester, find.text('Yes'));
    await _continue(tester);

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('Pregnant woman'), findsOneWidget);
    expect(find.text('GA 30+2 wk'), findsOneWidget);
    expect(find.text('Baby details'), findsNothing);
    expect(find.text('GIVE ACS'), findsOneWidget);
    expect(
      find.text(
          'DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES'),
      findsWidgets,
    );
    expect(find.text('Proceed to Follow-up Assessment'), findsOneWidget);

    await tapVisible(tester, find.text('Proceed to Follow-up Assessment'));
    expect(find.textContaining('MCQ 1 OF 8'), findsOneWidget);
  });

  testWidgets(
      'Hypoglycemia: IDM with BG 20 → IV bolus + GIR 6 with bolus formula',
      (tester) async {
    await _openCard(tester, 'STW Hypoglycemia', 'Neonatal Hypoglycemia');

    expect(find.text('Whom to screen for hypoglycemia'), findsOneWidget);
    await tapVisible(tester, find.text('Infants of diabetic mothers (IDM)'));
    await _continue(tester);

    await _enter(tester, 'Blood glucose (BG)', '20');
    await _enter(tester, 'Current weight (optional)', '1500');
    await _continue(tester);

    expect(find.text('On IV glucose infusion'), findsOneWidget);
    await tapVisible(tester, find.text('Not now — initial plan only'));
    await _continue(tester);

    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('Neonate'), findsOneWidget);
    expect(find.text('BG 20 mg/dL'), findsWidgets);
    expect(find.text('SYMPTOMATIC OR BG < 25 mg/dL'), findsOneWidget);
    expect(
      find.text('IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute'),
      findsWidgets,
    );
    expect(find.textContaining('2 ml/kg × 1.5 kg = 3 ml'), findsOneWidget);
    expect(find.text('At-risk infant — screen for hypoglycemia'),
        findsOneWidget);
  });

  testWidgets('STW text button opens the verbatim reference with disclaimer',
      (tester) async {
    await _pumpToSelection(tester);
    await tapVisible(tester, find.text('STW Hypoglycemia'));
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Continue').first);
    await tapVisible(tester, find.text("DOs/DON'Ts & KPIs"));

    expect(find.text('Hypoglycemia Reference'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('DON’Ts'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Do NOT give antibiotics for hypoglycemia unless sepsis '
            'is suspected'),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('DISCLAIMER (FROM THE STW)'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Kindly visit the DHR portal'), findsOneWidget);
  });

  testWidgets('leaving ANCS after an answer asks before resetting progress',
      (tester) async {
    await _openCard(
        tester, 'STW ANCS', 'Antenatal Corticosteroids for Preterm Birth');
    await _enter(tester, 'Gestational age (completed weeks) *', '30');
    await tapVisible(tester, find.text('Back to Selection'));
    expect(find.text('Progress will be reset'), findsOneWidget);
  });
}
