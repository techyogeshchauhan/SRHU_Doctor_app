import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/rd/domain/rd_rules.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';

const _signs = {RdSign.grunting};

SasScore _sas(int total) {
  // Spread [total] over the five items (max 2 each).
  final grades = List<int>.filled(5, 0);
  var left = total;
  for (var i = 0; i < 5 && left > 0; i++) {
    grades[i] = left >= 2 ? 2 : 1;
    left -= grades[i];
  }
  return SasScore.of(
    upperChest: grades[0],
    lowerChest: grades[1],
    xiphoid: grades[2],
    nares: grades[3],
    grunt: grades[4],
  );
}

RdInitialPlan _plan(Gestation g, SasScore sas,
    {bool severeDistress = false,
    bool apnea = false,
    bool perfusion = false,
    bool abdomen = false}) {
  final r = initialPlan(
    signs: _signs,
    gestation: g,
    sas: sas,
    severeDistress: severeDistress,
    recurrentApnea: apnea,
    poorPerfusion: perfusion,
    abdominalSigns: abdomen,
  );
  expect(r.pending, isNull, reason: r.pending);
  return r.plan!;
}

void main() {
  group('diagnosis and pending inputs', () {
    test('no signs → pending', () {
      final r = initialPlan(
          signs: {}, gestation: const Gestation(gaWeeks: 30), sas: _sas(5));
      expect(r.plan, isNull);
      expect(r.pending, contains('Tick at least one sign'));
    });

    test('no GA → pending', () {
      final r = initialPlan(
          signs: _signs, gestation: const Gestation(), sas: _sas(5));
      expect(r.pending, 'Enter gestational age.');
    });

    test('GA >34 with incomplete SAS → pending', () {
      final r = initialPlan(
        signs: _signs,
        gestation: const Gestation(gaWeeks: 36),
        sas: const SasScore({SasItem.grunt: 2}),
      );
      expect(r.pending, contains('1/5 graded'));
    });

    test('GA ≤34 does not need a complete SAS', () {
      final r = initialPlan(
        signs: _signs,
        gestation: const Gestation(gaWeeks: 30),
        sas: const SasScore(),
      );
      expect(r.plan!.support, RespSupport.cpap);
    });
  });

  group('initial support', () {
    test('GA 32 + mild SAS → CPAP + caffeine', () {
      final p = _plan(const Gestation(gaWeeks: 32), _sas(2));
      expect(p.support, RespSupport.cpap);
      expect(p.caffeine, CaffeineAdvice.indicated);
      expect(p.feeding, FeedingAdvice.gastricTube);
    });

    test('GA exactly 34 → CPAP but no caffeine', () {
      final p = _plan(const Gestation(gaWeeks: 34, gaDays: 5), _sas(2));
      expect(p.support, RespSupport.cpap);
      expect(p.caffeine, CaffeineAdvice.notIndicated);
    });

    test('GA 36 + SAS 5 → CPAP', () {
      final p = _plan(const Gestation(gaWeeks: 36), _sas(5));
      expect(p.support, RespSupport.cpap);
      expect(p.severity, RdSeverity.moderateSevere);
    });

    test('GA 36 + SAS 4 (boundary) → CPAP', () {
      expect(_plan(const Gestation(gaWeeks: 36), _sas(4)).support,
          RespSupport.cpap);
    });

    test('GA 36 + SAS 3 → nasal O₂, breastfeed, no routine labs', () {
      final p = _plan(const Gestation(gaWeeks: 36), _sas(3));
      expect(p.support, RespSupport.nasalO2);
      expect(p.feeding, FeedingAdvice.directBreastfeed);
      expect(p.avoid.join(), contains('CBC, CRP'));
    });

    test('GA uncertain + BW 1700 g → CPAP via surrogate, confirm GA for caffeine',
        () {
      final p = _plan(
          const Gestation(gaKnown: false, birthWeightG: 1700), _sas(1));
      expect(p.support, RespSupport.cpap);
      expect(p.caffeine, CaffeineAdvice.confirmGa);
      expect(p.why.first, contains('surrogate'));
    });

    test('GA uncertain + BW 1800 g (boundary) → treated as ≤34', () {
      expect(
          _plan(const Gestation(gaKnown: false, birthWeightG: 1800), _sas(1))
              .support,
          RespSupport.cpap);
    });

    test('GA uncertain + BW 2500 g + mild → nasal O₂', () {
      expect(
          _plan(const Gestation(gaKnown: false, birthWeightG: 2500), _sas(2))
              .support,
          RespSupport.nasalO2);
    });
  });

  group('IV fluids', () {
    test('severe distress checkbox → IV fluids', () {
      final p = _plan(const Gestation(gaWeeks: 37), _sas(8), severeDistress: true);
      expect(p.ivFluids, isTrue);
      expect(p.feeding, FeedingAdvice.ivFluids);
      expect(p.ivFluidReasons, contains('Severe distress (clinician judgement)'));
    });

    test('no IV fluids from SAS 8 alone (without severeDistress checkbox)', () {
      final p = _plan(const Gestation(gaWeeks: 37), _sas(8), severeDistress: false);
      expect(p.ivFluids, isFalse);
      expect(p.ivFluidReasons, isEmpty);
      expect(p.avoid.join(), contains('IV fluids'));
    });

    test('poor perfusion → IV fluids even when mild', () {
      final p =
          _plan(const Gestation(gaWeeks: 37), _sas(2), perfusion: true);
      expect(p.ivFluidReasons, ['Poor perfusion']);
    });

    test('no IV reasons → "do not give IV fluids routinely"', () {
      final p = _plan(const Gestation(gaWeeks: 37), _sas(5));
      expect(p.ivFluids, isFalse);
      expect(p.avoid.join(), contains('IV fluids'));
    });
  });

  group('reassessment', () {
    const preterm = Gestation(gaWeeks: 30);

    test('surfactant: <34 wk on CPAP, PEEP 7, FiO₂ 0.35', () {
      final o = reassess(const ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 7,
        fio2: 0.35,
        spo2: 92,
      ));
      expect(o.status, ReassessStatus.surfactant);
    });

    test('no surfactant when FiO₂ 0.28', () {
      final i = ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 7,
        fio2: 0.28,
        spo2: 92,
        sas: _sas(3),
        previousSasTotal: 5,
        comfortableBreathing: true,
      );
      expect(meetsSurfactantCriteria(i), isFalse);
      expect(reassess(i).status, ReassessStatus.improving);
    });

    test('no surfactant at FiO₂ exactly 0.30 or PEEP 6', () {
      expect(
          meetsSurfactantCriteria(const ReassessInput(
              gestation: preterm,
              support: RespSupport.cpap,
              peep: 7,
              fio2: 0.30)),
          isFalse);
      expect(
          meetsSurfactantCriteria(const ReassessInput(
              gestation: preterm,
              support: RespSupport.cpap,
              peep: 6,
              fio2: 0.40)),
          isFalse);
    });

    test('no surfactant at GA 34', () {
      expect(
          meetsSurfactantCriteria(const ReassessInput(
              gestation: Gestation(gaWeeks: 34),
              support: RespSupport.cpap,
              peep: 7,
              fio2: 0.40)),
          isFalse);
    });

    test('recurrent apnea on CPAP → CPAP failure', () {
      final o = reassess(const ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        recurrentApneaBrady: true,
      ));
      expect(o.status, ReassessStatus.cpapFailure);
    });

    test('no auto CPAP failure at SpO2 88 PEEP 8 unless a failure checkbox is ticked', () {
      final o = reassess(const ReassessInput(
        gestation: Gestation(gaWeeks: 36),
        support: RespSupport.cpap,
        peep: 8,
        fio2: 0.25,
        spo2: 88,
      ));
      expect(o.status, ReassessStatus.notImproving);
      expect(o.status, isNot(ReassessStatus.cpapFailure));

      final oFailure = reassess(const ReassessInput(
        gestation: Gestation(gaWeeks: 36),
        support: RespSupport.cpap,
        peep: 8,
        fio2: 0.25,
        spo2: 88,
        persistentHypoxemia: true,
      ));
      expect(oFailure.status, ReassessStatus.cpapFailure);
    });

    test('SpO₂ <91 at PEEP 6 → optimise CPAP, suggest PEEP 7', () {
      final o = reassess(ReassessInput(
        gestation: const Gestation(gaWeeks: 36),
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.25,
        spo2: 88,
        sas: _sas(5),
        previousSasTotal: 5,
      ));
      expect(o.status, ReassessStatus.notImproving);
      expect(o.actions.first, contains('6 → 7'));
    });

    test('increasing SAS on nasal O₂ → NOT IMPROVING / WORSENING (no invented escalate to CPAP)', () {
      final o = reassess(ReassessInput(
        gestation: const Gestation(gaWeeks: 37),
        support: RespSupport.nasalO2,
        spo2: 93,
        sas: _sas(3),
        previousSasTotal: 2,
      ));
      expect(o.status, ReassessStatus.notImproving);
      expect(o.title, 'NOT IMPROVING / WORSENING');
    });

    test('improving on CPAP with FiO₂ 0.30 → wean FiO₂ first', () {
      final o = reassess(ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.30,
        spo2: 94,
        sas: _sas(2),
        previousSasTotal: 5,
        comfortableBreathing: true,
      ));
      expect(o.status, ReassessStatus.improving);
      expect(o.actions.first, contains('Wean FiO₂ first'));
    });

    test('FiO₂ 0.21 + PEEP 6 → reduce to 5', () {
      expect(cpapWeanSteps(peep: 6, fio2: 0.21).first, contains('6 → 5'));
    });

    test('FiO₂ 0.21 + PEEP 5 → stop CPAP, monitor 24 h', () {
      final steps = cpapWeanSteps(peep: 5, fio2: 0.21);
      expect(steps.first, contains('stop CPAP'));
      expect(steps.last, contains('24 h'));
    });

    test('SpO₂ above 95 raises an alert', () {
      final o = reassess(ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        fio2: 0.25,
        spo2: 98,
        sas: _sas(1),
        previousSasTotal: 3,
        comfortableBreathing: true,
      ));
      expect(o.alerts.join(), contains('above target range (91–95%)'));
    });

    test('SAS 8 -> 5 with SpO2 93 and comfortable breathing = improving', () {
      final o = reassess(ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.25,
        spo2: 93,
        sas: _sas(5),
        previousSasTotal: 8,
        comfortableBreathing: true,
      ));
      expect(o.status, ReassessStatus.improving);
      expect(o.why, contains('SAS decreasing (8 → 5)'));
    });

    test('SAS 8 -> 5 without comfortable breathing = not improving', () {
      final o = reassess(ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.25,
        spo2: 93,
        sas: _sas(5),
        previousSasTotal: 8,
        comfortableBreathing: false,
      ));
      expect(o.status, isNot(ReassessStatus.improving));
      expect(o.status, ReassessStatus.stable);
    });

    test('SAS 3 with no previous SAS must NOT show improving', () {
      final o = reassess(ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        peep: 6,
        fio2: 0.25,
        spo2: 93,
        sas: _sas(3),
        previousSasTotal: null,
        comfortableBreathing: true,
      ));
      expect(o.status, isNot(ReassessStatus.improving));
      expect(o.status, ReassessStatus.stable);
    });

    test('sepsis trigger raises an alert', () {
      final o = reassess(const ReassessInput(
        gestation: preterm,
        support: RespSupport.cpap,
        sepsisTriggers: {SepsisTrigger.perinatalRisk},
      ));
      expect(o.alerts.join(), contains('Consider sepsis'));
    });

    test('missing SpO₂ and SAS → incomplete', () {
      final o = reassess(const ReassessInput(
          gestation: preterm, support: RespSupport.cpap));
      expect(o.status, ReassessStatus.incomplete);
    });

    test('off support with desaturation → distress recurring', () {
      final o = reassess(const ReassessInput(
        gestation: preterm,
        support: RespSupport.none,
        spo2: 88,
      ));
      expect(o.status, ReassessStatus.notImproving);
    });
  });
}
