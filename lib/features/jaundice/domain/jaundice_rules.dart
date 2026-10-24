/// Only the criteria printed in the supplied Neonatal Jaundice STW
/// (DHR, July 2020, "Neonatal jaundice in infants ≥ 35 weeks"). Pure Dart.
///
/// The STW prints no hour-specific phototherapy / exchange transfusion
/// chart, so nothing here computes a cut-off: whether TSB is at or above the
/// cut-off is recorded by the clinician from the unit's own chart.
library;

/// The STW covers infants of 35 weeks' gestation or more only.
const int jaundiceMinGaWeeks = 35;

/// Kramer zones with the approximate serum bilirubin printed for each.
enum KramerZone {
  zone1(1, 'Face and neck', '4 to 6 mg/dL'),
  zone2(2, 'Chest and upper abdomen', '8 to 10 mg/dL'),
  zone3(3, 'Lower abdomen and thighs', '12 to 14 mg/dL'),
  zone4(4, 'Legs and arms/ forearms', '15 to 18 mg/dL'),
  zone5(5, 'Palms and soles', '>15 to 20 mg/dL');

  const KramerZone(this.number, this.label, this.approxTsb);
  final int number;
  final String label;
  final String approxTsb;

  static KramerZone? byNumber(int n) =>
      values.where((z) => z.number == n).firstOrNull;
}

/// Signs of acute bilirubin encephalopathy (ABE), as printed.
enum AbeSign {
  poorSuck('Poor suck/feeding'),
  lethargy('Lethargy'),
  hypotonia('Hypotonia');

  const AbeSign(this.label);
  final String label;
}

/// Abnormal posturing and related signs, as printed.
enum PostureSign {
  arching('Arching'),
  retrocollis('Retrocollis'),
  opisthotonus('Opisthotonus'),
  convulsion('Convulsion'),
  fever('Fever'),
  highPitchedCry('High pitched cry');

  const PostureSign(this.label);
  final String label;
}

/// "LOOK FOR THESE RISK FACTORS", as printed.
enum JaundiceRisk {
  gestationBelow38('Gestation < 38 weeks'),
  sibling('Previous sibling requiring treatment for jaundice'),
  bloodGroup('Blood group incompatibility (ABO/Rh)'),
  g6pd('High prevalence of G6PD deficiency'),
  weightLoss('Exclusively breast fed baby with weight loss >3% per day; or '
      '>10% cumulative'),
  riskZone('Total serum bilirubin (TSB) / Transcutaneous bilirubin (TcB) '
      'value in the high/ high-intermediate risk zone');

  const JaundiceRisk(this.label);
  final String label;
}

/// True / false when gestation decides whether the STW applies; null when
/// it is not known yet. [gaWeeks] wins; with GA uncertain the clinician's
/// own assessment ([clinicianSays35OrMore]) is used.
bool? jaundiceStwApplies({int? gaWeeks, bool? clinicianSays35OrMore}) =>
    gaWeeks != null ? gaWeeks >= jaundiceMinGaWeeks : clinicianSays35OrMore;

/// "Visible jaundice in first 24 hrs": jaundice is visible now and the baby
/// is under 24 h old, or the clinician records it was visible before 24 h.
bool jaundiceInFirst24h({
  required bool visibleNow,
  int? ageHours,
  bool? visibleBefore24h,
}) =>
    (visibleNow && ageHours != null && ageHours < 24) ||
    visibleBefore24h == true;

/// SERIOUS JAUNDICE: any one of the four printed criteria.
bool isSeriousJaundice({
  required bool first24h,
  KramerZone? zone,
  Set<AbeSign> abe = const {},
  Set<PostureSign> posture = const {},
}) =>
    first24h ||
    zone == KramerZone.zone5 ||
    abe.isNotEmpty ||
    posture.isNotEmpty;

/// The STW prints "more than 12-14 mg/dL". The app reads the band at its
/// lower end so no baby who needs a TSB is missed (needs clinical review).
const double tsbVisualOrTcbThreshold = 12;

/// "Does the infant require TSB measurement?" Any one of:
/// - jaundice in first 24 hrs;
/// - beyond 24 hrs: more than 12-14 mg/dL on visual assessment / TcB, or
///   near the phototherapy cut-off;
/// - unsure about visual assessment.
///
/// Visual assessment uses the Kramer band: zone 3 (12 to 14 mg/dL) and
/// above reach the printed band.
bool needsTsb({
  required bool first24h,
  KramerZone? zone,
  bool unsureVisual = false,
  num? tcb,
  bool nearCutoff = false,
}) =>
    first24h ||
    unsureVisual ||
    nearCutoff ||
    (zone != null && zone.number >= 3) ||
    (tcb != null && tcb > tsbVisualOrTcbThreshold);

/// "TSB falls below 13-14 mg/dL or 2 mg/dL below cut-off". The app uses the
/// lower end of the printed band (13) so phototherapy is never stopped
/// early (needs clinical review). [cutoff] is the unit chart's value, when
/// the clinician enters it.
const double stopPhototherapyTsb = 13;

bool meetsStopPhototherapy({required num tsb, num? cutoff}) =>
    tsb < stopPhototherapyTsb || (cutoff != null && tsb <= cutoff - 2);

/// "Exchange volume = Twice the estimated blood volume of 80-100 mL/kg":
/// (low, high) in mL for [weightG].
(int, int) exchangeVolumeMl(int weightG) {
  final kg = weightG / 1000;
  return ((2 * 80 * kg).round(), (2 * 100 * kg).round());
}
