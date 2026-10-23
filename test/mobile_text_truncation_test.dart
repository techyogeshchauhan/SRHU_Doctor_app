/// Mobile text-truncation guard: renders every screen and flow at common
/// phone widths with the app's real fonts and fails if any text is cut short
/// (ellipsis/fade/clip, exceeded line limit) or a layout overflows.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/follow_up/data/disease_follow_up_registry.dart';
import 'package:neonatal_stw/features/follow_up/state/follow_up_controller.dart';

/// Loads the bundled Poppins/Inter fonts so text is measured with the real
/// glyph widths instead of the wide test font.
Future<void> loadAppFonts() async {
  final families = {
    'Poppins': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'Inter': ['Regular', 'Medium', 'SemiBold'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      final bytes =
          File('assets/fonts/${entry.key}-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  // Material icons and Roboto (Android's system font) ship with the SDK.
  final sdkFonts = Directory(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  if (sdkFonts.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(
          File('${sdkFonts.path}/materialicons-regular.otf')
              .readAsBytesSync()
              .buffer)));
    await icons.load();
    final roboto = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      final file = File('${sdkFonts.path}/roboto-$weight.ttf');
      if (file.existsSync()) {
        roboto.addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      }
    }
    await roboto.load();
  }
}

/// Every visible text that is cut short: an exceeded line limit (ellipsis,
/// fade or clip) or a single-line text wider than its box.
Set<String> truncatedTexts(WidgetTester tester) {
  final out = <String>{};
  for (final element in find.byType(RichText).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    final text = ro.text.toPlainText().trim();
    if (text.isEmpty) continue;
    final family = ro.text.style?.fontFamily ?? '';
    if (family.contains('Icons')) continue;
    var cut = ro.didExceedMaxLines;
    if (!cut && !ro.softWrap) {
      cut = ro.getMaxIntrinsicWidth(double.infinity) > ro.size.width + 1;
    }
    if (cut) out.add(text.replaceAll('\n', ' ⏎ '));
  }
  return out;
}

class Audit {
  final Map<String, Set<String>> hits = {};
  final Map<String, Set<String>> overflows = {};
  String screen = '';

  void record(WidgetTester tester) {
    final t = truncatedTexts(tester);
    if (t.isNotEmpty) hits.putIfAbsent(screen, () => {}).addAll(t);
  }

  /// Records the screen, then scrolls each vertical scrollable to its end,
  /// recording at every step so lazily built content is also checked.
  Future<void> sweep(WidgetTester tester) async {
    record(tester);
    final scrollables = find.byType(Scrollable).evaluate().toList();
    for (final el in scrollables) {
      if (!el.mounted) continue;
      final state = (el as StatefulElement).state as ScrollableState;
      if (state.axisDirection != AxisDirection.down) continue;
      final pos = state.position;
      if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) continue;
      for (var i = 0; i < 80 && pos.pixels < pos.maxScrollExtent; i++) {
        pos.jumpTo((pos.pixels + pos.viewportDimension * 0.7)
            .clamp(0, pos.maxScrollExtent));
        await tester.pump(const Duration(milliseconds: 50));
        record(tester);
      }
      pos.jumpTo(0);
      await tester.pump();
    }
  }

  String report(String title) {
    final b = StringBuffer('== $title ==\n');
    for (final s in {...hits.keys, ...overflows.keys}) {
      b.writeln('-- $s');
      for (final t in hits[s] ?? const <String>{}) {
        b.writeln('   TRUNC  $t');
      }
      for (final t in overflows[s] ?? const <String>{}) {
        b.writeln('   OVERFL $t');
      }
    }
    return b.toString();
  }
}

/// pumpAndSettle that tolerates endless animations (spinners, pulses).
Future<void> settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  } catch (_) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

Future<void> dismissDialogs(WidgetTester tester) async {
  for (final label in ['Got it', 'OK', 'Close']) {
    final f = find.widgetWithText(TextButton, label);
    final g = find.widgetWithText(FilledButton, label);
    if (f.evaluate().isNotEmpty) await tester.tap(f.first);
    if (g.evaluate().isNotEmpty) await tester.tap(g.first);
    await settle(tester);
  }
}

