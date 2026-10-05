/// Decision rules for the STW "Retinopathy of Prematurity (ROP)"
/// (ICD-11 9B71.3).
///
/// Pure Dart, no Flutter imports. Gestational age thresholds use completed
/// weeks; days are only used for postmenstrual age (PMA) arithmetic.
library;

// ---------------------------------------------------------------------------
// Whom to screen
// ---------------------------------------------------------------------------

enum RopRiskFactor {
  cardiorespiratorySupport('Significant cardiorespiratory support'),
  prolongedOxygen('Prolonged / poorly controlled oxygen therapy'),
  anemia('Significant anemia'),
  transfusion('Blood transfusion'),
  sepsis('Sepsis'),
  poorWeightGain('Poor postnatal weight gain'),
  unstableCourse('Unstable clinical course');

  const RopRiskFactor(this.label);
  final String label;
}

class RopEligibility {
  const RopEligibility({required this.eligible, required this.reasons});

  /// Null when neither GA nor BW has been entered.
  final bool? eligible;
  final List<String> reasons;
}

/// Screen if ANY ONE: GA <34 weeks; BW <2000 g; GA 34–36 weeks with a
/// specified risk factor or an unstable clinical course.
RopEligibility ropEligibility({
  int? gaWeeks,
  int? birthWeightG,
  Set<RopRiskFactor> risks = const {},
}) {
  if (gaWeeks == null && birthWeightG == null) {
    return const RopEligibility(
      eligible: null,
      reasons: ['Enter gestational age and/or birth weight.'],
    );
  }
  final reasons = <String>[
    if (gaWeeks != null && gaWeeks < 34) 'Gestation $gaWeeks weeks (<34)',
    if (birthWeightG != null && birthWeightG < 2000)
      'Birth weight $birthWeightG g (<2000 g)',
    if (gaWeeks != null && gaWeeks >= 34 && gaWeeks <= 36 && risks.isNotEmpty)
      'Gestation $gaWeeks weeks (34–36) with: '
          '${risks.map((r) => r.label.toLowerCase()).join(', ')}',
  ];
  if (reasons.isNotEmpty) {
    return RopEligibility(eligible: true, reasons: reasons);
  }
  return RopEligibility(
    eligible: false,
    reasons: [
      'None of the STW screening criteria are met'
          '${gaWeeks == null ? ' (GA not entered)' : ''}'
          '${birthWeightG == null ? ' (BW not entered)' : ''}.',
    ],
  );
}

/// Risk factors only matter for GA 34–36 weeks.
bool riskFactorsRelevant(int? gaWeeks) =>
    gaWeeks != null && gaWeeks >= 34 && gaWeeks <= 36;

// ---------------------------------------------------------------------------
// When to screen
// ---------------------------------------------------------------------------

enum FirstScreenStatus {
  notYetDue('Not yet due'),
  overdue('OVERDUE — screen ASAP');

  const FirstScreenStatus(this.label);
  final String label;
}

class FirstScreenTiming {
  const FirstScreenTiming({
    required this.earlyWindow,
    required this.windowStart,
    required this.dueBy,
    required this.postnatalAgeDays,
    required this.status,
  });

  /// True when GA <28 weeks or BW <1200 g (first screen by 2–3 weeks).
  final bool earlyWindow;

  /// Start of the 2–3 week window (early window only).
  final DateTime? windowStart;
  final DateTime dueBy;
  final int postnatalAgeDays;
  final FirstScreenStatus status;

  String get ruleText => earlyWindow
      ? 'GA <28 weeks or BW <1200 g → first screen by 2–3 weeks postnatal age'
      : 'First screen by 4 weeks postnatal age';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime from, DateTime to) =>
    _dateOnly(to).difference(_dateOnly(from)).inDays;

bool usesEarlyWindow({int? gaWeeks, int? birthWeightG}) =>
    (gaWeeks != null && gaWeeks < 28) ||
    (birthWeightG != null && birthWeightG < 1200);

