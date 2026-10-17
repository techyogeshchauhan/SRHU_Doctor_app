/// Structured record of a Triage decision for the research dataset. Pure
/// Dart.
///
/// Holds the inputs, the computed classification and why, the flagged
/// treatment cards with their STW links, and the doses shown. Free-text
/// history is never included, only whether it was provided.
library;

import '../../clinical_workflow/domain/condition_expr.dart';
import 'triage_treatment.dart';
import 'triage_workflow.dart';

List<String> _list(Object? v) => v is List ? [for (final x in v) '$x'] : [];

bool _provided(Object? v) => v is String && v.trim().isNotEmpty;

/// `EMERGENCY`, `PRIORITY` or `NO_SIGNS`.
String triageCategoryCode(VariableReader r) =>
    switch (r.valueOf(triageCategoryKey)) {
      triageEmergency => 'EMERGENCY',
      triagePriority => 'PRIORITY',
      _ => 'NO_SIGNS',
    };

/// Classification, triggers, flags and recorded values, without the cards.
/// Also sent as the chatbot context.
Map<String, Object?> triageClinicalState(VariableReader r) {
  final signs = r.valueOf(triageEmergencySignsKey);
  return {
    'category': triageCategoryCode(r),
    'triggers': triageReasonsFor(r),
    'emergencyTriggers': _list(r.valueOf(triageEmergencyTriggersKey)),
    'priorityReasons': _list(r.valueOf(triagePriorityReasonsKey)),
    'flags': {
      'shock': r.valueOf(triageShockKey) == true,
      'hypoglycemia': r.valueOf(triageHypoglycemiaKey) == true,
      'respiratoryEmergency': r.valueOf(triageRespiratoryEmergencyKey) == true,
      'ivDextroseIndicated': triageIvDextroseIndicated(r),
    },
    'vitals': {
      'temperatureC': r.valueOf(triageTemperatureKey),
      'heartRate': r.valueOf(triageHeartRateKey),
      'spo2': r.valueOf(triageSpo2Key),
      'rbs': r.valueOf(triageBloodGlucoseKey),
      'symptomatic': r.valueOf(triageHypoglycemiaSymptomsKey),
      'emergencySigns': signs is Set ? ([for (final s in signs) '$s']..sort()) : [],
    },
  };
}

/// Full decision snapshot recorded when the Triage results are shown.
Map<String, Object?> triageDecisionRecord(VariableReader r) {
  final weight = r.valueOf(triageWeightKey);
  final cards = triageTreatmentCards(r);
  final flagged = cards.where((c) => c.flagged).toList();
  return {
    ...triageClinicalState(r),
    'baseline': {
      'fastTrack': r.valueOf(triageFastTrackKey) == true,
      'gestation': r.valueOf(triageGestationKey),
      'weightG': weight,
      'maternalHistoryProvided': _provided(r.valueOf(triageMaternalHistoryKey)),
      'newbornHistoryProvided': _provided(r.valueOf(triageNewbornHistoryKey)),
    },
    'flaggedCards': [
      for (final c in flagged)
        {'id': c.id, 'title': c.title, 'because': c.flaggedBecause},
    ],
    'computedDoses': [
      if (weight is num && r.valueOf(triageShockKey) == true)
        {
          'card': 'shock',
          'drug': 'Normal saline',
          'mlPerKg': 10,
          'weightG': weight,
          'volumeMl': weight * 10 / 1000,
          'rate': triageShockRateText(r),
        },
      if (weight is num && triageIvDextroseIndicated(r))
        {
          'card': 'hypoglycemia',
          'drug': '10% dextrose',
          'mlPerKg': 2,
          'weightG': weight,
          'volumeMl': weight * 2 / 1000,
          'followedBy': 'infusion at 6 mg/kg/min',
        },
    ],
    'stwLinks': [
      for (final c in flagged)
        for (final l in c.links)
          {'card': c.id, 'stw': l.stw.name, 'regionId': l.regionId},
    ],
  };
}
