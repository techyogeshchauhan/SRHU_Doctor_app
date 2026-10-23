/// Decisions transcribed from Feeding_Nutrition Final 22 Oct 26.pdf only.
library;

enum FeedingStart { standard, aedf, verySmall }

/// Birth weight <1000 g explicitly overrides the other columns in the PDF.
/// Unknown gestation/flow is never inferred from weight or feeding maturity.
FeedingStart? feedingStart({num? birthGaWeeks, num? birthWeightG, bool? aedf}) {
  if ((birthWeightG != null && birthWeightG < 1000) ||
      (birthGaWeeks != null && birthGaWeeks < 28)) {
    return FeedingStart.verySmall;
  }
  if (birthGaWeeks == null || birthWeightG == null) return null;
  if (birthGaWeeks >= 35) return FeedingStart.standard;
  if (birthGaWeeks >= 28 && birthWeightG >= 1000 && aedf != null) {
    return aedf ? FeedingStart.aedf : FeedingStart.standard;
  }
  return null;
}

/// A starting guide for D1-D7, not an individualized fluid prescription.
/// The source supplies no D8+ table and no rule for resolving unknown GA.
String? feedingFluidGuide({
  required int? dayOfLife,
  num? birthGaWeeks,
  num? birthWeightG,
}) {
  if (dayOfLife == null || dayOfLife < 1 || dayOfLife > 7) return null;
  final small = (birthWeightG != null && birthWeightG < 1000) ||
      (birthGaWeeks != null && birthGaWeeks < 28);
  final other = birthWeightG != null &&
      birthWeightG >= 1000 &&
      birthGaWeeks != null &&
      birthGaWeeks >= 28;
  if (!small && !other) return null;
  return (small
      ? const ['80', '90', '100', '120', '140', '150', '150–160']
      : const [
          '60',
          '80',
          '100',
          '120',
          '140',
          '150',
          '150–160'
        ])[dayOfLife - 1];
}

bool canConsiderThreeHourly({
  required num? pmaWeeks,
  required bool stable,
  required bool fullFeeds,
  required bool offRespiratorySupport,
}) =>
    pmaWeeks != null &&
    pmaWeeks > 32 &&
    stable &&
    fullFeeds &&
    offRespiratorySupport;
