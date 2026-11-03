/// Structured clinical history and examination recorded during Triage, and
/// the STWs they suggest. Pure Dart.
///
/// The history is on the Triage page (hidden by "Baby is sick"); the
/// examination (LOOK / LISTEN / FEEL) is a second page. Neither changes the
/// triage category or any STW rule: findings only suggest STWs to consider
/// next and pre-fill matching answers there, which the clinician still
/// confirms. [triageSuggestionRules] is the table for clinical sign-off.
library;

import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/condition_expr.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_rules.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../jaundice/domain/jaundice_rules.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../post_asphyxia/domain/post_asphyxia_workflow.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import 'triage_workflow.dart';

/// Second Triage page.
const triageExaminationGroup = 'triage_examination';

const triageMaternalRisksKey = 'triage_maternal_risks';
const triageRhStatusKey = 'triage_rh_status';
const triageAntenatalSteroidsKey = 'triage_antenatal_steroids';
const triageNewbornRisksKey = 'triage_newborn_risks';
const triageExamLookKey = 'triage_exam_look';
const triageExamListenKey = 'triage_exam_listen';
const triageAirEntryKey = 'triage_air_entry';
const triageExamFeelKey = 'triage_exam_feel';
const triageFontanelleKey = 'triage_fontanelle';
const triageToneKey = 'triage_tone';

const _srcHistory = SourceReference.dataEntry('Clinical history (structured)');
const _srcExam = SourceReference.dataEntry('Neonatal examination');

const qTriageMaternalRisks = ClinicalQuestion(
  id: triageMaternalRisksKey,
  group: triageAssessmentGroup,
  question: 'Maternal history (tick any)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('prom18', 'PROM ≥18 hours'),
    QuestionOption('foulLiquor', 'Foul-smelling liquor'),
    QuestionOption(
        'congenitalAnomalies', 'Antenatally detected congenital anomalies'),
    QuestionOption('hypertension', 'Maternal hypertension / pre-eclampsia'),
    QuestionOption('gdm', 'Gestational diabetes mellitus'),
    QuestionOption('sle', 'Maternal SLE'),
  ],
  sources: [_srcHistory],
);

const qTriageRhStatus = ClinicalQuestion(
  id: triageRhStatusKey,
  group: triageAssessmentGroup,
  question: 'Maternal Rh status',
  type: QuestionType.singleChoice,
  inlineLabel: true,
  options: [
    QuestionOption('positive', 'Positive'),
    QuestionOption('negative', 'Negative'),
    QuestionOption('unknown', 'Unknown'),
  ],
  sources: [_srcHistory],
);

const qTriageAntenatalSteroids = ClinicalQuestion(
  id: triageAntenatalSteroidsKey,
  group: triageAssessmentGroup,
  question: 'Antenatal steroids',
  type: QuestionType.singleChoice,
  inlineLabel: true,
  options: [
    QuestionOption('complete', 'Complete'),
    QuestionOption('incomplete', 'Incomplete'),
    QuestionOption('notGiven', 'Not given'),
    QuestionOption('unknown', 'Unknown'),
  ],
  sources: [_srcHistory],
);

const qTriageNewbornRisks = ClinicalQuestion(
  id: triageNewbornRisksKey,
  group: triageAssessmentGroup,
  question: 'Newborn history (tick any)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('obstructedLabour', 'Obstructed labour'),
    QuestionOption('instrumentalDelivery', 'Instrumental delivery'),
    QuestionOption('delayedCry', 'Delayed cry'),
    QuestionOption(
        'prolongedResuscitation', 'Prolonged resuscitation at birth'),
    QuestionOption('lethargyPoorFeeding', 'Lethargy / poor feeding'),
    QuestionOption('abnormalMovements', 'Abnormal movements / seizures'),
    QuestionOption('apneaCyanosis', 'Apnea / cyanotic episodes'),
    QuestionOption('respiratoryDistress',
        'Respiratory distress (retractions, tachypnea)'),
    QuestionOption(
        'abdominal', 'Abdominal distension / bilious vomiting'),
    QuestionOption(
        'delayedMeconium', 'Delayed passage of meconium (>24 hours)'),
  ],
  sources: [_srcHistory],
);