FirstScreenTiming firstScreenTiming({
  required DateTime dob,
  required DateTime today,
  int? gaWeeks,
  int? birthWeightG,
}) {
  final early = usesEarlyWindow(gaWeeks: gaWeeks, birthWeightG: birthWeightG);
  final birth = _dateOnly(dob);
  final dueBy = birth.add(Duration(days: early ? 21 : 28));
  final age = daysBetween(birth, today);
  final daysLeft = daysBetween(today, dueBy);
  final status = daysLeft < 0
      ? FirstScreenStatus.overdue
      : FirstScreenStatus.notYetDue;
  return FirstScreenTiming(
    earlyWindow: early,
    windowStart: early ? birth.add(const Duration(days: 14)) : null,
    dueBy: dueBy,
    postnatalAgeDays: age,
    status: status,
  );
}

/// Postmenstrual age in days = GA at birth + postnatal age.
int pmaDays({
  required int gaWeeks,
  required int gaDays,
  required DateTime dob,
  required DateTime onDate,
}) =>
    gaWeeks * 7 + gaDays + daysBetween(dob, onDate);

String formatWeeksDays(int days) => '${days ~/ 7}+${days % 7} wk';

/// Calendar date on which the baby reaches [targetWeeks] PMA.
DateTime dateAtPma({
  required int gaWeeks,
  required int gaDays,
  required DateTime dob,
  required int targetWeeks,
}) =>
    _dateOnly(dob).add(Duration(days: targetWeeks * 7 - (gaWeeks * 7 + gaDays)));

/// After anti-VEGF, follow up at least until this PMA.
const int antiVegfFollowUpPmaWeeks = 65;

// ---------------------------------------------------------------------------
// Findings and treatment indications (per eye)
// ---------------------------------------------------------------------------

enum RopZone {
  i('Zone I'),
  ii('Zone II'),
  iii('Zone III');

  const RopZone(this.label);
  final String label;
}

enum RetinaStatus {
  immature('Immature retina, no ROP'),
  activeRop('Active ROP'),
  regressed('ROP regressed'),
  fullyVascularised('Retina fully vascularised');

  const RetinaStatus(this.label);
  final String label;
}

class EyeFindings {
  const EyeFindings({
    this.zone,
    this.stage,
    this.plus = false,
    this.prePlus = false,
    this.clockHours,
    this.aRop = false,
    this.progressive = false,
    this.priorAntiVegf = false,
    this.reactivationOrPar = false,
    this.status,
  });

  final RopZone? zone;

  /// 0 = no ROP, 1–5 = ICROP stage.
  final int? stage;
  final bool plus;
  final bool prePlus;

  /// Extent in clock hours (1–12) per ICROP3 / SNCU form.
  final int? clockHours;

  final bool aRop;
  final bool progressive;
  final bool priorAntiVegf;
  final bool reactivationOrPar;
  final RetinaStatus? status;

  bool get isEmpty =>
      zone == null &&
      stage == null &&
      status == null &&
      !aRop &&
      !plus &&
      !prePlus &&
      clockHours == null;

  EyeFindings copyWith({
    RopZone? Function()? zone,
    int? Function()? stage,
    bool? plus,
    bool? prePlus,
    int? Function()? clockHours,
    bool? aRop,
    bool? progressive,
    bool? priorAntiVegf,
    bool? reactivationOrPar,
    RetinaStatus? Function()? status,
  }) =>
      EyeFindings(
        zone: zone != null ? zone() : this.zone,
        stage: stage != null ? stage() : this.stage,
        plus: plus ?? this.plus,
        prePlus: prePlus ?? this.prePlus,
        clockHours: clockHours != null ? clockHours() : this.clockHours,
        aRop: aRop ?? this.aRop,
        progressive: progressive ?? this.progressive,
        priorAntiVegf: priorAntiVegf ?? this.priorAntiVegf,
        reactivationOrPar: reactivationOrPar ?? this.reactivationOrPar,
        status: status != null ? status() : this.status,
      );

  String describe() {
    if (aRop) return 'A-ROP';
    final parts = <String>[
      if (zone != null) zone!.label,
      if (stage != null) stage == 0 ? 'no ROP' : 'stage $stage',
      if (clockHours != null) '$clockHours clock hr',
      if (plus)
        'plus disease'
      else if (prePlus)
        'pre-plus disease',
      if (status != null) status!.label.toLowerCase(),
      if (priorAntiVegf) 'post anti-VEGF',
      if (reactivationOrPar) 'reactivation/PAR',
    ];
    return parts.isEmpty ? 'not examined' : parts.join(', ');
  }
}

