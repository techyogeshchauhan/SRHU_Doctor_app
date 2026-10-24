/// Deterministic understanding of a chatbot question. Pure Dart.
///
/// Finds which STW the question is about, what kind of answer it asks for
/// (dose, timing, contraindication, ...), whether it is negated ("when NOT
/// to give"), and any patient values it carries (BG, GA, SAS, ...). Nothing
/// here produces answer text: answers are verbatim STW text chosen from
/// this analysis.
library;

import 'hinglish_lexicon.dart';

enum StwTopic {
  rd,
  rop,
  ancs,
  hypo,
  triage,
  kmc,
  sepsis,
  feeding,
  postAsphyxia,
  jaundice
}

/// Kinds of question; regions in assets/regions/regions.json list the ones
/// they answer (tools/annotate_region_intents.py).
enum QueryIntent {
  definition,
  criteria,
  timing,
  contraindication,
  dose,
  schedule,
  procedure,
  management,
  escalate,
  wean,
  stop,
  refer,
  signs,
  prevention,
  dos,
  donts,
  kpi,
  abbreviation,
  documentation,
  followup,
  benefit,
}

/// Patient values found in the question.
class QueryEntities {
  int? bg;

  /// True: symptoms present; false: explicitly none; null: not said.
  bool? symptomatic;
  int? gaWeeks;

  /// '>' / '<' when GA is given as a comparison ("above 34 weeks").
  String? gaComparator;
  bool term = false;
  int? weightG;
  int? sas;
  int? gir;
  int? peep;
  double? fio2Percent;
  int? daysSincePreviousCourse;
  bool repeatCourseGiven = false;
  bool infection = false;
  Set<String> causes = {};
  bool afterFeed = false;
  bool onIv = false;
  bool euglycemic24h = false;
  bool feedingWell = false;
  bool glucoseNormal = false;
  bool glucoseLow = false;
  bool onCpap = false;

  /// Clinician's own severity word: 'mild' or 'moderateSevere'.
  String? severityWord;

  /// "+ days" of a GA written as "36+3 wk".
  int? gaDays;

  /// Respiratory rate (/min).
  int? rr;

  /// Respiratory distress signs described as present (`RdSign` names).
  Set<String> rdSigns = {};

  /// True: jaundice described; false: explicitly absent; null: not said.
  bool? jaundice;

  /// Highest Kramer zone (1–5) the jaundice is described to reach.
  int? kramerZone;

  /// Postnatal age when stated in hours ("36 hrs old").
  int? ageHours;

  /// Day of life when stated as "day 3" / "3 days old".
  int? dayOfLife;

  /// Signs of acute bilirubin encephalopathy (`AbeSign` names) and abnormal
  /// posturing (`PostureSign` names) described as present.
  Set<String> abeSigns = {};
  Set<String> postureSigns = {};

  /// Bilirubin values (mg/dL).
  double? tsb;
  double? tcb;

  /// Values that describe a case (used to offer the guided case entry).
  int get caseValueCount => [
        gaWeeks,
        weightG,
        bg,
        rr,
        kramerZone,
        ageHours ?? dayOfLife,
        tsb,
        tcb,
        if (rdSigns.isNotEmpty) true,
        if (abeSigns.isNotEmpty || postureSigns.isNotEmpty) true,
      ].where((v) => v != null).length;

  bool get hasPatientValue =>
      bg != null ||
      gaWeeks != null ||
      weightG != null ||
      sas != null ||
      gir != null ||
      peep != null ||
      fio2Percent != null ||
      daysSincePreviousCourse != null ||
      repeatCourseGiven ||
      symptomatic != null ||
      glucoseNormal;
}

class QueryAnalysis {
  QueryAnalysis({
    required this.raw,
    required this.normalized,
    required this.topics,
    required this.intents,
    required this.negated,
    required this.entities,
    this.outOfScope,
    this.abbreviation,
    this.abbreviationCandidates = const [],
  });

  final String raw;

  /// Lower-case English(-ised) text used for matching.
  final String normalized;
  final Set<StwTopic> topics;
  final Set<QueryIntent> intents;

  /// Asks what NOT to do / when NOT to give.
  final bool negated;
  final QueryEntities entities;

  /// Why the question is outside the bundled STWs (null: in scope).
  final String? outOfScope;

  /// The abbreviation asked about (lower case), for "full form" questions.
  final String? abbreviation;

