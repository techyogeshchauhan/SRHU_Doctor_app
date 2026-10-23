import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

void main() {
  test('all 14 conditions exist, each with one definition', () {
    expect(NeonatalCondition.values, hasLength(14));
    expect(conditionDefinitions, hasLength(14));
    expect(
      conditionDefinitions.map((d) => d.id).toList(),
      unorderedEquals(NeonatalCondition.values),
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
      'STW Fluids & Feeds',
      'STW Hypoglycemia',
      'STW Respiratory Distress',
      'STW Post Asphyxia',
      'STW Sepsis',
      'STW Jaundice',
      'STW Seizures',
      'STW KMC',
      'STW ANCS',
      'STW ROP',
      'STW Transport',
      'STW Discharge & Follow up',
    ]);
  });

  test(
      'the nine supplied workflows are implemented; others carry no description',
      () {
    final implemented = {
      for (final d in conditionDefinitions)
        if (d.implemented) d.id,
    };
    expect(implemented, {
      NeonatalCondition.fluidsAndFeeds,
      NeonatalCondition.triage,
      NeonatalCondition.kmc,
      NeonatalCondition.respiratoryDistress,
      NeonatalCondition.ancs,
      NeonatalCondition.hypoglycemia,
      NeonatalCondition.sepsis,
      NeonatalCondition.rop,
      NeonatalCondition.hie,
    });
    for (final d in conditionDefinitions) {
      if (!d.implemented) {
        expect(d.description, isNull, reason: d.title);
        expect(d.status, ConditionStatus.comingSoon);
      }
    }
  });

  test('definitionOf looks up by id', () {
    expect(definitionOf(NeonatalCondition.hie).title, 'STW Post Asphyxia');
  });
}