const qTriageExamLook = ClinicalQuestion(
  id: triageExamLookKey,
  group: triageExaminationGroup,
  question: 'LOOK (tick any present)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('chestIndrawing', 'Chest indrawing'),
    QuestionOption('nasalFlaring', 'Nasal flaring'),
    QuestionOption('centralCyanosis', 'Central cyanosis'),
    QuestionOption('mottling', 'Mottling'),
    QuestionOption('severePallor', 'Severe pallor'),
    QuestionOption('jaundice', 'Jaundice'),
    QuestionOption('lethargy', 'Lethargy / unconsciousness'),
    QuestionOption('irritability', 'Irritability'),
    QuestionOption('seizureLike', 'Abnormal movements (seizure-like activity)'),
    QuestionOption('umbilical', 'Umbilical redness or discharge'),
    QuestionOption('pustules', 'Skin pustules'),
    QuestionOption(
      'dehydration',
      'Dehydration signs (depressed fontanelle, sunken eyes, delayed skin '
          'turgor, significant weight loss)',
    ),
    QuestionOption('sga', 'Small for gestational age (SGA)'),
    QuestionOption('lga', 'Large for gestational age (LGA)'),
  ],
  sources: [_srcExam],
);

const qTriageExamListen = ClinicalQuestion(
  id: triageExamListenKey,
  group: triageExaminationGroup,
  question: 'LISTEN (tick any present)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('grunting', 'Grunting'),
    QuestionOption('stridor', 'Stridor'),
    QuestionOption('abnormalBreathSounds', 'Abnormal breath sounds'),
  ],
  sources: [_srcExam],
);

const qTriageAirEntry = ClinicalQuestion(
  id: triageAirEntryKey,
  group: triageExaminationGroup,
  question: 'Air entry',
  type: QuestionType.singleChoice,
  inlineLabel: true,
  options: [
    QuestionOption('equal', 'Equal'),
    QuestionOption('unequal', 'Unequal'),
    QuestionOption('reduced', 'Reduced'),
  ],
  sources: [_srcExam],
);

const qTriageExamFeel = ClinicalQuestion(
  id: triageExamFeelKey,
  group: triageExaminationGroup,
  question: 'FEEL (tick any present)',
  type: QuestionType.multipleChoice,
  options: [
    QuestionOption('coolExtremities', 'Cool extremities'),
    QuestionOption('crtProlonged', 'Capillary refill time (CRT) >3 s'),
    QuestionOption('weakPeripheralPulses', 'Weak peripheral pulses'),
    QuestionOption('weakFemoralPulses', 'Weak or absent femoral pulses'),
    QuestionOption('radioFemoralDelay', 'Radio-femoral delay'),
    QuestionOption('abdominal', 'Abdominal distension / tenderness'),
  ],
  sources: [_srcExam],
);

const qTriageFontanelle = ClinicalQuestion(
  id: triageFontanelleKey,
  group: triageExaminationGroup,
  question: 'Anterior fontanelle',
  type: QuestionType.singleChoice,
  inlineLabel: true,
  options: [
    QuestionOption('normal', 'Normal'),
    QuestionOption('bulging', 'Bulging'),
    QuestionOption('sunken', 'Sunken'),
  ],
  sources: [_srcExam],
);

const qTriageTone = ClinicalQuestion(
  id: triageToneKey,
  group: triageExaminationGroup,
  question: 'Muscle tone',
  type: QuestionType.singleChoice,
  inlineLabel: true,
  options: [
    QuestionOption('normal', 'Normal'),
    QuestionOption('hypotonia', 'Hypotonia'),
    QuestionOption('hypertonia', 'Hypertonia'),
  ],
  sources: [_srcExam],
);

/// Examination page, in display order.
const triageExaminationQuestions = [
  qTriageExamLook,
  qTriageExamListen,
  qTriageAirEntry,
  qTriageExamFeel,
  qTriageFontanelle,
  qTriageTone,
];