  /// Every abbreviation-like word in the question (lower case).
  final List<String> abbreviationCandidates;
}

// ---------------------------------------------------------------------------
// Normalisation
// ---------------------------------------------------------------------------

String _basic(String q) => q
    .toLowerCase()
    .replaceAll('≥', '>=')
    .replaceAll('≤', '<=')
    .replaceAll('₂', '2')
    .replaceAll(RegExp('[–—]'), '-')
    .replaceAll(RegExp('[’‘`]'), "'")
    .replaceAll('ﬁ', 'fi')
    .replaceAll('ﬂ', 'fl')
    .replaceAll('haemorrhage', 'hemorrhage')
    .replaceAll('apnoea', 'apnea')
    .replaceAll('organis', 'organiz')
    .replaceAll('optimis', 'optimiz');

final _phrasePatterns = [
  for (final e
      in (hinglishPhrases.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length))))
    (RegExp('\\b${RegExp.escape(e.key)}\\b'), e.value),
];

/// Lower-case text with Hinglish translated to English words.
String normalizeQuery(String query) {
  var s = _basic(query);
  for (final (re, repl) in _phrasePatterns) {
    s = s.replaceAll(re, repl);
  }
  final out = <String>[];
  for (final m
      in RegExp(r"[a-z0-9][a-z0-9'./%+-]*|[<>]=?|[?,]").allMatches(s)) {
    final w = m.group(0)!;
    final mapped = hinglishWords[w];
    if (mapped == null) {
      out.add(w);
    } else if (mapped.isNotEmpty) {
      out.add(mapped);
    }
  }
  return out.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ---------------------------------------------------------------------------
// Scope and topics
// ---------------------------------------------------------------------------

/// Topics or populations the bundled STWs do not cover.
final _outOfScope = RegExp(
  r"\b(vaccin\w*|bcg|vitamin k|covid\w*|coronavirus|adults?|year old|years old|cancer|"
  r"chemotherap\w*|copd|ards|ketoacidosis|dka|insulin|eczema|cream|lasik|"
  r"coffee|labetalol|magnesium|tocoly\w*|appendectomy|paracetamol|"
  r"diabetic retinopathy|sleep apnea|"
  // The Jaundice STW prints no hour-specific phototherapy / exchange
  // transfusion chart: cut-off values stay out of scope.
  r"phototherapy threshold|threshold for.*phototherapy|bilirubin level|bilirubin cutoff|phototherapy cutoff|"
  r"exchange transfusion threshold|exchange transfusion level|phototherapy chart|phototherapy nomogram|"
  r"(jaundice|bilirubin).*(threshold|cutoff|level|chart)|"
  r"(threshold|cutoff|level|chart).*(phototherapy|exchange)|"
  r"hypothermia management|"
  r"weather|cricket|cake|recipe|hypertension with)\b",
);

final _topicPatterns = <StwTopic, RegExp>{
  StwTopic.jaundice: RegExp(
      r'jaundice|icterus|hyperbilirubin\w*|bilirubin|phototherapy|kramer|'
      r'\btsb\b|\btcb\b|exchange (blood )?transfusion|\bebt\b|'
      r'yellow palms|palms and soles|\bdct\b|coombs'),
  StwTopic.postAsphyxia: RegExp(
      r'post.?asphyxia\w*|perinatal asphyxia|birth asphyxia|\bhie\b|hypoxic.?ischa?emic encephalopathy|sarnat|therapeutic hypothermia'),
  StwTopic.feeding: RegExp(
    r'feeding and nutrition|fluids? (and|&) feeds?|enteral|milk source|donor milk|'
    r'mother.?s own milk|colostrum|fortifi\w*|poor weight gain|gastric residual|'
    r'feeding route|route of feeding|daily fluid|total fluid|day of life|'
    r'feeding frequency|3.hourly|2.hourly|aedf|redf|iron|vitamin d|calcium|'
    r'phosphorus|zinc|nutrition|\blmu\b',
  ),
  StwTopic.sepsis: RegExp(
    r'\bsepsis\b|\bseptic\b|sclerema|blood culture|lumbar puncture|\bcsf\b|'
    r'procalcitonin|yellow flags?|red flags?|antibiotic duration|meningitis',
  ),
  StwTopic.rd: RegExp(
    r"respiratory distress|\brds?\b|breath\w*|\bcpap\b|silverman|\bsas\b|"
    r"surfactant|caffeine|grunt\w*|retraction|flaring|nasal.?prong|\bpeep\b|"
    r"\bfio2\b|\bspo2\b|tachypn\w*|respiratory|\bcrt\b|\btabc\b|ventilat\w*|"
    r"nares|xiphoid|chest x-?ray|\bapnea\b|oxygen",
  ),
  StwTopic.rop: RegExp(
    r"\brop\b|retinopath\w*|\beyes?\b|ophthalm\w*|retina\w*|laser|vegf|"
    r"\bzone\b|plus disease|a-rop|pupils?|phenylephrine|tropicamide|\bpma\b|"
    r"\bpar\b|vision|blind\w*|\bsight\b|tele-?screen\w*",
  ),
  StwTopic.ancs: RegExp(
    r"\bacs\b|antenatal|corticosteroid\w*|steroids?|dexamethasone|"
    r"betamethasone|pprom|preterm labou?r|pregnan\w*|chorioamnionitis|"
    r"eclampsia|antepartum|hemorrhage|\baph\b|in-utero|\bmcp\b|twins?|"
    r"multiple pregnancy|\bfgr\b|fetal growth|deliver\w*|\bwom[ae]n\b|"
    r"(previous|repeat|second|first|steroid|acs) course",
  ),
  StwTopic.hypo: RegExp(
    r"glucose|hypoglyc\w*|dextrose|\bgir\b|\bbg\b|glucometer|\bidm\b|"
    r"diabetic mother|beta.?blocker|euglyc\w*|hydrocortisone|paladai|gavage|"
    r"heel prick|infusion rate",
  ),
  StwTopic.triage: RegExp(
    r"\btriage\b|emergency signs?|priority signs?|non.?urgent|tabc|"
    r"sick or at.?risk neonate|triage classification|shock|dehydrat\w*|"
    r"persistent tachycardia|hypothermia|seizures?|convulsions?|"
    r"phenobarbit\w*|levetiracetam|danger signs|"
    r"jaundice|bilirubin|phototherapy|"
    r"apnea or gasping|central cyanosis|severe pallor|major malformation",
  ),
  StwTopic.kmc: RegExp(
    r"\bkmc\b|kangaroo( mother care| position| nutrition| discharge)?|"
    r"skin.?to.?skin|low.?birth.?weight|\blbw\b|kmc provider|kmc transport|"
    r"kmc follow.?up|alternate caregiver|kmc eligibility",
  ),
};

// ---------------------------------------------------------------------------
// Intents and negation
// ---------------------------------------------------------------------------

final _intentPatterns = <QueryIntent, RegExp>{
  QueryIntent.abbreviation: RegExp(
      r"full form|stands? for|abbreviat\w*|meaning of|what does \S+ mean"),
  QueryIntent.dose:
      RegExp(r"\bdoses?\b|dosage|how much|regimen|\broute\b|\bmg\b|ml/kg|"
          r"pressure|flow|volume|\bdrug|medicine|how many doses"),
  QueryIntent.dos:
      RegExp(r"\bdos\b|\bdo's\b|good practices?|important things|key things|"
          r"best practices?|things to do"),
  QueryIntent.donts: RegExp(
      r"don'?ts|\bdonts\b|mistake|avoid\w*|must not|should not|not be done|"
      r"what not do|routinely|separated?|discharg\w* without"),
  QueryIntent.kpi:
      RegExp(r"\bkpis?\b|indicators?|quality|coverage|compliance|targets? for"),
  QueryIntent.timing:
      RegExp(r"\bwhen\b|how soon|within how|at what|first|timing|how long|"
          r"which weeks|gestational age range|age range|range for"),
  QueryIntent.schedule:
      RegExp(r"how often|frequency|schedule|\bevery\b|interval|\brepeat\b|"
          r"at what hours|before or after|recheck|re-check|check"),
  QueryIntent.criteria: RegExp(
      r"which (babies|newborns?|neonates|women|patients)|\bwhom?\b|\bwho\b|"
      r"eligib\w*|criteria|indicat\w*|need\w*|enough|conditions|"
      r"what counts|cutoff|cut-off|withh?eld|withhold|can \w+ be given|"
      r"can a|is acs|get antenatal|classif\w*|categor\w*"),
  QueryIntent.procedure: RegExp(
      r"how to\b|technique|steps|\bdone\b|examin\w*|arrange\w*|organiz\w*|"
      r"prepar\w*|measure|lens|drops|dilat\w*|pain relief|graded|score|"
      r"pump|peripheral|first steps|before (the )?(\w+ )?(screening|exam\w*)"),
  QueryIntent.management: RegExp(
      r"what to do|what next|treat\w*|manag\w*|support|next step|"
      r"what should|what do|\baction\w*\b|\bfed\b|give|therapy|surgery|options|available"),
  QueryIntent.escalate:
      RegExp(r"increase|optimi\w*|step up|maximum|\bmax\b|higher|not improving|"
          r"still low|not responding"),
  QueryIntent.wean: RegExp(r"wean\w*|taper\w*|reduce|lower|decrease"),
  QueryIntent.stop: RegExp(r"\bstop\w*|discontinu\w*|band|end screening"),
  QueryIntent.refer: RegExp(r"refer\w*|transfer|higher cent\w*|urgently"),
  QueryIntent.signs: RegExp(
      r"\bsigns?\b|symptoms?|features?|recogni[sz]e|identify|getting better|"
      r"improving|worsen\w*|deteriorat\w*|look like|convulsion|suspect\w*|"
      r"how know|what does it mean"),
  QueryIntent.prevention: RegExp(r"prevent\w*|replace|substitute|risk"),
  QueryIntent.definition: RegExp(
      r"what is\b|\bdefin\w*|cutoff|cut-off|threshold|level is|considered|"
      r"what glucose level|disease|what does \w+ reduce|low to low"),
  QueryIntent.documentation:
      RegExp(r"document\w*|record\w*|written|write|discharge card|case sheet"),
  QueryIntent.followup: RegExp(r"follow-?up|developmental"),
  QueryIntent.benefit: RegExp(
      r"\bwhy\b|benefit|useful|important|purpose|main message|reduce in"),
};

/// "When NOT to give", "what should not be done", "avoid", ...
final _negation = RegExp(
  r"\b(should|must|do|does|can|cannot|could)\s+(not|n't)\b|"
  r"\bnot\s+(be\s+)?(give|given|giving|use|used|using|do|done|start|started|"
  r"recommended|indicated)\b|\bwhen not\b|\bwhat not\b|\bavoid\w*\b|"
  r"contraindicat\w*|\bdon'?t\b|\bdonts\b|\bmistake\b|\bnever\b",
);

// ---------------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------------

final _comparator = RegExp(
    r"(above|below|over|under|more than|less than|after|before|>|<)\s*=?\s*$");

int? _num(String? s) => s == null ? null : int.tryParse(s);

/// First number after one of [keys] that is not preceded by a comparator.
int? _valueAfter(String n, String keys, {int maxGap = 25}) {
  final re = RegExp(
      '(?:$keys)([^0-9]{0,$maxGap}?)(\\d{1,4})(?![0-9.]*\\s*(?:weeks?|days?|hours?|%))');
  for (final m in re.allMatches(n)) {
    if (_comparator.hasMatch(m.group(1)!)) continue;
    return _num(m.group(2));
  }
  return null;
}

QueryEntities _entities(String n) {
  final e = QueryEntities();
  e.bg = _valueAfter(n, r'\bbg\b|blood glucose|glucose(?! infusion)');
  if (e.bg == null) {
    final m = RegExp(r'(\d{2,3})\s*mg/?dl').firstMatch(n);
    if (m != null) {
      final before = n.substring(0, m.start);
      // "TSB 18 mg/dL" / "zone 3: 12 to 14 mg/dL" are bilirubin, not BG.
      final bilirubin = RegExp(r'(bilirubin|\btsb\b|\btcb\b|\bsbr?\b|zone|'
              r'kramer|cut-?off|jaundice)\D{0,20}$')
          .hasMatch(before);
      if (!_comparator.hasMatch(before) && !bilirubin) {
        e.bg = _num(m.group(1));
      }
    }
  }

  for (final m in RegExp(
    r'(\d{2})(?:\s*\+\s*(\d))?\s*-?\s*(?:weeks?|wks?|wk)\b',
  ).allMatches(n)) {
    final before = n.substring(0, m.start);
    final after = n.substring(m.end);
    if (RegExp(r'^\s*pma').hasMatch(after)) continue;
    final cmp =
        RegExp(r'(above|over|more than|after|>)\s*=?\s*$').hasMatch(before) ||
                RegExp(r'^\s*(above|or more|and above|plus)\b').hasMatch(after)
            ? '>'
            : RegExp(r'(below|under|less than|before|<)\s*=?\s*$')
                        .hasMatch(before) ||
                    RegExp(r'^\s*(below|or less|and below)\b').hasMatch(after)
                ? '<'
                : null;
    e.gaWeeks = _num(m.group(1));
    e.gaDays = _num(m.group(2));
    e.gaComparator = cmp;
    break;
  }
  e.term = RegExp(r'\bterm (baby|neonate|newborn|infant)').hasMatch(n);

  final w = RegExp(r'(\d{3,4})\s*(?:g|gm|grams?)\b').firstMatch(n);
  final kg = RegExp(r'(?<![\d.])(\d(?:\.\d{1,3})?)\s*(?:kg|kgs|kilos?)\b')
      .firstMatch(n);
  e.weightG = _num(w?.group(1)) ??
      (kg == null ? null : (double.parse(kg.group(1)!) * 1000).round()) ??
      _valueAfter(n, r'birth weight|\bbw\b', maxGap: 10);
  e.sas = _valueAfter(n, r'\bsas\b', maxGap: 8);
  e.gir = _valueAfter(n, r'\bgir\b', maxGap: 8);
  e.peep = _valueAfter(n, r'\bpeep\b', maxGap: 6);
  final f = RegExp(r'\bfio2\D{0,6}?(0?\.\d+|\d{2,3})').firstMatch(n);
  if (f != null) {
    final v = double.parse(f.group(1)!);
    e.fio2Percent = v <= 1 ? v * 100 : v;
  }
  final d =
      RegExp(r'(\d{1,2})\s*days?\s*(ago|before|earlier|back)').firstMatch(n);
  e.daysSincePreviousCourse = _num(d?.group(1));
  e.repeatCourseGiven = RegExp(
    r'already (had|received|given|got) (a |the )?repeat|repeat course (already|was given)',
  ).hasMatch(n);
  e.infection =
      RegExp(r'chorioamnionitis|systemic (maternal )?infection').hasMatch(n);
  e.causes = {
    if (RegExp(r'\bpprom\b').hasMatch(n)) 'pprom',
    if (RegExp(r'antepartum|\baph\b').hasMatch(n)) 'aph',
    if (RegExp(r'eclampsia').hasMatch(n)) 'preEclampsia',
    if (RegExp(r'preterm labou?r').hasMatch(n)) 'labour',
    if (RegExp(r'planned preterm').hasMatch(n)) 'planned',
  };

  final present = RegExp(
    r'jitter\w*|tremor\w*|letharg\w*|\blimp\w*|stupor|seizur\w*|convuls\w*|cyanos\w*|'
    r'tachypn\w*|high-pitched|weak cry|unable to feed|not feeding|\bapnea\b|'
    r'\bsymptomatic\b',
  );
  final absent = RegExp(
    r'no symptoms?|without symptoms?|asymptomatic|symptoms? not|'
    r'not symptomatic|symptom-?free|(newborn|baby) (is )?(completely )?'
    r'(normal|fine|well)\b',
  );
  if (absent.hasMatch(n)) {
    e.symptomatic = false;
  } else if (present.hasMatch(n)) {
    e.symptomatic = true;
  }

  e.afterFeed = RegExp(
    r'after (feeding|feed|a feed|giving a feed)|\d\s*hours? after|'
    r'after \d\s*hours?|recheck|re-check|repeat bg',
  ).hasMatch(n);
  e.onIv = RegExp(
    r'\bon gir\b|\bgir \d|\bon iv\b|iv dextrose|dextrose infusion|on dextrose',
  ).hasMatch(n);
  e.euglycemic24h =
      RegExp(r'normal for 24|euglyc\w* (for )?24|24 hours? normal').hasMatch(n);
  e.feedingWell = RegExp(r'feeding well|tolerating|enteral feeds').hasMatch(n);
  e.glucoseNormal =
      RegExp(r'(blood glucose|\bbg) (is )?normal|normal blood glucose')
          .hasMatch(n);
  e.glucoseLow =
      RegExp(r'low blood glucose|blood glucose low|\bbg low|hypoglyc')
          .hasMatch(n);
  e.onCpap = RegExp(r'on cpap').hasMatch(n);
  if (RegExp(r'\bmild\b').hasMatch(n)) {
    e.severityWord = 'mild';
  } else if (RegExp(r'\b(moderate|severe)\b').hasMatch(n)) {
    e.severityWord = 'moderateSevere';
  }
  _caseEntities(n, e);
  return e;
}

/// "no grunting", "without retractions", "grunting absent", "RR normal".
final _negatedBefore = RegExp(
    r"\b(no|not|nil|without|absent|denies|negative for|free of)\b[^,]{0,30}$");
final _negatedAfter =
    RegExp(r'^[^,]{0,12}\b(absent|not present|not seen|nil|negative|not)\b');

/// True when [re] matches [n] at least once without a negation next to it.
bool _mentioned(String n, RegExp re) => re.allMatches(n).any((m) =>
    !_negatedBefore.hasMatch(n.substring(0, m.start)) &&
    !_negatedAfter.hasMatch(n.substring(m.end)));

final _jaundiceWord =
    RegExp(r'jaundice\w*|icter\w*|yellow\w*|hyperbilirubin\w*|kramer');

/// Body parts the jaundice reaches, highest Kramer zone first. "Hands and
/// feet" (Hinglish "haath pair") is read as palms and soles.
final _kramerParts = <int, RegExp>{
  5: RegExp(r'palms?|soles?|hands and feet'),
  4: RegExp(r'\blegs?\b|\barms?\b|forearms?|limbs?|extremit\w*|knees?|shins?'),
  3: RegExp(r'thighs?|lower abdomen|below (the )?umbilicus|umbilicus'),
  2: RegExp(r'chest(?! (wall|retraction|indrawing|recession|x-?ray))|'
      r'upper abdomen|trunk|abdomen'),
  1: RegExp(r'\bface\b|\bneck\b|\bhead\b|sclera\w*'),
};

/// Highest Kramer zone described in [n]: "kramer 4", "zone 5 jaundice", or
/// the body part reached ("jaundice up to palms and soles"). Body parts
/// count only when [jaundiceContext] is true (else "chest" could be a chest
/// retraction).
int? kramerZoneOf(String n, {required bool jaundiceContext}) {
  final explicit = RegExp(r"kramer'?s?\s*(?:zone)?\s*([1-5])\b|"
          r'\bzone\s*([1-5])\b(?=[^,]{0,20}(jaundice|icter|yellow))|'
          r'(?:jaundice|icter\w*)[^,]{0,20}\bzone\s*([1-5])\b')
      .firstMatch(n);
  if (explicit != null) {
    return int.parse(
        explicit.group(1) ?? explicit.group(2) ?? explicit.group(4)!);
  }
  if (!jaundiceContext) return null;
  for (final e in _kramerParts.entries) {
    if (e.value.hasMatch(n)) return e.key;
  }
  return null;
}

/// Case-history values: RR, RD signs, jaundice extent, age, ABE signs and
/// bilirubin values.
void _caseEntities(String n, QueryEntities e) {
  final rr = _valueAfter(n, r'\brr\b|resp\w* rate|breathing rate|respirations?',
          maxGap: 8) ??
      _num(RegExp(r'(\d{2,3})\s*breaths?\b').firstMatch(n)?.group(1));
  e.rr = rr;

  e.rdSigns = {
    if (_mentioned(n, RegExp(r'grunt\w*'))) 'grunting',
    if (_mentioned(
        n,
        RegExp(r'retraction\w*|indrawing|recession\w*|subcostal|intercostal|'
            r'xiphoid')))
      'retractions',
    if (_mentioned(n, RegExp(r'flaring|nasal flar\w*|alae? nasi')))
      'nasalFlaring',
    if (_mentioned(n, RegExp(r'tachypn\w*|fast breathing|rapid breathing')))
      'rrAbove60',
  };

  final jaundiceSaid = _jaundiceWord.hasMatch(n);
  if (jaundiceSaid) e.jaundice = _mentioned(n, _jaundiceWord);
  e.kramerZone = kramerZoneOf(n, jaundiceContext: e.jaundice == true);

  final hours = RegExp(r'(?<![\d.])(\d{1,3})\s*-?\s*(?:hours?|hrs?|h)\b'
          r'(?!\s*(?:after|before|ago|post|later|apart|interval))')
      .allMatches(n)
      .where((m) => !RegExp(
              r'(every|within|for|after|since|q|in|first|initial|last|past)\s*$')
          .hasMatch(n.substring(0, m.start)))
      .firstOrNull;
  e.ageHours = _num(hours?.group(1));
  final day = RegExp(
          r'\b(?:day of life|day|dol)\s*-?\s*(\d{1,2})\b(?!\s*(?:weeks?|wks?|days?))|'
          r'(\d{1,2})\s*(?:st|nd|rd|th)?\s*day of life|'
          r'(?:aged?\s*)?(\d{1,2})\s*days?\s*(?:old|of life|of age)')
      .firstMatch(n);
  e.dayOfLife = _num(day?.group(1) ?? day?.group(2) ?? day?.group(3));

  e.abeSigns = {
    if (_mentioned(
        n,
        RegExp(r'poor (suck\w*|feed\w*)|not feeding|feeding poorly|'
            r'refus\w* feeds?|unable to feed|poor feeding')))
      'poorSuck',
    if (_mentioned(n, RegExp(r'letharg\w*|drows\w*|sleepy'))) 'lethargy',
    if (_mentioned(n, RegExp(r'hypoton\w*|floppy|\blimp\b'))) 'hypotonia',
  };
  e.postureSigns = {
    if (_mentioned(n, RegExp(r'arching'))) 'arching',
    if (_mentioned(n, RegExp(r'retrocollis'))) 'retrocollis',
    if (_mentioned(n, RegExp(r'opisthoton\w*'))) 'opisthotonus',
    if (_mentioned(n, RegExp(r'convuls\w*|seizur\w*|\bfits?\b'))) 'convulsion',
    if (_mentioned(n, RegExp(r'fever\w*|febrile|pyrexi\w*'))) 'fever',
    if (_mentioned(n, RegExp(r'high.?pitched cry|shrill cry')))
      'highPitchedCry',
  };

  double? value(String keys) {
    final m = RegExp(
            '(?:$keys)\\D{0,8}?(\\d{1,2}(?:\\.\\d)?)(?![\\d.]*\\s*(?:weeks?|wks?|hours?|hrs?|days?|%))')
        .firstMatch(n);
    return m == null ? null : double.parse(m.group(1)!);
  }

  e.tcb = value(r'\btcb\b|transcutaneous bilirubin');
  e.tsb = value(
      r'\btsb\b|\bsbr?\b|(?<!transcutaneous )(?:total |serum )?bilirubin');
}

// ---------------------------------------------------------------------------
// Analysis
// ---------------------------------------------------------------------------

QueryAnalysis analyzeQuery(String query) {
  final n = normalizeQuery(query);
  // The supplied Post Asphyxia poster now covers TH referral management.
  // Keep accidental hypothermia and unsupported populations out of scope.
  final scopeText = n.replaceAll(
      'therapeutic hypothermia management', 'therapeutic hypothermia');
  final oos = _outOfScope.firstMatch(scopeText)?.group(0);
  final topics = {
    for (final e in _topicPatterns.entries)
      if (e.value.hasMatch(n)) e.key,
  };
  if (topics.isEmpty && RegExp(r'\bfeeding\b|\bfeeds\b').hasMatch(n)) {
    topics.add(StwTopic.feeding);
  }
  // An explicit Post Asphyxia request keeps its own source for shared signs.
  // Explicit requests for multiple STWs retain their separate topics.
  final explicitPost = topics.contains(StwTopic.postAsphyxia);
  if (explicitPost &&
      !RegExp(r'\btriage\b|\brop\b|\bancs\b|\bacs\b|kangaroo|\bkmc\b|respiratory distress|\brds?\b|\bhypoglycemia\b|\bsepsis\b|feeding and nutrition|fluids? (and|&) feeds?')
          .hasMatch(n)) {
    topics.removeWhere((t) => t != StwTopic.postAsphyxia);
  }
  // An explicit Feeding/Nutrition request uses its own source. Shared words
  // such as antenatal, PMA, respiratory support or glucose do not select
  // another clinical engine unless that STW is explicitly requested.
  if (!explicitPost &&
      topics.contains(StwTopic.feeding) &&
      !RegExp(r'\btriage\b|\brop\b|\bancs\b|\bacs\b|kangaroo|\bkmc\b|respiratory distress|\brds?\b|hypoglyc\w*|\bsepsis\b')
          .hasMatch(n)) {
    topics.removeWhere((t) => t != StwTopic.feeding);
  }
  // Explicit Sepsis questions use its own source even when its signs or
  // maternal factors also occur in other workflows. Explicit cross-STW
  // requests retain both topics (e.g. sepsis in respiratory distress).
  if (!explicitPost &&
      topics.contains(StwTopic.sepsis) &&
      !RegExp(r'\btriage\b|\brop\b|\bancs\b|\bacs\b|antenatal|kangaroo|\bkmc\b|respiratory distress|\brds?\b|hypoglyc\w*|\bbg\b|\bgir\b')
          .hasMatch(n)) {
    topics.removeWhere((t) => t != StwTopic.sepsis);
  }
  if (topics.contains(StwTopic.triage) &&
      topics.any((topic) => topic != StwTopic.triage) &&
      !RegExp(r'\btriage\b|phenobarbit\w*|levetiracetam').hasMatch(n)) {
    topics.remove(StwTopic.triage);
  }

  // "ya nahi" / "or not" asks yes-or-no, it does not negate.
  final forNegation = n.replaceAll(RegExp(r'\bor (no|not)\b'), ' ').replaceAll(
        RegExp(r'\bnot (improving|responding|known|feeding)\b'),
        ' ',
      );
  final negated = _negation.hasMatch(forNegation);

  final intents = {
    for (final e in _intentPatterns.entries)
      if (e.value.hasMatch(n)) e.key,
  };
  if (negated) {
    // "When not to give / contraindicated" asks for contraindications;
    // "what not to do / avoid" asks for the DON'Ts.
    intents.add(
      RegExp(r'when not|contraindicat\w*|not (be )?giv\w*|not give')
              .hasMatch(forNegation)
          ? QueryIntent.contraindication
          : QueryIntent.donts,
    );
  }
  // "Where is the dose documented?", "first dose before referral?": the
  // dose is the object; documentation / referral is what is asked.
  if (intents.contains(QueryIntent.documentation) ||
      intents.contains(QueryIntent.refer)) {
    intents.remove(QueryIntent.dose);
  }
  final entities = _entities(n);
  // "No symptoms" / "jittery" describe the baby; they do not ask for the
  // list of symptoms.
  if (entities.symptomatic != null &&
      !RegExp(r'\bsigns\b|features|look like').hasMatch(n)) {
    intents.remove(QueryIntent.signs);
  }
  if (intents.contains(QueryIntent.management) &&
      RegExp(r'\baction\w*\b').hasMatch(n)) {
    intents.remove(QueryIntent.signs);
  }

  String? abbreviation;
  var candidates = <String>[];
  if (intents.contains(QueryIntent.abbreviation)) {
    candidates = RegExp(r'\b([A-Za-z][A-Za-z0-9-]{1,6})\b')
        .allMatches(query)
        .map((m) => m.group(1)!)
        .where((w) =>
            w.replaceAll(RegExp(r'[^A-Za-z]'), '').length >= 2 &&
            (w.toUpperCase() == w || RegExp(r'\d|[A-Z].*[A-Z]').hasMatch(w)))
        .where((w) => !const {'STW', 'I', 'A'}.contains(w))
        .map((w) => w.toLowerCase())
        .toList();
    // Prefer the word right after "does"/"of"/"is" ("What does PAR mean").
    final m = RegExp(r'\b(?:does|of|is|form)\s+([A-Za-z][A-Za-z0-9-]{1,6})\b')
        .firstMatch(query);
    final picked = m?.group(1)?.toLowerCase();
    abbreviation = candidates.contains(picked)
        ? picked
        : (candidates.isEmpty ? null : candidates.first);
  }

  return QueryAnalysis(
    raw: query,
    normalized: n,
    topics: topics,
    intents: intents,
    negated: negated,
    entities: entities,
    outOfScope: oos,
    abbreviation: abbreviation,
    abbreviationCandidates: candidates,
  );
}

/// Topic of a region by its document.
StwTopic? topicOfDocument(String document) {
  final d = document.toLowerCase();
  if (d.startsWith('post asphyxia')) return StwTopic.postAsphyxia;
  if (d.startsWith('neonatal jaundice')) return StwTopic.jaundice;
  if (d.startsWith('feeding_nutrition')) return StwTopic.feeding;
  if (d.startsWith('sepsis_')) return StwTopic.sepsis;
  if (d.startsWith('respiratory')) return StwTopic.rd;
  if (d.startsWith('retinopathy')) return StwTopic.rop;
  if (d.startsWith('antenatal')) return StwTopic.ancs;
  if (d.startsWith('neonatal_hypoglycemia')) return StwTopic.hypo;
  if (d.startsWith('triage_')) return StwTopic.triage;
  if (d.startsWith('kmc-')) return StwTopic.kmc;
  return null;
}
