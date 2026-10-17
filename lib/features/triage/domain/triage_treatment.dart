/// Emergency treatment cards shown after Triage: TABC plus the Shock,
/// Hypoglycemia and Respiratory distress protocols. Pure Dart.
///
/// Action text is from the STW boxes the cards link to; a card is flagged
/// when the recorded signs or measurements call for it.
library;

import '../../clinical_workflow/domain/condition_expr.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import 'triage_workflow.dart';

/// A box of a bundled STW PDF, opened highlighted.
class StwLink {
  const StwLink(this.stw, this.regionId, this.label);

  /// STW whose PDF holds the box.
  final NeonatalCondition stw;

  /// Id in `assets/regions/regions.json`.
  final String regionId;
  final String label;
}

/// One line of a protocol card; [applies] when it matches this neonate.
class ProtocolAction {
  const ProtocolAction(this.text, {this.applies = false});

  final String text;
  final bool applies;
}

class TriageProtocolCard {
  const TriageProtocolCard({
    required this.id,
    required this.title,
    required this.actions,
    required this.links,
    this.letter,
    this.flaggedBecause = const [],
  });

  final String id;

  /// T, A, B or C for the TABC cards; null for protocol cards.
  final String? letter;
  final String title;
  final List<ProtocolAction> actions;
  final List<StwLink> links;

  /// Signs or measurements that flag the card; empty when not flagged.
  final List<String> flaggedBecause;

  bool get flagged => flaggedBecause.isNotEmpty;
  bool get isTabc => letter != null;
}

const _triage = NeonatalCondition.triage;

const _linkEmergencyActions =
    StwLink(_triage, 'triage_emergency_actions', 'Triage STW: Treat immediately');
const _linkHypothermia =
    StwLink(_triage, 'triage_hypothermia', 'Triage STW: Hypothermia');
const _linkShock = StwLink(_triage, 'triage_shock', 'Triage STW: Shock');
const _linkHypoglycemia =
    StwLink(_triage, 'triage_hypoglycemia', 'Triage STW: Hypoglycemia');
const _linkRd = StwLink(NeonatalCondition.respiratoryDistress,
    'rd_immediate_actions', 'Respiratory Distress STW');

Set<String> _values(Object? v) =>
    v is Set ? {for (final x in v) x.toString()} : const {};

