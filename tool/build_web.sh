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

# Same build as scripts/build_web.ps1 (Windows), minus its API checks.
# --no-web-resources-cdn bundles CanvasKit so the app also starts offline.
# build.env holds API_BASE_URL / API_KEY (see docs/RELEASE.md).
DEFINES=()
[ -f build.env ] && DEFINES+=(--dart-define-from-file=build.env)
"$FLUTTER" build web --release --no-web-resources-cdn \
  --base-href "${BASE_HREF:-/}" "${DEFINES[@]}" "$@"
"$DART" run tool/generate_service_worker.dart
