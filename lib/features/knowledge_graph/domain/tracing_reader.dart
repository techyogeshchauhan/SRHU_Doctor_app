/// A [VariableReader] that records what it was asked. Pure Dart.
library;

import '../../clinical_workflow/domain/condition_expr.dart';

/// Wraps [inner] and records every variable key and finding id read through
/// it. Used to find the inputs of `ClinicalVariable.compute` and
/// `ClinicalRule.then`, which are closures and cannot be read statically.
class TracingReader implements VariableReader {
  TracingReader(this.inner);

  final VariableReader inner;
  final keys = <String>{};
  final findings = <String>{};

  @override
  Object? valueOf(String key) {
    keys.add(key);
    return inner.valueOf(key);
  }

  @override
  bool hasFinding(String id) {
    findings.add(id);
    return inner.hasFinding(id);
  }

  /// Runs [f] against a fresh tracer over [inner]; returns the keys read.
  /// Errors thrown by [f] are ignored (the keys read so far still count).
  static ({Set<String> keys, Set<String> findings}) trace(
    VariableReader inner,
    void Function(VariableReader r) f,
  ) {
    final t = TracingReader(inner);
    try {
      f(t);
    } catch (_) {
      // A computation may assume values the replay does not have; what it
      // read before failing is still a dependency.
    }
    return (keys: t.keys, findings: t.findings);
  }
}