enum EyeAction {
  incomplete,
  urgentTreatment,
  surgeryReferral,
  treat,
  observe,
  mayStop,
}

class EyeIndication {
  const EyeIndication({
    required this.action,
    required this.title,
    this.why = const [],
    this.followUp,
  });

  final EyeAction action;
  final String title;
  final List<String> why;

  /// Repeat-screen advice when no treatment is needed.
  final String? followUp;

  bool get needsTreatment =>
      action == EyeAction.urgentTreatment ||
      action == EyeAction.surgeryReferral ||
      action == EyeAction.treat;

  /// Priority for picking the worse eye (higher = more urgent).
  int get severityRank => switch (action) {
        EyeAction.urgentTreatment => 5,
        EyeAction.surgeryReferral => 4,
        EyeAction.treat => 3,
        EyeAction.observe => 2,
        EyeAction.mayStop => 1,
        EyeAction.incomplete => 0,
      };
}

/// Treatment indications, in priority order:
/// A-ROP → urgent; stage 4–5 → surgery referral; reactivation/PAR after
/// anti-VEGF with stage 2–3; Zone I any stage with plus, or stage 3 without
/// plus; Zone II stage 2–3 with plus. Otherwise observe or, when advised,
/// stop.
///
/// [pmaWeeks] (completed weeks) is used to keep babies treated with
/// anti-VEGF under follow-up until 65 weeks PMA.
EyeIndication eyeIndication(EyeFindings f, {int? pmaWeeks}) {
  if (f.aRop) {
    return const EyeIndication(
      action: EyeAction.urgentTreatment,
      title: 'URGENT treatment — Aggressive ROP',
      why: ['Aggressive ROP (A-ROP): urgent treatment'],
    );
  }
  final stage = f.stage;
  if (stage != null && stage >= 4) {
    return EyeIndication(
      action: EyeAction.surgeryReferral,
      title: 'Advanced ROP — refer for vitreo-retinal surgery',
      why: ['Stage $stage (advanced ROP, stage 4–5)'],
    );
  }
  // TO CONFIRM WITH SUPERVISOR: ROP line "Reactivation/significant PAR after anti-VEGF; stage 2-3; stage 4-5" is ambiguous in the PDF.
  // Interpreted as: reactivation with stage 2–3 → treat (4–5 is caught above).
  if (f.priorAntiVegf && f.reactivationOrPar && stage != null && stage >= 2) {
    return EyeIndication(
      action: EyeAction.treat,
      title: 'Treat — reactivation after anti-VEGF',
      why: ['Reactivation / significant PAR after anti-VEGF, stage $stage'],
    );
  }

  final zone = f.zone;
  if (zone == null || stage == null) {
    if (f.status == RetinaStatus.fullyVascularised ||
        f.status == RetinaStatus.regressed) {
      return _stopOrContinue(f, pmaWeeks);
    }
    return const EyeIndication(
      action: EyeAction.incomplete,
      title: 'Select zone and stage',
    );
  }

  if (zone == RopZone.i && stage >= 1 && f.plus) {
    return EyeIndication(
      action: EyeAction.treat,
      title: 'Treatment-requiring ROP',
      why: ['Zone I, stage $stage with plus disease (any stage with plus)'],
    );
  }
  if (zone == RopZone.i && stage == 3) {
    return const EyeIndication(
      action: EyeAction.treat,
      title: 'Treatment-requiring ROP',
      why: ['Zone I, stage 3 without plus disease'],
    );
  }
  if (zone == RopZone.ii && (stage == 2 || stage == 3) && f.plus) {
    return EyeIndication(
      action: EyeAction.treat,
      title: 'Treatment-requiring ROP',
      why: ['Zone II, stage $stage with plus disease'],
    );
  }

  if (stage == 0 &&
      (f.status == RetinaStatus.fullyVascularised ||
          f.status == RetinaStatus.regressed)) {
    return _stopOrContinue(f, pmaWeeks);
  }

  // Posterior (Zone I), progressive disease, or pre-plus → review within 1 week.
  final closeReview = zone == RopZone.i || f.progressive || f.prePlus;
  return EyeIndication(
    action: EyeAction.observe,
    title: 'No treatment indication — continue screening',
    why: [
      '${zone.label}, ${stage == 0 ? 'no ROP' : 'stage $stage'}'
          '${f.plus ? ' with plus' : (f.prePlus ? ' with pre-plus' : '')}: does not meet treatment criteria',
      if (f.prePlus)
        'Pre-plus disease: abnormal vessel tortuosity/dilation present, monitor closely within 1 week',
    ],
    followUp: closeReview
        ? 'Posterior/progressive disease or pre-plus: review within 1 week or sooner.'
        : 'Repeat screen as advised by the ROP-trained ophthalmologist, '
            'usually every 1–3 weeks.',
  );
}