/// Answer for [q] that passes validation. [variant] 0 picks the first
/// option / "yes"; 1 picks the last option / "no", reaching other branches.
Object? sampleAnswer(ClinicalQuestion q, int variant, DateTime today) {
  final opts = q.options;
  switch (q.type) {
    case QuestionType.singleChoice:
      if (opts.isEmpty) return null;
      return (variant == 0 ? opts.first : opts.last).value;
    case QuestionType.multipleChoice:
      if (opts.isEmpty || variant == 1) return <Object>{};
      return {for (final o in opts.take(3)) o.value};
    case QuestionType.numeric:
      final lo = q.min ?? 0, hi = q.max ?? (lo + 100);
      return lo + ((hi - lo) * (variant == 0 ? 0.15 : 0.6)).round();
    case QuestionType.decimal:
      final lo = q.min ?? 0, hi = q.max ?? (lo + 100);
      return lo + (hi - lo) * (variant == 0 ? 0.15 : 0.6);
    case QuestionType.text:
      return 'Sample note';
    case QuestionType.date:
      return today.subtract(const Duration(days: 3));
    case QuestionType.boolean:
      return variant == 0;
  }
}

Future<void> runAudit(WidgetTester tester, Size size, String title,
    Future<void> Function(Audit audit, ProviderContainer c) body) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audit = Audit();
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final msg = d.exceptionAsString();
    if (msg.contains('overflowed')) {
      final where =
          RegExp(r'lib/[^\s:]+\.dart:\d+').firstMatch(d.toString())?.group(0);
      audit.overflows
          .putIfAbsent(audit.screen, () => {})
          .add('${msg.split('\n').first} ($where)');
    } else {
      original?.call(d);
    }
  };
  try {
    await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
    await tester.pumpAndSettle();
    await dismissDialogs(tester);
    final c =
        ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
    await body(audit, c);
  } finally {
    FlutterError.onError = original;
  }
  expect(audit.hits.isEmpty && audit.overflows.isEmpty, isTrue,
      reason: audit
          .report('$title @ ${size.width.toInt()}x${size.height.toInt()}'));
}

Future<void> visit(WidgetTester tester, Audit audit, String label) async {
  await settle(tester);
  audit.screen = label;
  await audit.sweep(tester);
}

/// Runs the dynamic assessment for [selected], auditing every page and the
/// summary.
Future<void> auditAssessment(WidgetTester tester, Audit audit,
    ProviderContainer c, Set<NeonatalCondition> selected, int variant) async {
  final n = c.read(assessmentProvider.notifier);
  final engine = c.read(assessmentEngineProvider);
  final today = c.read(assessmentTodayProvider);
  routerOf(tester).go('/home');
  await settle(tester);
  n.start(selected, forceReset: true);
  routerOf(tester).push('/workflow');
  final name = selected.map((e) => e.name).join('+');
  for (var page = 0; page < 25; page++) {
    final st = c.read(assessmentProvider);
    final group = st.currentGroup;
    if (group == null) break;
    for (final rq in engine.pageQuestions(st.context, group)) {
      final q = rq.question;
      if (c.read(assessmentProvider).context.answers.containsKey(q.variable)) {
        continue;
      }
      n.answer(q.id, sampleAnswer(q, variant, today));
    }
    await visit(tester, audit, 'workflow $name v$variant page "$group"');
    n.confirmPage();
    if (c.read(assessmentProvider).currentGroup == group) break;
  }
  await visit(tester, audit, 'workflow $name v$variant SUMMARY');
}

