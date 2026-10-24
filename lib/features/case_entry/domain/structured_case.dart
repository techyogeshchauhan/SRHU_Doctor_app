/// Case history entered with selectable fields instead of free text.
/// Pure Dart.
///
/// Options are the existing STW question options (RD signs, Kramer zones,
/// ABE / posturing signs, hypoglycemia risk factors, sepsis flags, post
/// asphyxia risk); no new finding or threshold is introduced. Values are
/// validated against the limits of the questions they pre-fill and are never
/// changed silently: conversions (kg → g, days → hours, °F → °C) are shown
/// with a note. [toParsedCase] uses the same builder as the free-text parser.
library;

import '../../clinical_workflow/domain/clinical_question.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../hypoglycemia/domain/hypo_rules.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../jaundice/domain/jaundice_rules.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../post_asphyxia/domain/post_asphyxia_workflow.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import 'case_parser.dart';

enum GaStatus { known, uncertain, notRecorded }

enum AgeUnit {
  hours('hours'),
  days('days');

  const AgeUnit(this.label);
  final String label;
}

enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F');

  const TemperatureUnit(this.label);
  final String label;
}

/// Yes / No / Unknown answer; null when not answered.
enum YesNoUnknown {
  yes('Yes'),
  no('No'),
  unknown('Unknown / not assessed');

  const YesNoUnknown(this.label);
  final String label;
}

/// Whether respiratory signs were looked for.
enum SignsStatus {
  present('Present (select below)'),
  none('None of these'),
  notAssessed('Not assessed');

  const SignsStatus(this.label);
  final String label;
}

/// RD signs offered on the form: the measured RR decides "RR ≥60/min".
final rdFormSigns = [
  for (final s in RdSign.values)
    if (s != RdSign.rrAbove60) s,
];

/// Field ids, used for validation messages and the form's text fields.
abstract final class CaseField {
  static const gaWeeks = 'gaWeeks';
  static const gaDays = 'gaDays';
  static const birthWeightKg = 'birthWeightKg';
  static const age = 'age';
  static const temperature = 'temperature';
  static const rr = 'rr';
  static const tcb = 'tcb';
  static const tsb = 'tsb';
  static const bg = 'bg';
}

/// Typing limits of each field, from the question it pre-fills.
final _gaRange = (qGaWeeks.min!, qGaWeeks.max!);
final _gaDaysRange = (qGaDays.min!, qGaDays.max!);
final _bwKgRange = (qBirthWeight.min! / 1000, qBirthWeight.max! / 1000);
final _ageHoursRange = (qJaundiceAgeHours.min!, qJaundiceAgeHours.max!);
final _ageDaysRange = (0, qJaundiceAgeHours.max! ~/ 24);
final _rrRange = (qRdRr.min!, qRdRr.max!);
final _bilirubinRange = (qJaundiceTsb.min!, qJaundiceTsb.max!);
final _bgRange = (qHypoBg.min!, qHypoBg.max!);

/// Plausible measured body temperature, a typing check only: the app never
/// classifies a temperature itself (Triage does, when it is run).
const _temperatureRange = {
  TemperatureUnit.celsius: (25.0, 45.0),
  TemperatureUnit.fahrenheit: (77.0, 113.0),
};

class StructuredCase {
  StructuredCase({
    this.gaStatus = GaStatus.notRecorded,
    this.gaWeeks = '',
    this.gaDays = '',
    this.birthWeightKg = '',
    this.age = '',
    this.ageUnit = AgeUnit.hours,
    this.temperature = '',
    this.temperatureUnit = TemperatureUnit.celsius,
    this.rr = '',
    this.rdStatus = SignsStatus.notAssessed,
    Set<String>? rdSigns,
    this.rdEmergency = false,
    this.jaundice,
    this.kramer,
    this.before24h,
    Set<String>? abe,
    Set<String>? posture,
    this.tcb = '',
    this.tsb = '',
    this.bg = '',
    Set<String>? hypoRisks,
    Set<String>? sepsisRed,
    Set<String>? sepsisYellow,
    Set<String>? paRisk,
  })  : rdSigns = rdSigns ?? {},
        abe = abe ?? {},
        posture = posture ?? {},
        hypoRisks = hypoRisks ?? {},
        sepsisRed = sepsisRed ?? {},
        sepsisYellow = sepsisYellow ?? {},
        paRisk = paRisk ?? {};

