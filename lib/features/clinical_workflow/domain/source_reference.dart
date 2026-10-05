/// Source metadata attached to every clinical question, rule and finding.
///
/// Section numbers refer to `docs/STW_APP_SPEC_FROM_PDFs.md`, the verbatim
/// extraction of the two ICMR/DHR STW PDFs bundled in `assets/pdfs/`.
library;

const rdStwDocument = 'Respiratory Distress in Neonates';
const ropStwDocument = 'Retinopathy of Prematurity (ROP)';

class SourceReference {
  const SourceReference({
    required this.document,
    required this.section,
    this.authority = 'ICMR/DHR',
    this.version = 'August 2026',
    this.needsClinicalReview = false,
    this.note,
  });

  /// Respiratory Distress in Neonates STW (ICD-11 KB23).
  const SourceReference.rd(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
  })  : document = rdStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Retinopathy of Prematurity STW (ICD-11 9B71.3).
  const SourceReference.rop(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
  })  : document = ropStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Data-entry step of the app (e.g. "record a reassessment now?"). Carries
  /// no clinical rule of its own.
  const SourceReference.dataEntry(String this.note)
      : document = 'App data entry',
        section = 'No clinical rule',
        authority = 'STW Neo',
        version = '',
        needsClinicalReview = false;

  final String document;
  final String section;
  final String authority;
  final String version;

  /// Set where the STW wording is ambiguous and the app's reading must be
  /// confirmed (see the open points in the spec, section 6).
  final bool needsClinicalReview;
  final String? note;

  bool get isClinical => document != 'App data entry';

  String get citation => isClinical
      ? '$authority STW "$document" ($version), $section'
      : '$document: ${note ?? section}';
}
