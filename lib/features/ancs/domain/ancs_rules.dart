/// Decision logic of the ICMR/DHR STW "Antenatal Corticosteroids for
/// Preterm Birth" (August 2026). Pure Dart, deterministic.
///
/// Every threshold and outcome comes from the PDF boxes named in the
/// comments; nothing is inferred. Readings that need clinician sign-off are
/// listed in CLINICAL_REVIEW.md.
library;

import 'ancs_content.dart';

/// ELIGIBILITY CRITERIA / WHEN TO GIVE: 24+0 to 33+6 weeks, i.e. completed
/// weeks 24 to 33 (any day count 0–6).
const ancsGaMinWeeks = 24;
const ancsGaMaxWeeks = 33;

/// WHEN NOT TO GIVE: routine use at ≥34 weeks.
const ancsRoutineCutoffWeeks = 34;

/// WHEN TO GIVE REPEAT COURSE: previous course started ≥7 days earlier.
const ancsRepeatMinDays = 7;

/// ELIGIBILITY CRITERIA 1: causes of high likelihood of preterm birth within
/// the next 7 days ("due to any one").
enum AncsCause {
  spontaneousLabour(ancsCauseSpontaneousLabour),
  pprom(ancsCausePprom),
  antepartumHemorrhage(ancsCauseAph),
  severePreEclampsia(ancsCausePreEclampsia),
  plannedPretermBirth(ancsCausePlanned);

  const AncsCause(this.label);
  final String label;
}

/// ACS courses already given in this pregnancy.
enum AncsPreviousCourse {
  none('No previous ACS course'),
  one('One ACS course given (repeat course not yet given)'),
  repeatGiven('A repeat course has already been given');

  const AncsPreviousCourse(this.label);
  final String label;
}

/// SPECIAL SITUATIONS: do not withhold ACS because of these.
enum AncsSpecialSituation {
  multiplePregnancy('Multiple pregnancy'),
  fetalGrowthRestriction('Fetal growth restriction'),
  hypertensiveDisorders('Hypertensive disorders'),
  diabetes('Diabetes in pregnancy');

  const AncsSpecialSituation(this.label);
  final String label;
}

enum AncsDecision {
  /// All five eligibility criteria met, no previous course.
  giveInitial,

  /// Eligibility criteria and repeat-course criteria met.
  giveRepeat,

  /// One or more WHEN NOT TO GIVE items apply.
  doNotGive,

  /// A criterion that is not a WHEN NOT TO GIVE item is not met.
  criteriaNotMet,

  /// Not enough answers yet.
  incomplete,
}

class AncsInput {
  const AncsInput({
    this.gaWeeks,
    this.gaDays,
    this.gaAccurate,
    this.causes,
    this.infection,
    this.childbirthCare,
    this.newbornCare,
    this.previousCourse,
    this.daysSincePrevious,
  });

  final int? gaWeeks;
  final int? gaDays;

  /// Criterion 2.
  final bool? gaAccurate;

  /// Criterion 1; null = not answered, empty = none of the listed causes.
  final Set<AncsCause>? causes;

  /// Criterion 3 (true = chorioamnionitis or systemic infection present).
  final bool? infection;

  /// Criterion 4.
  final bool? childbirthCare;

  /// Criterion 5.
  final bool? newbornCare;
  final AncsPreviousCourse? previousCourse;

  /// Days since the previous course was started (when [previousCourse] is
  /// [AncsPreviousCourse.one]).
  final int? daysSincePrevious;
}

class AncsResult {
  const AncsResult({
    required this.decision,
    this.doNotGiveReasons = const [],
    this.unmetCriteria = const [],
    this.metCriteria = const [],
  });

  final AncsDecision decision;

  /// Matching WHEN NOT TO GIVE lines, verbatim.
  final List<String> doNotGiveReasons;

  /// Eligibility / repeat-course lines that are not met, verbatim.
  final List<String> unmetCriteria;

  /// Eligibility / repeat-course lines that are met, verbatim.
  final List<String> metCriteria;
}

bool ancsGaInWindow(int weeks) =>
    weeks >= ancsGaMinWeeks && weeks <= ancsGaMaxWeeks;

/// High likelihood of preterm birth within the next 7 days (criterion 1).
bool ancsLikely(Set<AncsCause>? causes) => causes != null && causes.isNotEmpty;

AncsResult evaluateAncs(AncsInput i) {
  final doNotGive = <String>[];
  final unmet = <String>[];
  final met = <String>[];
  var missing = false;

  final weeks = i.gaWeeks;
  if (weeks == null) {
    return const AncsResult(decision: AncsDecision.incomplete);
  }
  final inWindow = ancsGaInWindow(weeks);
  if (weeks >= ancsRoutineCutoffWeeks) {
    doNotGive.add(ancsNotGiveRoutine34);
  } else if (weeks < ancsGaMinWeeks) {
    unmet.add('Women at 24+0 to 33+6 weeks of gestation');
  } else {
    met.add('Women at 24+0 to 33+6 weeks of gestation');
  }

  // Outside the window nothing else is asked.
  if (inWindow) {
    final causes = i.causes;
    if (causes == null) {
      missing = true;
    } else if (causes.isEmpty) {
      doNotGive.add(ancsNotGiveUnlikely);
    } else {
      met.add(ancsCriterion1);
    }

    if (ancsLikely(causes)) {
      switch (i.gaAccurate) {
        case null:
          missing = true;
        case true:
          met.add(ancsCriterion2);
        case false:
          unmet.add(ancsCriterion2);
      }
      switch (i.infection) {
        case null:
          missing = true;
        case true:
          doNotGive.add(ancsNotGiveInfection);
        case false:
          met.add(ancsCriterion3);
      }
      switch (i.childbirthCare) {
        case null:
          missing = true;
        case true:
          met.add(ancsCriterion4);
        case false:
          unmet.add(ancsCriterion4);
      }
      switch (i.newbornCare) {
        case null:
          missing = true;
        case true:
          met.add(ancsCriterion5);
        case false:
          unmet.add(ancsCriterion5);
      }
      switch (i.previousCourse) {
        case null:
          missing = true;
        case AncsPreviousCourse.none:
          break;
        case AncsPreviousCourse.repeatGiven:
          doNotGive.add(ancsNotGiveMoreThanOneRepeat);
        case AncsPreviousCourse.one:
          final days = i.daysSincePrevious;
          if (days == null) {
            missing = true;
          } else if (days >= ancsRepeatMinDays) {
            met.add(ancsRepeatSevenDays);
          } else {
            unmet.add(ancsRepeatSevenDays);
          }
      }
    }
  }

  final AncsDecision decision;
  if (doNotGive.isNotEmpty) {
    decision = AncsDecision.doNotGive;
  } else if (unmet.isNotEmpty) {
    decision = AncsDecision.criteriaNotMet;
  } else if (missing) {
    decision = AncsDecision.incomplete;
  } else if (i.previousCourse == AncsPreviousCourse.one) {
    decision = AncsDecision.giveRepeat;
  } else {
    decision = AncsDecision.giveInitial;
  }
  return AncsResult(
    decision: decision,
    doNotGiveReasons: doNotGive,
    unmetCriteria: unmet,
    metCriteria: met,
  );
}

/// "30+2 wk" from the GA answers.
String describeAncsGa(int? weeks, int? days) =>
    weeks == null ? 'GA —' : 'GA $weeks+${days ?? 0} wk';