EyeIndication _stopOrContinue(EyeFindings f, int? pmaWeeks) {
  if (f.priorAntiVegf &&
      (pmaWeeks == null || pmaWeeks < antiVegfFollowUpPmaWeeks)) {
    return EyeIndication(
      action: EyeAction.observe,
      title: 'Continue follow-up (post anti-VEGF)',
      why: [
        'After anti-VEGF, follow up at least until '
            '$antiVegfFollowUpPmaWeeks weeks PMA'
            '${pmaWeeks == null ? '' : ' (now $pmaWeeks weeks)'}',
        'Risk of late reactivation and persistent avascular retina (PAR)',
      ],
      followUp: 'Repeat screen as advised by the ROP-trained ophthalmologist.',
    );
  }
  return EyeIndication(
    action: EyeAction.mayStop,
    title: 'Screening may stop — only if advised by ROP-trained ophthalmologist',
    why: [f.status!.label],
  );
}


// ---------------------------------------------------------------------------
// Discharge-card summary (the app is stateless, so this text is the record)
// ---------------------------------------------------------------------------

String buildRopSummary({
  required String babyLine,
  required RopEligibility eligibility,
  String hospitalName = '',
  String sncuNumber = '',
  FirstScreenTiming? timing,
  DateTime? examDate,
  EyeFindings? right,
  EyeFindings? left,
  EyeIndication? rightResult,
  EyeIndication? leftResult,
  DateTime? nextExamDate,
  String nextExamPlace = '',
  bool familyCounselled = false,
  String Function(DateTime)? formatDate,
}) {
  final fmt = formatDate ??
      (DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final b = StringBuffer()
    ..writeln('ROP SCREENING SUMMARY (per ICMR/DHR STW & SNCU Record)')
    ..writeln('Facility: ${hospitalName.trim().isEmpty ? 'SNCU / Neonatal Center' : hospitalName.trim()} | SNCU/CR No: ${sncuNumber.trim().isEmpty ? 'Not documented' : sncuNumber.trim()}')
    ..writeln(babyLine)
    ..writeln(
        'Eligible for screening: ${switch (eligibility.eligible) {
          true => 'YES',
          false => 'NO',
          null => 'not assessed',
        }}')
    ..writeln('  ${eligibility.reasons.join('; ')}');
  // Once an exam is recorded the first-screen deadline is no longer relevant.
  if (timing != null && examDate == null) {
    b.writeln('First screen due by: ${fmt(timing.dueBy)} '
        '(${timing.status.label.toLowerCase()})');
  }
  if (examDate != null) b.writeln('Exam date: ${fmt(examDate)}');
  if (right != null && !right.isEmpty) {
    b.writeln('Right eye: ${right.describe()}'
        '${rightResult == null ? '' : ' → ${rightResult.title}'}');
  }
  if (left != null && !left.isEmpty) {
    b.writeln('Left eye: ${left.describe()}'
        '${leftResult == null ? '' : ' → ${leftResult.title}'}');
  }
  b.writeln('NEXT ROP EXAMINATION: '
      '${nextExamDate == null ? 'NOT DOCUMENTED' : fmt(nextExamDate)}'
      ' at ${nextExamPlace.trim().isEmpty ? 'PLACE NOT DOCUMENTED' : nextExamPlace.trim()}');
  b.writeln('Family counselled on follow-up and risk of vision loss: '
      '${familyCounselled ? 'Yes' : 'No'}');
  return b.toString().trimRight();
}
