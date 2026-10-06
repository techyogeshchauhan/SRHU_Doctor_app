#!/usr/bin/env bash
# Release build of the web app / PWA with offline support.
#
#   tool/build_web.sh                    # served from the domain root
#   BASE_HREF=/stw/ tool/build_web.sh    # served from https://host/stw/
#
# Output: build/web (static files; serve over HTTPS).
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-flutter}"
DART="${DART:-dart}"

# --no-web-resources-cdn bundles CanvasKit so the app also starts offline.
# -O4 maximizes dart2js optimization; --tree-shake-icons strips unused font glyphs.
"$FLUTTER" build web --release --no-web-resources-cdn -O4 --tree-shake-icons \
  --base-href "${BASE_HREF:-/}" "$@"
"$DART" run tool/generate_service_worker.dart
