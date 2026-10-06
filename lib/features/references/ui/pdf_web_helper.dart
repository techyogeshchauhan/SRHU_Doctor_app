import 'dart:typed_data';

import 'pdf_web_helper_stub.dart'
    if (dart.library.js_interop) 'pdf_web_helper_web.dart' as helper;

/// Triggers opening or downloading the PDF on Web platforms.
void openOrDownloadPdf(Uint8List bytes, String filename) {
  helper.openOrDownloadPdfOnWeb(bytes, filename);
}
