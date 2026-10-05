/// The 14 neonatal conditions / care areas offered on the selection screen.
///
/// Pure Dart, no Flutter imports. These are clinical topics (not all are
/// diseases). Only topics whose approved STW is bundled with the app are
/// [ConditionStatus.available]; the rest are listed so the clinician can see
/// them, but carry no clinical content until their STW is added.
library;

/// Enum order is the display order and the order workflows are combined in.
enum NeonatalCondition {
  triage,
  thermalCare,
  kmc,
  fluidsAndFeeds,
  respiratoryDistress,
  ancs,
  sepsis,
  hypoglycemia,
  jaundice,
  seizures,
  hie,
  transport,
  rop,
  dischargeAndFollowUp,
}

enum ConditionStatus {
  available('Available'),
  comingSoon('Coming soon');

  const ConditionStatus(this.label);
  final String label;
}

class ConditionDefinition {
  const ConditionDefinition({
    required this.id,
    required this.title,
    this.description,
    this.status = ConditionStatus.comingSoon,
  });

  final NeonatalCondition id;
  final String title;

  /// Only set where the wording is supported by a bundled STW.
  final String? description;
  final ConditionStatus status;

  bool get implemented => status == ConditionStatus.available;
}

/// Shown for any condition whose approved STW has not been added yet.
const pendingStwMessage =
    'Clinical workflow content requires the corresponding approved STW.';

const List<ConditionDefinition> conditionDefinitions = [
  ConditionDefinition(id: NeonatalCondition.triage, title: 'Triage'),
  ConditionDefinition(id: NeonatalCondition.thermalCare, title: 'Thermal Care'),
  ConditionDefinition(id: NeonatalCondition.kmc, title: 'KMC'),
  ConditionDefinition(
      id: NeonatalCondition.fluidsAndFeeds, title: 'Fluids & Feeds'),
  ConditionDefinition(
    id: NeonatalCondition.respiratoryDistress,
    title: 'Respiratory Distress',
    description: 'Assessment and management workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(id: NeonatalCondition.ancs, title: 'ANCS'),
  ConditionDefinition(id: NeonatalCondition.sepsis, title: 'Sepsis'),
  ConditionDefinition(
      id: NeonatalCondition.hypoglycemia, title: 'Hypoglycemia'),
  ConditionDefinition(id: NeonatalCondition.jaundice, title: 'Jaundice'),
  ConditionDefinition(id: NeonatalCondition.seizures, title: 'Seizures'),
  ConditionDefinition(id: NeonatalCondition.hie, title: 'HIE'),
  ConditionDefinition(id: NeonatalCondition.transport, title: 'Transport'),
  ConditionDefinition(
    id: NeonatalCondition.rop,
    title: 'ROP',
    description: 'Screening and follow-up workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.dischargeAndFollowUp,
    title: 'Discharge & Follow-up',
  ),
];

final Map<NeonatalCondition, ConditionDefinition> _byId = {
  for (final d in conditionDefinitions) d.id: d,
};

ConditionDefinition definitionOf(NeonatalCondition c) => _byId[c]!;
