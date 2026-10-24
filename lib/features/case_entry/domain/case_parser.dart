/// Free-text case history → STW topics and pre-filled answers. Pure Dart.
///
/// Deterministic rules on top of the chatbot's `analyzeQuery()`; no AI. The
/// parser only fills answers to existing questions (keyed by their ids):
/// every recommendation still comes from the STW rules, and every value is
/// shown to the clinician to confirm before and during the assessment.
library;

import '../../chatbot/domain/understanding/query_analyzer.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../jaundice/domain/jaundice_rules.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/domain/rd_workflow.dart';

/// How a value can be edited on the review screen.
enum ParsedValueKind { integer, decimal, fixed }

/// One value read from the text, for the "We understood" screen.
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

  /// The words of the case history it was read from.
  final String source;
  final ParsedValueKind kind;

  /// Topic whose question it fills; null for shared baby details.
  final NeonatalCondition? topic;

  /// How the value was derived, when not written as such (e.g. kg → g).
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
  });

  final String text;

  /// STW topics the findings point to (in topic order).
  final Set<NeonatalCondition> topics;

  /// Why each topic was detected, e.g. "RR 70/min (≥60)".
  final Map<NeonatalCondition, String> topicReasons;

  /// Pre-filled answers keyed by question variable.
  final Map<String, Object?> answers;
  final List<ParsedItem> items;

  /// Things understood but not pre-filled (e.g. "Noted as absent: no
  /// grunting", "Day 1: enter the age in hours").
  final List<String> notes;

  /// Parts of the text nothing matched; they were ignored.
  final List<String> unrecognised;

  bool get isEmpty => topics.isEmpty && items.isEmpty;
}

/// Splits on commas, semicolons, line breaks, full stops (not decimal
/// points) and "but".
final _clauseSplit = RegExp(r'[,;\n]+|\.(?!\d)|\bbut\b', caseSensitive: false);

final _negationWord = RegExp(r'\b(no|not|nil|without|absent|denies|normal)\b');

/// Words that describe the patient but carry no value of their own.
final _filler = RegExp(r'^(baby|newborn|neonate|infant|male|female|boy|girl|'
    r'case|history|of|a|an|the|and|with|is|has|was|on|at|aged?|born|'
    r'delivered|admitted|presented|presenting|noted|seen|present)$');

