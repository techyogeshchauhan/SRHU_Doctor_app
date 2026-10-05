import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/neonatal_condition.dart';

/// Conditions ticked on the selection screen. In memory only.
class ConditionSelectionController extends Notifier<Set<NeonatalCondition>> {
  @override
  Set<NeonatalCondition> build() => const {};

  void add(NeonatalCondition c) => state = {...state, c};
  void remove(NeonatalCondition c) => state = {...state}..remove(c);
  void toggle(NeonatalCondition c) => isSelected(c) ? remove(c) : add(c);
  void clear() => state = const {};
  bool isSelected(NeonatalCondition c) => state.contains(c);
}

final conditionSelectionProvider =
    NotifierProvider<ConditionSelectionController, Set<NeonatalCondition>>(
  ConditionSelectionController.new,
);
