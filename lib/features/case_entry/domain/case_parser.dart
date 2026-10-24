/// Case history → STW topics and pre-filled answers. Pure Dart.
///
/// Two inputs share one builder: free text ([parseCase], deterministic rules
/// on top of the chatbot's `analyzeQuery()`; no AI) and the structured form
/// (`structured_case.dart`). Both fill [CaseFacts]; [buildCase] turns them
/// into topics and answers to existing questions (keyed by their ids). Every
/// recommendation still comes from the STW rules, and every value is shown to
/// the clinician to confirm before and during the assessment.
library;

import '../../chatbot/domain/understanding/query_analyzer.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_rules.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../jaundice/domain/jaundice_rules.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../post_asphyxia/domain/post_asphyxia_workflow.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import '../../triage/domain/triage_workflow.dart';

/// How a value can be edited on the review screen.
enum ParsedValueKind { integer, decimal, fixed }

/// One value read from the case, for the "We understood" screen.
class ParsedItem {
  const ParsedItem({
    required this.key,
    required this.label,
    required this.value,
    required this.display,
    required this.source,
    required this.kind,
    this.topic,
    this.note,
  });

  /// Answer key (the question's variable) the value pre-fills.
  final String key;
  final String label;
  final Object value;

  /// Value as shown, with its unit (e.g. "70/min").
  final String display;

  /// The words of the case history it was read from, or the value as the
  /// clinician entered it on the form.
  final String source;
  final ParsedValueKind kind;

  /// Topic whose question it fills; null for shared baby details.
  final NeonatalCondition? topic;

  /// How the value was derived, when not entered as such (e.g. kg → g).
  final String? note;
}

class ParsedCase {
  const ParsedCase({
    required this.text,
    required this.topics,
    required this.topicReasons,
    required this.answers,
    required this.items,
    required this.notes,
    required this.unrecognised,
    this.flags = const [],
  });

  /// The free text, or the structured summary for form input.
  final String text;

  /// STW topics the findings point to (in topic order).
  final Set<NeonatalCondition> topics;

  /// Why each topic was detected, e.g. "RR 70/min (≥60)".
  final Map<NeonatalCondition, String> topicReasons;

  /// Pre-filled answers keyed by question variable.
  final Map<String, Object?> answers;
  final List<ParsedItem> items;

  /// Things understood but not pre-filled (e.g. "Noted as absent: no
  /// grunting").
  final List<String> notes;

  /// Missing, ambiguous or unsupported information the clinician should
  /// check. No guidance is inferred for these.
  final List<String> flags;

  /// Parts of the text nothing matched; they were ignored.
  final List<String> unrecognised;

  bool get isEmpty => topics.isEmpty && items.isEmpty;
}

/// Values of one case before they become answers. Each value keeps where it
/// came from ([gaSrc], ...): a clause of the text, or the entry on the form.
class CaseFacts {
  int? ga, gaDays, bw, rr, bg, ageHours, dayOfLife, ageDays, kramer;
  String? gaSrc, bwSrc, rrSrc, bgSrc, ageSrc, daySrc, ageDaysSrc, kramerSrc;

  /// GA recorded as uncertain (the "GA uncertain" answer).
  bool gaUncertain = false;
  String? bwNote;
  double? temperatureC, tsb, tcb;
  String? temperatureSrc, temperatureNote, tsbSrc, tcbSrc;
  bool jaundice = false, jaundiceDenied = false, kramerUnsure = false;
  bool? jaundiceBefore24h;
  var rdNamed = false, hypoNamed = false, sepsisNamed = false;
  var asphyxiaNamed = false;

  /// "Apnoea/gasping, poor effort or shock" (RD §1.2).
  var rdEmergency = false;

  /// RD signs recorded as checked with none present.
  var rdSignsNone = false;
  final rdSigns = <String>{}, abe = <String>{}, posture = <String>{};
  final hypoRisks = <String>{}, sepsisRed = <String>{};
  final sepsisYellow = <String>{}, paRisk = <String>{};
  final rdSignSrc = <String>[], abeSrc = <String>[];
  final notes = <String>[], flags = <String>[], unrecognised = <String>[];
}

