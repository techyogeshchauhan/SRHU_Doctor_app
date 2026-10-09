import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

void main() {
  test('all 14 conditions exist, each with one definition', () {
    expect(NeonatalCondition.values, hasLength(14));
    expect(conditionDefinitions, hasLength(14));
    expect(
      conditionDefinitions.map((d) => d.id).toList(),
      NeonatalCondition.values,
    );
  });

  test('ids are unique', () {
    final ids = conditionDefinitions.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('display names are exact and in order', () {
    expect(conditionDefinitions.map((d) => d.title).toList(), [
      'STW Triage',
      'STW Thermal Care',
      'STW KMC',
      'STW Fluids & Feeds',
      'STW Respiratory Distress',
      'STW ANCS',
      'STW Sepsis',
      'STW Hypoglycemia',
      'STW Jaundice',
      'STW Seizures',
      'STW HIE',
      'STW Transport',
      'STW ROP',
      'STW Discharge & Follow up',
    ]);
  });

  test('RD, ANCS, Hypoglycemia and ROP are implemented; others carry no description', () {
    final implemented = {
      for (final d in conditionDefinitions)
        if (d.implemented) d.id,
    };
    expect(implemented, {
      NeonatalCondition.respiratoryDistress,
      NeonatalCondition.ancs,
      NeonatalCondition.hypoglycemia,
      NeonatalCondition.rop,
    });
    for (final d in conditionDefinitions) {
      if (!d.implemented) {
        expect(d.description, isNull, reason: d.title);
        expect(d.status, ConditionStatus.comingSoon);
      }
    }
  });

  test('definitionOf looks up by id', () {
    expect(definitionOf(NeonatalCondition.hie).title, 'STW HIE');
  });
}
