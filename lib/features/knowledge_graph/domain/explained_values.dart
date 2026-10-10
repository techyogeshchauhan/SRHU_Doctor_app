/// Computed values shown as their own step in the reasoning tree. Pure Dart.
///
/// Only values whose meaning is printed in an STW box are listed, each with
/// that box as its source. Every other computed value is engine-internal:
/// the tree skips it and shows the answers it was computed from instead.
/// Labels are short names of the STW wording; no new clinical content.
library;

import '../../ancs/domain/ancs_workflow.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../rd/domain/sas.dart';
import '../../rop/domain/rop_workflow.dart';

class ExplainedValue {
  const ExplainedValue(this.label, this.source, {this.display, this.inputs});

  final String label;
  final SourceReference source;

  /// The answers that decide the value, where the engine reads more than
  /// it uses (null: everything the computation reads).
  final Set<String> Function(VariableReader r)? inputs;

  /// Text of an engine value that has no plain form (e.g. the SAS score
  /// object → its total); null uses the default formatting.
  final String? Function(Object value)? display;
}

/// "GA ≤34 weeks" / "GA >34 weeks", as printed in the RD ALGORITHM box,
/// from the validated `Gestation.band` (with the BW surrogate noted).
String? _gestationGroup(Object v) {
  if (v is! Gestation) return null;
  final band = switch (v.band) {
    GaBand.upTo34 => 'GA ≤34 weeks',
    GaBand.above34 => 'GA >34 weeks',
    null => null,
  };
  if (band == null) return null;
  return v.usesBwSurrogate ? '$band (BW ≤1800 g surrogate)' : band;
}

/// GA decides the group when known; birth weight only when GA is uncertain
/// (RD ALGORITHM box: "If GA is uncertain, BW ≤1800 g may be used as an
/// operational surrogate"), as in `Gestation.band`.
Set<String> _gestationInputs(VariableReader r) => r.valueOf(gaKnownKey) == false
    ? {gaKnownKey, birthWeightKey}
    : {gaKnownKey, gaWeeksKey};

/// RD signs by their STW wording (e.g. "Chest retractions").
String? _rdSigns(Object v) {
  String label(Object s) => RdSign.values.asNameMap()[s]?.label ?? '$s';
  return switch (v) {
    final Iterable<Object?> i =>
      i.isEmpty ? 'None' : i.whereType<Object>().map(label).join(', '),
    final Object s => label(s),
  };
}

String? _sasTotal(Object v) =>
    v is SasScore && v.isComplete ? '${v.total}' : null;

const Map<String, ExplainedValue> explainedValues = {
  rdSignsEffectiveKey: ExplainedValue(
    'Signs of respiratory distress present',
    SourceReference.rd('§1.1 Definition: RD present if ANY ONE'),
    display: _rdSigns,
  ),
  rdGestationKey: ExplainedValue(
    'Gestation group',
    SourceReference.rd('§1.5 Algorithm: GA ≤34 / >34 weeks'),
    display: _gestationGroup,
    inputs: _gestationInputs,
  ),
  rdSasScoreKey: ExplainedValue(
    'SAS total',
    SourceReference.rd(
        '§1.4 Silverman-Andersen Score (Avery & Fletcher, 1974)'),
    display: _sasTotal,
  ),
  rdReSasScoreKey: ExplainedValue(
    'Repeat SAS total',
    SourceReference.rd('§1.5 Reassess: clinical status, SAS, SpO₂'),
    display: _sasTotal,
  ),
  rdSeverityKey: ExplainedValue(
    'Severity by SAS',
    SourceReference.rd(
        '§1.4 Silverman-Andersen Score (Avery & Fletcher, 1974)'),
  ),
  ropEligibleKey: ExplainedValue(
    'Eligible for ROP screening',
    SourceReference.rop('§2.1 Whom to screen'),
  ),
  ropFirstScreenStatusKey: ExplainedValue(
    'First ROP screen',
    SourceReference.rop('§2.2 When to screen'),
  ),
  ropPmaWeeksKey: ExplainedValue(
    'Postmenstrual age (PMA, weeks)',
    SourceReference.rop('§2.8 After anti-VEGF: until 65 weeks PMA'),
  ),
  hypoAtRiskKey: ExplainedValue(
    'At-risk infant (WHOM TO SCREEN)',
    SourceReference.hypo(
      'WHOM TO SCREEN FOR HYPOGLYCEMIA',
      regionId: 'hypo_whom_to_screen',
    ),
  ),
  hypoNextGirKey: ExplainedValue(
    'Next GIR (increase by 2, maximum 12 mg/kg/min)',
    SourceReference.hypo(
      'Flowchart: BG < 45 mg/dL → increase GIR',
      regionId: 'hypo_increase_gir',
    ),
  ),
  ancsInWindowKey: ExplainedValue(
    'GA 24+0 to 33+6 weeks',
    SourceReference.ancs('WHEN TO GIVE', regionId: 'ancs_when_to_give'),
  ),
  ancsLikelyKey: ExplainedValue(
    'High likelihood of preterm birth within the next 7 days',
    SourceReference.ancs('WHEN TO GIVE', regionId: 'ancs_when_to_give'),
  ),
};
