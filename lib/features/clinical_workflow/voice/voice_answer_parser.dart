/// Spoken answer → typed answer for a [ClinicalQuestion]. Pure Dart.
///
/// The result is only a proposal: the caller still stores it through
/// `AssessmentController.answer`, which validates it again.
library;

import '../../../core/voice/number_words.dart';
import '../../chatbot/domain/understanding/hinglish_lexicon.dart';
import '../domain/clinical_question.dart';
import 'voice_commands.dart';

enum VoiceProblem {
  /// Nothing usable was heard (or no option matched).
  notUnderstood,

  /// A number outside the question's min–max.
  outOfRange,

  /// A decimal or negative number for a whole-number question.
  notWholeNumber,

  /// Several options match equally well; see [VoiceParse.candidates].
  ambiguous,

  /// A date outside the allowed window.
  dateOutOfRange,
}

class VoiceParse {
  const VoiceParse.value(Object this.value)
      : problem = null,
        candidates = const [];
  const VoiceParse.problem(VoiceProblem this.problem,
      {this.candidates = const []})
      : value = null;

  final Object? value;
  final VoiceProblem? problem;

  /// Labels of the equally good options for [VoiceProblem.ambiguous].
  final List<String> candidates;

  bool get ok => problem == null;
}

/// First and last date a date question accepts (same window as the date
/// picker in `QuestionField`).
(DateTime, DateTime) dateBounds(ClinicalQuestion q, DateTime today) => (
      today.subtract(const Duration(days: 730)),
      q.pastOnly ? today : today.add(const Duration(days: 365)),
    );

/// Parses [transcript] as an answer to [q], choosing among the currently
/// visible [options]. [today] anchors relative dates.
VoiceParse parseVoiceAnswer(
  ClinicalQuestion q,
  List<QuestionOption> options,
  String transcript, {
  required DateTime today,
}) {
  if (transcript.trim().isEmpty) {
    return const VoiceParse.problem(VoiceProblem.notUnderstood);
  }
  return switch (q.type) {
    QuestionType.numeric => _numeric(q, transcript),
    QuestionType.decimal => _decimal(q, transcript),
    QuestionType.boolean => switch (spokenYesNo(transcript)) {
        final b? => VoiceParse.value(b),
        null => const VoiceParse.problem(VoiceProblem.notUnderstood),
      },
    QuestionType.singleChoice => _single(options, transcript),
    QuestionType.multipleChoice => _multiple(options, transcript),
    QuestionType.date => _date(q, transcript, today),
    QuestionType.text => VoiceParse.value(transcript.trim()),
  };
}

// ---------------------------------------------------------------- numeric

VoiceParse _numeric(ClinicalQuestion q, String transcript) {
  if (hasDecimalOrNegative(transcript)) {
    return const VoiceParse.problem(VoiceProblem.notWholeNumber);
  }
  final v = parseSpokenInt(transcript);
  if (v == null) return const VoiceParse.problem(VoiceProblem.notUnderstood);
  if (q.validate(v) != null) {
    return const VoiceParse.problem(VoiceProblem.outOfRange);
  }
  return VoiceParse.value(v);
}

VoiceParse _decimal(ClinicalQuestion q, String transcript) {
  final value = num.tryParse(transcript.trim());
  if (value == null) {
    return const VoiceParse.problem(VoiceProblem.notUnderstood);
  }
  if (q.validate(value) != null) {
    return const VoiceParse.problem(VoiceProblem.outOfRange);
  }
  return VoiceParse.value(value);
}

// ---------------------------------------------------------------- yes / no

const _yesWords = {
  'yes',
  'yeah',
  'yep',
  'yup',
  'yah',
  'correct',
  'true',
  'right',
  'affirmative',
  'present',
  'positive',
  'done',
  'given',
  'haan',
  'han',
  'haa',
  'ha',
  'ji',
  'jee',
  'bilkul',
  'sahi',
  'हां',
  'हा',
  'जी',
  'सही',
  'बिल्कुल',
};
const _noWords = {
  'no',
  'nope',
  'nah',
  'not',
  'false',
  'negative',
  'absent',
  'nahi',
  'nahin',
  'nai',
  'na',
  'naa',
  'नहीं',
  'नही',
  'ना',
  'न',
};
const _unsureWords = {
  'sure',
  'maybe',
  'perhaps',
  'know',
  'unsure',
  'uncertain',
  'unknown',
  'pata',
  'shayad',
  'पता',
  'शायद',
};