/// Splits on commas, semicolons, line breaks, full stops (not decimal
/// points) and "but".
final _clauseSplit = RegExp(r'[,;\n]+|\.(?!\d)|\bbut\b', caseSensitive: false);

final _negationWord = RegExp(r'\b(no|not|nil|without|absent|denies|normal)\b');

/// Words that describe the patient but carry no value of their own.
final _filler = RegExp(r'^(baby|newborn|neonate|infant|male|female|boy|girl|'
    r'case|history|of|a|an|the|and|with|is|has|was|on|at|aged?|born|'
    r'delivered|admitted|presented|presenting|noted|seen|present)$');

ParsedCase parseCase(String text) => buildCase(_factsFromText(text), text);

CaseFacts _factsFromText(String text) {
  final f = CaseFacts();
  var jaundiceContext = false;
  for (final raw in text.split(_clauseSplit)) {
    final clause = raw.trim();
    if (clause.isEmpty) continue;
    final a = analyzeQuery(clause);
    final e = a.entities;
    final n = a.normalized;
    var used = false;

    void take<T>(T? v, void Function(T) set, {bool when = true}) {
      if (v == null || !when) return;
      set(v);
      used = true;
    }

    if (e.gaWeeks != null && e.gaComparator != null) {
      f.notes.add('"$clause": GA given as a comparison, not used');
      used = true;
    } else if (f.ga == null) {
      take(e.gaWeeks, (v) {
        f.ga = v;
        f.gaDays = e.gaDays;
        f.gaSrc = clause;
      }, when: e.gaWeeks != null && e.gaWeeks! >= 22 && e.gaWeeks! <= 44);
    }
    if (f.bw == null) {
      final current = RegExp(r'current|present|today|now|weighs').hasMatch(n);
      if (current && e.weightG != null) {
        f.notes.add('"$clause": current weight is not asked; birth weight '
            'not filled');
        used = true;
      } else {
        take(e.weightG, (v) {
          f.bw = v;
          f.bwSrc = clause;
          if (RegExp(r'\d\s*(kg|kgs|kilos?)\b').hasMatch(n)) {
            f.bwNote = 'Converted from kg';
          }
        }, when: e.weightG != null && e.weightG! >= 300 && e.weightG! <= 6000);
      }
    }
    if (f.rr == null) {
      take(e.rr, (v) {
        f.rr = v;
        f.rrSrc = clause;
      }, when: e.rr != null && e.rr! <= 150);
    }
    if (f.bg == null) {
      take(e.bg, (v) {
        f.bg = v;
        f.bgSrc = clause;
      }, when: e.bg != null && e.bg! <= 600);
    }
    if (f.ageHours == null) {
      take(e.ageHours, (v) {
        f.ageHours = v;
        f.ageSrc = clause;
      }, when: e.ageHours != null && e.ageHours! <= 720);
    }
    if (f.dayOfLife == null) {
      take(e.dayOfLife, (v) {
        f.dayOfLife = v;
        f.daySrc = clause;
      });
    }
    if (e.rdSigns.isNotEmpty) {
      f.rdSigns.addAll(e.rdSigns);
      f.rdSignSrc.add(clause);
      used = true;
    }

    // Jaundice extent may follow in its own clause: "jaundice, up to palms".
    if (e.jaundice == true) {
      f.jaundice = true;
      jaundiceContext = true;
      used = true;
    } else if (e.jaundice == false) {
      f.jaundiceDenied = true;
      jaundiceContext = false;
      f.notes.add('Noted as absent: $clause');
      used = true;
    }
    final zone = e.kramerZone ??
        (jaundiceContext && e.jaundice == null && e.rdSigns.isEmpty
            ? kramerZoneOf(n, jaundiceContext: true)
            : null);
    if (zone != null && (f.kramer == null || zone > f.kramer!)) {
      f.kramer = zone;
      f.kramerSrc = clause;
      used = true;
    } else if (zone != null) {
      used = true;
    }
    if (e.abeSigns.isNotEmpty || e.postureSigns.isNotEmpty) {
      f.abe.addAll(e.abeSigns);
      f.posture.addAll(e.postureSigns);
      f.abeSrc.add(clause);
      used = true;
    }
    if (f.tsb == null) {
      take(e.tsb, (v) {
        f.tsb = v;
        f.tsbSrc = clause;
      });
    }
    if (f.tcb == null) {
      take(e.tcb, (v) {
        f.tcb = v;
        f.tcbSrc = clause;
      });
    }

    bool named(RegExp re) {
      final m = re.firstMatch(n);
      if (m == null) return false;
      used = true;
      final negated = _negationWord.hasMatch(n.substring(0, m.start));
      if (negated) f.notes.add('Noted as absent: $clause');
      return !negated;
    }

    f.rdNamed |= named(RegExp(r'respiratory distress|\brds?\b'));
    f.hypoNamed |= named(RegExp(r'hypoglyc\w*|low blood glucose'));
    f.sepsisNamed |= named(RegExp(r'\bsepsis\b|\bseptic\w*'));
    f.asphyxiaNamed |= named(RegExp(r'asphyx\w*|\bhie\b|hypoxic.?ischa?emic'));

    if (!used) {
      if (_negationWord.hasMatch(n) &&
          (a.topics.isNotEmpty ||
              RegExp(r'grunt|retract|flar|\brr\b|resp\w*|breath\w*|letharg|'
                      r'feed\w*|tone|cry')
                  .hasMatch(n))) {
        f.notes.add('Noted as absent: $clause');
      } else if (!n.split(' ').every(_filler.hasMatch)) {
        f.unrecognised.add(clause);
      }
    }
  }
  return f;
}

