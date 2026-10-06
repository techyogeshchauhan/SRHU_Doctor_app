import 'app_reload_stub.dart'
    if (dart.library.js_interop) 'app_reload_web.dart' as impl;

/// Refreshes/reloads the application on Web and installed PWA.
void reloadApplication() => impl.reloadApplication();