void main() {
  setUpAll(loadAppFonts);

  final sizes = [
    const Size(320, 640),
    const Size(360, 780),
    const Size(412, 915),
  ];

  for (final size in sizes) {
    final w = size.width.toInt();
    testWidgets('route screens at $w', (tester) async {
      await runAudit(tester, size, 'routes', (audit, c) async {
        routerOf(tester).go('/');
        await visit(tester, audit, 'landing /');
        final routes = [
          '/home',
          '/disease-selection',
          '/next-stw',
          '/stw-map',
          '/assessment-map',
          '/references',
          '/about',
          '/chat',
          '/rd',
          '/rop',
          '/rop/reference',
          for (final cond in NeonatalCondition.values)
            '/stw-reference/${cond.name}',
        ];
        for (final r in routes) {
          routerOf(tester).go(r);
          await settle(tester);
          await dismissDialogs(tester);
          await visit(tester, audit, r);
        }
        // Home disclaimer dialog.
        routerOf(tester).go('/home');
        await settle(tester);
        final disclaimer = find.text('Disclaimer');
        if (disclaimer.evaluate().isNotEmpty) {
          await tester.ensureVisible(disclaimer.first);
          await tester.tap(disclaimer.first);
          await visit(tester, audit, '/home disclaimer dialog');
        }
      });
    });

    testWidgets('assessment flows at $w', (tester) async {
      await runAudit(tester, size, 'assessments', (audit, c) async {
        final modules = [
          NeonatalCondition.triage,
          for (final d in stwModuleDefinitions)
            if (d.implemented && d.id != NeonatalCondition.triage) d.id,
        ];
        for (final m in modules) {
          for (final v in [0, 1]) {
            await auditAssessment(tester, audit, c, {m}, v);
          }
        }
        // Post-Triage STW list and the selected-only list.
        await auditAssessment(tester, audit, c, {NeonatalCondition.triage}, 0);
        routerOf(tester).go('/next-stw');
        await visit(tester, audit, '/next-stw after Triage');
        routerOf(tester).go('/selected-stws', extra: {
          for (final d in stwModuleDefinitions)
            if (d.implemented && d.id != NeonatalCondition.triage) d.id,
        });
        await visit(tester, audit, '/selected-stws (all)');
      });
    });

    testWidgets('follow-up assessments at $w', (tester) async {
      await runAudit(tester, size, 'follow-up', (audit, c) async {
        for (final cond in diseaseFollowUpRegistry.keys) {
          final n = c.read(followUpProvider.notifier);
          n.initForCondition(cond);
          routerOf(tester).go('/follow-up-assessment');
          await visit(tester, audit, 'follow-up ${cond.name} intro');
          n.startAssessment();
          final mcqs = c.read(followUpProvider).mcqs;
          for (var i = 0; i < mcqs.length; i++) {
            n.goToMcq(i);
            // Alternate right/wrong answers so both feedback styles render.
            n.selectMcqOption(i.isEven
                ? mcqs[i].correctAnswerIndex
                : (mcqs[i].correctAnswerIndex + 1) % mcqs[i].options.length);
            await visit(tester, audit, 'follow-up ${cond.name} MCQ ${i + 1}');
          }
          n.submitMcqs();
          await visit(tester, audit, 'follow-up ${cond.name} MCQ result');
          n.proceedToCaseScenarios();
          final cases = c.read(followUpProvider).caseScenarios;
          for (var i = 0; i < cases.length; i++) {
            n.goToCase(i);
            n.selectCaseOption(i.isEven
                ? cases[i].correctAnswerIndex
                : (cases[i].correctAnswerIndex + 1) % cases[i].options.length);
            await visit(tester, audit, 'follow-up ${cond.name} case ${i + 1}');
          }
          n.submitCaseScenarios();
          await visit(tester, audit, 'follow-up ${cond.name} final summary');
          n.reset();
        }
      });
    });

    testWidgets('chatbot answers at $w', (tester) async {
      await runAudit(tester, size, 'chat', (audit, c) async {
        routerOf(tester).go('/chat');
        await settle(tester);
        for (final q in [
          'Initial CPAP pressure in preterm ≤34 weeks',
          'What are the red flags for neonatal sepsis?',
          'How should the baby be positioned for KMC?',
          'What is the starting feed volume for a 1200 g baby?',
          'Post asphyxia Sarnat staging',
        ]) {
          await tester.enterText(find.byType(TextField).last, q);
          await tester.testTextInput.receiveAction(TextInputAction.send);
          await visit(tester, audit, 'chat: $q');
        }
      });
    });
  }
}
