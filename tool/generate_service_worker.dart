// Generates build/web/sw.js (offline support for the web/PWA build) from
// tool/sw_template.js. Run after `flutter build web`; see tool/build_web.sh.
//
// The version is a hash of every listed file, so each new build produces a
// new cache and old ones are deleted on activation.
import 'dart:convert';
import 'dart:io';

const _buildDir = 'build/web';

/// Not cached: debug symbols, source maps, Flutter's deprecated service
/// worker, and renderer builds a dart2js/CanvasKit app never loads.
bool _excluded(String path) =>
    path == 'sw.js' ||
    path == 'flutter_service_worker.js' ||
    path.startsWith('.') ||
    path.endsWith('.symbols') ||
    path.endsWith('.map') ||
    path.startsWith('canvaskit/skwasm') ||
    path.startsWith('canvaskit/wimp') ||
    path.startsWith('canvaskit/webparagraph/');

bool _isExtra(String path) =>
    path.startsWith('assets/assets/pdfs/') ||
    path.startsWith('pdfjs/') ||
    path == 'assets/NOTICES';

/// URL-encodes each path segment the way the browser requests it
/// (e.g. spaces in asset names).
String _url(String path) => path.split('/').map(Uri.encodeComponent).join('/');

/// 64-bit FNV-1a, enough to detect changed builds.
int _fnv(int hash, List<int> bytes) {
  for (final b in bytes) {
    hash ^= b;
    hash *= 0x100000001b3; // wraps modulo 2^64 on the Dart VM
  }
  return hash;
}

/// Unsigned hex of a 64-bit hash (Dart ints are signed).
String _hex64(int v) => [v >> 32, v]
    .map((x) => (x & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0'))
    .join();

void main() {
  final root = Directory(_buildDir);
  if (!root.existsSync()) {
    stderr.writeln('$_buildDir not found. Run `flutter build web` first.');
    exit(1);
  }
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.substring(root.path.length + 1).replaceAll('\\', '/'))
      .where((p) => !_excluded(p))
      .toList()
    ..sort();

  final core = <String>['', 'index.html'];
  final chromium = <String>[];
  final defaultCk = <String>[];
  final extra = <String>[];
  var hash = 0xcbf29ce484222325;
  for (final path in files) {
    hash = _fnv(hash, utf8.encode(path));
    hash = _fnv(hash, File('$_buildDir/$path').readAsBytesSync());
    if (path == 'index.html') continue;
    if (path.startsWith('canvaskit/chromium/')) {
      chromium.add(_url(path));
    } else if (path.startsWith('canvaskit/')) {
      defaultCk.add(_url(path));
    } else if (_isExtra(path)) {
      extra.add(_url(path));
    } else {
      core.add(_url(path));
    }
  }

  final template = File('tool/sw_template.js').readAsStringSync();
  final sw = template
      .replaceFirst('__VERSION__', _hex64(hash))
      .replaceFirst('__CORE__', jsonEncode(core))
      .replaceFirst('__CANVASKIT_CHROMIUM__', jsonEncode(chromium))
      .replaceFirst('__CANVASKIT_DEFAULT__', jsonEncode(defaultCk))
      .replaceFirst('__EXTRA__', jsonEncode(extra));
  File('$_buildDir/sw.js').writeAsStringSync(sw);

  int size(List<String> urls) => urls
      .where((u) => u.isNotEmpty)
      .map((u) => File('$_buildDir/${Uri.decodeComponent(u)}').lengthSync())
      .fold(0, (a, b) => a + b);
  String mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
  stdout.writeln('Wrote $_buildDir/sw.js '
      '(core ${core.length} files ${mb(size(core))}, '
      'CanvasKit ${mb(size(chromium))} Chromium / ${mb(size(defaultCk))} other, '
      'extra ${extra.length} files ${mb(size(extra))})');
}
