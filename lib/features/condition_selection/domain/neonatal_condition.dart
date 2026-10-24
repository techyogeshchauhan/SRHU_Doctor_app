/// The 14 neonatal conditions / care areas offered on the selection screen.
///
/// Pure Dart, no Flutter imports. These are clinical topics (not all are
/// diseases). Only topics whose approved STW is bundled with the app are
/// [ConditionStatus.available]; the rest are listed so the clinician can see
/// them, but carry no clinical content until their STW is added.
library;

/// Stable workflow evaluation order. Display order is [conditionDefinitions].
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
  ConditionDefinition(
    id: NeonatalCondition.triage,
    title: 'STW Triage',
    description:
        'Emergency triage assessment and management workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
      id: NeonatalCondition.thermalCare, title: 'STW Thermal Care'),
  ConditionDefinition(
    id: NeonatalCondition.fluidsAndFeeds,
    title: 'STW Fluids & Feeds',
    description:
        'Feeding and nutrition in neonates as per the October 2026 ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.hypoglycemia,
    title: 'STW Hypoglycemia',
    description: 'Screening and management workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.respiratoryDistress,
    title: 'STW Respiratory Distress',
    description: 'Assessment and management workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  // Keep the persisted HIE identifier and enum ordinal for record compatibility.
  ConditionDefinition(
      id: NeonatalCondition.hie,
      title: 'STW Post Asphyxia',
      description:
          'Post-asphyxial management of neonates as per the supplied ICMR/DHR STW.',
      status: ConditionStatus.available),
  ConditionDefinition(
    id: NeonatalCondition.sepsis,
    title: 'STW Sepsis',
    description:
        'Sepsis signs, risk factors, treatment and review as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.jaundice,
    title: 'STW Jaundice',
    description: 'Neonatal jaundice in infants ≥35 weeks as per the July 2020 '
        'ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(id: NeonatalCondition.seizures, title: 'STW Seizures'),
  ConditionDefinition(
    id: NeonatalCondition.kmc,
    title: 'STW KMC',
    description:
        'Kangaroo Mother Care eligibility and care workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.ancs,
    title: 'STW ANCS',
    description:
        'Antenatal corticosteroid eligibility workflow as per ICMR/DHR '
        'STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(
    id: NeonatalCondition.rop,
    title: 'STW ROP',
    description: 'Screening and follow-up workflow as per ICMR/DHR STW.',
    status: ConditionStatus.available,
  ),
  ConditionDefinition(id: NeonatalCondition.transport, title: 'STW Transport'),
  ConditionDefinition(
    id: NeonatalCondition.dischargeAndFollowUp,
    title: 'STW Discharge & Follow up',
  ),
];

final Map<NeonatalCondition, ConditionDefinition> _byId = {
  for (final d in conditionDefinitions) d.id: d,
};

/// Standard presentation order, independent of clinical evaluation order.
Iterable<NeonatalCondition> get conditionDisplayOrder =>
    conditionDefinitions.map((d) => d.id);

ConditionDefinition definitionOf(NeonatalCondition c) => _byId[c]!;

/// Topics offered as STW modules. Triage is not one: it is the first step
/// before the module list (Landing -> Triage -> modules) and is reopened from
/// its own entry point, not selected like a module.
final List<ConditionDefinition> stwModuleDefinitions = [
  for (final d in conditionDefinitions)
    if (d.id != NeonatalCondition.triage) d,
];

/// Count unique selectable STW modules, excluding Triage and topics whose
/// approved STW is still coming soon.
int get availableDiseaseCount => stwModuleDefinitions
    .where((d) => d.implemented)
    .map((d) => d.id)
    .toSet()
    .length;

int get listedConditionCount =>
    stwModuleDefinitions.map((d) => d.id).toSet().length;
