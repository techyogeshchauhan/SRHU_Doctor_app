import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/audit_log_repository.dart';
import '../features/ancs/domain/ancs_content.dart';
import '../features/chatbot/domain/models/stw_chunk.dart';
import '../features/clinical_workflow/domain/source_reference.dart';
import '../features/condition_selection/domain/neonatal_condition.dart';
import '../features/hypoglycemia/domain/hypo_content.dart';
import '../features/references/ui/pdf_viewer_screen.dart' show HighlightTarget;

/// Asset paths and titles for the bundled ICMR / DHR STW PDFs.
const rdPdfAsset = 'assets/pdfs/respiratory_distress_neonates_stw.pdf';
const rdPdfTitle = 'Respiratory Distress in Neonates';

const ropPdfAsset = 'assets/pdfs/retinopathy_of_prematurity_stw.pdf';
const ropPdfTitle = 'Retinopathy of Prematurity (ROP)';
const triagePdfAsset = 'assets/pdfs/Triage_13-10-26.pdf';
const triagePdfTitle = 'Neonatal Emergency Triage Assessment and Management';
const kmcPdfAsset = 'assets/pdfs/KMC-13-10-2026.pdf';
const kmcPdfTitle = 'Kangaroo Mother Care';
const sepsisPdfAsset = 'assets/pdfs/Sepsis_STW_Final_15-10-26.pdf';
const sepsisPdfTitle = 'Sepsis in Neonates';
const feedingPdfAsset = 'assets/pdfs/Feeding_Nutrition Final 22 Oct 26.pdf';
const feedingPdfTitle = 'Feeding and Nutrition in Neonates';
const postAsphyxiaPdfAsset = 'assets/pdfs/Post Asphyxia 16-10-26.pdf';
const postAsphyxiaPdfTitle = 'Post Asphyxia';
const jaundicePdfAsset = 'assets/pdfs/Neonatal Jaundice.pdf';
const jaundicePdfTitle = 'Neonatal Jaundice';

/// A bundled STW PDF.
class StwPdf {
  const StwPdf(this.asset, this.title);
  final String asset;
  final String title;
}

/// The STW PDF of each implemented topic; null for topics without one.
StwPdf? stwPdfFor(NeonatalCondition c) => switch (c) {
      NeonatalCondition.respiratoryDistress =>
        const StwPdf(rdPdfAsset, rdPdfTitle),
      NeonatalCondition.rop => const StwPdf(ropPdfAsset, ropPdfTitle),
      NeonatalCondition.ancs => const StwPdf(ancsPdfAsset, ancsPdfTitle),
      NeonatalCondition.hypoglycemia =>
        const StwPdf(hypoPdfAsset, hypoPdfTitle),
      NeonatalCondition.triage => const StwPdf(triagePdfAsset, triagePdfTitle),
      NeonatalCondition.kmc => const StwPdf(kmcPdfAsset, kmcPdfTitle),
      NeonatalCondition.fluidsAndFeeds =>
        const StwPdf(feedingPdfAsset, feedingPdfTitle),
      NeonatalCondition.sepsis => const StwPdf(sepsisPdfAsset, sepsisPdfTitle),
      NeonatalCondition.hie =>
        const StwPdf(postAsphyxiaPdfAsset, postAsphyxiaPdfTitle),
      NeonatalCondition.jaundice =>
        const StwPdf(jaundicePdfAsset, jaundicePdfTitle),
      _ => null,
    };

