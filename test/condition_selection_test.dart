import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/condition_selection/state/condition_selection_controller.dart';

void main() {
  late ProviderContainer container;
  late ConditionSelectionController n;

  Set<NeonatalCondition> selection() =>
      container.read(conditionSelectionProvider);

  setUp(() {
    container = ProviderContainer();
    n = container.read(conditionSelectionProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('initial selection is empty', () {
    expect(selection(), isEmpty);
  });

  test('select one condition', () {
    n.add(NeonatalCondition.respiratoryDistress);
    expect(selection(), {NeonatalCondition.respiratoryDistress});
    expect(n.isSelected(NeonatalCondition.respiratoryDistress), isTrue);
    expect(n.isSelected(NeonatalCondition.rop), isFalse);
  });

  test('select multiple conditions', () {
    n
      ..add(NeonatalCondition.respiratoryDistress)
      ..toggle(NeonatalCondition.sepsis)
      ..toggle(NeonatalCondition.hypoglycemia);
    expect(selection(), {
      NeonatalCondition.respiratoryDistress,
      NeonatalCondition.sepsis,
      NeonatalCondition.hypoglycemia,
    });
  });

  test('unselect condition', () {
    n
      ..add(NeonatalCondition.respiratoryDistress)
      ..add(NeonatalCondition.rop)
      ..remove(NeonatalCondition.rop);
    expect(selection(), {NeonatalCondition.respiratoryDistress});
    n.toggle(NeonatalCondition.respiratoryDistress);
    expect(selection(), isEmpty);
  });

  test('clear selection', () {
    n
      ..add(NeonatalCondition.triage)
      ..add(NeonatalCondition.rop)
      ..clear();
    expect(selection(), isEmpty);
  });
}
