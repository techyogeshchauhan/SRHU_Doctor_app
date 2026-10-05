/// Plain-text combined summary for copy/share. Pure Dart.
///
/// Sections carry text already produced by each condition's own engine; this
/// only lays them out.
library;

class SummarySection {
  const SummarySection({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

const combinedSummaryAdvisory =
    'Advisory clinical decision support based on the configured ICMR/DHR STW '
    'content. Management of an individual patient is decided by the '
    'treating physician.';

String buildCombinedSummary({
  required String babyLine,
  required List<String> selectedTitles,
  required List<SummarySection> sections,
}) {
  final b = StringBuffer()
    ..writeln('CLINICAL ASSESSMENT SUMMARY')
    ..writeln(babyLine)
    ..writeln('Selected: ${selectedTitles.join(', ')}');
  for (final s in sections) {
    b
      ..writeln()
      ..writeln('— ${s.title.toUpperCase()} —');
    for (final l in s.lines) {
      b.writeln(l);
    }
  }
  b
    ..writeln()
    ..writeln(combinedSummaryAdvisory);
  return b.toString().trimRight();
}