/// true for "yes"/"haan", false for "no"/"nahi", null when unclear
/// (both, neither, or "not sure").
bool? spokenYesNo(String transcript) {
  final words = normalizeUtterance(transcript).split(' ').toSet();
  if (words.any(_unsureWords.contains)) return null;
  final yes = words.any(_yesWords.contains);
  final no = words.any(_noWords.contains);
  if (yes == no) return null;
  return yes;
}

// ---------------------------------------------------------------- choices

const _stopWords = {
  'the',
  'a',
  'an',
  'is',
  'it',
  'its',
  'of',
  'on',
  'in',
  'with',
  'for',
  'to',
  'and',
  'or',
  'please',
  'i',
  'think',
  'say',
  'select',
  'choose',
  'option',
  'eg',
  'e',
  'g',
  'only',
  'hai',
  'he',
  'ka',
  'ki',
  'ke',
  'है',
};

/// Content tokens of [text]: Hinglish words are added in English, number
/// words become digits, and "zone I/II/III" roman numerals become digits.
Set<String> _tokens(String text) {
  final words = normalizeUtterance(text).split(' ');
  final out = <String>{};
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty || _stopWords.contains(w)) continue;
    final prev = i > 0 ? words[i - 1] : '';
    final roman = const {'i': 1, 'ii': 2, 'iii': 3}[w];
    if (roman != null && (w != 'i' || prev == 'zone' || prev == 'stage')) {
      out.add('$roman');
      continue;
    }
    final n = spokenNumberToken(w);
    if (n != null) {
      out.add('$n');
      continue;
    }
    out.add(w);
    if (w == 'oxygen') out.add('o2');
    final english = hinglishWords[w];
    if (english != null && english.isNotEmpty) {
      out.addAll(english.split(' '));
    }
  }
  return out;
}

bool _isNumber(String t) => RegExp(r'^\d+$').hasMatch(t);

/// Score of each option for [spoken]: share of the label's words heard,
/// plus 1 when a number in the label was said ("stage 3", SAS "one").
List<(QuestionOption, double)> _score(
  List<QuestionOption> options,
  Set<String> spoken,
) =>
    [
      for (final o in options)
        () {
          final label = _tokens(o.label);
          if (label.isEmpty) return (o, 0.0);
          final hit = label.intersection(spoken);
          final number = hit.any(_isNumber) ? 1.0 : 0.0;
          return (o, hit.length / label.length + number);
        }(),
    ];

/// Best option for [transcript], ambiguous, or not understood.
VoiceParse _matchOption(List<QuestionOption> options, String transcript) {
  final spoken = _tokens(transcript);
  if (spoken.isEmpty) {
    return const VoiceParse.problem(VoiceProblem.notUnderstood);
  }
  final scored = _score(options, spoken)..sort((a, b) => b.$2.compareTo(a.$2));
  if (scored.isEmpty || scored.first.$2 < 0.5) {
    return const VoiceParse.problem(VoiceProblem.notUnderstood);
  }
  final best = scored.first.$2;
  final top = [
    for (final s in scored)
      if (s.$2 >= best - 1e-9) s.$1
  ];
  if (top.length > 1) {
    return VoiceParse.problem(VoiceProblem.ambiguous,
        candidates: [for (final o in top) o.label]);
  }
  return VoiceParse.value(top.single.value);
}

VoiceParse _single(List<QuestionOption> options, String transcript) {
  final byLabel = _matchOption(options, transcript);
  if (byLabel.ok) return byLabel;

  // "Yes"/"No" for options such as "Yes — enter findings" / "Not yet".
  final yn = spokenYesNo(transcript);
  if (yn != null) {
    final byValue = [
      for (final o in options)
        if (o.value == yn) o
    ];
    final byWord = [
      for (final o in options)
        if (RegExp(yn ? r'^yes\b' : r'^(no|not)\b')
            .hasMatch(normalizeUtterance(o.label)))
          o,
    ];
    final pick = byValue.length == 1 ? byValue : byWord;
    if (pick.length == 1) return VoiceParse.value(pick.single.value);
  }

  // "first option", "second", "doosra" when labels carry no numbers.
  final ordinal = _ordinal(transcript, options.length);
  if (ordinal != null && !options.any((o) => _tokens(o.label).any(_isNumber))) {
    return VoiceParse.value(options[ordinal].value);
  }
  return byLabel;
}

