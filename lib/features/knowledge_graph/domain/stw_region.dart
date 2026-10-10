/// A box of an STW PDF (`assets/regions/regions.json`). Pure Dart.
library;

class StwRegionInfo {
  const StwRegionInfo({
    required this.id,
    required this.document,
    required this.page,
    required this.text,
  });

  final String id;

  /// PDF file name.
  final String document;
  final int page;

  /// The box's text as extracted from the PDF (see [readableStwText]).
  final String text;
}

/// PDF ligatures (ﬁ, ﬂ) as plain letters; nothing else changes.
String readableStwText(String s) =>
    s.replaceAll('\uFB01', 'fi').replaceAll('\uFB02', 'fl').trim();

/// [s] on one line with single spaces, for verbatim comparisons.
String flatStwText(String s) =>
    readableStwText(s).replaceAll(RegExp(r'\s+'), ' ');
