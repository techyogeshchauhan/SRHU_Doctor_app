/// Silverman-Andersen Score (SAS) — five items, each graded 0, 1 or 2.
///
/// Descriptors are taken verbatim from the SAS chart in the STW
/// "Respiratory Distress in Neonates" (Avery & Fletcher, 1974).
library;

enum SasItem {
  upperChest(
    'Upper chest',
    'upper_chest',
    ['Synchronized', 'Lag on inspiration', 'See-saw'],
  ),
  lowerChest(
    'Lower chest',
    'lower_chest',
    ['No retractions', 'Just visible', 'Marked'],
  ),
  xiphoid(
    'Xiphoid retractions',
    'xiphoid',
    ['None', 'Just visible', 'Marked'],
  ),
  nares(
    'Nares dilatation',
    'nares',
    ['None', 'Minimal', 'Marked'],
  ),
  grunt(
    'Expiratory grunt',
    'grunt',
    ['None', 'Heard with stethoscope', 'Audible'],
  );

  const SasItem(this.title, this.assetKey, this.gradeLabels);

  final String title;
  final String assetKey;

  /// Index = grade (0, 1, 2).
  final List<String> gradeLabels;

  String imageAsset(int grade) => 'assets/images/sas/${assetKey}_$grade.png';
}

/// Severity bands.
///
/// The STW distinguishes Mild (SAS ≤3) from Moderate-severe (SAS ≥4).
enum RdSeverity {
  mild('Mild'),
  moderateSevere('Moderate–severe');

  const RdSeverity(this.label);
  final String label;

  static RdSeverity fromTotal(int total) {
    if (total <= 3) return RdSeverity.mild;
    return RdSeverity.moderateSevere;
  }

  bool get isModerateOrSevere => this == RdSeverity.moderateSevere;
}

/// Immutable SAS entry. Items that have not been graded yet are absent.
class SasScore {
  const SasScore([this.grades = const {}]);

  /// Convenience for tests and presets.
  factory SasScore.of({
    int upperChest = 0,
    int lowerChest = 0,
    int xiphoid = 0,
    int nares = 0,
    int grunt = 0,
  }) =>
      SasScore({
        SasItem.upperChest: upperChest,
        SasItem.lowerChest: lowerChest,
        SasItem.xiphoid: xiphoid,
        SasItem.nares: nares,
        SasItem.grunt: grunt,
      });

  final Map<SasItem, int> grades;

  int? gradeOf(SasItem item) => grades[item];

  SasScore withGrade(SasItem item, int grade) {
    assert(grade >= 0 && grade <= 2);
    return SasScore({...grades, item: grade});
  }

  bool get isComplete => SasItem.values.every(grades.containsKey);

  int get gradedCount => grades.length;

  /// Sum of the graded items (0–10).
  int get total => grades.values.fold(0, (a, b) => a + b);

  /// Null until every item is graded.
  RdSeverity? get severity =>
      isComplete ? RdSeverity.fromTotal(total) : null;
}