/// A history or examination finding that suggests [stw], with the answers
/// it pre-fills there. A [Set] value is added to that STW's checklist;
/// anything else is the answer itself.
class StwSuggestionRule {
  const StwSuggestionRule(
    this.question,
    this.value,
    this.stw, {
    this.prefill = const {},
  });

  final ClinicalQuestion question;
  final Object value;
  final NeonatalCondition stw;
  final Map<String, Object> prefill;

  /// The finding as shown to the clinician, e.g. "Delayed cry" or
  /// "Maternal Rh status: Negative".
  String get reason {
    final label = question.options.firstWhere((o) => o.value == value).label;
    return question.type == QuestionType.singleChoice
        ? '${question.question}: $label'
        : label;
  }
}

const _sepsis = NeonatalCondition.sepsis;
const _rd = NeonatalCondition.respiratoryDistress;
const _hypo = NeonatalCondition.hypoglycemia;
const _jaundice = NeonatalCondition.jaundice;
const _hie = NeonatalCondition.hie;
const _seizures = NeonatalCondition.seizures;

const _m = qTriageMaternalRisks;
const _n = qTriageNewbornRisks;
const _look = qTriageExamLook;
const _listen = qTriageExamListen;
const _feel = qTriageExamFeel;

/// Draft mapping for clinical sign-off. Findings with no row (e.g. congenital
/// anomalies, severe pallor, delayed meconium) are recorded only: no
/// available STW covers them.
final triageSuggestionRules = <StwSuggestionRule>[
  // Maternal history.
  const StwSuggestionRule(_m, 'prom18', _sepsis),
  const StwSuggestionRule(_m, 'foulLiquor', _sepsis,
      prefill: {sepsisMaternalRedKey: true}),
  StwSuggestionRule(qTriageRhStatus, 'negative', _jaundice, prefill: {
    jaundiceRiskKey: {JaundiceRisk.bloodGroup.name},
  }),
  StwSuggestionRule(_m, 'gdm', _hypo, prefill: {
    hypoRiskKey: {HypoRisk.idm.name},
  }),
  // Newborn history.
  const StwSuggestionRule(_n, 'obstructedLabour', _hie),
  const StwSuggestionRule(_n, 'instrumentalDelivery', _hie),
  StwSuggestionRule(_n, 'delayedCry', _hie, prefill: {
    qPaRisk.variable: {'cry'},
  }),
  StwSuggestionRule(_n, 'prolongedResuscitation', _hie, prefill: {
    qPaRisk.variable: {'resuscitation'},
  }),
  const StwSuggestionRule(_n, 'lethargyPoorFeeding', _sepsis, prefill: {
    sepsisYellowKey: {'lethargy', 'refusal'},
  }),
  const StwSuggestionRule(_n, 'abnormalMovements', _seizures),
  const StwSuggestionRule(_n, 'abnormalMovements', _sepsis, prefill: {
    sepsisYellowKey: {'seizure'},
  }),
  const StwSuggestionRule(_n, 'apneaCyanosis', _sepsis, prefill: {
    sepsisYellowKey: {'apnea'},
  }),
  const StwSuggestionRule(_n, 'apneaCyanosis', _rd),
  const StwSuggestionRule(_n, 'respiratoryDistress', _rd),
  // Examination: LOOK.
  StwSuggestionRule(_look, 'chestIndrawing', _rd, prefill: {
    rdSignsKey: {RdSign.retractions.name},
  }),
  StwSuggestionRule(_look, 'nasalFlaring', _rd, prefill: {
    rdSignsKey: {RdSign.nasalFlaring.name},
  }),
  const StwSuggestionRule(_look, 'centralCyanosis', _rd),
  const StwSuggestionRule(_look, 'mottling', _sepsis),
  const StwSuggestionRule(_look, 'jaundice', _jaundice),
  const StwSuggestionRule(_look, 'lethargy', _sepsis, prefill: {
    sepsisYellowKey: {'lethargy'},
  }),
  const StwSuggestionRule(_look, 'lethargy', _hie),
  const StwSuggestionRule(_look, 'seizureLike', _seizures),
  const StwSuggestionRule(_look, 'seizureLike', _sepsis, prefill: {
    sepsisYellowKey: {'seizure'},
  }),
  const StwSuggestionRule(_look, 'umbilical', _sepsis),
  const StwSuggestionRule(_look, 'pustules', _sepsis),
  StwSuggestionRule(_look, 'sga', _hypo, prefill: {
    hypoRiskKey: {HypoRisk.sga.name},
  }),
  StwSuggestionRule(_look, 'lga', _hypo, prefill: {
    hypoRiskKey: {HypoRisk.lga.name},
  }),
  // LISTEN.
  StwSuggestionRule(_listen, 'grunting', _rd, prefill: {
    rdSignsKey: {RdSign.grunting.name},
  }),
  const StwSuggestionRule(_listen, 'stridor', _rd),
  const StwSuggestionRule(_listen, 'abnormalBreathSounds', _rd),
  const StwSuggestionRule(qTriageAirEntry, 'unequal', _rd),
  const StwSuggestionRule(qTriageAirEntry, 'reduced', _rd),
  // FEEL.
  const StwSuggestionRule(_feel, 'coolExtremities', _sepsis),
  const StwSuggestionRule(_feel, 'crtProlonged', _sepsis),
  const StwSuggestionRule(_feel, 'weakPeripheralPulses', _sepsis),
  const StwSuggestionRule(_feel, 'weakFemoralPulses', _sepsis),
  const StwSuggestionRule(qTriageFontanelle, 'bulging', _sepsis),
  const StwSuggestionRule(qTriageTone, 'hypotonia', _sepsis, prefill: {
    sepsisYellowKey: {'floppy'},
  }),
  const StwSuggestionRule(qTriageTone, 'hypotonia', _hie),
];