String _fmt(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// The cards for the current answers, TABC first.
List<TriageProtocolCard> triageTreatmentCards(VariableReader r) {
  final temperature = r.valueOf(triageTemperatureKey);
  final hr = r.valueOf(triageHeartRateKey);
  final spo2 = r.valueOf(triageSpo2Key);
  final bg = r.valueOf(triageBloodGlucoseKey);
  final weight = r.valueOf(triageWeightKey);
  final signs = _values(r.valueOf(triageEmergencySignsKey));
  final symptomatic = r.valueOf(triageHypoglycemiaSymptomsKey) == true;

  final cold = temperature is num && temperature < 36.5;
  final tachycardia = hr is num && hr > triageHeartRateEmergencyAbove;
  final lowSpo2 = spo2 is num && spo2 < triageSpo2EmergencyBelow;
  final apnea = signs.contains('apnea');
  final cyanosis = signs.contains('centralCyanosis');
  final distress = signs.contains('respiratoryDistress');
  final dehydration = signs.contains('severeDehydration');
  final shock = r.valueOf(triageShockKey) == true;
  final lowBg = bg is num && bg < triageRbsEmergencyBelow;
  final ivDextrose = triageIvDextroseIndicated(r);

  final shockSigns = [if (shock) 'Shock'];
  final tempText = temperature is num ? 'Temperature ${_fmt(temperature)}°C' : '';
  final hrText = hr is num ? 'HR ${_fmt(hr)}/min (>200/min)' : '';
  final spo2Text = spo2 is num ? 'SpO₂ ${_fmt(spo2)}% (<91%)' : '';

  return [
    TriageProtocolCard(
      id: 'temperature',
      letter: 'T',
      title: 'Temperature',
      flaggedBecause: [
        if (cold) tempText,
        if (tachycardia) '$hrText: check for hyperthermia',
      ],
      actions: [
        ProtocolAction(
          'Temperature <35.5°C: nurse under a radiant warmer in servo mode.',
          applies: temperature is num && temperature < 35.5,
        ),
        ProtocolAction(
          'Temperature 35.5–36.4°C and baby is well: warm environment, '
          'skin-to-skin contact; recheck in 30 min.',
          applies: temperature is num && temperature >= 35.5 && temperature < 36.5,
        ),
        const ProtocolAction(
          'If unwell or temperature fails to improve, nurse under a warmer.',
        ),
        ProtocolAction(
          'Persistent HR >200/min: check and correct hyperthermia.',
          applies: tachycardia,
        ),
      ],
      links: const [_linkHypothermia],
    ),
    TriageProtocolCard(
      id: 'airway',
      letter: 'A',
      title: 'Airway',
      flaggedBecause: [if (apnea) 'Apnea or gasping'],
      actions: [
        const ProtocolAction('Maintain TABC.'),
        ProtocolAction('Intubate if gasping or poor effort.', applies: apnea),
      ],
      links: const [_linkEmergencyActions],
    ),
    TriageProtocolCard(
      id: 'breathing',
      letter: 'B',
      title: 'Breathing',
      flaggedBecause: [
        if (lowSpo2) spo2Text,
        if (cyanosis) 'Central cyanosis',
        if (distress) 'Respiratory distress',
        if (apnea) 'Apnea or gasping',
      ],
      actions: [
        ProtocolAction(
          'Nasal prong O₂ if SpO₂ <91% (titrate to 91–95%).',
          applies: lowSpo2 || cyanosis,
        ),
        ProtocolAction('Nasal CPAP if respiratory distress.',
            applies: distress),
        ProtocolAction('Intubate if gasping or poor effort.', applies: apnea),
      ],
      links: const [_linkEmergencyActions, _linkRd],
    ),
    TriageProtocolCard(
      id: 'circulation',
      letter: 'C',
      title: 'Circulation',
      flaggedBecause: [
        ...shockSigns,
        if (tachycardia) hrText,
        if (dehydration) 'Severe dehydration',
      ],
      actions: [
        ProtocolAction('Start IV fluids as per weight and postnatal age.',
            applies: shock || dehydration),
        ProtocolAction('Manage shock, dehydration and seizures.',
            applies: shock || dehydration),
        ProtocolAction(
          'Persistent HR >200/min: check ECG for arrhythmia; refer for further '
          'management.',
          applies: tachycardia,
        ),
      ],
      links: const [_linkEmergencyActions, _linkShock],
    ),
    TriageProtocolCard(
      id: 'shock',
      title: 'Shock → Fluid bolus',
      flaggedBecause: shockSigns,
      actions: [
        ProtocolAction(
          'IV NS 10 mL/kg if volume expansion is indicated: preterm over '
          '30–60 min; term over 15–20 min.',
          applies: shock,
        ),
        if (triageShockRateText(r) case final rate?)
          ProtocolAction(rate, applies: shock),
        if (weight is num)
          ProtocolAction(triageNsBolusVolumeText(weight.round()),
              applies: shock),
        ProtocolAction('Consider inotropes early.', applies: shock),
      ],
      links: const [_linkShock],
    ),
    TriageProtocolCard(
      id: 'hypoglycemia',
      title: 'Hypoglycemia',
      flaggedBecause: [
        if (bg is num && lowBg) 'RBS ${_fmt(bg)} mg/dL (<45 mg/dL)',
        if (lowBg && symptomatic) 'Symptomatic',
      ],
      actions: [
        ProtocolAction(
          'Blood glucose <45 mg/dL and asymptomatic: supervised breastfeeding '
          'or EBM.',
          applies: lowBg && !ivDextrose,
        ),
        ProtocolAction(
          'Blood glucose <20 mg/dL OR symptomatic: 2 mL/kg 10% dextrose IV, '
          'followed by infusion at 6 mg/kg/min.',
          applies: ivDextrose,
        ),
        if (ivDextrose && weight is num)
          ProtocolAction(triageDextroseBolusVolumeText(weight.round()),
              applies: true),
      ],
      links: [
        _linkHypoglycemia,
        StwLink(
          NeonatalCondition.hypoglycemia,
          ivDextrose ? 'hypo_symptomatic_branch' : 'hypo_asymptomatic_branch',
          'STW Hypoglycemia Guidelines',
        ),
      ],
    ),
    TriageProtocolCard(
      id: 'respiratory',
      title: 'Respiratory distress',
      flaggedBecause: [
        if (apnea) 'Apnea or gasping',
        if (cyanosis) 'Central cyanosis',
        if (lowSpo2) spo2Text,
        if (distress) 'Respiratory distress',
      ],
      actions: [
        ProtocolAction(
          'Respiratory support: Nasal prong O₂ if SpO₂ <91% (titrate to '
          '91–95%); nasal CPAP if respiratory distress; intubate if gasping '
          'or poor effort.',
          applies: r.valueOf(triageRespiratoryEmergencyKey) == true,
        ),
      ],
      links: const [_linkRd, _linkEmergencyActions],
    ),
  ];
}
