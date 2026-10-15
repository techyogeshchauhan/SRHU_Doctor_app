/// Spoken whole numbers → int, for voice data entry. Pure Dart.
///
/// Understands digits ("62", "2,500", Devanagari "६२"), English words
/// ("sixty two", "two thousand five hundred"), romanised Hindi ("baasath",
/// "ek sau bees") and Hindi words ("बासठ"). Digits read one by one ("one
/// five zero") are joined (150). Decimals and negatives are rejected because
/// every numeric question takes a whole number.
library;

/// The whole number spoken in [text], or null when there is none, more
/// than one, or it is a decimal/negative.
int? parseSpokenInt(String text) {
  final normal = _normalize(text);
  if (normal.isEmpty || hasDecimalOrNegative(normal)) return null;

  final values = <int>[];
  var multipliers = 0;
  for (final token in normal.replaceAll(RegExp(r'[.\-]'), ' ').split(' ')) {
    final v = _tokenValue(token);
    if (v != null) {
      values.add(v);
      if (v == 100 || v == 1000) multipliers++;
    }
  }
  if (values.isEmpty) return null;

  // "one five zero" → 150 (digits read one by one).
  if (multipliers == 0 && values.length > 1 && values.every((v) => v < 10)) {
    return int.parse(values.join());
  }

  var total = 0;
  var current = 0;
  for (final v in values) {
    if (v == 1000) {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
    } else if (v == 100) {
      if (current % 100 != current) return null; // "two hundred hundred"
      current = (current == 0 ? 1 : current) * 100;
    } else {
      final tail = current % 100;
      // "sixty two" adds a unit to a ten; "sixty seventy" or "five two"
      // (mixed with words) is two numbers, not one.
      if (tail != 0 && (tail < 10 || tail % 10 != 0 || v >= 10)) return null;
      if (current >= 100 && v >= 100) return null; // "100 150"
      current += v;
    }
  }
  return total + current;
}

/// True when [text] says a decimal ("36.5", "point") or negative number.
bool hasDecimalOrNegative(String text) {
  final t = text.toLowerCase();
  return RegExp(r'\d[.,]\d{1,2}(?!\d)').hasMatch(_digitsOnly(t)) ||
      RegExp(r'(^|\s)(point|dot|decimal|dashamlav|दशमलव|minus|negative|ऋण)(\s|$)')
          .hasMatch(t) ||
      RegExp(r'(^|\s)-\d').hasMatch(t);
}

/// Value of a single spoken number word or digit string, else null.
int? spokenNumberToken(String token) => _tokenValue(_normalize(token));

int? _tokenValue(String token) {
  if (token.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(token)) return int.tryParse(token);
  return _english[token] ?? _hindi[_squash(token)];
}

