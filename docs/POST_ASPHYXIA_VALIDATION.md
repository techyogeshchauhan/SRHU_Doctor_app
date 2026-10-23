# Post Asphyxia integration — 23 October 2026

The existing HIE slot is now **STW Post Asphyxia**, at position 6 in the
14-topic display order. It has an available status and uses the existing
selection, assessment, summary, PDF, chatbot and STW Map screens. There is no
additional module. The previous slot was a `PendingWorkflow`; it contained no
HIE assessment rules to carry forward.

## Source and clinical scope

Only `Post Asphyxia 16-10-26.pdf` supplies clinical content. Its printed
edition is August 2026, ICD-11 KB21. SHA-256:
`6759f46ab811d9bd40267d253117b7ff59691462ad78cfd2dfdcaacffc6071aa`.
The user confirmed PDF-only clinical content with full application integration.
No external NNF guideline, video or other clinical source has been imported.

The evidence generator creates 25 cards / 58 complete source excerpts, with
page geometry, crops, a full-page render, retrieval fallback entries and graph
headings. Repeated Sarnat words are matched within their own table row and
column-heading area. The table and hypothermia crop were visually checked
against the poster.

| PDF section | Implementation |
| --- | --- |
| Identify risk; stabilize; assess | Risk observations and required clinician-assessed stability; full stabilization guidance |
| High-risk features | Apgar ≤5 at 10 min, PPV at 10 min, pH ≤7.1 or base deficit ≥12; blood gas thresholds apply only to cord / within-one-hour samples |
| Modified Sarnat | Six separate domain observations and a required clinician-entered overall stage; no automatic aggregation |
| Serial assessment | Seizures recorded separately; serial reassessment and evolving-HIE warning retained |
| Normal examination | Source branch when recorded stable, normal, without recorded seizures or worsening |
| Mild HIE | SNCU/NICU support and serial assessment; source urgent review/referral when mild HIE worsens |
| Moderate/severe HIE or unstable | Stabilization, referral NICU contact and urgent transfer |
| Seizures | Complete immediate source pathway, including phenobarbitone 20 mg/kg IV over 15 min and concurrent glucose/calcium correction; no extra or repeat doses |
| Therapeutic hypothermia | Potential referral candidate only: recorded GA ≥36 weeks, moderate/severe HIE and evidence of acute perinatal hypoxia; complete source restrictions and initiation ASAP within 6 h of birth |
| Monitoring | All seven parameter/frequency/action rows, including oxygen, temperature and glucose targets with their qualifiers |
| Discharge | Source conditions and high-risk neurodevelopmental/hearing follow-up guidance; no automated discharge clearance |
| DOs / DON'Ts / KPIs | Complete source statements, formulas and footnotes |
| Related information / abbreviations / references | PDF evidence and source references retained |

### Source limits requiring clinical review

The poster does not explain how to combine discordant Sarnat domains. The app
records the clinician's overall assessment instead of implementing a majority
rule or a domain-count threshold. Uncertain assessments are visibly flagged for
clinical review. A recorded normal stage with worsening also requires review.

The poster refers to external strict NNF criteria without reproducing them.
The app identifies **potential referral candidates**, never final eligibility
or ineligibility for cooling. It retains the requirement for immediate referral
discussion, confirmation of strict NNF criteria and an appropriately staffed
Level III/IV NICU. Cooling temperature/duration, rewarming protocols and repeat
anticonvulsant doses are absent from this PDF and are not supplied by the app or
chatbot. These source limitations remain explicit; no clinical approval of an
unstated algorithm is implied by software test results.

## Integration and compatibility

- `post_asphyxia_workflow.dart`, `post_asphyxia_rules.dart` and generated
  `post_asphyxia_content.dart`: isolated source-bound clinical implementation.
- `neonatal_condition.dart` and `workflow_registry.dart`: activate and rename
  the existing slot; enum order and the 14 existing identifiers are unchanged.
- `pdf_navigation.dart`, `pubspec.yaml`, disease selection and references:
  source links, assets and existing card presentation.
- Chatbot analyzer, router, answerer, topic mapping and
  `post_asphyxia_answers.dart`: complete source-card answers and PDF/STW Map
  links. Ordinary glucose/seizure questions retain their existing engines;
  explicitly requested Post Asphyxia questions use this PDF's evidence.
- Regions, fallback index, page index and `stw_map.json`: new source entries,
  headings and the PDF-quoted Seizures STW referral. That cross-link is marked
  unapproved, following the existing clinician-review convention.
- Dashboard `format.ts` and `Screenings.tsx`: display `Post Asphyxia` for the
  existing `hie` code and include it in the ordered available-module filter.
  Generated build information picks up the shared definitions.

