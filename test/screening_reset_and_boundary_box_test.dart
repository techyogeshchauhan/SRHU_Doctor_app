import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/core/utils/condition_exit_dialog.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/assessment_summary.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/condition_selection/state/condition_selection_controller.dart';
import 'package:neonatal_stw/features/condition_selection/ui/condition_selection_screen.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';
import 'package:neonatal_stw/features/rd/state/rd_controller.dart';
import 'package:neonatal_stw/features/rd/ui/rd_screen.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';
import 'package:neonatal_stw/features/rop/state/rop_controller.dart';
import 'package:neonatal_stw/features/rop/ui/rop_screen.dart';
import 'package:neonatal_stw/shared/baby_context.dart';

import 'test_helpers.dart';

void main() {
  group('1. Boundary Box Indication Size & Position Verification', () {
    test('regions.json bounding boxes do not have arbitrary full-page width (w=1.0) or excessive overflow', () {
      final file = File('assets/regions/regions.json');
      expect(file.existsSync(), isTrue);
      final regions = (jsonDecode(file.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

      int oversizedCount = 0;
      for (final r in regions) {
        final w = (r['w'] as num).toDouble();
        final h = (r['h'] as num).toDouble();
        // Any box with w >= 0.98 or h >= 0.98 indicates whole-page indiscriminate overlay
        if (w >= 0.98) {
          oversizedCount++;
        }
        expect(w, greaterThan(0.0));
        expect(w, lessThanOrEqualTo(1.0));
        expect(h, greaterThan(0.0));
        expect(h, lessThanOrEqualTo(1.0));
      }
      expect(oversizedCount, equals(0), reason: 'No region should cover the full page width indiscriminately');
    });

    test('stw_index.json bounding boxes match tightened coordinates', () {
      final file = File('assets/stw_index/stw_index.json');
      expect(file.existsSync(), isTrue);
      final indexList = (jsonDecode(file.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

      for (final item in indexList) {
        final rawBoxes = item['bounding_boxes'];
        if (rawBoxes is! List) continue;
        for (final b in rawBoxes) {
          final w = (b['width'] as num).toDouble();
          expect(w, lessThan(0.98), reason: 'Chunk ${item['chunk_id'] ?? item['id']} width should be tightly bounded');
        }
      }
    });

    test('Specific previously oversized regions (triage, kmc, ancs, hypo) are now tightly framed', () {
      final file = File('assets/regions/regions.json');
      final regions = (jsonDecode(file.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();

      // Check triage_initial_assessment (previously w: 0.953)
      final triage = regions.firstWhere((r) => r['id'] == 'triage_initial_assessment');
      expect((triage['w'] as num).toDouble(), lessThan(0.60), reason: 'Triage box should tightly frame the left column');

      // Check kmc_in_position (previously w: 0.831)
      final kmc = regions.firstWhere((r) => r['id'] == 'kmc_in_position');
      expect((kmc['w'] as num).toDouble(), lessThan(0.55), reason: 'KMC position box should fit the left column content');

      // Check ancs_abbreviations (previously w: 1.0)
      final ancs = regions.firstWhere((r) => r['id'] == 'ancs_abbreviations');
      expect((ancs['w'] as num).toDouble(), lessThan(0.85), reason: 'ANCS abbreviations should not span full page');

      // Check kmc_donts tightly fits the pink DON'Ts box without overlapping FOLLOW-UP VISITS
      final kmcDonts = regions.firstWhere((r) => r['id'] == 'kmc_donts');
      expect((kmcDonts['y'] as num).toDouble(), inInclusiveRange(0.475, 0.482),
          reason: 'KMC DON\'Ts must start at the DON\'Ts row (y ~0.478), not encroaching into row above');
      expect((kmcDonts['h'] as num).toDouble(), lessThanOrEqualTo(0.068),
          reason: 'KMC DON\'Ts height must strictly bound the DON\'Ts box');
      expect((kmcDonts['x'] as num).toDouble(), greaterThanOrEqualTo(0.50),
          reason: 'KMC DON\'Ts must start in the right column');

      // Check kmc_dos tightly fits the grey DO's box
      final kmcDos = regions.firstWhere((r) => r['id'] == 'kmc_dos');
      expect((kmcDos['y'] as num).toDouble(), inInclusiveRange(0.475, 0.482),
          reason: 'KMC DO\'s must start at DO\'s row (y ~0.478)');
      expect((kmcDos['h'] as num).toDouble(), lessThanOrEqualTo(0.068),
          reason: 'KMC DO\'s height must strictly bound the DO\'s box');

      // Check kmc_followup does not overlap into DO's/DON'Ts
      final kmcFollowup = regions.firstWhere((r) => r['id'] == 'kmc_followup');
      final followupBottom = (kmcFollowup['y'] as num).toDouble() + (kmcFollowup['h'] as num).toDouble();
      expect(followupBottom, lessThanOrEqualTo(0.478),
          reason: 'KMC Follow-up visits bottom must remain strictly above DO\'s/DON\'Ts row');

      // Check hypo_dos and hypo_donts start at DOs/DON'Ts row (~0.763)
      final hypoDos = regions.firstWhere((r) => r['id'] == 'hypo_dos');
      expect((hypoDos['y'] as num).toDouble(), greaterThanOrEqualTo(0.75),
          reason: 'Hypoglycemia DO\'s must start at DO\'s row (~0.763)');
      final hypoDonts = regions.firstWhere((r) => r['id'] == 'hypo_donts');
      expect((hypoDonts['y'] as num).toDouble(), greaterThanOrEqualTo(0.75),
          reason: 'Hypoglycemia DON\'Ts must start at DON\'Ts row (~0.763)');
    });
  });

  group('2. Screening Reset Functionality Verification', () {
    testWidgets('Reset Screening button is visible on workflow screen and shows dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Initialize workflow with Triage
      container.read(assessmentProvider.notifier).start({NeonatalCondition.triage}, forceReset: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WorkflowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reset Screening button must be found
      final resetBtn = find.widgetWithText(OutlinedButton, 'Reset Screening');
      expect(resetBtn, findsWidgets);

      // Tap Reset Screening button
      await tester.tap(resetBtn.first);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Reset Screening'), findsWidgets);
      expect(find.text('Restart Screening'), findsOneWidget);
      expect(find.text('Reset & Go to Home'), findsOneWidget);
    });

    testWidgets('Reset Screening restart clears answers and starts from clean state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(assessmentProvider.notifier).start({NeonatalCondition.triage}, forceReset: true);
      final initialFindingsCount = container.read(assessmentProvider).context.findings.length;

      // Record an answer
      final engine = container.read(assessmentEngineProvider);
      final currentGroup = container.read(assessmentProvider).currentGroup!;
      final questions = engine.pageQuestions(container.read(assessmentProvider).context, currentGroup);
      expect(questions.isNotEmpty, isTrue);
      final firstQ = questions.first.question;
      // The first Triage field is Weight, stored in grams.
      container.read(assessmentProvider.notifier).answer(firstQ.id, 2500);

      // Verify answer exists
      expect(container.read(assessmentProvider).context.answers, isNotEmpty);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WorkflowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reset Screening button
      final resetBtn = find.widgetWithText(OutlinedButton, 'Reset Screening');
      await tester.tap(resetBtn.first);
      await tester.pumpAndSettle();

      // Tap 'Restart Screening' in dialog
      await tester.tap(find.text('Restart Screening'));
      await tester.pumpAndSettle();

      // Answers must now be empty and findings reset to initial baseline
      expect(container.read(assessmentProvider).context.answers, isEmpty);
      expect(container.read(assessmentProvider).context.findings.length, equals(initialFindingsCount));
    });

    testWidgets('AssessmentSummaryView displays Reset Screening & Start New button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(assessmentProvider.notifier).start({NeonatalCondition.triage}, forceReset: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentSummaryView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Screening & Start New'), findsOneWidget);
      expect(find.text('Back to Home (Condition Selection)'), findsOneWidget);
    });

    testWidgets('Returning to ConditionSelectionScreen automatically resets all screening progress', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate a completed or in-progress assessment
      container.read(conditionSelectionProvider.notifier).toggle(NeonatalCondition.triage);
      container.read(assessmentProvider.notifier).start({NeonatalCondition.triage}, forceReset: true);
      container.read(assessmentProvider.notifier).answer('triage_apnea', true);
      container.read(babyProvider.notifier).setGaWeeks(34);

      expect(hasConditionProgress(container), isTrue);

      // Now open ConditionSelectionScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ConditionSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Automatically reset screening data when returning to condition-selection
      expect(container.read(assessmentProvider).context.answers, isEmpty);
      expect(container.read(assessmentProvider).context.selected, isEmpty);
      expect(container.read(conditionSelectionProvider), isEmpty);
      expect(container.read(babyProvider).isEmpty, isTrue);
      expect(hasConditionProgress(container), isFalse);
    });

    testWidgets('ROP screen displays visible Reset Screening button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RopScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Reset Screening'), findsOneWidget);
    });

    testWidgets('RD screen displays visible Reset Screening button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: RdScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Reset Screening'), findsOneWidget);
    });
  });
}
