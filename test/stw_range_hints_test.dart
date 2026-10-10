import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/core/widgets/inputs.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';

/// The value-range hints under the ANCS and Hypoglycemia inputs quote the
/// STW PDFs: every number, with its sign and unit, must occur in the
/// verbatim text of the STW box it comes from.
void main() {
  // Question id -> STW boxes (assets/regions/regions.json) the hint quotes.
  const sourcesOf = <String, List<String>>{
    ancsGaWeeksKey: ['ancs_when_to_give'],
    ancsDaysSincePreviousKey: ['ancs_repeat_course'],
    hypoBgKey: [
      'hypo_flowchart_entry',
      'hypo_symptomatic_branch',
      'hypo_asymptomatic_branch',
    ],
    hypoRecheckBgKey: ['hypo_recheck_1h'],
    hypoGirKey: [
      'hypo_symptomatic_branch',
      'hypo_increase_gir',
      'hypo_stop_iv',
    ],
    hypoIvBgKey: ['hypo_recheck_30min', 'hypo_increase_gir'],
  };

  // Numeric inputs for which the PDFs give no range (no hint shown):
  // weight is only used with the per-kg bolus; "+ days" belongs to the
  // gestational-age window shown under the weeks field.
  const noRangeInPdf = {hypoWeightKey, ancsGaDaysKey};

  final regions = {
    for (final r
        in jsonDecode(File('assets/regions/regions.json').readAsStringSync())
            as List)
      (r as Map)['id'] as String: r['text'] as String,
  };

  /// Comparable form: lower case, one space, no space after a slash
  /// ("mg/ kg/min") or between a sign and its number ("≥ 45").
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'/ '), '/')
      .replaceAllMapped(RegExp(r'([<>≥≤]) (\d)'), (m) => '${m[1]}${m[2]}');

  final valueToken =
      RegExp(r'[<>≥≤]?\d+(?:\+\d+)?(?: (?:mg/dl|mg/kg/min|weeks|days))?');

  final numeric = [
    for (final w in [ancsWorkflow, hypoWorkflow])
      for (final u in w.uses)
        if (u.question.type == QuestionType.numeric) u.question,
  ];

  test('every numeric ANCS / Hypoglycemia input has a PDF hint or none', () {
    for (final q in numeric) {
      if (noRangeInPdf.contains(q.id)) {
        expect(q.stwRange, isNull, reason: '${q.id}: PDF gives no range');
      } else {
        expect(q.stwRange, isNotNull, reason: '${q.id}: hint missing');
        expect(sourcesOf.keys, contains(q.id));
      }
    }
  });

  for (final MapEntry(key: id, value: boxes) in sourcesOf.entries) {
    test('$id: every value in the hint is in the STW text', () {
      final q = numeric.firstWhere((q) => q.id == id);
      final hint = norm(q.stwRange!);
      expect(hint, startsWith('stw: '));
      final pdf = norm(boxes.map((b) => regions[b]!).join(' '));
      final values = valueToken.allMatches(hint).map((m) => m[0]!).toList();
      expect(values, isNotEmpty);
      for (final v in values) {
        expect(pdf, contains(v), reason: '"$v" not in ${boxes.join(', ')}');
      }
    });
  }

  testWidgets('the hint is shown under the number field', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NumberField(
          label: 'Blood glucose (BG)',
          value: null,
          min: 0,
          max: 600,
          suffix: 'mg/dL',
          rangeHint: qHypoBg.stwRange,
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text(qHypoBg.stwRange!), findsOneWidget);
    final field = tester.getRect(find.byType(TextField));
    final hint = tester.getRect(find.text(qHypoBg.stwRange!));
    expect(hint.top, greaterThan(field.bottom - 1));
  });
}