`NeonatalCondition.hie`, its ordinal 10, serialized name and database/API code
`hie` are intentionally retained. Existing records and URLs therefore require
no migration or API/database change. HIE remains in legitimate clinical text
in this poster and other modules. There was no blind global text replacement.

## Verification

- Source validator: 25 cards / 58 segments; exact source hash, local token
  coverage, geometry, crops, full-page render, retrieval index and graph.
- Preservation audit against a snapshot taken before this integration:
  existing evidence entries, PDFs, crops and page images are unchanged;
  RD, ROP, ANCS, Hypoglycemia, Sepsis, Triage, KMC and Feeding domain files
  retain their original hashes. Existing graph entries and links are retained.
- Clinical tests cover all stage/stability/seizure combinations, missing
  inputs, high-risk boundaries and sample timing, potential-candidate criteria,
  complete source qualifiers, chatbot scope and graph/PDF links.
- Full Flutter suite: **641 passed, 1 existing skip**.
- Dashboard TypeScript and Vite build pass. Browser checks pass at 360×640
  and 1280×800 for all 14 cards, availability colors, filters, charts and
  timing-table order, including the existing `hie` code's new display label.

## Platform runtime results

| Platform | Result and checks |
| --- | --- |
| Android — physical Samsung SM-G780F, Android 13 | Passed: Triage first and emergency execution; ordered available list after Triage; checkbox selection/deselection without automatic screening; selected-only filtering; Post Asphyxia assessment with clinician-recorded moderate HIE, GA 36 and recorded acute hypoxia; potential TH referral and complete monitoring/discharge guidance; completion returns to the same selected list; existing KMC assessment; all 14 display positions and available/awaited indicators; chatbot source excerpts, correct PDF highlight and STW Map focus; prophylaxis and unsupported repeat-dose scope guards. |
| Web — Chrome, 360×640 and 1280×800 | Passed: landing/catalog order, status indicators and disabled filters; Triage HR 210 emergency execution; ordered post-Triage and selected lists; manual launch and completion return; Post Asphyxia assessment, source targets and referral qualifiers; chatbot, PDF highlight and graph focus; unsupported-dose/prophylaxis handling. Existing Feeding/Nutrition and KMC assessment flows also passed. |
| PWA — Chrome installed standalone, 412×915 | Passed the same assessment, navigation, selection, chatbot, PDF and graph checks after an actual offline reload. Verified standalone display mode, active service-worker control, current build cache and removal of older STW caches. Existing Feeding/Nutrition and KMC flows also passed offline. The test PWA was uninstalled afterward. |

The Android run used an isolated QA package with API sync unconfigured.
Browser tests blocked external network requests and dashboard checks used
fixtures. No research records were submitted to a live API.

During native UI automation, assertions were adjusted for clipped/scrolled
accessibility nodes and Android's `36.0` decimal representation. Browser
automation was adjusted for Flutter text-input focus timing and merged
accessibility labels. The final checks passed; these harness adjustments did
not change application navigation or clinical logic.

## Final checks and local artifacts

- Final complete Flutter suite: **641 passed, 1 existing skip**. Final targeted
  analysis of the new module and integration files: **no issues found**.
- The preservation validator also confirms that routing, shared assessment
  engine/controller/screens, post-Triage navigation and existing backend
  source files retain their pre-integration hashes.
- All **31** new/shared evidence assets checked in the local Web output and
  isolated Android APK match the source files byte for byte.
- Local Web/PWA output: `build/web`; service-worker version
  `bff30c5556b38c2e`.
- Isolated Android test APK: `build/STW-post_asphyxia-QA.apk`, SHA-256
  `98a487c0b8ab79145a090fbbc69bac46acc2ee3c15d8afe1a6394f0bee38fd2a`.
  This is a test package, not a production release.
- Android production packaging files were restored exactly. The existing
  production APK in `dist` is unchanged. The pre-existing staged PDF.js worker
  deletion was preserved.
- Detailed local evidence: `build/post-asphyxia-final-full-tests.log`,
  `build/post-asphyxia-final-analyze.log`,
  `build/post-asphyxia-final-web-pwa-ui.log`,
  `build/post-asphyxia-web-pwa-results.json`,
  `build/post-asphyxia-android-results.json`,
  `build/post-asphyxia-android-summary-labels.json`,
  `build/post-asphyxia-artifact-checks.json` and platform screenshots.

No commit, push, merge or production deployment was performed. The separate
Web deployment repository was not updated by this task. The source changes
and local verified builds are ready for review.

Cleanup was verified: the isolated Android QA package was removed, the original
USB stay-awake setting (`0`) was restored, and the local Web and dashboard QA
servers were stopped. Automatic approval review rejected removal of the
temporary `dashboard/dist-post-asphyxia-qa` build folder with the reason
"blocked by policy"; that generated folder remains in place.
