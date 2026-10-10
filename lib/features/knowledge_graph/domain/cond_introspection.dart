/// Reads the structure of a [Cond] expression tree. Pure Dart.
library;

import '../../clinical_workflow/domain/condition_expr.dart';

extension CondIntrospection on Cond {
  /// Variable keys compared anywhere in the expression.
  Set<String> get variableKeys => {
        for (final c in leafComparisons) c.key,
      };

  /// Finding ids tested with [HasFinding] anywhere in the expression.
  Set<String> get findingIds => switch (this) {
        AllOf(:final parts) || AnyOf(:final parts) => {
            for (final p in parts) ...p.findingIds,
          },
        Not(:final inner) => inner.findingIds,
        HasFinding(:final id) => {id},
        Compare() => const {},
      };

  /// Every [Compare] leaf, in expression order.
  List<Compare> get leafComparisons => switch (this) {
        AllOf(:final parts) || AnyOf(:final parts) => [
            for (final p in parts) ...p.leafComparisons,
          ],
        Not(:final inner) => inner.leafComparisons,
        HasFinding() => const [],
        final Compare c => [c],
      };
}
