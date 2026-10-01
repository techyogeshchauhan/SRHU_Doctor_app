import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/inputs.dart';
import '../../../shared/baby_context.dart';
import '../domain/rop_rules.dart';

enum FollowUpAssured {
  yes('Yes'),
  no('No'),
  uncertain('Uncertain');

  const FollowUpAssured(this.label);
  final String label;
}

enum Eye {
  right('Right eye (OD)'),
  left('Left eye (OS)');

  const Eye(this.label);
  final String label;
}

/// In-memory state of the ROP wizard for the current baby.
class RopState {
  const RopState({
    this.step = 0,
    this.risks = const {},
    this.followUp,
    this.prepDone = const {},
    this.examDate,
    this.right = const EyeFindings(),
    this.left = const EyeFindings(),
    this.nextExam,
    this.place = '',
    this.counselled = false,
  });

  final int step;
  final Set<RopRiskFactor> risks;
  final FollowUpAssured? followUp;

  /// Checklist ticks: 0.. for "prepare", 100.. for "how to screen".
  final Set<int> prepDone;
  final DateTime? examDate;
  final EyeFindings right;
  final EyeFindings left;
  final DateTime? nextExam;
  final String place;
  final bool counselled;

  EyeFindings eye(Eye e) => e == Eye.right ? right : left;

  RopState copyWith({
    int? step,
    Set<RopRiskFactor>? risks,
    FollowUpAssured? followUp,
    Set<int>? prepDone,
    DateTime? examDate,
    EyeFindings? right,
    EyeFindings? left,
    DateTime? Function()? nextExam,
    String? place,
    bool? counselled,
  }) =>
      RopState(
        step: step ?? this.step,
        risks: risks ?? this.risks,
        followUp: followUp ?? this.followUp,
        prepDone: prepDone ?? this.prepDone,
        examDate: examDate ?? this.examDate,
        right: right ?? this.right,
        left: left ?? this.left,
        nextExam: nextExam != null ? nextExam() : this.nextExam,
        place: place ?? this.place,
        counselled: counselled ?? this.counselled,
      );
}

class RopController extends Notifier<RopState> {
  static const stepCount = 5;

  @override
  RopState build() => const RopState();

  void goTo(int step) =>
      state = state.copyWith(step: step.clamp(0, stepCount - 1));
  void next() => goTo(state.step + 1);
  void back() => goTo(state.step - 1);

  void setRisks(Set<RopRiskFactor> v) => state = state.copyWith(risks: v);
  void setFollowUp(FollowUpAssured v) => state = state.copyWith(followUp: v);
  void setPrepDone(Set<int> v) => state = state.copyWith(prepDone: v);
  void setExamDate(DateTime v) => state = state.copyWith(examDate: v);

  void updateEye(Eye e, EyeFindings f) => state =
      e == Eye.right ? state.copyWith(right: f) : state.copyWith(left: f);

  void copyEye({required Eye from}) {
    final f = state.eye(from);
    state = state.copyWith(right: f, left: f);
  }

  void setNextExam(DateTime? v) => state = state.copyWith(nextExam: () => v);
  void setPlace(String v) => state = state.copyWith(place: v);
  void setCounselled(bool v) => state = state.copyWith(counselled: v);

  void reset() => state = const RopState();
}

final ropProvider =
    NotifierProvider<RopController, RopState>(RopController.new);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

final ropEligibilityProvider = Provider<RopEligibility>((ref) {
  final baby = ref.watch(babyProvider);
  final risks = ref.watch(ropProvider.select((s) => s.risks));
  return ropEligibility(
    gaWeeks: baby.gaWeeks,
    birthWeightG: baby.birthWeightG,
    // Risk factors only count for 34–36 weeks; ignore stale ticks otherwise.
    risks: riskFactorsRelevant(baby.gaWeeks) ? risks : const {},
  );
});

final ropTimingProvider = Provider<FirstScreenTiming?>((ref) {
  final baby = ref.watch(babyProvider);
  final dob = baby.dob;
  if (dob == null) return null;
  return firstScreenTiming(
    dob: dob,
    today: _today(),
    gaWeeks: baby.gaWeeks,
    birthWeightG: baby.birthWeightG,
  );
});

final ropExamDateProvider = Provider<DateTime>(
  (ref) => ref.watch(ropProvider.select((s) => s.examDate)) ?? _today(),
);

/// PMA in completed weeks on the exam date, when GA and DOB are known.
final ropPmaWeeksProvider = Provider<int?>((ref) {
  final baby = ref.watch(babyProvider);
  final ga = baby.gaWeeks;
  final dob = baby.dob;
  if (ga == null || dob == null) return null;
  return pmaDays(
        gaWeeks: ga,
        gaDays: baby.gaDays,
        dob: dob,
        onDate: ref.watch(ropExamDateProvider),
      ) ~/
      7;
});

/// Date the baby reaches 65 weeks PMA (anti-VEGF follow-up horizon).
final ropPma65DateProvider = Provider<DateTime?>((ref) {
  final baby = ref.watch(babyProvider);
  final ga = baby.gaWeeks;
  final dob = baby.dob;
  if (ga == null || dob == null) return null;
  return dateAtPma(
    gaWeeks: ga,
    gaDays: baby.gaDays,
    dob: dob,
    targetWeeks: antiVegfFollowUpPmaWeeks,
  );
});

final ropEyeResultProvider = Provider.family<EyeIndication, Eye>((ref, eye) {
  final f = ref.watch(ropProvider.select((s) => s.eye(eye)));
  return eyeIndication(f, pmaWeeks: ref.watch(ropPmaWeeksProvider));
});


/// Whether the doctor may skip the follow-up plan (both eyes "may stop").
final ropBothMayStopProvider = Provider<bool>((ref) {
  final r = ref.watch(ropEyeResultProvider(Eye.right));
  final l = ref.watch(ropEyeResultProvider(Eye.left));
  return r.action == EyeAction.mayStop && l.action == EyeAction.mayStop;
});

final ropSummaryProvider = Provider<String>((ref) {
  final s = ref.watch(ropProvider);
  final baby = ref.watch(babyProvider);
  return buildRopSummary(
    babyLine: baby.describe(),
    eligibility: ref.watch(ropEligibilityProvider),
    timing: ref.watch(ropTimingProvider),
    examDate: s.right.isEmpty && s.left.isEmpty
        ? null
        : ref.watch(ropExamDateProvider),
    right: s.right,
    left: s.left,
    rightResult: s.right.isEmpty ? null : ref.watch(ropEyeResultProvider(Eye.right)),
    leftResult: s.left.isEmpty ? null : ref.watch(ropEyeResultProvider(Eye.left)),
    nextExamDate: s.nextExam,
    nextExamPlace: s.place,
    familyCounselled: s.counselled,
    formatDate: dateFormat.format,
  );
});