String _labels(Iterable<String> values, Map<String, String> labels) =>
    values.map((v) => labels[v] ?? v).join(', ');

Map<String, String> _optionLabels(List<QuestionOption> options) => {
      for (final o in options) '${o.value}': o.label,
    };

/// Topics, answers and confirm-screen items from [f]. Topics follow the
/// findings the STWs act on, never a keyword alone.
ParsedCase buildCase(CaseFacts f, String text) {
  final items = <ParsedItem>[];
  final notes = [...f.notes];
  final flags = [...f.flags];
  final rr = f.rr, ga = f.ga, kramer = f.kramer;

  // ---- Topics ----
  final reasons = <NeonatalCondition, String>{};
  final rrSign = rr != null && rr >= rrThresholdPerMin;
  if (rrSign || f.rdSigns.isNotEmpty || f.rdNamed || f.rdEmergency) {
    reasons[NeonatalCondition.respiratoryDistress] = [
      if (rrSign) 'RR $rr/min (≥60)',
      for (final s in f.rdSigns) RdSign.values.byName(s).label,
      if (f.rdEmergency) qRdEmergency.question,
      if (f.rdNamed && f.rdSigns.isEmpty && !rrSign && !f.rdEmergency)
        'respiratory distress',
    ].join(', ');
  }
  final jaundicePresent = (f.jaundice ||
          kramer != null ||
          f.kramerUnsure ||
          f.tsb != null ||
          f.tcb != null) &&
      !(f.jaundiceDenied && !f.jaundice && kramer == null);
  if (jaundicePresent) {
    reasons[NeonatalCondition.jaundice] = [
      if (kramer != null) 'Kramer zone $kramer' else if (f.jaundice) 'jaundice',
      if (f.tsb != null) 'TSB ${f.tsb} mg/dL',
      if (f.tcb != null) 'TcB ${f.tcb} mg/dL',
    ].join(', ');
  }
  final hypoRiskLabels = {for (final r in HypoRisk.values) r.name: r.label};
  if (f.bg != null || f.hypoNamed || f.hypoRisks.isNotEmpty) {
    reasons[NeonatalCondition.hypoglycemia] = [
      if (f.bg != null) 'BG ${f.bg} mg/dL',
      if (f.hypoRisks.isNotEmpty)
        'whom to screen: ${_labels(f.hypoRisks, hypoRiskLabels)}',
      if (f.bg == null && f.hypoRisks.isEmpty) 'hypoglycemia',
    ].join(', ');
  }
  final redLabels = _optionLabels(qSepsisRed.options);
  final yellowLabels = _optionLabels(qSepsisYellow.options);
  if (f.sepsisNamed || f.sepsisRed.isNotEmpty || f.sepsisYellow.isNotEmpty) {
    reasons[NeonatalCondition.sepsis] = [
      if (f.sepsisRed.isNotEmpty)
        'red flags: ${_labels(f.sepsisRed, redLabels)}',
      if (f.sepsisYellow.isNotEmpty)
        'yellow signs: ${_labels(f.sepsisYellow, yellowLabels)}',
      if (f.sepsisRed.isEmpty && f.sepsisYellow.isEmpty) 'sepsis',
    ].join('; ');
  }
  final paLabels = _optionLabels(qPaRisk.options);
  if (f.asphyxiaNamed || f.paRisk.isNotEmpty) {
    reasons[NeonatalCondition.hie] =
        f.paRisk.isEmpty ? 'asphyxia' : 'risk: ${_labels(f.paRisk, paLabels)}';
  }

  // ---- Answers and confirm-screen items ----
  final answers = <String, Object?>{};
  void put(String key, Object value, String label, String display,
      String source, ParsedValueKind kind,
      {NeonatalCondition? topic, String? note}) {
    answers[key] = value;
    items.add(ParsedItem(
      key: key,
      label: label,
      value: value,
      display: display,
      source: source,
      kind: kind,
      topic: topic,
      note: note,
    ));
  }

  if (ga != null) {
    answers[gaKnownKey] = true;
    put(
        gaWeeksKey,
        ga,
        'Gestational age',
        f.gaDays == null ? '$ga wk' : '$ga+${f.gaDays} wk',
        f.gaSrc!,
        ParsedValueKind.integer);
    if (f.gaDays != null) answers[gaDaysKey] = f.gaDays;
  } else if (f.gaUncertain) {
    put(gaKnownKey, false, 'Gestational age', 'GA uncertain', f.gaSrc!,
        ParsedValueKind.fixed);
  }
  if (f.bw != null) {
    put(birthWeightKey, f.bw!, 'Birth weight', '${f.bw} g', f.bwSrc!,
        ParsedValueKind.integer,
        note: f.bwNote);
  }
  if (rr != null) {
    put(rdRrKey, rr, 'Respiratory rate', '$rr/min', f.rrSrc!,
        ParsedValueKind.integer,
        topic: NeonatalCondition.respiratoryDistress);
  }
  if (f.rdEmergency) {
    put(rdEmergencyKey, true, qRdEmergency.question, 'Present', 'Selected',
        ParsedValueKind.fixed,
        topic: NeonatalCondition.respiratoryDistress);
  }
  if (f.rdSigns.isNotEmpty || f.rdSignsNone) {
    put(
        rdSignsKey,
        <Object>{...f.rdSigns},
        'Respiratory distress signs',
        f.rdSigns.isEmpty
            ? 'None of these signs'
            : f.rdSigns.map((s) => RdSign.values.byName(s).label).join(', '),
        f.rdSignSrc.isEmpty ? 'Selected' : f.rdSignSrc.join(' · '),
        ParsedValueKind.fixed,
        topic: NeonatalCondition.respiratoryDistress);
  }

  // Age in hours, as entered or derived; null when it cannot be told.
  int? ageHours = f.ageHours;
  String? ageSrc = f.ageSrc, ageNote;
  if (ageHours == null && f.dayOfLife != null && f.dayOfLife! >= 2) {
    ageHours = f.dayOfLife! * 24;
    ageSrc = f.daySrc;
    ageNote = 'Day ${f.dayOfLife} × 24 h: check the age in hours';
  } else if (ageHours == null && f.ageDays != null && f.ageDays! >= 1) {
    ageHours = f.ageDays! * 24;
    ageSrc = f.ageDaysSrc;
    ageNote = '${f.ageDays} days × 24 h (at least): check the age in hours';
  }
  final ageNeeded =
      jaundicePresent || reasons.containsKey(NeonatalCondition.sepsis);
  if (ageHours == null && ageNeeded) {
    if (f.dayOfLife != null) {
      flags.add('Day ${f.dayOfLife}: may be under or over 24 h. Enter the age '
          'in hours on the assessment page.');
    } else if (f.ageDays == 0) {
      flags.add('Age 0 days: under 24 h, exact hours not known. Enter the age '
          'in hours on the assessment page.');
    }
  }

  if (jaundicePresent) {
    const j = NeonatalCondition.jaundice;
    if (ageHours != null) {
      put(jaundiceAgeHoursKey, ageHours, 'Age', '$ageHours h', ageSrc!,
          ParsedValueKind.integer,
          topic: j, note: ageNote);
    }
    if (f.jaundiceBefore24h != null && (ageHours == null || ageHours >= 24)) {
      put(
          jaundiceBefore24hKey,
          f.jaundiceBefore24h!,
          qJaundiceBefore24h.question,
          f.jaundiceBefore24h! ? 'Yes' : 'No',
          'Selected',
          ParsedValueKind.fixed,
          topic: j);
    }
    if (kramer != null) {
      final z = KramerZone.byNumber(kramer)!;
      final src = f.kramerSrc!;
      put(jaundiceKramerKey, z.name, 'Jaundice extent',
          'Kramer zone ${z.number} (${z.label})', src, ParsedValueKind.fixed,
          topic: j,
          note: RegExp(r'haath|hath|hands and feet', caseSensitive: false)
                  .hasMatch(src)
              ? 'Hands and feet read as palms and soles; change to zone 4 if '
                  'only arms/legs'
              : null);
    } else if (f.kramerUnsure) {
      put(
          jaundiceKramerKey,
          kramerUnsure,
          'Jaundice extent',
          'Unsure about visual assessment',
          f.kramerSrc ?? 'Selected',
          ParsedValueKind.fixed,
          topic: j);
    } else {
      flags.add('Jaundice extent not recorded: it is asked on the jaundice '
          'page.');
    }
    if (f.abe.isNotEmpty) {
      put(
          jaundiceAbeKey,
          <Object>{...f.abe},
          'Signs of ABE',
          f.abe.map((s) => AbeSign.values.byName(s).label).join(', '),
          f.abeSrc.isEmpty ? 'Selected' : f.abeSrc.join(' · '),
          ParsedValueKind.fixed,
          topic: j);
    }
    if (f.posture.isNotEmpty) {
      put(
          jaundicePostureKey,
          <Object>{...f.posture},
          'Abnormal posturing / related signs',
          f.posture.map((s) => PostureSign.values.byName(s).label).join(', '),
          f.abeSrc.isEmpty ? 'Selected' : f.abeSrc.join(' · '),
          ParsedValueKind.fixed,
          topic: j);
    }
    if (f.tcb != null) {
      put(jaundiceTcbKey, f.tcb!, 'TcB', '${f.tcb} mg/dL', f.tcbSrc!,
          ParsedValueKind.decimal,
          topic: j);
    }
    if (f.tsb != null) {
      put(jaundiceTsbKey, f.tsb!, 'TSB', '${f.tsb} mg/dL', f.tsbSrc!,
          ParsedValueKind.decimal,
          topic: j);
    }
    if (ga != null && ga < 38) {
      put(
          jaundiceRiskKey,
          <Object>{JaundiceRisk.gestationBelow38.name},
          'Jaundice risk factor',
          JaundiceRisk.gestationBelow38.label,
          f.gaSrc!,
          ParsedValueKind.fixed,
          topic: j,
          note: 'From the gestational age');
    }
    if (ga == null && !f.gaUncertain) {
      flags.add('Gestational age not recorded: the Jaundice STW covers '
          'infants ≥35 weeks only; it is asked first.');
    }
  } else if (f.abe.isNotEmpty || f.posture.isNotEmpty) {
    notes.add('${f.abeSrc.join(' · ')}: used only as jaundice signs; no '
        'jaundice recorded');
  }
  if (f.bg != null) {
    put(hypoBgKey, f.bg!, 'Blood glucose', '${f.bg} mg/dL', f.bgSrc!,
        ParsedValueKind.integer,
        topic: NeonatalCondition.hypoglycemia);
  }
  if (f.hypoRisks.isNotEmpty) {
    put(hypoRiskKey, <Object>{...f.hypoRisks}, 'Hypoglycemia risk factors',
        _labels(f.hypoRisks, hypoRiskLabels), 'Selected', ParsedValueKind.fixed,
        topic: NeonatalCondition.hypoglycemia);
  }
  if (f.sepsisRed.isNotEmpty || f.sepsisYellow.isNotEmpty) {
    const s = NeonatalCondition.sepsis;
    // The red/yellow questions belong to the initial assessment.
    put(sepsisStageKey, 'initial', 'Sepsis assessment stage',
        'Initial assessment', 'Case entry', ParsedValueKind.fixed,
        topic: s, note: 'Change on the sepsis page if this is a review');
    if (ageHours != null) {
      put(sepsisAgeKey, ageHours, 'Age', '$ageHours h', ageSrc!,
          ParsedValueKind.integer,
          topic: s, note: ageNote);
    }
    if (ga != null) {
      put(sepsisGaKey, ga, 'Gestation at birth', '$ga wk', f.gaSrc!,
          ParsedValueKind.integer,
          topic: s);
    }
    if (f.bw != null) {
      put(sepsisBwKey, f.bw!, 'Birth weight', '${f.bw} g', f.bwSrc!,
          ParsedValueKind.integer,
          topic: s, note: f.bwNote);
    }
    if (f.sepsisRed.isNotEmpty) {
      put(sepsisRedKey, <Object>{...f.sepsisRed}, 'Sepsis red flags',
          _labels(f.sepsisRed, redLabels), 'Selected', ParsedValueKind.fixed,
          topic: s);
    }
    if (f.sepsisYellow.isNotEmpty) {
      put(
          sepsisYellowKey,
          <Object>{...f.sepsisYellow},
          'Sepsis yellow signs',
          _labels(f.sepsisYellow, yellowLabels),
          'Selected',
          ParsedValueKind.fixed,
          topic: s);
    }
  }
  if (f.paRisk.isNotEmpty) {
    put(qPaRisk.id, <Object>{...f.paRisk}, 'Post asphyxia risk observations',
        _labels(f.paRisk, paLabels), 'Selected', ParsedValueKind.fixed,
        topic: NeonatalCondition.hie);
  }
  if (f.temperatureC != null) {
    // Recorded only: it is classified by the Triage STW if Triage is run.
    put(triageTemperatureKey, f.temperatureC!, 'Temperature',
        '${f.temperatureC} °C', f.temperatureSrc!, ParsedValueKind.decimal,
        topic: NeonatalCondition.triage, note: f.temperatureNote);
    notes.add('Temperature is recorded, not classified. Only the Triage STW '
        'uses it; add Triage below to have it assessed.');
  }

  final ordered = {
    for (final c in NeonatalCondition.values)
      if (reasons.containsKey(c)) c,
  };
  return ParsedCase(
    text: text,
    topics: ordered,
    topicReasons: {for (final c in ordered) c: reasons[c]!},
    answers: answers,
    items: items,
    notes: notes,
    flags: flags,
    unrecognised: f.unrecognised,
  );
}
