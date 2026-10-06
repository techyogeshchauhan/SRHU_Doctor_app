import 'dart:js_interop';
import 'dart:typed_data';

@JS('downloadPdfBlob')
external void _downloadPdfBlob(JSUint8Array bytes, JSString filename);

/// Triggers opening or downloading the PDF on Web platforms.
void openOrDownloadPdfOnWeb(Uint8List bytes, String filename) {
  try {
    _downloadPdfBlob(bytes.toJS, filename.toJS);
  } catch (e) {
    // Graceful fallback
  }
}
