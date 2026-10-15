import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/core/theme.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/stw_section_regions.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/disease_selection/ui/disease_selection_screen.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/kmc/domain/kmc_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';
import 'package:neonatal_stw/features/references/ui/references_screen.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

import 'test_helpers.dart';

Widget _buildTestApp({
  String initialLocation = '/references',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/references',
        builder: (_, __) => const ReferencesScreen(),
      ),
      GoRoute(
        path: '/disease-selection',
        builder: (_, __) => const DiseaseSelectionScreen(),
      ),
      GoRoute(
        path: '/pdf-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final path = state.uri.queryParameters['path'] ??
              extra?['path'] as String? ??
              '';
          final title = state.uri.queryParameters['title'] ??
              extra?['title'] as String? ??
              'STW Document';
          final highlight = extra?['highlight'] as HighlightTarget?;
          return PdfViewerScreen(
            assetPath: path,
            title: title,
            highlightTarget: highlight,
            customViewerBuilder: (ctx) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mock PDF Viewer: $title'),
                  Text('Path: $path'),
                  if (highlight != null)
                    Text('Target Document: ${highlight.document}'),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Assets & File System Verification', () {
    test('all 8 bundled PDF assets exist on disk', () {
      final expectedPdfs = [
        'assets/pdfs/Triage_13-10-26.pdf',
        'assets/pdfs/KMC-13-10-2026.pdf',
        'assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
        'assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf',
        'assets/pdfs/respiratory_distress_neonates_stw.pdf',
        'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
        'assets/pdfs/Respiratory distress in neonates_New.pdf',
        'assets/pdfs/Retinopathy of Prematurity (ROP).pdf',
      ];
      for (final path in expectedPdfs) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: 'Missing PDF asset file: $path');
        expect(f.lengthSync(), greaterThan(10000),
            reason: 'PDF file is empty or corrupted: $path');
      }
    });

    test('all 8 PDF documents have rendered 1.webp pages and pages.json entries',
        () {
      final pagesFile = File('assets/pages/pages.json');
      expect(pagesFile.existsSync(), isTrue);
      final jsonList =
          jsonDecode(pagesFile.readAsStringSync()) as List<dynamic>;

      final docsFound = <String>{};
      for (final item in jsonList) {
        final map = item as Map<String, dynamic>;
        docsFound.add(map['document'] as String);
      }

      final expectedDocs = [
        'Triage_13-10-26.pdf',
        'KMC-13-10-2026.pdf',
        'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
        'Neonatal_Hypoglycemia_8th_Oct.pdf',
        'respiratory_distress_neonates_stw.pdf',
        'retinopathy_of_prematurity_stw.pdf',
        'Respiratory distress in neonates_New.pdf',
        'Retinopathy of Prematurity (ROP).pdf',
      ];

      for (final doc in expectedDocs) {
        expect(docsFound.contains(doc), isTrue,
            reason: 'pages.json missing doc: $doc');
        final firstPage = File('assets/pages/$doc/1.webp');
        expect(firstPage.existsSync(), isTrue,
            reason: 'Missing page image: assets/pages/$doc/1.webp');
      }
    });
  });

  group('PDF Mapping Verification for All Conditions', () {
    const conditions = [
      (
        NeonatalCondition.triage,
        'assets/pdfs/Triage_13-10-26.pdf',
        'Neonatal Emergency Triage Assessment and Management',
      ),
      (
        NeonatalCondition.kmc,
        'assets/pdfs/KMC-13-10-2026.pdf',
        'Kangaroo Mother Care',
      ),
      (
        NeonatalCondition.ancs,
        'assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
        'Antenatal Corticosteroids for Preterm Birth',
      ),
      (
        NeonatalCondition.hypoglycemia,
        'assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf',
        'Neonatal Hypoglycemia',
      ),
      (
        NeonatalCondition.respiratoryDistress,
        'assets/pdfs/respiratory_distress_neonates_stw.pdf',
        'Respiratory Distress in Neonates',
      ),
      (
        NeonatalCondition.rop,
        'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
        'Retinopathy of Prematurity (ROP)',
      ),
    ];

    for (final (cond, expectedAsset, expectedTitle) in conditions) {
      test('${cond.name} maps to correct PDF asset and title', () {
        final pdf = stwPdfFor(cond);
        expect(pdf, isNotNull, reason: '${cond.name} must have a registered PDF');
        expect(pdf!.asset, expectedAsset);
        expect(pdf.title, expectedTitle);
        expect(File(pdf.asset).existsSync(), isTrue);

        // Verify resolution by document title and by filename
        final resolvedByTitle = stwPdfForDocument(pdf.title);
        expect(resolvedByTitle, isNotNull);
        expect(resolvedByTitle!.asset, expectedAsset);

        final filename = expectedAsset.split('/').last;
        final resolvedByFilename = stwPdfForDocument(filename);
        expect(resolvedByFilename, isNotNull);
        expect(resolvedByFilename!.asset, expectedAsset);
      });
    }

    test('legacy document names map to their respective current PDFs', () {
      expect(
        stwPdfForDocument('respiratory_distress_neonates_stw.pdf')?.asset,
        'assets/pdfs/respiratory_distress_neonates_stw.pdf',
      );
      expect(
        stwPdfForDocument('Respiratory distress in neonates_New.pdf')?.asset,
        'assets/pdfs/respiratory_distress_neonates_stw.pdf',
      );
      expect(
        stwPdfForDocument('retinopathy_of_prematurity_stw.pdf')?.asset,
        'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
      );
      expect(
        stwPdfForDocument('Retinopathy of Prematurity (ROP).pdf')?.asset,
        'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
      );
    });
  });

  group('Clinical Workflow Source Reference & Region Accuracy', () {
    final workflows = <(NeonatalCondition, StwWorkflow)>[
      (NeonatalCondition.triage, triageWorkflow),
      (NeonatalCondition.kmc, kmcWorkflow),
      (NeonatalCondition.ancs, ancsWorkflow),
      (NeonatalCondition.hypoglycemia, hypoWorkflow),
      (NeonatalCondition.respiratoryDistress, rdWorkflow),
      (NeonatalCondition.rop, ropWorkflow),
    ];

    for (final (cond, wf) in workflows) {
      test('${cond.name} workflow questions and rules map to valid regions',
          () async {
        // Collect all clinical source references
        final sources = <SourceReference>[
          for (final u in wf.uses) ...u.question.sources,
          for (final r in wf.rules) r.source,
        ].where((s) => s.isClinical);

        expect(sources, isNotEmpty,
            reason: '${cond.name} should have clinical source references');

        for (final s in sources) {
          final mappedPdf = stwPdfForDocument(s.document);
          expect(mappedPdf, isNotNull,
              reason: 'Source document "${s.document}" could not be mapped to any PDF');

          final regionId = s.pdfRegionId;
          if (regionId == null) {
            final isOutside = sectionsOutsideStwPdf.contains('${s.document}|${s.section}');
            expect(isOutside, isTrue,
                reason: 'Reference without region "${s.document}|${s.section}" is not registered in sectionsOutsideStwPdf');
            continue;
          }

          final isOutside = sectionsOutsideStwPdf.contains('${s.document}|${s.section}') ||
              sectionsOutsideStwPdf.contains('${s.document}|$regionId');
          if (isOutside) {
            continue;
          }

          final target = await stwRegionTarget(regionId);
          expect(target, isNotNull,
              reason: 'Region "$regionId" referenced in ${cond.name} (${s.citation}) not found in regions.json');
          final docFilename = mappedPdf!.asset.split('/').last;
          expect(target!.document, docFilename,
              reason: 'Region "$regionId" belongs to document "${target.document}" instead of "$docFilename"');
          expect(target.page, greaterThanOrEqualTo(1));
          expect(target.normalizedBboxes, isNotEmpty);
          for (final bbox in target.normalizedBboxes) {
            expect(bbox.width, greaterThan(0));
            expect(bbox.height, greaterThan(0));
            expect(bbox.left, greaterThanOrEqualTo(0.0));
            expect(bbox.top, greaterThanOrEqualTo(0.0));
            expect(bbox.right, lessThanOrEqualTo(1.05));
            expect(bbox.bottom, lessThanOrEqualTo(1.05));
          }
        }
      });
    }

    test('regions.json contains regions for all 6 STWs without corrupted bounds',
        () {
      final regionsFile = File('assets/regions/regions.json');
      expect(regionsFile.existsSync(), isTrue);
      final jsonList =
          jsonDecode(regionsFile.readAsStringSync()) as List<dynamic>;

      final expectedDocNames = {
        'Triage_13-10-26.pdf',
        'KMC-13-10-2026.pdf',
        'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
        'Neonatal_Hypoglycemia_8th_Oct.pdf',
        'respiratory_distress_neonates_stw.pdf',
        'retinopathy_of_prematurity_stw.pdf',
      };

      final docsFound = <String>{};
      for (final item in jsonList) {
        final regionData = item as Map<String, dynamic>;
        final doc = regionData['document'] as String;
        docsFound.add(doc);
        final page = regionData['page'] as int;
        expect(page, greaterThanOrEqualTo(1));
        final x = (regionData['x'] as num).toDouble();
        final y = (regionData['y'] as num).toDouble();
        final w = (regionData['w'] as num).toDouble();
        final h = (regionData['h'] as num).toDouble();
        final id = regionData['id'] as String;
        expect(x >= 0, isTrue, reason: '$id x negative');
        expect(y >= 0, isTrue, reason: '$id y negative');
        expect(w > 0, isTrue, reason: '$id w non-positive');
        expect(h > 0, isTrue, reason: '$id h non-positive');
        expect(x + w <= 1.05, isTrue, reason: '$id overflows x');
        expect(y + h <= 1.05, isTrue, reason: '$id overflows y');
      }

      for (final doc in expectedDocNames) {
        expect(docsFound.contains(doc), isTrue,
            reason: 'regions.json missing document: $doc');
      }
    });
  });

  Future<void> scrollListViewUntil(WidgetTester tester, Finder target) async {
    int maxTries = 15;
    while (target.evaluate().isEmpty && maxTries > 0) {
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      maxTries--;
    }
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
  }

  group('References Screen UI & PDF Launching', () {
    testWidgets('all 6 STW reference cards are present with View PDF buttons',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
      await tester.pumpAndSettle();

      expect(find.text('References'), findsOneWidget);
      expect(find.text('Original Standard Treatment Workflows'), findsOneWidget);

      expect(find.text('Respiratory Distress in Neonates'), findsWidgets);
      expect(find.text('Retinopathy of Prematurity (ROP)'), findsWidgets);

      final ancs = find.text('Antenatal Corticosteroids for Preterm Birth');
      await scrollListViewUntil(tester, ancs);
      expect(ancs, findsWidgets);

      final hypo = find.text('Neonatal Hypoglycemia');
      await scrollListViewUntil(tester, hypo);
      expect(hypo, findsWidgets);

      final triage =
          find.text('Neonatal Emergency Triage Assessment and Management');
      await scrollListViewUntil(tester, triage);
      expect(triage, findsWidgets);

      final kmc = find.text('Kangaroo Mother Care');
      await scrollListViewUntil(tester, kmc);
      expect(kmc, findsWidgets);

      final sources = find.text('Sources cited in the STWs');
      await scrollListViewUntil(tester, sources);
      expect(sources, findsOneWidget);

      final triageSource = find.textContaining('Paediatric Emergency Triage');
      await scrollListViewUntil(tester, triageSource);
      expect(triageSource, findsWidgets);

      final kmcSource = find.textContaining('Operational guidelines for Kangaroo Mother Care');
      await scrollListViewUntil(tester, kmcSource);
      expect(kmcSource, findsWidgets);
    });

    testWidgets('tapping View PDF on Triage card opens Triage PDF viewer',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
      await tester.pumpAndSettle();

      final triageTitle =
          find.text('Neonatal Emergency Triage Assessment and Management');
      await scrollListViewUntil(tester, triageTitle);

      final triageCard =
          find.ancestor(of: triageTitle, matching: find.byType(Card));
      final triageBtn =
          find.descendant(of: triageCard, matching: find.text('View PDF'));
      await scrollListViewUntil(tester, triageBtn);
      await tester.tap(triageBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.textContaining('Triage_13-10-26.pdf'), findsOneWidget);
      expect(
          find.text(
              'Mock PDF Viewer: Neonatal Emergency Triage Assessment and Management'),
          findsOneWidget);
    });

    testWidgets('tapping View PDF on KMC card opens KMC PDF viewer',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(initialLocation: '/references'));
      await tester.pumpAndSettle();

      final kmcTitle = find.text('Kangaroo Mother Care');
      await scrollListViewUntil(tester, kmcTitle);

      final kmcCard =
          find.ancestor(of: kmcTitle, matching: find.byType(Card));
      final kmcBtn =
          find.descendant(of: kmcCard, matching: find.text('View PDF'));
      await scrollListViewUntil(tester, kmcBtn);
      await tester.tap(kmcBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.textContaining('KMC-13-10-2026.pdf'), findsOneWidget);
      expect(find.text('Mock PDF Viewer: Kangaroo Mother Care'), findsOneWidget);
    });
  });

  group('Disease Selection Screen UI & PDF Reference Buttons', () {
    testWidgets('all 6 diseases display Reference buttons opening correct PDFs',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _buildTestApp(initialLocation: '/disease-selection'));
      await tester.pumpAndSettle();

      expect(find.text('Available Clinical Workflows'), findsOneWidget);

      final diseaseChecks = [
        (
          'Retinopathy of Prematurity',
          'retinopathy_of_prematurity_stw.pdf',
          'Retinopathy of Prematurity (ROP)',
        ),
        (
          'Respiratory Distress in Neonates',
          'respiratory_distress_neonates_stw.pdf',
          'Respiratory Distress in Neonates',
        ),
        (
          'Neonatal Emergency Triage Assessment and Management',
          'Triage_13-10-26.pdf',
          'Neonatal Emergency Triage Assessment and Management',
        ),
        (
          'Kangaroo Mother Care (KMC)',
          'KMC-13-10-2026.pdf',
          'Kangaroo Mother Care',
        ),
        (
          'Antenatal Corticosteroids for Preterm Birth',
          'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
          'Antenatal Corticosteroids for Preterm Birth',
        ),
        (
          'Neonatal Hypoglycemia',
          'Neonatal_Hypoglycemia_8th_Oct.pdf',
          'Neonatal Hypoglycemia',
        ),
      ];

      for (final (title, expectedDoc, expectedPdfTitle) in diseaseChecks) {
        final card = find.text(title);
        await tester.scrollUntilVisible(card, 200);
        expect(card, findsOneWidget, reason: 'Card missing for: $title');

        final refBtn = find.descendant(
          of: find.ancestor(of: card, matching: find.byType(InkWell)),
          matching: find.widgetWithText(OutlinedButton, 'Reference'),
        );
        expect(refBtn, findsOneWidget,
            reason: 'Reference button missing for: $title');

        await tester.tap(refBtn);
        await tester.pumpAndSettle();

        expect(find.byType(PdfViewerScreen), findsOneWidget);
        expect(
            find.textContaining('Path: assets/pdfs/$expectedDoc'), findsOneWidget,
            reason: '$title opened wrong PDF file');
        expect(find.text('Mock PDF Viewer: $expectedPdfTitle'), findsOneWidget,
            reason: '$title opened wrong PDF title');

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });
  });

  group('Workflow Screen Question Page PDF Indication Buttons', () {
    testWidgets('Triage workflow displays Triage STW PDF button',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();

      if (find.text('Continue').evaluate().isNotEmpty) {
        await tapVisible(tester, find.text('Continue'));
      }

      await tapVisible(tester, find.text('STW Triage'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);

      await tapVisible(
          tester, find.text('Neonatal Emergency Triage Assessment and Management'));

      final triagePdfBtn = find.text('Triage STW PDF');
      expect(triagePdfBtn, findsOneWidget);

      await tapVisible(tester, triagePdfBtn);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.text('Neonatal Emergency Triage Assessment and Management'),
          findsWidgets);
    });

    testWidgets('KMC workflow displays KMC STW PDF button',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();

      if (find.text('Continue').evaluate().isNotEmpty) {
        await tapVisible(tester, find.text('Continue'));
      }

      await tapVisible(tester, find.text('STW KMC'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);

      await tapVisible(tester, find.text('Kangaroo Mother Care (KMC)'));

      final kmcPdfBtn = find.text('KMC STW PDF');
      expect(kmcPdfBtn, findsOneWidget);

      await tapVisible(tester, kmcPdfBtn);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.text('Kangaroo Mother Care'),
          findsWidgets);
    });

    testWidgets('ANCS workflow displays ANCS STW PDF button',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();

      if (find.text('Continue').evaluate().isNotEmpty) {
        await tapVisible(tester, find.text('Continue'));
      }

      await tapVisible(tester, find.text('STW ANCS'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);

      await tapVisible(
          tester, find.text('Antenatal Corticosteroids for Preterm Birth'));

      final ancsPdfBtn = find.text('ANCS STW PDF');
      expect(ancsPdfBtn, findsOneWidget);

      await tapVisible(tester, ancsPdfBtn);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.text('Antenatal Corticosteroids for Preterm Birth'),
          findsWidgets);
    });

    testWidgets('Hypoglycemia workflow displays Hypoglycemia STW PDF button',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();

      if (find.text('Continue').evaluate().isNotEmpty) {
        await tapVisible(tester, find.text('Continue'));
      }

      await tapVisible(tester, find.text('STW Hypoglycemia'));
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Continue').first);

      await tapVisible(tester, find.text('Neonatal Hypoglycemia'));

      final hypoPdfBtn = find.text('Hypoglycemia STW PDF');
      expect(hypoPdfBtn, findsOneWidget);

      await tapVisible(tester, hypoPdfBtn);
      expect(find.byType(PdfViewerScreen), findsOneWidget);
      expect(find.text('Neonatal Hypoglycemia'), findsWidgets);
    });
  });
}
