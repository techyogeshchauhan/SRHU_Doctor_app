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
  ConditionDefinition(id: NeonatalCondition.triage, title: 'STW Triage'),
  ConditionDefinition(
      id: NeonatalCondition.thermalCare, title: 'STW Thermal Care'),
  ConditionDefinition(id: NeonatalCondition.kmc, title: 'STW KMC'),
  ConditionDefinition(
      id: NeonatalCondition.fluidsAndFeeds, title: 'STW Fluids & Feeds'),
  ConditionDefinition(
    id: NeonatalCondition.respiratoryDistress,
    title: 'STW Respiratory Distress',
    description: 'Assessment and management workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(id: NeonatalCondition.ancs, title: 'STW ANCS'),
  ConditionDefinition(id: NeonatalCondition.sepsis, title: 'STW Sepsis'),
  ConditionDefinition(
      id: NeonatalCondition.hypoglycemia, title: 'STW Hypoglycemia'),
  ConditionDefinition(id: NeonatalCondition.jaundice, title: 'STW Jaundice'),
  ConditionDefinition(id: NeonatalCondition.seizures, title: 'STW Seizures'),
  ConditionDefinition(id: NeonatalCondition.hie, title: 'STW HIE'),
  ConditionDefinition(id: NeonatalCondition.transport, title: 'STW Transport'),
  ConditionDefinition(
    id: NeonatalCondition.rop,
    title: 'STW ROP',
    description: 'Screening and follow-up workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.dischargeAndFollowUp,
    title: 'STW Discharge & Follow up',
  ),
];

final Map<NeonatalCondition, ConditionDefinition> _byId = {
  for (final d in conditionDefinitions) d.id: d,
};

ConditionDefinition definitionOf(NeonatalCondition c) => _byId[c]!;