/// The STW PDF a [SourceReference.document] refers to.
StwPdf? stwPdfForDocument(String document) => switch (document) {
      rdStwDocument ||
      'respiratory_distress_neonates_stw.pdf' ||
      'Respiratory_Distress_STW_Final 15-10-26.pdf' =>
        stwPdfFor(NeonatalCondition.respiratoryDistress),
      ropStwDocument ||
      'retinopathy_of_prematurity_stw.pdf' ||
      'Retinopathy of Prematurity (ROP).pdf' =>
        stwPdfFor(NeonatalCondition.rop),
      ancsStwDocument ||
      ancsPdfFile ||
      'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf' =>
        stwPdfFor(NeonatalCondition.ancs),
      hypoStwDocument ||
      hypoPdfFile ||
      'Neonatal_Hypoglycemia_8th_Oct.pdf' =>
        stwPdfFor(NeonatalCondition.hypoglycemia),
      triageStwDocument ||
      'Triage_13-10-26.pdf' =>
        stwPdfFor(NeonatalCondition.triage),
      kmcStwDocument ||
      'KMC-13-10-2026.pdf' =>
        stwPdfFor(NeonatalCondition.kmc),
      postAsphyxiaStwDocument ||
      'Post Asphyxia 16-10-26.pdf' =>
        stwPdfFor(NeonatalCondition.hie),
      jaundiceStwDocument ||
      'Neonatal Jaundice.pdf' =>
        stwPdfFor(NeonatalCondition.jaundice),
      feedingStwDocument ||
      'Feeding_Nutrition Final 22 Oct 26.pdf' =>
        stwPdfFor(NeonatalCondition.fluidsAndFeeds),
      sepsisStwDocument ||
      'Sepsis_STW_Final_15-10-26.pdf' =>
        stwPdfFor(NeonatalCondition.sepsis),
      _ => null,
    };

/// Open a bundled STW PDF in the in-app PDF viewer. [origin] (the card or
/// page holding the link) is recorded in the audit trail.
void openStwPdf(
  BuildContext context, {
  required String assetPath,
  required String title,
  String? origin,
}) {
  AuditLog.instance.stwPdfOpened(asset: assetPath, origin: origin);
  context.push(
    '/pdf-viewer?path=${Uri.encodeComponent(assetPath)}&title=${Uri.encodeComponent(title)}',
    extra: {
      'path': assetPath,
      'title': title,
    },
  );
}

const _regionsAsset = 'assets/regions/regions.json';
Map<String, HighlightTarget>? _regionTargets;

/// Frame the cited section on the PDF, including its heading and content.
/// Chat answer excerpts must not turn this into separate line-level frames.
HighlightTarget stwChunkTarget(StwChunk chunk) => HighlightTarget(
      document: chunk.document,
      page: chunk.page,
      normalizedBboxes: [
        for (final b in chunk.boundingBoxes)
          Rect.fromLTWH(b.x, b.y, b.width, b.height),
      ],
      sectionTitle: chunk.sectionTitle,
      regionId: chunk.chunkId,
    );

/// Highlight for region [regionId] of `assets/regions/regions.json`, or null
/// when it is not there.
Future<HighlightTarget?> stwRegionTarget(String regionId) async {
  var targets = _regionTargets;
  if (targets == null) {
    try {
      final raw =
          jsonDecode(await rootBundle.loadString(_regionsAsset)) as List;
      targets = {
        for (final r in raw.cast<Map<String, dynamic>>())
          r['id'] as String: stwChunkTarget(StwChunk.fromJson(r)),
      };
    } catch (_) {
      targets = const {};
    }
    _regionTargets = targets;
  }
  return targets[regionId];
}

/// Open [pdf] scrolled to and highlighting region [regionId]; opens the
/// plain PDF when the region is unknown. [origin] (the card or page holding
/// the link) is recorded in the audit trail.
Future<void> openStwRegion(
  BuildContext context, {
  required StwPdf pdf,
  required String regionId,
  String? origin,
}) async {
  AuditLog.instance
      .stwPdfOpened(asset: pdf.asset, regionId: regionId, origin: origin);
  final resolved = await stwRegionTarget(regionId);
  final target = resolved != null && pdf.asset.endsWith('/${resolved.document}')
      ? resolved
      : null;
  if (!context.mounted) return;
  context.push(
    '/pdf-viewer?path=${Uri.encodeComponent(pdf.asset)}&title=${Uri.encodeComponent(pdf.title)}',
    extra: {
      'path': pdf.asset,
      'title': target?.sectionTitle ?? pdf.title,
      if (target != null) 'highlightTarget': target,
    },
  );
}
