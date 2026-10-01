import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/rd/domain/sas.dart';

void main() {
  test('empty score is incomplete with no severity', () {
    const s = SasScore();
    expect(s.isComplete, isFalse);
    expect(s.total, 0);
    expect(s.severity, isNull);
  });

  test('withGrade builds up a complete score', () {
    var s = const SasScore();
    for (final item in SasItem.values) {
      s = s.withGrade(item, 1);
    }
    expect(s.isComplete, isTrue);
    expect(s.total, 5);
    expect(s.severity, RdSeverity.moderateSevere);
  });

  test('severity bands: mild <=3, moderate-severe >=4', () {
    expect(RdSeverity.fromTotal(0), RdSeverity.mild);
    expect(RdSeverity.fromTotal(3), RdSeverity.mild);
    expect(RdSeverity.fromTotal(4), RdSeverity.moderateSevere);
    expect(RdSeverity.fromTotal(6), RdSeverity.moderateSevere);
    expect(RdSeverity.fromTotal(7), RdSeverity.moderateSevere);
    expect(RdSeverity.fromTotal(10), RdSeverity.moderateSevere);
  });

  test('every item has three grade labels and image assets', () {
    for (final item in SasItem.values) {
      expect(item.gradeLabels, hasLength(3));
      expect(item.imageAsset(2), 'assets/images/sas/${item.assetKey}_2.png');
    }
  });
}