int? _ordinal(String transcript, int count) {
  const words = {
    'first': 0,
    'second': 1,
    'third': 2,
    'fourth': 3,
    'fifth': 4,
    'sixth': 5,
    'pehla': 0,
    'pahla': 0,
    'doosra': 1,
    'dusra': 1,
    'teesra': 2,
    'tisra': 2,
    'chautha': 3,
    'पहला': 0,
    'दूसरा': 1,
    'तीसरा': 2,
    'चौथा': 3,
  };
  final w = normalizeUtterance(transcript).split(' ');
  for (var i = 0; i < w.length; i++) {
    var idx = words[w[i]];
    if (idx == null && w[i] == 'option' && i + 1 < w.length) {
      final n = spokenNumberToken(w[i + 1]);
      if (n != null) idx = n - 1;
    }
    if (w[i] == 'last') idx = count - 1;
    if (idx != null) return idx >= 0 && idx < count ? idx : null;
  }
  return null;
}

const _noneAnswers = {
  'none',
  'nothing',
  'no',
  'nil',
  'none of these',
  'none of them',
  'none of the above',
  'no signs',
  'koi nahi',
  'kuch nahi',
  'koi bhi nahi',
  'कोई नहीं',
  'कुछ नहीं',
  'कोई भी नहीं',
};

VoiceParse _multiple(List<QuestionOption> options, String transcript) {
  final whole = normalizeUtterance(transcript);
  if ({for (final a in _noneAnswers) normalizeUtterance(a)}.contains(whole)) {
    return const VoiceParse.value(<Object>{});
  }

  // "grunting and nasal flaring": match each part on its own.
  final parts = whole
      .split(RegExp(r'\s+(and|aur|also|or|और|तथा)\s+'))
      .where((p) => p.trim().isNotEmpty)
      .toList();
  final picked = <Object>{};
  var allParts = true;
  for (final p in parts) {
    final r = _matchOption(options, p);
    if (!r.ok) {
      allParts = false;
      break;
    }
    picked.add(r.value!);
  }
  if (allParts && picked.isNotEmpty) return VoiceParse.value(picked);

  // A part that matches nothing must be asked again, not dropped.
  if (parts.length > 1) {
    return const VoiceParse.problem(VoiceProblem.notUnderstood);
  }

  // No separator heard ("grunting nasal flaring"): every option whose
  // words were all said.
  final spoken = _tokens(transcript);
  final full = {
    for (final o in options)
      if (_tokens(o.label).isNotEmpty && spoken.containsAll(_tokens(o.label)))
        o.value,
  };
  if (full.isNotEmpty) return VoiceParse.value(full);
  return _matchOption(options, transcript);
}

// ---------------------------------------------------------------- dates

const _months = {
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
  'जनवरी': 1,
  'फरवरी': 2,
  'मार्च': 3,
  'अप्रैल': 4,
  'मई': 5,
  'जून': 6,
  'जुलाई': 7,
  'अगस्त': 8,
  'सितंबर': 9,
  'सितम्बर': 9,
  'अक्टूबर': 10,
  'अक्तूबर': 10,
  'नवंबर': 11,
  'नवम्बर': 11,
  'दिसंबर': 12,
  'दिसम्बर': 12,
};

VoiceParse _date(ClinicalQuestion q, String transcript, DateTime today) {
  final d = parseSpokenDate(transcript, today: today, pastOnly: q.pastOnly);
  if (d == null) return const VoiceParse.problem(VoiceProblem.notUnderstood);
  final (first, last) = dateBounds(q, today);
  if (d.isBefore(first) || d.isAfter(last)) {
    return const VoiceParse.problem(VoiceProblem.dateOutOfRange);
  }
  return VoiceParse.value(d);
}

