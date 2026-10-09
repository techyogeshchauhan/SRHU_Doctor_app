/// Source metadata attached to every clinical question, rule and finding.
///
/// Section numbers refer to `docs/STW_APP_SPEC_FROM_PDFs.md`, the verbatim
/// extraction of the two ICMR/DHR STW PDFs bundled in `assets/pdfs/`.
library;

const rdStwDocument = 'Respiratory Distress in Neonates';
const ropStwDocument = 'Retinopathy of Prematurity (ROP)';
const ancsStwDocument = 'Antenatal Corticosteroids for Preterm Birth';
const hypoStwDocument = 'Neonatal Hypoglycemia';

class SourceReference {
  const SourceReference({
    required this.document,
    required this.section,
    this.authority = 'ICMR/DHR',
    this.version = 'August 2026',
    this.needsClinicalReview = false,
    this.note,
    this.regionId,
  });

  /// Respiratory Distress in Neonates STW (ICD-11 KB23).
  const SourceReference.rd(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
    this.regionId,
  })  : document = rdStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Retinopathy of Prematurity STW (ICD-11 9B71.3).
  const SourceReference.rop(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
    this.regionId,
  })  : document = ropStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Antenatal Corticosteroids for Preterm Birth STW. [section] is the
  /// heading of the PDF box the content comes from (single-page poster).
  const SourceReference.ancs(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
    this.regionId,
  })  : document = ancsStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Neonatal Hypoglycemia STW (ICD-11 KB60.4). [section] is the heading of
  /// the PDF box the content comes from (single-page poster).
  const SourceReference.hypo(
    this.section, {
    this.needsClinicalReview = false,
    this.note,
    this.regionId,
  })  : document = hypoStwDocument,
        authority = 'ICMR/DHR',
        version = 'August 2026';

  /// Data-entry step of the app (e.g. "record a reassessment now?"). Carries
  /// no clinical rule of its own.
  const SourceReference.dataEntry(String this.note)
      : document = 'App data entry',
        section = 'No clinical rule',
        authority = 'STW Neo',
        version = '',
        needsClinicalReview = false,
        regionId = null;

  final String document;
  final String section;
  final String authority;
  final String version;

  /// Set where the STW wording is ambiguous and the app's reading must be
  /// confirmed (see the open points in the spec, section 6).
  final bool needsClinicalReview;
  final String? note;

  /// Id of the box in `assets/regions/regions.json` this content comes from;
  /// "View in PDF" highlights it.
  final String? regionId;

  bool get isClinical => document != 'App data entry';

  String get citation => isClinical
      ? '$authority STW "$document" ($version), $section'
      : '$document: ${note ?? section}';
}