ParsedCase parseCase(String text) {
  final items = <ParsedItem>[];
  final notes = <String>[];
  final unrecognised = <String>[];

  int? ga, gaDays, bw, rr, bg, ageHours, dayOfLife, kramer;
  double? tsb, tcb;
  String? gaSrc, bwSrc, rrSrc, bgSrc, ageSrc, daySrc, kramerSrc;
  String? tsbSrc, tcbSrc;
  var bwFromKg = false;
  var jaundice = false, jaundiceDenied = false;
  var rdNamed = false, hypoNamed = false, sepsisNamed = false;
  var asphyxiaNamed = false;
  final rdSigns = <String>{}, abe = <String>{}, posture = <String>{};
  final rdSignSrc = <String>[], abeSrc = <String>[];

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
      notes.add('"$clause": GA given as a comparison, not used');
      used = true;
    } else if (ga == null) {
      take(e.gaWeeks, (v) {
        ga = v;
        gaDays = e.gaDays;
        gaSrc = clause;
      }, when: e.gaWeeks != null && e.gaWeeks! >= 22 && e.gaWeeks! <= 44);
    }
    if (bw == null) {
      final current = RegExp(r'current|present|today|now|weighs').hasMatch(n);
      if (current && e.weightG != null) {
        notes.add('"$clause": current weight is not asked; birth weight '
            'not filled');
        used = true;
      } else {
        take(e.weightG, (v) {
          bw = v;
          bwSrc = clause;
          bwFromKg = RegExp(r'\d\s*(kg|kgs|kilos?)\b').hasMatch(n);
        }, when: e.weightG != null && e.weightG! >= 300 && e.weightG! <= 6000);
      }
    }
    if (rr == null) {
      take(e.rr, (v) {
        rr = v;
        rrSrc = clause;
      }, when: e.rr != null && e.rr! <= 150);
    }
    if (bg == null) {
      take(e.bg, (v) {
        bg = v;
        bgSrc = clause;
      }, when: e.bg != null && e.bg! <= 600);
    }
    if (ageHours == null) {
      take(e.ageHours, (v) {
        ageHours = v;
        ageSrc = clause;
      }, when: e.ageHours != null && e.ageHours! <= 720);
    }
    if (dayOfLife == null) {
      take(e.dayOfLife, (v) {
        dayOfLife = v;
        daySrc = clause;
      });
    }
    if (e.rdSigns.isNotEmpty) {
      rdSigns.addAll(e.rdSigns);
      rdSignSrc.add(clause);
      used = true;
    }

    // Jaundice extent may follow in its own clause: "jaundice, up to palms".
    if (e.jaundice == true) {
      jaundice = true;
      jaundiceContext = true;
      used = true;
    } else if (e.jaundice == false) {
      jaundiceDenied = true;
      jaundiceContext = false;
      notes.add('Noted as absent: $clause');
      used = true;
    }
    final zone = e.kramerZone ??
        (jaundiceContext && e.jaundice == null && e.rdSigns.isEmpty
            ? kramerZoneOf(n, jaundiceContext: true)
            : null);
    if (zone != null && (kramer == null || zone > kramer)) {
      kramer = zone;
      kramerSrc = clause;
      used = true;
    } else if (zone != null) {
      used = true;
    }
    if (e.abeSigns.isNotEmpty || e.postureSigns.isNotEmpty) {
      abe.addAll(e.abeSigns);
      posture.addAll(e.postureSigns);
      abeSrc.add(clause);
      used = true;
    }
    if (tsb == null) {
      take(e.tsb, (v) {
        tsb = v;
        tsbSrc = clause;
      });
    }
    if (tcb == null) {
      take(e.tcb, (v) {
        tcb = v;
        tcbSrc = clause;
      });
    }

    bool named(RegExp re) {
      final m = re.firstMatch(n);
      if (m == null) return false;
      used = true;
      final negated = _negationWord.hasMatch(n.substring(0, m.start));
      if (negated) notes.add('Noted as absent: $clause');
      return !negated;
    }

    rdNamed |= named(RegExp(r'respiratory distress|\brds?\b'));
    hypoNamed |= named(RegExp(r'hypoglyc\w*|low blood glucose'));
    sepsisNamed |= named(RegExp(r'\bsepsis\b|\bseptic\w*'));
    asphyxiaNamed |= named(RegExp(r'asphyx\w*|\bhie\b|hypoxic.?ischa?emic'));

    if (!used) {
      if (_negationWord.hasMatch(n) &&
          (a.topics.isNotEmpty ||
              RegExp(r'grunt|retract|flar|\brr\b|resp\w*|breath\w*|letharg|'
                      r'feed\w*|tone|cry')
                  .hasMatch(n))) {
        notes.add('Noted as absent: $clause');
      } else if (!n.split(' ').every(_filler.hasMatch)) {
        unrecognised.add(clause);
      }
    }
  }

  // ---- Topics: from findings, not keywords alone ----
  final reasons = <NeonatalCondition, String>{};
  if ((rr != null && rr! >= rrThresholdPerMin) ||
      rdSigns.isNotEmpty ||
      rdNamed) {
    reasons[NeonatalCondition.respiratoryDistress] = [
      if (rr != null && rr! >= rrThresholdPerMin) 'RR $rr/min (≥60)',
      for (final s in rdSigns) RdSign.values.byName(s).label,
      if (rdNamed && rdSigns.isEmpty && (rr ?? 0) < 60) 'respiratory distress',
    ].join(', ');
  }
  final jaundicePresent =
      (jaundice || kramer != null || tsb != null || tcb != null) &&
          !(jaundiceDenied && !jaundice && kramer == null);
  if (jaundicePresent) {
    reasons[NeonatalCondition.jaundice] = [
      if (kramer != null) 'Kramer zone $kramer' else if (jaundice) 'jaundice',
      if (tsb != null) 'TSB $tsb mg/dL',
      if (tcb != null) 'TcB $tcb mg/dL',
    ].join(', ');
  }
  if (bg != null || hypoNamed) {
    reasons[NeonatalCondition.hypoglycemia] =
        bg != null ? 'BG $bg mg/dL' : 'hypoglycemia';
  }
  if (sepsisNamed) reasons[NeonatalCondition.sepsis] = 'sepsis';
  if (asphyxiaNamed) reasons[NeonatalCondition.hie] = 'asphyxia';

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
        ga!,
        'Gestational age',
        gaDays == null ? '$ga wk' : '$ga+$gaDays wk',
        gaSrc!,
        ParsedValueKind.integer);
    if (gaDays != null) answers[gaDaysKey] = gaDays;
  }
  if (bw != null) {
    put(birthWeightKey, bw!, 'Birth weight', '$bw g', bwSrc!,
        ParsedValueKind.integer,
        note: bwFromKg ? 'Converted from kg' : null);
  }
  if (rr != null) {
    put(rdRrKey, rr!, 'Respiratory rate', '$rr/min', rrSrc!,
        ParsedValueKind.integer,
        topic: NeonatalCondition.respiratoryDistress);
  }
  if (rdSigns.isNotEmpty) {
    put(
        rdSignsKey,
        <Object>{...rdSigns},
        'Respiratory distress signs',
        rdSigns.map((s) => RdSign.values.byName(s).label).join(', '),
        rdSignSrc.join(' · '),
        ParsedValueKind.fixed,
        topic: NeonatalCondition.respiratoryDistress);
  }
  if (jaundicePresent) {
    const j = NeonatalCondition.jaundice;
    if (ageHours != null) {
      put(jaundiceAgeHoursKey, ageHours!, 'Age', '$ageHours h', ageSrc!,
          ParsedValueKind.integer,
          topic: j);
    } else if (dayOfLife != null && dayOfLife! >= 2) {
      put(jaundiceAgeHoursKey, dayOfLife! * 24, 'Age', '${dayOfLife! * 24} h',
          daySrc!, ParsedValueKind.integer,
          topic: j, note: 'Day $dayOfLife × 24 h: check the age in hours');
    } else if (dayOfLife != null) {
      notes.add('Day $dayOfLife: may be under or over 24 h. Enter the age in '
          'hours on the jaundice page.');
    }
    if (kramer != null) {
      final z = KramerZone.byNumber(kramer)!;
      put(
          jaundiceKramerKey,
          z.name,
          'Jaundice extent',
          'Kramer zone ${z.number} (${z.label})',
          kramerSrc!,
          ParsedValueKind.fixed,
          topic: j,
          note: RegExp(r'haath|hath|hands and feet', caseSensitive: false)
                  .hasMatch(kramerSrc)
              ? 'Hands and feet read as palms and soles; change to zone 4 if '
                  'only arms/legs'
              : null);
    }
    if (abe.isNotEmpty) {
      put(
          jaundiceAbeKey,
          <Object>{...abe},
          'Signs of ABE',
          abe.map((s) => AbeSign.values.byName(s).label).join(', '),
          abeSrc.join(' · '),
          ParsedValueKind.fixed,
          topic: j);
    }
    if (posture.isNotEmpty) {
      put(
          jaundicePostureKey,
          <Object>{...posture},
          'Abnormal posturing / related signs',
          posture.map((s) => PostureSign.values.byName(s).label).join(', '),
          abeSrc.join(' · '),
          ParsedValueKind.fixed,
          topic: j);
    }
    if (tcb != null) {
      put(jaundiceTcbKey, tcb!, 'TcB', '$tcb mg/dL', tcbSrc!,
          ParsedValueKind.decimal,
          topic: j);
    }
    if (tsb != null) {
      put(jaundiceTsbKey, tsb!, 'TSB', '$tsb mg/dL', tsbSrc!,
          ParsedValueKind.decimal,
          topic: j);
    }
    if (ga != null && ga! < 38) {
      put(
          jaundiceRiskKey,
          <Object>{JaundiceRisk.gestationBelow38.name},
          'Jaundice risk factor',
          JaundiceRisk.gestationBelow38.label,
          gaSrc!,
          ParsedValueKind.fixed,
          topic: j,
          note: 'From the gestational age');
    }
  } else if (abe.isNotEmpty || posture.isNotEmpty) {
    notes.add('${abeSrc.join(' · ')}: used only as jaundice signs; no '
        'jaundice recorded');
  }
  if (bg != null) {
    put(hypoBgKey, bg!, 'Blood glucose', '$bg mg/dL', bgSrc!,
        ParsedValueKind.integer,
        topic: NeonatalCondition.hypoglycemia);
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
    unrecognised: unrecognised,
  );
}
