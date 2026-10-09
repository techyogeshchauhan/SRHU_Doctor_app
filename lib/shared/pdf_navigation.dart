import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../features/ancs/domain/ancs_content.dart';
import '../features/clinical_workflow/domain/source_reference.dart';
import '../features/condition_selection/domain/neonatal_condition.dart';
import '../features/hypoglycemia/domain/hypo_content.dart';
import '../features/references/ui/pdf_viewer_screen.dart' show HighlightTarget;

/// Asset paths and titles for the bundled ICMR / DHR STW PDFs.
const rdPdfAsset = 'assets/pdfs/respiratory_distress_neonates_stw.pdf';
const rdPdfTitle = 'Respiratory Distress in Neonates';

const ropPdfAsset = 'assets/pdfs/retinopathy_of_prematurity_stw.pdf';
const ropPdfTitle = 'Retinopathy of Prematurity (ROP)';

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
      _ => null,
    };

/// The STW PDF a [SourceReference.document] refers to.
StwPdf? stwPdfForDocument(String document) => switch (document) {
      rdStwDocument => stwPdfFor(NeonatalCondition.respiratoryDistress),
      ropStwDocument => stwPdfFor(NeonatalCondition.rop),
      ancsStwDocument => stwPdfFor(NeonatalCondition.ancs),
      hypoStwDocument => stwPdfFor(NeonatalCondition.hypoglycemia),
      _ => null,
    };

/// Open a bundled STW PDF in the in-app PDF viewer.
void openStwPdf(
  BuildContext context, {
  required String assetPath,
  required String title,
}) {
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
          r['id'] as String: HighlightTarget(
            document: r['document'] as String,
            page: r['page'] as int? ?? 1,
            normalizedBboxes: [
              Rect.fromLTWH(
                (r['x'] as num).toDouble(),
                (r['y'] as num).toDouble(),
                (r['w'] as num).toDouble(),
                (r['h'] as num).toDouble(),
              ),
            ],
            sectionTitle: r['title'] as String?,
            regionId: r['id'] as String,
          ),
      };
    } catch (_) {
      targets = const {};
    }
    _regionTargets = targets;
  }
  return targets[regionId];
}

/// Open [pdf] scrolled to and highlighting region [regionId]; opens the
/// plain PDF when the region is unknown.
Future<void> openStwRegion(
  BuildContext context, {
  required StwPdf pdf,
  required String regionId,
}) async {
  final target = await stwRegionTarget(regionId);
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
