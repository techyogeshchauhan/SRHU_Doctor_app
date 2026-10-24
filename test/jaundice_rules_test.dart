import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_content.dart';
import 'package:neonatal_stw/features/jaundice/domain/jaundice_rules.dart';

void main() {
  test('Kramer zones and bands are the printed table', () {
    final printed = jaundiceEvidence['jaundice_kramer']!.skip(1).toList();
    for (final z in KramerZone.values) {
      expect(printed[z.number - 1], '${z.number} ${z.label}: ${z.approxTsb}');
      expect(KramerZone.byNumber(z.number), z);
    }
    expect(KramerZone.byNumber(6), isNull);
  });

  test('ABE, posturing and risk-factor labels are printed in the STW', () {
    final serious =
        jaundiceEvidence['jaundice_serious']!.join(' ').toLowerCase();
    for (final s in AbeSign.values.map((s) => s.label)) {
      for (final word in s.toLowerCase().split('/')) {
        expect(serious, contains(word), reason: s);
      }
    }
    for (final s in PostureSign.values) {
      expect(serious, contains(s.label.toLowerCase()), reason: s.label);
    }
    expect(JaundiceRisk.values.map((r) => r.label),
        jaundiceEvidence['jaundice_risk_factors']);
  });

  test('applies to GA ≥35 weeks only; clinician decides when GA uncertain', () {
    expect(jaundiceStwApplies(gaWeeks: 34), isFalse);
    expect(jaundiceStwApplies(gaWeeks: 35), isTrue);
    expect(jaundiceStwApplies(gaWeeks: 40), isTrue);
    expect(jaundiceStwApplies(clinicianSays35OrMore: true), isTrue);
    expect(jaundiceStwApplies(clinicianSays35OrMore: false), isFalse);
    expect(jaundiceStwApplies(), isNull);
    // A recorded GA wins over the clinician's estimate.
    expect(
        jaundiceStwApplies(gaWeeks: 33, clinicianSays35OrMore: true), isFalse);
  });

  test('jaundice in first 24 hrs', () {
    expect(jaundiceInFirst24h(visibleNow: true, ageHours: 23), isTrue);
    expect(jaundiceInFirst24h(visibleNow: true, ageHours: 24), isFalse);
    expect(jaundiceInFirst24h(visibleNow: false, ageHours: 10), isFalse);
    expect(jaundiceInFirst24h(visibleNow: true), isFalse);
    expect(
        jaundiceInFirst24h(
            visibleNow: true, ageHours: 60, visibleBefore24h: true),
        isTrue);
  });

  group('serious jaundice: any one printed criterion', () {
    test('none', () {
      expect(
          isSeriousJaundice(first24h: false, zone: KramerZone.zone4), isFalse);
    });
    test('visible in first 24 hrs', () {
      expect(isSeriousJaundice(first24h: true, zone: KramerZone.zone1), isTrue);
    });
    test('yellow palms and soles anytime', () {
      expect(
          isSeriousJaundice(first24h: false, zone: KramerZone.zone5), isTrue);
    });
    test('each ABE sign', () {
      for (final s in AbeSign.values) {
        expect(isSeriousJaundice(first24h: false, abe: {s}), isTrue);
      }
    });
    test('each posturing sign', () {
      for (final s in PostureSign.values) {
        expect(isSeriousJaundice(first24h: false, posture: {s}), isTrue);
      }
    });
  });

  test('needs TSB: first 24 hrs, >12-14 visual/TcB, near cut-off, unsure', () {
    expect(needsTsb(first24h: false), isFalse);
    expect(needsTsb(first24h: true), isTrue);
    expect(needsTsb(first24h: false, unsureVisual: true), isTrue);
    expect(needsTsb(first24h: false, nearCutoff: true), isTrue);
    for (final z in KramerZone.values) {
      expect(needsTsb(first24h: false, zone: z), z.number >= 3, reason: '$z');
    }
    for (final (tcb, expected) in [(11.9, false), (12, false), (12.1, true)]) {
      expect(needsTsb(first24h: false, tcb: tcb), expected, reason: '$tcb');
    }
  });

  test('stop phototherapy: below 13-14 mg/dL or 2 mg/dL below cut-off', () {
    expect(meetsStopPhototherapy(tsb: 12.9), isTrue);
    expect(meetsStopPhototherapy(tsb: 13), isFalse);
    expect(meetsStopPhototherapy(tsb: 13.5), isFalse);
    expect(meetsStopPhototherapy(tsb: 15, cutoff: 17), isTrue);
    expect(meetsStopPhototherapy(tsb: 15.1, cutoff: 17), isFalse);
    expect(jaundiceEvidence['jaundice_stop_pt']!.single,
        'TSB falls below 13-14 mg/dL or 2 mg/dL below cut-off');
  });

  test('exchange volume is twice 80-100 mL/kg', () {
    expect(exchangeVolumeMl(2400), (384, 480));
    expect(exchangeVolumeMl(3000), (480, 600));
    expect(jaundiceEvidence['jaundice_optimal_ebt']!.last,
        'Exchange volume = Twice the estimated blood volume of 80-100 mL/kg');
  });
}
