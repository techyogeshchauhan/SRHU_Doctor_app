import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/question_field.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 10, 14);

  testWidgets('triage measurements show examples and units responsively',
      (tester) async {
    for (final size in const [Size(320, 640), Size(820, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final question in [
                  qTriageWeight,
                  qTriageTemperature,
                  qTriageSpo2,
                  qTriageBloodGlucose,
                ])
                  QuestionField(
                    question: question,
                    options: const [],
                    value: null,
                    isRequired: false,
                    today: today,
                    onChanged: (_) {},
                    onVoice: () {},
                  ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      for (final question in [
        qTriageWeight,
        qTriageTemperature,
        qTriageSpo2,
        qTriageBloodGlucose,
      ]) {
        expect(find.text(question.inputHint!), findsOneWidget,
            reason: question.question);
        // The STW range sits outside the placeholder, below the field.
        expect(find.text(question.stwRange!), findsOneWidget,
            reason: question.question);
      }
      for (final unit in ['°C', '%', 'kg', 'mg/dL']) {
        expect(find.text(unit), findsOneWidget, reason: unit);
      }
      expect(find.text('bpm'), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('weight displays kilograms but reports canonical grams',
      (tester) async {
    Object? storedWeight;

    Widget field() => MaterialApp(
          home: Scaffold(
            body: QuestionField(
              question: qTriageWeight,
              options: const [],
              value: storedWeight,
              isRequired: false,
              today: today,
              onChanged: (value) => storedWeight = value,
            ),
          ),
        );

    await tester.pumpWidget(field());
    await tester.enterText(find.byType(TextField), '2.5');
    expect(storedWeight, 2500);

    await tester.pumpWidget(field());
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '2.5');
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('e.g., 2.5'), findsNothing);
  });

  test('weight is the first triage field and heart rate is removed', () {
    final measurements = [
      for (final u in triageWorkflow.uses)
        if (u.question.group == 'triage_measurements') u.question.id,
    ];
    expect(measurements, [
      triageWeightKey,
      triageTemperatureKey,
      triageSpo2Key,
      triageBloodGlucoseKey,
    ]);
    expect(triageGroups.first.questionOrder.first, triageWeightKey);
    expect(
      triageWorkflow.uses.where((u) => u.question.question == 'Heart rate'),
      isEmpty,
    );
  });

  testWidgets('STW range stays visible below the field while typing',
      (tester) async {
    for (final question in [qTriageWeight, qTriageTemperature]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuestionField(
            question: question,
            options: const [],
            value: null,
            isRequired: false,
            today: today,
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      final range = find.text(question.stwRange!);
      expect(range, findsOneWidget, reason: question.question);
      expect(tester.getRect(range).top,
          greaterThan(tester.getRect(find.byType(TextField)).bottom - 1));
      expect(find.text(question.inputHint!), findsNothing);
    }
  });

  test('measurement helper is attached to the triage measurement group', () {
    expect(
      triageGroups.first.footnote,
      "Examples indicate the expected input format only. Enter the baby's actual measured values.",
    );
  });

  testWidgets('numeric and text questions get field-specific placeholders',
      (tester) async {
    Object? answer;

    Widget field(ClinicalQuestion question, ValueChanged<Object?> onChanged) =>
        MaterialApp(
          home: Scaffold(
            body: QuestionField(
              question: question,
              options: const [],
              value: null,
              isRequired: false,
              today: today,
              onChanged: onChanged,
            ),
          ),
        );

    await tester.pumpWidget(field(qAncsGaWeeks, (value) => answer = value));
    var input = tester.widget<TextField>(find.byType(TextField));
    expect(
        input.decoration?.hintText, 'Enter gestational age (completed weeks)');
    await tester.enterText(find.byType(TextField), '32.5');
    expect(input.controller!.text, '');
    expect(answer, isNull);

    await tester.enterText(find.byType(TextField), '32');
    expect(answer, 32);
    expect(answer, isA<int>());

    answer = null;
    await tester
        .pumpWidget(field(qTriageTemperature, (value) => answer = value));
    input = tester.widget<TextField>(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '36.5x');
    expect(input.controller!.text, '');
    expect(answer, isNull);
    await tester.enterText(find.byType(TextField), '36.5');
    expect(answer, 36.5);
    expect(answer, isA<num>());

    await tester
        .pumpWidget(field(qRopNextExamPlace, (value) => answer = value));
    input = tester.widget<TextField>(find.byType(TextField));
    expect(input.decoration?.hintText, 'Enter place of next ROP examination');
    await tester.enterText(find.byType(TextField), 'SNCU Room 3');
    expect(answer, 'SNCU Room 3');
    expect(answer, isA<String>());
    await tester.pump();
    expect(find.text('Enter place of next ROP examination'), findsNothing);
  });

  test('question models reject values of the wrong type', () {
    expect(qAncsGaWeeks.validate('32'), isNotNull);
    expect(qAncsGaWeeks.validate(32.5), isNotNull);
    expect(qTriageTemperature.validate('36.5'), isNotNull);
    expect(qRopNextExamPlace.validate(123), isNotNull);
    expect(qRopNextExamPlace.validate('SNCU Room 3'), isNull);
  });
}