/// Date in [transcript]: "today", "yesterday", "kal", "3 days ago", "after
/// 2 weeks", "12 March 2026", "March 12th", "12/3/26" (day first).
/// [pastOnly] reads "kal" as yesterday and a year-less date as the most
/// recent one; otherwise "kal" is tomorrow-or-yesterday and is rejected.
DateTime? parseSpokenDate(
  String transcript, {
  required DateTime today,
  bool pastOnly = false,
}) {
  final raw = transcript.toLowerCase();
  final t = normalizeUtterance(raw);
  final w = t.split(' ');
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  if (t == 'today' || t == 'aaj' || t == 'आज') return day(0);
  if (t == 'yesterday' || (pastOnly && (t == 'kal' || t == 'कल'))) {
    return day(-1);
  }
  if (t == 'day before yesterday' || t == 'parso' || t == 'परसों') {
    return pastOnly ? day(-2) : null;
  }
  if (t == 'tomorrow') return day(1);

  // "3 days ago", "after 2 weeks", "in one month", "2 hafte baad".
  // The number may follow other words ("next exam in 2 weeks"):
  // parseSpokenInt skips words that are not numbers.
  final rel = RegExp(
    r'(.+?) (day|days|din|दिन|week|weeks|hafta|hafte|हफ्ते|हफ्ता|सप्ताह|month|months|mahina|mahine|महीना|महीने)(?: (ago|before|pehle|पहले|baad|bad|later|बाद))?(?: |$)',
  ).firstMatch(t);
  if (rel != null) {
    final n = parseSpokenInt(rel[1]!);
    if (n != null) {
      final unit = rel[2]!;
      final past = const {'ago', 'before', 'pehle', 'पहले'}.contains(rel[3]);
      final sign = past ? -1 : 1;
      if (RegExp(r'^(day|days|din|दिन)$').hasMatch(unit)) return day(sign * n);
      if (RegExp(r'^(month|months|mahina|mahine|महीना|महीने)$')
          .hasMatch(unit)) {
        return DateTime(today.year, today.month + sign * n, today.day);
      }
      return day(sign * n * 7);
    }
  }

  // "12/3/2026", "12-03-26", "12.3.26" (day first, as written in India).
  final numeric =
      RegExp(r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})(?:\s*[/\-.]\s*(\d{2,4}))?\b')
          .firstMatch(raw);
  if (numeric != null) {
    return _build(int.parse(numeric[1]!), int.parse(numeric[2]!),
        numeric[3] == null ? null : int.parse(numeric[3]!), today, pastOnly);
  }

  // "12 March 2026", "12th of March", "March 12th", "बारह मार्च".
  final mi = w.indexWhere(_months.containsKey);
  if (mi < 0) return null;
  final before = w.sublist(0, mi);
  var after = w.sublist(mi + 1);
  var d = parseSpokenInt(before.join(' '));
  if (d == null && after.isNotEmpty) {
    d = parseSpokenInt(after.first); // "March 12th"
    after = after.sublist(1);
  }
  if (d == null) return null;
  int? year;
  if (after.isNotEmpty) {
    year = _spokenYear(after);
    if (year == null) return null;
  }
  return _build(d, _months[w[mi]]!, year, today, pastOnly);
}

/// "2026", "26", "two thousand twenty six", "twenty twenty six".
int? _spokenYear(List<String> words) {
  final whole = parseSpokenInt(words.join(' '));
  if (whole != null) return whole;
  if (words.length > 1 && spokenNumberToken(words.first) == 20) {
    final rest = parseSpokenInt(words.skip(1).join(' '));
    if (rest != null && rest < 100) return 2000 + rest;
  }
  return null;
}

DateTime? _build(int d, int m, int? y, DateTime today, bool pastOnly) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  var year = y ?? today.year;
  if (year < 100) year += 2000;
  var date = DateTime(year, m, d);
  if (date.month != m) return null; // 31 February
  if (y == null) {
    // No year said: the most recent such date for past-only questions,
    // the next one when it is well in the past otherwise ("5 January"
    // for a next exam in October means next January).
    if (pastOnly && date.isAfter(today)) {
      date = DateTime(year - 1, m, d);
    } else if (!pastOnly &&
        date.isBefore(today.subtract(const Duration(days: 180)))) {
      date = DateTime(year + 1, m, d);
    }
  }
  return date;
}
