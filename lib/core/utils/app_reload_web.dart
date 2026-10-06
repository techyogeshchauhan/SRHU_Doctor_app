import 'dart:js_interop';

@JS('reloadApp')
external void _reloadApp();

/// Web implementation of reloadApplication for Web and installed PWA.
void reloadApplication() {
  try {
    _reloadApp();
  } catch (_) {}
}
