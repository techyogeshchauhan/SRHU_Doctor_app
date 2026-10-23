import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/combined_summary.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/disease_selection/ui/disease_selection_screen.dart';
import 'package:neonatal_stw/features/next_stw/ui/next_stw_screen.dart';
import 'package:neonatal_stw/features/triage/ui/triage_entry.dart';

import 'test_helpers.dart';

const expectedOrder = [
  NeonatalCondition.triage,
  NeonatalCondition.thermalCare,
  NeonatalCondition.fluidsAndFeeds,
  NeonatalCondition.hypoglycemia,
  NeonatalCondition.respiratoryDistress,
  NeonatalCondition.hie,
  NeonatalCondition.sepsis,
  NeonatalCondition.jaundice,
  NeonatalCondition.seizures,
  NeonatalCondition.kmc,
  NeonatalCondition.ancs,
  NeonatalCondition.rop,
  NeonatalCondition.transport,
  NeonatalCondition.dischargeAndFollowUp,
];

const availableTitles = [
  'Feeding and Nutrition in Neonates',
  'Neonatal Hypoglycemia',
  'Respiratory Distress in Neonates',
  'Post Asphyxia',
  'Sepsis in Neonates',
  'Kangaroo Mother Care (KMC)',
  'Antenatal Corticosteroids for Preterm Birth',
  'Retinopathy of Prematurity',
];

void main() {
  test('all 14 display positions retain existing ids and evaluation order', () {
    expect(conditionDisplayOrder, expectedOrder);
    const engine = AssessmentEngine();
    final ctx = engine.evaluate(
      selected: expectedOrder.reversed.toSet(),
      answers: const {},
      today: DateTime(2026, 10, 23),
    );
    final summary = CombinedAssessmentSummary.from(ctx);
    expect(summary.topics.map((t) => t.topic), expectedOrder);
    expect(summary.selectedTitles,
        expectedOrder.map((c) => definitionOf(c).title));
    // Presentation must not reorder questions, rules or clinical evaluation.
    expect(engine.workflowsFor(ctx.selected).map((w) => w.condition), [
      NeonatalCondition.triage,
      NeonatalCondition.kmc,
      NeonatalCondition.fluidsAndFeeds,
      NeonatalCondition.respiratoryDistress,
      NeonatalCondition.ancs,
      NeonatalCondition.sepsis,
      NeonatalCondition.hypoglycemia,
      NeonatalCondition.hie,
      NeonatalCondition.rop,
    ]);
  });

  for (final size in [const Size(360, 640), const Size(1280, 800)]) {
    testWidgets('all 14 topics retain their display positions at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();
      await goToHome(tester);

      expect(
          tester
              .widget<Icon>(
                  find.byKey(const ValueKey('stw-availability-triage')))
              .color,
          const Color(0xFF16A34A));
      for (final c in expectedOrder.skip(1)) {
        final badge = tester.widget<Container>(
            find.byKey(ValueKey('stw-availability-${c.name}')));
        expect(
            (badge.decoration! as BoxDecoration).color,
            definitionOf(c).implemented
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEE2E2),
            reason: c.name);
      }
      var previous = tester.getTopLeft(find.byType(TriageEntryCard)).dy;
      for (final c in expectedOrder.skip(1)) {
        final title = find.text(definitionOf(c).title);
        expect(title, findsOneWidget);
        final y = tester.getTopLeft(title).dy;
        expect(y, greaterThan(previous), reason: c.name);
        previous = y;
      }
      expect(find.byType(Checkbox), findsNWidgets(13));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'available and selected workflow cards follow display order at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: DiseaseSelectionScreen()),
      ));
      await tester.pumpAndSettle();
      expect(
          tester
              .widgetList<DiseaseCard>(find.byType(DiseaseCard))
              .map((card) => card.title),
          availableTitles);

      // Deliberately supply selected modules in reverse order.
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
            home: NextStwScreen(selectedModules: {
          NeonatalCondition.rop,
          NeonatalCondition.ancs,
          NeonatalCondition.kmc,
          NeonatalCondition.sepsis,
          NeonatalCondition.hie,
          NeonatalCondition.respiratoryDistress,
          NeonatalCondition.hypoglycemia,
          NeonatalCondition.fluidsAndFeeds,
        })),
      ));
      await tester.pumpAndSettle();
      expect(
          tester
              .widgetList<DiseaseCard>(find.byType(DiseaseCard))
              .map((card) => card.title),
          [
            'Feeding and Nutrition in Neonates',
            'Neonatal Hypoglycemia',
            'Respiratory Distress in Neonates',
            'Post Asphyxia',
            'Sepsis in Neonates',
            'Kangaroo Mother Care',
            'Antenatal Corticosteroids for Preterm Birth',
            'Retinopathy of Prematurity (ROP)',
          ]);
      expect(tester.takeException(), isNull);
    });
  }
}
