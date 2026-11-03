import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/app.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

import 'mobile_text_truncation_test.dart' show loadAppFonts;
import 'test_helpers.dart';

/// Gestation is laid out with the real app fonts: the wide test font would
/// wrap options that fit on a device.
void main() {
  setUpAll(loadAppFonts);

  for (final size in const [
    Size(320, 640),
    Size(360, 640),
    Size(412, 915),
    Size(800, 1280),
    Size(1280, 800),
  ]) {
    testWidgets(
        'Gestation: compact radio buttons beside the label '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Continue'));

      final gestation = find.byKey(const ValueKey(triageGestationKey));
      await tester.ensureVisible(gestation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final weight =
          tester.getRect(find.byKey(const ValueKey(triageWeightKey)));
      final rect = tester.getRect(gestation);
      expect(rect.top, greaterThan(weight.bottom));

      Rect textRect(String t) => tester
          .getRect(find.descendant(of: gestation, matching: find.text(t)));
      final label = textRect('Gestation');
      final term = textRect('Term (T)');
      final preterm = textRect('Preterm (PT)');
      // Term sits beside the label, not on a line below it.
      expect(term.left, greaterThan(label.right));
      expect(term.top, lessThan(label.bottom));
      if (size.width >= 412) {
        // Typical phones and up: everything on one line.
        expect(preterm.center.dy, closeTo(term.center.dy, 2));
        expect(rect.height, lessThan(50));
      } else {
        // Narrow phones: Preterm wraps under Term, still two short lines.
        expect(preterm.top, greaterThanOrEqualTo(term.top));
        expect(rect.height, lessThan(90));
      }

      await tapVisible(tester, find.text('Preterm (PT)'));
      final answers = ProviderScope.containerOf(tester.element(gestation))
          .read(assessmentProvider)
          .context
          .answers;
      expect(answers[triageGestationKey], triagePreterm);
      await tapVisible(tester, find.text('Term (T)'));
      expect(
          ProviderScope.containerOf(tester.element(gestation))
              .read(assessmentProvider)
              .context
              .answers[triageGestationKey],
          triageTerm);
    });
  }

  for (final size in const [Size(320, 640), Size(360, 640), Size(412, 915)]) {
    testWidgets(
        'history and examination lay out without overflow '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(child: NeonatalStwApp()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Continue'));

      for (final id in const [
        triageMaternalRisksKey,
        triageRhStatusKey,
        triageAntenatalSteroidsKey,
        triageNewbornRisksKey,
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(id)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: id);
      }
      await tapVisible(tester, find.text('Negative'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
      expect(find.text('Examination: Look / Listen / Feel'), findsOneWidget);
      for (final q in triageExaminationQuestions) {
        await tester.ensureVisible(find.byKey(ValueKey(q.id)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: q.id);
      }
      // Compact radios: the options start on the label's line.
      final tone = find.byKey(const ValueKey(triageToneKey));
      final label = tester.getRect(
          find.descendant(of: tone, matching: find.text('Muscle tone')));
      final normal = tester
          .getRect(find.descendant(of: tone, matching: find.text('Normal')));
      expect(normal.left, greaterThan(label.right));
      expect(normal.top, lessThan(label.bottom));
      await tapVisible(tester, find.text('Hypotonia'));
      expect(
          ProviderScope.containerOf(tester.element(tone))
              .read(assessmentProvider)
              .context
              .answers[triageToneKey],
          'hypotonia');
    });
  }
}
