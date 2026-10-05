import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_steps.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

import 'test_helpers.dart';

Future<void> _pumpToHome(
  WidgetTester tester, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Continue'));
}

bool _checked(WidgetTester tester, String title) => tester
    .widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, title).first)
    .value!;

FilledButton _continueButton(WidgetTester tester) => tester.widget(find
    .ancestor(of: find.text('Continue'), matching: find.byType(FilledButton)));

void main() {
  testWidgets(
      'selection screen lists all 14 conditions; Continue disabled at 0',
      (tester) async {
    await _pumpToHome(tester);
    await tapVisible(tester, find.text('Get Started →'));

    expect(find.text('Select one or more conditions/topics to continue.'),
        findsOneWidget);
    expect(find.text('Selected: 0'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    for (final d in conditionDefinitions) {
      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, d.title),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(CheckboxListTile, d.title), findsOneWidget);
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Sepsis'));
    expect(find.text('Selected: 1'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('RD + ROP → both workflows; back keeps selection; remove ROP',
      (tester) async {
    await _pumpToHome(tester);
    await tapVisible(tester, find.text('Get Started →'));
    await tapVisible(tester, find.text('Respiratory Distress'));
    await tapVisible(tester, find.text('ROP'));
    expect(find.text('Selected: 2'), findsOneWidget);

    await tapVisible(tester, find.text('Continue'));
    expect(find.text('Step 1 of 4: Baby details'), findsOneWidget);
    expect(find.text('3. ROP'), findsOneWidget);

    // Back on the first step returns to selection with ticks intact.
    await tapVisible(tester, find.text('Back'));
    expect(find.text('Selected: 2'), findsOneWidget);
    expect(_checked(tester, 'Respiratory Distress'), isTrue);
    expect(_checked(tester, 'ROP'), isTrue);

    await tapVisible(tester, find.text('ROP'));
    await tapVisible(tester, find.text('Continue'));
    expect(find.text('Step 1 of 3: Baby details'), findsOneWidget);
    expect(find.text('3. ROP'), findsNothing);
    // DOB is only asked when ROP is selected.
    expect(find.text('Date of birth'), findsNothing);
  });

  testWidgets('RD step opens the existing RD module; summary reuses its plan',
      (tester) async {
    await _pumpToHome(tester);
    await openModuleFromHome(tester, 'Respiratory Distress');
    expect(find.text('Signs of respiratory distress'), findsOneWidget);

    await tapVisible(tester, find.text('Grunting'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Gestational age'), '30');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('START CPAP 5–6 cm H₂O + caffeine'), findsOneWidget);

    await tapVisible(tester, find.text('Next: Summary'));
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
    expect(find.text('START CPAP 5–6 cm H₂O + caffeine'), findsWidgets);
  });

  testWidgets('pending condition shows placeholder, never recommendations',
      (tester) async {
    await _pumpToHome(tester);
    await tapVisible(tester, find.text('Get Started →'));
    await tapVisible(tester, find.text('Hypoglycemia'));
    await tapVisible(tester, find.text('Continue'));

    expect(find.text('Step 1 of 2: Hypoglycemia'), findsOneWidget);
    expect(find.text(pendingStwMessage), findsOneWidget);

    await tapVisible(tester, find.text('Next: Summary'));
    expect(
      find.text('No recommendations — STW content not yet available.'),
      findsOneWidget,
    );
  });

  testWidgets('all workflow steps fit a 320x568 phone (RD + Sepsis + ROP)',
      (tester) async {
    await _pumpToHome(tester, size: const Size(320, 568));
    await tapVisible(tester, find.text('Get Started →'));
    for (final t in ['Respiratory Distress', 'Sepsis', 'ROP']) {
      await tapVisible(tester, find.text(t));
    }
    await tapVisible(tester, find.text('Continue'));
    expect(find.text('Step 1 of 5: Baby details'), findsOneWidget);
    for (final next in [
      'Next: Respiratory Distress',
      'Next: Sepsis',
      'Next: ROP',
      'Next: Summary',
    ]) {
      await tapVisible(tester, find.text(next));
    }
    expect(find.text('Clinical Assessment Summary'), findsOneWidget);
  });

  testWidgets('questionnaire renderer shows a branch only when its gate is on',
      (tester) async {
    // Test fixture only — no condition uses a questionnaire yet.
    const workflow = QuestionnaireWorkflow(
      NeonatalCondition.sepsis,
      questions: [
        ClinicalQuestion(
          id: 'gate',
          condition: NeonatalCondition.sepsis,
          question: 'Fixture gate',
          type: QuestionType.boolean,
        ),
        ClinicalQuestion(
          id: 'branch',
          condition: NeonatalCondition.sepsis,
          question: 'Fixture branch',
          type: QuestionType.singleChoice,
          options: [QuestionOption('a', 'Option A')],
          showWhen: ShowWhen('gate', equals: true),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: QuestionnaireStepView(workflow: workflow),
          ),
        ),
      ),
    ));
    expect(find.text('Fixture gate'), findsOneWidget);
    expect(find.text('Fixture branch'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Fixture branch'), findsOneWidget);
    expect(find.text('Option A'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Fixture branch'), findsNothing);
  });
}
