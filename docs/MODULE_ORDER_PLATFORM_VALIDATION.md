# STW module order: platform validation

Validated on 23 October 2026 against the current working tree based on
`8ec971a`. This includes the uncommitted module display-order changes and green/red availability indicators.

## Results

| Platform | Runtime checked | Result |
| --- | --- | --- |
| Android | Physical Samsung SM-G780F, Android 13 / API 33, ARM release build | Passed |
| Web | Compiled Flutter release in Chrome, 360x640 and 1280x800 | Passed |
| PWA | Installed Chrome PWA, actual standalone window, offline reload | Passed |

All three runtimes verified:

- Triage remains the separate first step, followed by the 13 existing modules.
- All 14 display positions follow the requested order. The existing `STW HIE`
  name and identifier remain at the Post Asphyxia position, number 6.
- Available STWs have green indicators; awaited STWs have red indicators.
  This includes the separate Triage entry and the post-Triage module cards.
- The seven pending modules remain disabled. Available-module lists retain
  their existing availability filters and follow the new relative order.
- The post-Triage available list uses the shared `stwModuleDefinitions`
  configuration and preserves its filters. Its exact order is Hypoglycemia,
  Respiratory Distress, Sepsis, KMC, ANCS, ROP. Completed Triage is not repeated,
  and awaited modules are not added.
- Selecting modules does not start screening. Deselecting ROP excludes it
  from the selected list; selecting KMC and Sepsis displays Sepsis before KMC.
- Only clicking a selected module starts its assessment.
- KMC assessment completes and returns to the same selected list without
  automatically launching another assessment.
- Automatic Emergency classification still executes: apnea on Android and
  heart rate 210/min on Web/PWA.

The installed PWA also verified its active service worker, the new build's
cache replacing the previous cache, offline startup, and the same navigation,
selection filters, ordering, and assessment completion while offline.

## Build and test evidence

- `scripts/build_web.ps1`: production Web/PWA build and generated `sw.js` passed.
- `scripts/build_apk.ps1`: production Android ARM/ARM64 release build passed.
- `flutter test --no-pub --reporter expanded`: 621 passed, one live-backend
  integration test skipped. The latest run includes the status colors, enlarged-text layout, and explicit
  post-Triage relative-order assertions.
- Changed Dart files passed analysis; source and generated deployment
  repository whitespace checks passed.
- All 222 generated Web/PWA files match `../neonatal_stw_web` by SHA-256.
  The existing deployed PDF worker asset was retained so the source checkout's
  unrelated, pre-existing staged deletion was not included in this release.

Runtime evidence is saved locally under `build/`:

- `module-order-android-results.json`
- `module_indicator_android_runtime.log`
- `module-order-web-pwa-results.json`
- `module_indicator_web_pwa_qa.log`
- `module-order-android-catalog-top.png` and
  `module-order-android-catalog-bottom.png`
- `module-order-web-360-catalog.png`, `module-order-web-1280-catalog.png`,
  and `module-order-pwa-standalone-offline-catalog.png`

Android runtime tests used the same release source with API sync unconfigured
in an isolated `com.example.neonatal_stw.order_qa` package. The QA package was
removed afterward. The existing production app's data was preserved when
installing the latest production-configured release APK. The installed APK's
SHA-256 matches `dist/STW-Neo-1.1.0+31.apk`:

`c7db20d7bffe17720686d05de1b6eaad3a3009cc12dbc057509ad17016a28aef`

Browser tests blocked external requests; they verified UI and clinical
execution, not live backend delivery. The temporary installed PWA was
uninstalled after testing.

## Publication state

The Android release APK is built and installed on the connected device.
The tested Web/PWA release is copied into the separate deployment repository.
No Git commit, push, or production server deployment was performed.

Routing, screening steps, clinical evaluation order and rules, chatbot,
knowledge graph, STW Map, PDF reference callbacks, APIs, database structures,
and disease-code mappings were preserved.
