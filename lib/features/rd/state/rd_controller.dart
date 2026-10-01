import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/baby_context.dart';
import '../domain/rd_rules.dart';
import '../domain/sas.dart';

/// In-memory state of the RD module for the current baby.
class RdState {
  const RdState({
    this.signs = const {},
    this.rr,
    this.immediateDone = const {},
    this.gaKnown = true,
    this.sas = const SasScore(),
    this.severeDistress = false,
    this.recurrentApnea = false,
    this.poorPerfusion = false,
    this.abdominalSigns = false,
    this.support,
    this.peep = 5,
    this.fio2 = 0.21,
    this.spo2,
    this.reSas = const SasScore(),
    this.comfortableBreathing = false,
    this.risingO2Need = false,
    this.apneaBrady = false,
    this.fatigue = false,
    this.shock = false,
    this.deterioration = false,
    this.persistentHypoxemia = false,
    this.sepsisTriggers = const {},
    this.sasHistory = const [],
  });

  // Assess
  final Set<RdSign> signs;
  final int? rr;
  final Set<int> immediateDone;
  final bool gaKnown;
  final SasScore sas;
  final bool severeDistress;
  final bool recurrentApnea;
  final bool poorPerfusion;
  final bool abdominalSigns;

  // Reassess. `support == null` means "use the initial plan's support".
  final RespSupport? support;
  final int peep;
  final double fio2;
  final int? spo2;
  final SasScore reSas;
  final bool comfortableBreathing;
  final bool risingO2Need;
  final bool apneaBrady;
  final bool fatigue;
  final bool shock;
  final bool deterioration;
  final bool persistentHypoxemia;
  final Set<SepsisTrigger> sepsisTriggers;

  /// SAS totals of recorded reassessments, oldest first.
  final List<int> sasHistory;

  RdState copyWith({
    Set<RdSign>? signs,
    int? Function()? rr,
    Set<int>? immediateDone,
    bool? gaKnown,
    SasScore? sas,
    bool? severeDistress,
    bool? recurrentApnea,
    bool? poorPerfusion,
    bool? abdominalSigns,
    RespSupport? support,
    int? peep,
    double? fio2,
    int? Function()? spo2,
    SasScore? reSas,
    bool? comfortableBreathing,
    bool? risingO2Need,
    bool? apneaBrady,
    bool? fatigue,
    bool? shock,
    bool? deterioration,
    bool? persistentHypoxemia,
    Set<SepsisTrigger>? sepsisTriggers,
    List<int>? sasHistory,
  }) =>
      RdState(
        signs: signs ?? this.signs,
        rr: rr != null ? rr() : this.rr,
        immediateDone: immediateDone ?? this.immediateDone,
        gaKnown: gaKnown ?? this.gaKnown,
        sas: sas ?? this.sas,
        severeDistress: severeDistress ?? this.severeDistress,
        recurrentApnea: recurrentApnea ?? this.recurrentApnea,
        poorPerfusion: poorPerfusion ?? this.poorPerfusion,
        abdominalSigns: abdominalSigns ?? this.abdominalSigns,
        support: support ?? this.support,
        peep: peep ?? this.peep,
        fio2: fio2 ?? this.fio2,
        spo2: spo2 != null ? spo2() : this.spo2,
        reSas: reSas ?? this.reSas,
        comfortableBreathing:
            comfortableBreathing ?? this.comfortableBreathing,
        risingO2Need: risingO2Need ?? this.risingO2Need,
        apneaBrady: apneaBrady ?? this.apneaBrady,
        fatigue: fatigue ?? this.fatigue,
        shock: shock ?? this.shock,
        deterioration: deterioration ?? this.deterioration,
        persistentHypoxemia: persistentHypoxemia ?? this.persistentHypoxemia,
        sepsisTriggers: sepsisTriggers ?? this.sepsisTriggers,
        sasHistory: sasHistory ?? this.sasHistory,
      );

  /// Baseline for the SAS trend: last recorded reassessment, else the
  /// initial SAS.
  int? get previousSasTotal => sasHistory.isNotEmpty
      ? sasHistory.last
      : (sas.isComplete ? sas.total : null);
}

class RdController extends Notifier<RdState> {
  @override
  RdState build() => const RdState();

  void setSigns(Set<RdSign> v) => state = state.copyWith(signs: v);

  /// Entering RR auto-ticks / unticks "RR >60/min".
  void setRr(int? rr) {
    var signs = state.signs;
    if (rr != null) {
      signs = rr > 60
          ? {...signs, RdSign.rrAbove60}
          : ({...signs}..remove(RdSign.rrAbove60));
    }
    state = state.copyWith(rr: () => rr, signs: signs);
  }

