/// Deterministic understanding of a chatbot question. Pure Dart.
///
/// Finds which STW the question is about, what kind of answer it asks for
/// (dose, timing, contraindication, ...), whether it is negated ("when NOT
/// to give"), and any patient values it carries (BG, GA, SAS, ...). Nothing
/// here produces answer text: answers are verbatim STW text chosen from
/// this analysis.
library;

import 'hinglish_lexicon.dart';

enum StwTopic { rd, rop, ancs, hypo }

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
  for (final e in (hinglishPhrases.entries.toList()
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
  for (final m in RegExp(r"[a-z0-9][a-z0-9'./%+-]*|[<>]=?|[?,]").allMatches(s)) {
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
  r"\b(jaundice|bilirubin|phototherapy|kangaroo|kmc|vaccin\w*|bcg|vitamin k|"
  r"resuscitat\w*|covid\w*|coronavirus|adults?|year old|years old|cancer|"
  r"chemotherap\w*|copd|ards|ketoacidosis|dka|insulin|eczema|cream|lasik|"
  r"coffee|labetalol|magnesium|tocoly\w*|appendectomy|paracetamol|"
  r"phenobarbit\w*|phenytoin|levetiracetam|diabetic retinopathy|sleep apnea|"
  r"weather|cricket|cake|recipe|hypertension with)\b",
);

final _topicPatterns = <StwTopic, RegExp>{
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
};

// ---------------------------------------------------------------------------
// Intents and negation
// ---------------------------------------------------------------------------

final _intentPatterns = <QueryIntent, RegExp>{
  QueryIntent.abbreviation: RegExp(
      r"full form|stands? for|abbreviat\w*|meaning of|what does \S+ mean"),
  QueryIntent.dose: RegExp(
      r"\bdoses?\b|dosage|how much|regimen|\broute\b|\bmg\b|ml/kg|"
      r"pressure|flow|volume|\bdrug|medicine|how many doses"),
  QueryIntent.dos: RegExp(
      r"\bdos\b|\bdo's\b|good practices?|important things|key things|"
      r"best practices?|things to do"),
  QueryIntent.donts: RegExp(
      r"don'?ts|\bdonts\b|mistake|avoid\w*|must not|should not|not be done|"
      r"what not do|routinely|separated?|discharg\w* without"),
  QueryIntent.kpi: RegExp(
      r"\bkpis?\b|indicators?|quality|coverage|compliance|targets? for"),
  QueryIntent.timing: RegExp(
      r"\bwhen\b|how soon|within how|at what|first|timing|how long|"
      r"which weeks|gestational age range|age range|range for"),
  QueryIntent.schedule: RegExp(
      r"how often|frequency|schedule|\bevery\b|interval|\brepeat\b|"
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
      r"what should|what do|\bfed\b|give|therapy|surgery|options|available"),
  QueryIntent.escalate: RegExp(
      r"increase|optimi\w*|step up|maximum|\bmax\b|higher|not improving|"
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
  QueryIntent.documentation: RegExp(
      r"document\w*|record\w*|written|write|discharge card|case sheet"),
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

final _comparator =
    RegExp(r"(above|below|over|under|more than|less than|after|before|>|<)\s*=?\s*$");

int? _num(String? s) => s == null ? null : int.tryParse(s);

/// First number after one of [keys] that is not preceded by a comparator.
int? _valueAfter(String n, String keys, {int maxGap = 25}) {
  final re = RegExp('(?:$keys)([^0-9]{0,$maxGap}?)(\\d{1,4})(?![0-9.]*\\s*(?:weeks?|days?|hours?|%))');
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
      if (!_comparator.hasMatch(before)) e.bg = _num(m.group(1));
    }
  }

  for (final m in RegExp(
    r'(\d{2})(?:\s*\+\s*\d)?\s*-?\s*(?:weeks?|wks?|wk)\b',
  ).allMatches(n)) {
    final before = n.substring(0, m.start);
    final after = n.substring(m.end);
    if (RegExp(r'^\s*pma').hasMatch(after)) continue;
    final cmp = RegExp(r'(above|over|more than|after|>)\s*=?\s*$').hasMatch(before) ||
            RegExp(r'^\s*(above|or more|and above|plus)\b').hasMatch(after)
        ? '>'
        : RegExp(r'(below|under|less than|before|<)\s*=?\s*$').hasMatch(before) ||
                RegExp(r'^\s*(below|or less|and below)\b').hasMatch(after)
            ? '<'
            : null;
    e.gaWeeks = _num(m.group(1));
    e.gaComparator = cmp;
    break;
  }
  e.term = RegExp(r'\bterm (baby|neonate|newborn|infant)').hasMatch(n);

  final w = RegExp(r'(\d{3,4})\s*(?:g|gm|grams?)\b').firstMatch(n);
  e.weightG = _num(w?.group(1)) ?? _valueAfter(n, r'birth weight|\bbw\b', maxGap: 10);
  e.sas = _valueAfter(n, r'\bsas\b', maxGap: 8);
  e.gir = _valueAfter(n, r'\bgir\b', maxGap: 8);
  e.peep = _valueAfter(n, r'\bpeep\b', maxGap: 6);
  final f = RegExp(r'\bfio2\D{0,6}?(0?\.\d+|\d{2,3})').firstMatch(n);
  if (f != null) {
    final v = double.parse(f.group(1)!);
    e.fio2Percent = v <= 1 ? v * 100 : v;
  }
  final d = RegExp(r'(\d{1,2})\s*days?\s*(ago|before|earlier|back)').firstMatch(n);
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
    r'jitter\w*|tremor\w*|letharg\w*|\blimp\w*|stupor|convuls\w*|cyanos\w*|'
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
  e.feedingWell =
      RegExp(r'feeding well|tolerating|enteral feeds').hasMatch(n);
  e.glucoseNormal =
      RegExp(r'(blood glucose|\bbg) (is )?normal|normal blood glucose').hasMatch(n);
  e.glucoseLow = RegExp(r'low blood glucose|blood glucose low|\bbg low|hypoglyc')
      .hasMatch(n);
  e.onCpap = RegExp(r'on cpap').hasMatch(n);
  if (RegExp(r'\bmild\b').hasMatch(n)) {
    e.severityWord = 'mild';
  } else if (RegExp(r'\b(moderate|severe)\b').hasMatch(n)) {
    e.severityWord = 'moderateSevere';
  }
  return e;
}

// ---------------------------------------------------------------------------
// Analysis
// ---------------------------------------------------------------------------

QueryAnalysis analyzeQuery(String query) {
  final n = normalizeQuery(query);
  final oos = _outOfScope.firstMatch(n)?.group(0);
  final topics = {
    for (final e in _topicPatterns.entries)
      if (e.value.hasMatch(n)) e.key,
  };

  // "ya nahi" / "or not" asks yes-or-no, it does not negate.
  final forNegation =
      n.replaceAll(RegExp(r'\bor (no|not)\b'), ' ').replaceAll(
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
  if (d.startsWith('respiratory')) return StwTopic.rd;
  if (d.startsWith('retinopathy')) return StwTopic.rop;
  if (d.startsWith('antenatal')) return StwTopic.ancs;
  if (d.startsWith('neonatal_hypoglycemia')) return StwTopic.hypo;
  return null;
}
