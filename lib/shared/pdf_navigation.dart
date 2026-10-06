import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Asset paths and titles for the bundled ICMR / DHR STW PDFs.
const rdPdfAsset = 'assets/pdfs/respiratory_distress_neonates_stw.pdf';
const rdPdfTitle = 'Respiratory Distress in Neonates';

const ropPdfAsset = 'assets/pdfs/retinopathy_of_prematurity_stw.pdf';
const ropPdfTitle = 'Retinopathy of Prematurity (ROP)';

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