  void setImmediateDone(Set<int> v) =>
      state = state.copyWith(immediateDone: v);
  void setGaKnown(bool v) => state = state.copyWith(gaKnown: v);
  void setSasGrade(SasItem item, int grade) =>
      state = state.copyWith(sas: state.sas.withGrade(item, grade));
  void clearSas() => state = state.copyWith(sas: const SasScore());
  void setIvFlags({
    bool? severe,
    bool? apnea,
    bool? perfusion,
    bool? abdomen,
  }) =>
      state = state.copyWith(
        severeDistress: severe,
        recurrentApnea: apnea,
        poorPerfusion: perfusion,
        abdominalSigns: abdomen,
      );

  void setSupport(RespSupport v) => state = state.copyWith(support: v);
  void setPeep(int v) => state = state.copyWith(peep: v);
  void setFio2(double v) => state = state.copyWith(fio2: v);
  void setSpo2(int? v) => state = state.copyWith(spo2: () => v);
  void setReSasGrade(SasItem item, int grade) =>
      state = state.copyWith(reSas: state.reSas.withGrade(item, grade));
  void setComfortableBreathing(bool v) =>
      state = state.copyWith(comfortableBreathing: v);
  void setWarnings({
    bool? risingO2Need,
    bool? apneaBrady,
    bool? fatigue,
    bool? shock,
    bool? deterioration,
    bool? persistentHypoxemia,
  }) =>
      state = state.copyWith(
        risingO2Need: risingO2Need,
        apneaBrady: apneaBrady,
        fatigue: fatigue,
        shock: shock,
        deterioration: deterioration,
        persistentHypoxemia: persistentHypoxemia,
      );
  void setSepsisTriggers(Set<SepsisTrigger> v) =>
      state = state.copyWith(sepsisTriggers: v);

  /// Keeps support settings, stores the SAS for the trend, and clears the
  /// per-assessment findings ready for the next reassessment.
  void recordReassessment() {
    if (!state.reSas.isComplete) return;
    state = RdState(
      signs: state.signs,
      rr: state.rr,
      immediateDone: state.immediateDone,
      gaKnown: state.gaKnown,
      sas: state.sas,
      severeDistress: state.severeDistress,
      recurrentApnea: state.recurrentApnea,
      poorPerfusion: state.poorPerfusion,
      abdominalSigns: state.abdominalSigns,
      support: state.support,
      peep: state.peep,
      fio2: state.fio2,
      sasHistory: [...state.sasHistory, state.reSas.total],
    );
  }

  void reset() => state = const RdState();
}

final rdProvider = NotifierProvider<RdController, RdState>(RdController.new);

/// Gestation derived from the shared baby details and the GA-known toggle.
final rdGestationProvider = Provider<Gestation>((ref) {
  final baby = ref.watch(babyProvider);
  final gaKnown = ref.watch(rdProvider.select((s) => s.gaKnown));
  return Gestation(
    gaKnown: gaKnown,
    gaWeeks: baby.gaWeeks,
    gaDays: baby.gaDays,
    birthWeightG: baby.birthWeightG,
  );
});

final rdInitialProvider = Provider<RdInitialResult>((ref) {
  final s = ref.watch(rdProvider);
  return initialPlan(
    signs: s.signs,
    gestation: ref.watch(rdGestationProvider),
    sas: s.sas,
    severeDistress: s.severeDistress,
    recurrentApnea: s.recurrentApnea,
    poorPerfusion: s.poorPerfusion,
    abdominalSigns: s.abdominalSigns,
  );
});

/// Support currently in use: explicit choice, else the initial plan's.
final rdCurrentSupportProvider = Provider<RespSupport>((ref) {
  final explicit = ref.watch(rdProvider.select((s) => s.support));
  return explicit ??
      ref.watch(rdInitialProvider).plan?.support ??
      RespSupport.cpap;
});

final rdReassessProvider = Provider<ReassessOutcome>((ref) {
  final s = ref.watch(rdProvider);
  return reassess(ReassessInput(
    gestation: ref.watch(rdGestationProvider),
    support: ref.watch(rdCurrentSupportProvider),
    peep: s.peep,
    fio2: s.fio2,
    spo2: s.spo2,
    previousSasTotal: s.previousSasTotal,
    sas: s.reSas,
    comfortableBreathing: s.comfortableBreathing,
    risingO2Need: s.risingO2Need,
    recurrentApneaBrady: s.apneaBrady,
    fatigue: s.fatigue,
    shock: s.shock,
    deterioration: s.deterioration,
    persistentHypoxemia: s.persistentHypoxemia,
    sepsisTriggers: s.sepsisTriggers,
  ));
});