/// One suggested STW: why, and the answers to pre-fill when it is opened.
class StwSuggestion {
  const StwSuggestion(this.stw, this.reasons, this.prefill);

  final NeonatalCondition stw;
  final List<String> reasons;
  final Map<String, Object?> prefill;
}

bool _recorded(Object? answer, Object value) =>
    answer is Set ? answer.contains(value) : answer == value;

String _fmt(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// STWs suggested by the history, the examination and Triage RR ≥60/min /
/// the respiratory distress sign, in STW order.
List<StwSuggestion> triageStwSuggestions(VariableReader r) {
  final reasons = <NeonatalCondition, List<String>>{};
  final prefill = <NeonatalCondition, Map<String, Object?>>{};

  void suggest(NeonatalCondition stw, String reason,
      [Map<String, Object> answers = const {}]) {
    final why = reasons.putIfAbsent(stw, () => []);
    if (!why.contains(reason)) why.add(reason);
    final into = prefill.putIfAbsent(stw, () => {});
    for (final MapEntry(:key, :value) in answers.entries) {
      final had = into[key];
      into[key] = value is Set && had is Set ? {...had, ...value} : value;
    }
  }

  for (final rule in triageSuggestionRules) {
    if (_recorded(r.valueOf(rule.question.variable), rule.value)) {
      suggest(rule.stw, rule.reason, rule.prefill);
    }
  }

  // Already directed to the RD STW by the Triage page (see triage rules).
  final rr = r.valueOf(triageRespiratoryRateKey);
  if (r.valueOf(triageTachypneaKey) == true && rr is num) {
    suggest(_rd, 'RR ${_fmt(rr)}/min (≥60/min)', {rdRrKey: rr.round()});
  }
  final signs = r.valueOf(triageEmergencySignsKey);
  if (signs is Set && signs.contains('respiratoryDistress')) {
    suggest(_rd, 'Respiratory distress (retractions, grunt)');
  }
  // A measured RR is carried into the RD STW whenever it is suggested.
  if (reasons.containsKey(_rd) && rr is num) {
    prefill[_rd]![rdRrKey] = rr.round();
  }

  return [
    for (final c in NeonatalCondition.values)
      if (reasons[c] case final why?)
        StwSuggestion(c, List.unmodifiable(why), Map.unmodifiable(prefill[c]!)),
  ];
}