/// Lowercases, maps Devanagari digits, joins "2,500", splits "sixty-two",
/// and drops punctuation (keeping "." and "-" for the decimal check).
String _normalize(String text) {
  var t = _digitsOnly(text.toLowerCase());
  t = t.replaceAllMapped(RegExp(r'(\d),(\d{3})'), (m) => '${m[1]}${m[2]}');
  t = t.replaceAllMapped(RegExp(r'([a-z])-([a-z])'), (m) => '${m[1]} ${m[2]}');
  t = t.replaceAllMapped(RegExp(r'(\d)([^\d\s.,])'), (m) => '${m[1]} ${m[2]}');
  t = t.replaceAll(RegExp(r'[^\p{L}\p{M}\d.\-\s]', unicode: true), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _digitsOnly(String t) => t.replaceAllMapped(
      RegExp('[०-९]'),
      (m) => '${m[0]!.codeUnitAt(0) - 0x0966}',
    );

/// Spelling-tolerant key for Hindi words: collapses doubled letters and
/// drops nukta/chandrabindu differences ("baasath" = "basath",
/// "पाँच" = "पांच").
String _squash(String w) => w
    .replaceAll('़', '') // nukta
    .replaceAll('ँ', 'ं') // chandrabindu → anusvara
    .replaceAll('w', 'v')
    .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

const _english = <String, int>{
  'zero': 0,
  'nil': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fourty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
  'hundred': 100,
  'thousand': 1000,
};

/// Hindi 0–100 is irregular, so each number is listed (romanised spellings
/// first, then Devanagari), plus सौ/हज़ार as multipliers.
final Map<String, int> _hindi = () {
  const words = <int, List<String>>{
    0: ['shunya', 'shoonya', 'शून्य'],
    1: ['ek', 'एक'],
    2: ['do', 'दो'],
    3: ['teen', 'tin', 'तीन'],
    4: ['char', 'chaar', 'चार'],
    5: ['paanch', 'panch', 'पांच', 'पाँच'],
    6: ['chhah', 'chhe', 'chah', 'che', 'छह', 'छः', 'छे'],
    7: ['saat', 'सात'],
    8: ['aath', 'आठ'],
    9: ['nau', 'नौ'],
    10: ['das', 'दस'],
    11: ['gyarah', 'gyara', 'ग्यारह'],
    12: ['barah', 'bara', 'बारह'],
    13: ['terah', 'tera', 'तेरह'],
    14: ['chaudah', 'chauda', 'चौदह'],
    15: ['pandrah', 'pandra', 'पंद्रह', 'पन्द्रह'],
    16: ['solah', 'sola', 'सोलह'],
    17: ['satrah', 'satra', 'सत्रह'],
    18: ['atharah', 'athara', 'अठारह'],
    19: ['unnis', 'unees', 'उन्नीस'],
    20: ['bees', 'bis', 'बीस'],
    21: ['ikkis', 'ikkees', 'इक्कीस'],
    22: ['bais', 'baees', 'बाईस'],
    23: ['teis', 'teyis', 'तेईस'],
    24: ['chaubis', 'chaubees', 'चौबीस'],
    25: ['pachchis', 'pachis', 'pachees', 'पच्चीस'],
    26: ['chhabbis', 'chabbis', 'छब्बीस'],
    27: ['sattais', 'sattaees', 'सत्ताईस'],
    28: ['atthais', 'athais', 'अट्ठाईस', 'अठ्ठाईस'],
    29: ['untis', 'unatis', 'उनतीस'],
    30: ['tees', 'tis', 'तीस'],
    31: ['ikattis', 'iktis', 'इकतीस', 'इकत्तीस'],
    32: ['battis', 'battees', 'बत्तीस'],
    33: ['taintis', 'tentis', 'तैंतीस'],
    34: ['chautis', 'chauntis', 'चौंतीस'],
    35: ['paintis', 'pentis', 'पैंतीस'],
    36: ['chhattis', 'chattis', 'छत्तीस'],
    37: ['saintis', 'sentis', 'सैंतीस'],
    38: ['adtis', 'artis', 'adatis', 'अड़तीस'],
    39: ['untalis', 'unchalis', 'उनतालीस'],
    40: ['chalis', 'chaalis', 'चालीस'],
    41: ['iktalis', 'ikatalis', 'इकतालीस'],
    42: ['bayalis', 'byalis', 'बयालीस'],
    43: ['taintalis', 'tentalis', 'तैंतालीस'],
    44: ['chavalis', 'chauvalis', 'चवालीस', 'चौवालीस'],
    45: ['paintalis', 'pentalis', 'पैंतालीस'],
    46: ['chhiyalis', 'chiyalis', 'छियालीस'],
    47: ['saintalis', 'sentalis', 'सैंतालीस'],
    48: ['adtalis', 'artalis', 'अड़तालीस'],
    49: ['unchas', 'उनचास'],
    50: ['pachas', 'pachaas', 'पचास'],
    51: ['ikyavan', 'ikyaavan', 'इक्यावन'],
    52: ['bavan', 'baavan', 'बावन'],
    53: ['tirpan', 'tirepan', 'तिरपन'],
    54: ['chauvan', 'chauvvan', 'चौवन'],
    55: ['pachpan', 'पचपन'],
    56: ['chhappan', 'chappan', 'छप्पन'],
    57: ['sattavan', 'sattaavan', 'सत्तावन'],
    58: ['atthavan', 'athavan', 'अट्ठावन'],
    59: ['unsath', 'unsaath', 'उनसठ'],
    60: ['saath', 'sath', 'साठ'],
    61: ['iksath', 'iksaath', 'इकसठ'],
    62: ['basath', 'baasath', 'baasat', 'बासठ'],
    63: ['tirsath', 'tiresath', 'तिरसठ'],
    64: ['chausath', 'chaunsath', 'चौंसठ'],
    65: ['painsath', 'pensath', 'पैंसठ'],
    66: ['chhiyasath', 'chiyasath', 'छियासठ'],
    67: ['sadsath', 'sarsath', 'सड़सठ'],
    68: ['adsath', 'arsath', 'अड़सठ'],
    69: ['unhattar', 'unhatar', 'उनहत्तर'],
    70: ['sattar', 'सत्तर'],
    71: ['ikhattar', 'ikahattar', 'इकहत्तर'],
    72: ['bahattar', 'behattar', 'बहत्तर'],
    73: ['tihattar', 'tehattar', 'तिहत्तर'],
    74: ['chauhattar', 'chohattar', 'चौहत्तर'],
    75: ['pachhattar', 'pachattar', 'पचहत्तर'],
    76: ['chhihattar', 'chihattar', 'छिहत्तर'],
    77: ['satattar', 'sathattar', 'सतहत्तर'],
    78: ['athattar', 'athhattar', 'अठहत्तर'],
    79: ['unasi', 'unyasi', 'उन्यासी', 'उनासी'],
    80: ['assi', 'अस्सी'],
    81: ['ikyasi', 'ikkyasi', 'इक्यासी'],
    82: ['bayasi', 'byasi', 'बयासी'],
    83: ['tirasi', 'तिरासी'],
    84: ['chaurasi', 'चौरासी'],
    85: ['pachasi', 'पचासी'],
    86: ['chhiyasi', 'chiyasi', 'छियासी'],
    87: ['sattasi', 'सत्तासी'],
    88: ['athasi', 'atthasi', 'अट्ठासी'],
    89: ['navasi', 'nawasi', 'नवासी'],
    90: ['nabbe', 'nabbey', 'नब्बे'],
    91: ['ikyanve', 'ikyanbe', 'इक्यानबे', 'इक्यानवे'],
    92: ['banve', 'baanbe', 'बानबे', 'बानवे'],
    93: ['tiranve', 'tiraanbe', 'तिरानबे', 'तिरानवे'],
    94: ['chauranve', 'chauraanbe', 'चौरानबे', 'चौरानवे'],
    95: ['pachanve', 'pachaanbe', 'पचानबे', 'पंचानवे'],
    96: ['chhiyanve', 'chiyaanbe', 'छियानबे', 'छियानवे'],
    97: ['sattanve', 'sattaanbe', 'सत्तानबे', 'सत्तानवे'],
    98: ['atthanve', 'athaanbe', 'अट्ठानबे', 'अट्ठानवे'],
    99: ['ninyanve', 'ninyaanbe', 'निन्यानबे', 'निन्यानवे'],
    100: ['sau', 'सौ'],
    1000: ['hazaar', 'hazar', 'hajar', 'हज़ार', 'हजार'],
  };
  return {
    for (final e in words.entries)
      for (final w in e.value) _squash(w): e.key,
  };
}();