  GaStatus gaStatus;
  String gaWeeks, gaDays, birthWeightKg, age, temperature, rr;
  AgeUnit ageUnit;
  TemperatureUnit temperatureUnit;
  SignsStatus rdStatus;
  final Set<String> rdSigns;

  /// "Apnoea/gasping, poor effort or shock".
  bool rdEmergency;
  YesNoUnknown? jaundice;

  /// A [KramerZone] name, [kramerUnsure], or null (not assessed).
  String? kramer;
  YesNoUnknown? before24h;
  final Set<String> abe, posture;
  String tcb, tsb, bg;
  final Set<String> hypoRisks, sepsisRed, sepsisYellow, paRisk;

  bool get jaundicePresent => jaundice == YesNoUnknown.yes;

  // ---- Parsing ----

  static int? _int(String s) => int.tryParse(s.trim());
  static double? _dec(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  int? get _ga => gaStatus == GaStatus.known ? _int(gaWeeks) : null;

  /// "Visible in the first 24 hrs?" applies once the baby is 24 h or older
  /// (or the age is not known).
  bool get asksBefore24h {
    if (!jaundicePresent) return false;
    final a = _int(age);
    if (a == null) return true;
    return ageUnit == AgeUnit.days ? a >= 1 : a >= 24;
  }

  /// Validation messages by [CaseField]; empty when every entered value is
  /// acceptable. Empty fields are "not recorded", not errors (except GA
  /// weeks once GA is marked known).
  Map<String, String> validate() {
    final e = <String, String>{};
    void range<T extends num>(String field, String text, T? Function(String) p,
        (num, num) r, String what, String unit,
        {bool required = false}) {
      if (text.trim().isEmpty) {
        if (required) e[field] = 'Enter $what, or choose another option.';
        return;
      }
      final v = p(text);
      if (v == null) {
        e[field] = T == int
            ? 'Enter $what as a whole number.'
            : 'Enter $what as a number.';
      } else if (v < r.$1 || v > r.$2) {
        e[field] = 'Check $what: enter ${_fmt(r.$1)}–${_fmt(r.$2)} $unit.';
      }
    }

    if (gaStatus == GaStatus.known) {
      range(CaseField.gaWeeks, gaWeeks, _int, _gaRange, 'the gestational age',
          'weeks',
          required: true);
      range(CaseField.gaDays, gaDays, _int, _gaDaysRange, 'the extra days',
          'days');
    }
    range(CaseField.birthWeightKg, birthWeightKg, _dec, _bwKgRange,
        'the birth weight', 'kg');
    range(
        CaseField.age,
        age,
        _int,
        ageUnit == AgeUnit.hours ? _ageHoursRange : _ageDaysRange,
        'the age',
        ageUnit.label);
    range(
        CaseField.temperature,
        temperature,
        _dec,
        _temperatureRange[temperatureUnit]!,
        'the temperature',
        temperatureUnit.label);
    range(CaseField.rr, rr, _int, _rrRange, 'the respiratory rate',
        'breaths/min');
    if (jaundicePresent) {
      range(CaseField.tcb, tcb, _dec, _bilirubinRange, 'the TcB', 'mg/dL');
      range(CaseField.tsb, tsb, _dec, _bilirubinRange, 'the TSB', 'mg/dL');
    }
    range(CaseField.bg, bg, _int, _bgRange, 'the blood glucose', 'mg/dL');
    return e;
  }

  static String _fmt(num v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toString();

  // ---- Summary ----

  /// (section, label, value) for every recorded value, as entered.
  List<(String, String, String)> summary() {
    const basic = 'Basic information';
    const temp = 'Temperature';
    const resp = 'Respiratory assessment';
    const jaun = 'Jaundice assessment';
    const other = 'Other findings';
    String labels(Iterable<String> v, List<QuestionOption> options) => [
          for (final o in options)
            if (v.contains('${o.value}')) o.label,
        ].join(', ');
    final zone = KramerZone.values.asNameMap()[kramer];
    return [
      (
        basic,
        'Gestational age',
        switch (gaStatus) {
          GaStatus.known => gaDays.trim().isEmpty
              ? '${gaWeeks.trim()} weeks'
              : '${gaWeeks.trim()}+${gaDays.trim()} weeks',
          GaStatus.uncertain => 'Uncertain',
          GaStatus.notRecorded => 'Not recorded',
        }
      ),
      (
        basic,
        'Birth weight',
        birthWeightKg.trim().isEmpty
            ? 'Not recorded'
            : '${birthWeightKg.trim()} kg'
      ),
      (
        basic,
        'Age',
        age.trim().isEmpty ? 'Not recorded' : '${age.trim()} ${ageUnit.label}'
      ),
      if (temperature.trim().isNotEmpty)
        (temp, 'Temperature', '${temperature.trim()} ${temperatureUnit.label}'),
      if (rr.trim().isNotEmpty)
        (resp, 'Respiratory rate', '${rr.trim()} breaths/min'),
      (
        resp,
        'Respiratory signs',
        switch (rdStatus) {
          SignsStatus.present => rdSigns.isEmpty
              ? 'Present (none selected)'
              : [
                  for (final s in rdFormSigns)
                    if (rdSigns.contains(s.name)) s.label,
                ].join(', '),
          SignsStatus.none => 'None of these',
          SignsStatus.notAssessed => 'Not assessed',
        }
      ),
      if (rdEmergency) (resp, qRdEmergency.question, 'Present'),
      if (jaundice != null)
        (
          jaun,
          'Jaundice',
          switch (jaundice!) {
            YesNoUnknown.yes => 'Present',
            YesNoUnknown.no => 'Absent',
            YesNoUnknown.unknown => 'Unknown / not assessed',
          }
        ),
      if (jaundicePresent) ...[
        (
          jaun,
          'Extent',
          zone != null
              ? 'Zone ${zone.number}: ${zone.label}'
              : kramer == kramerUnsure
                  ? 'Unsure about visual assessment'
                  : 'Not assessed'
        ),
        if (asksBefore24h && before24h != null)
          (jaun, 'Visible in first 24 hrs', before24h!.label),
        if (abe.isNotEmpty)
          (jaun, 'Signs of ABE', labels(abe, qJaundiceAbe.options)),
        if (posture.isNotEmpty)
          (
            jaun,
            'Abnormal posturing',
            labels(posture, qJaundicePosture.options)
          ),
        if (tcb.trim().isNotEmpty) (jaun, 'TcB', '${tcb.trim()} mg/dL'),
        if (tsb.trim().isNotEmpty) (jaun, 'TSB', '${tsb.trim()} mg/dL'),
      ],
      if (bg.trim().isNotEmpty) (other, 'Blood glucose', '${bg.trim()} mg/dL'),
      if (hypoRisks.isNotEmpty)
        (
          other,
          'Hypoglycemia risk factors',
          labels(hypoRisks, hypoRiskOptions)
        ),
      if (sepsisRed.isNotEmpty)
        (other, 'Sepsis red flags', labels(sepsisRed, qSepsisRed.options)),
      if (sepsisYellow.isNotEmpty)
        (
          other,
          'Sepsis yellow signs',
          labels(sepsisYellow, qSepsisYellow.options)
        ),
      if (paRisk.isNotEmpty)
        (other, 'Post asphyxia risk', labels(paRisk, qPaRisk.options)),
    ];
  }

  // ---- To the case-analysis builder ----

  /// The case for the existing analysis. Call only when [validate] is empty.
  ParsedCase toParsedCase() {
    assert(validate().isEmpty, 'toParsedCase() with invalid values');
    final f = CaseFacts();
    final ga = _ga;
    if (ga != null) {
      f.ga = ga;
      f.gaDays = _int(gaDays);
      f.gaSrc = f.gaDays == null ? '$ga weeks' : '$ga+${f.gaDays} weeks';
    } else if (gaStatus == GaStatus.uncertain) {
      f.gaUncertain = true;
      f.gaSrc = 'GA uncertain';
    }
    final kg = _dec(birthWeightKg);
    if (kg != null) {
      f.bw = (kg * 1000).round();
      f.bwSrc = '${birthWeightKg.trim()} kg';
      f.bwNote = 'Entered as ${birthWeightKg.trim()} kg';
    }
    final a = _int(age);
    if (a != null) {
      if (ageUnit == AgeUnit.hours) {
        f.ageHours = a;
        f.ageSrc = '$a hours';
      } else {
        f.ageDays = a;
        f.ageDaysSrc = '$a days';
      }
    }
    final t = _dec(temperature);
    if (t != null) {
      f.temperatureSrc = '${temperature.trim()} ${temperatureUnit.label}';
      if (temperatureUnit == TemperatureUnit.celsius) {
        f.temperatureC = t;
      } else {
        f.temperatureC = ((t - 32) * 5 / 9 * 10).round() / 10;
        f.temperatureNote = 'Entered as ${temperature.trim()} °F, converted '
            'to °C';
      }
    }
    final r = _int(rr);
    if (r != null) {
      f.rr = r;
      f.rrSrc = '$r breaths/min';
    }
    switch (rdStatus) {
      case SignsStatus.present:
        f.rdSigns.addAll(rdSigns);
      case SignsStatus.none:
        f.rdSignsNone = true;
        if (r != null && r >= rrThresholdPerMin) {
          f.notes.add('RR $r/min is itself an RD sign (RR ≥60/min); "none of '
              'these" refers to the other signs.');
        }
      case SignsStatus.notAssessed:
        break;
    }
    f.rdEmergency = rdEmergency;
    switch (jaundice) {
      case YesNoUnknown.yes:
        f.jaundice = true;
        final zone = KramerZone.values.asNameMap()[kramer];
        if (zone != null) {
          f.kramer = zone.number;
          f.kramerSrc = 'Selected: ${zone.label}';
        } else if (kramer == kramerUnsure) {
          f.kramerUnsure = true;
          f.kramerSrc = 'Selected: unsure about visual assessment';
        }
        if (asksBefore24h) {
          f.jaundiceBefore24h = switch (before24h) {
            YesNoUnknown.yes => true,
            YesNoUnknown.no => false,
            _ => null,
          };
        }
        f.abe.addAll(abe);
        f.posture.addAll(posture);
        f.tcb = _dec(tcb);
        f.tcbSrc = '${tcb.trim()} mg/dL';
        f.tsb = _dec(tsb);
        f.tsbSrc = '${tsb.trim()} mg/dL';
      case YesNoUnknown.no:
        f.jaundiceDenied = true;
        f.notes.add('Jaundice recorded as absent.');
      case YesNoUnknown.unknown:
        f.flags.add('Jaundice not assessed: the Jaundice STW is not selected. '
            'Add it on the next screen if it applies.');
      case null:
        break;
    }
    final g = _int(bg);
    if (g != null) {
      f.bg = g;
      f.bgSrc = '$g mg/dL';
    }
    f.hypoRisks.addAll(hypoRisks);
    f.sepsisRed.addAll(sepsisRed);
    f.sepsisYellow.addAll(sepsisYellow);
    f.paRisk.addAll(paRisk);
    final text = [for (final (_, l, v) in summary()) '$l: $v'].join('; ');
    return buildCase(f, text);
  }
}

/// Hypoglycemia "whom to screen" options as question options.
final hypoRiskOptions = [
  for (final r in HypoRisk.values) QuestionOption(r.name, r.label),
];
