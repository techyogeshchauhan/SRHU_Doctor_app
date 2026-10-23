# Respiratory Distress MCQ integration validation

Validated on 23 October 2026. The questions from `MCQs RD.docx` were added to the existing Respiratory Distress follow-up assessment. No new module, route or assessment logic was created.

## Source and implementation

- Retained source: `docs/MCQs RD.docx`, byte-identical to the supplied file.
- DOCX SHA-256: `005261f48ec0ba9197555c899cdb355b10a3f6269cf84b57fd446fe21c7c2ff1`.
- Content: 20 questions. Section 1 (Q1–Q10) becomes the MCQ stage. Section 2 (Q11–Q20, clinical scenarios) becomes the case-scenario stage.
- Answer key (bold answers in the DOCX): `BCDBCBBCADBCBBBBBBCB`.
- Question data: `lib/features/follow_up/data/rd_follow_up_data.dart`, registered for `NeonatalCondition.respiratoryDistress` in `disease_follow_up_registry.dart`.
- Question wording, options, correct answers and explanations are taken from the DOCX. Only Word's Q/A prefixes and surrounding whitespace are removed.
- `tools/validate_rd_mcq_source.py` re-reads the DOCX and checks that it matches `test/fixtures/rd_follow_up_source.json`. `test/rd_follow_up_test.dart` checks that the compiled question package matches the same fixture.

## Shared follow-up screen changes

- The final-summary subtitle was hardcoded to "ICMR / DHR Retinopathy of Prematurity Guidelines". It now shows `<module title> · Follow-up Assessment` for every module except ROP, and ROP's text is unchanged.
- Some progress, legend, header and score rows overflowed at 360 px width. They now wrap instead (`Row` → `Wrap` / `Flexible`). Layout at wider sizes is unchanged.

Existing ROP, ANCS and Hypoglycemia follow-up packages, scoring, retake and reset behavior are unchanged.

## Tests and platform evidence

| Check | Result |
| --- | --- |
| Source validator | Passed: all 20 questions, options, bold answer keys and explanations match the DOCX. |
| Full Flutter regression | 647 passed, 1 skipped (existing live-backend test). |
| Analysis (`lib`, `test`) | No issues in changed files. The only 7 warnings are pre-existing unused imports in `test/screening_reset_and_boundary_box_test.dart`. |
| Web, Chrome at 360×800 and 1280×900 | Passed: RD selection and screening summary, all 20 questions, 10 MCQ and 10 case explanations, 20/20 score, subtitle, retake. |
| Installed PWA, standalone, offline | Passed the same flow after service-worker activation, verification that only the current cache exists, and an offline reload. |
| Android (Samsung, Android 13), isolated QA package | Passed: navigation from Home, all 20 questions, MCQ 10/10, final 20/20, corrected subtitle. |

## Release artifacts

- Android: `dist/STW-Neo-1.1.0+31.apk`, SHA-256 `8ee7540cb93fe9bea649dad3c8b646dfd708dd17fe4a05ef2ee730418d82f072`. Installed with `-r` (data preserved), and the installed base APK hash matches.
- Web/PWA: `build/web/` copied to sibling `neonatal_stw_web/`. All 274 generated files match by SHA-256. The deployment's existing `pdfjs/pdf.worker.min.mjs` was kept. The app loads `pdf.worker.min.js`.
- The isolated QA app was uninstalled, and the device's USB stay-awake setting was restored to its original value. Temporary Android packaging edits were restored exactly.

Logs, screenshots and structured results are under ignored `build/rd-mcq-verification/`. No commit, push or live-server deployment was performed.
