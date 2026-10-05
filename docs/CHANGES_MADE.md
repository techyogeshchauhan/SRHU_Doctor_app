# Changes Made

This document records every change made to the **SRHU STW / STW Neo** Flutter app during the Claude Code sessions (October 2026), in the order they were made. For how the app works today, see [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md).

**Starting point.** A Flutter app (Android / iOS / web) with two separate modules, **Respiratory Distress (RD)** and **Retinopathy of Prematurity (ROP)**. Home had two cards that opened them directly, and the landing page had a full-screen baby poster image. There were **92 tests**, all passing.

**Current state.** A single dynamic clinical assessment covering 14 neonatal topics (RD and ROP implemented, 12 awaiting their STWs). The app has a responsive layout for phone, tablet and desktop, and is installable as an offline PWA. There are **167 tests**, all passing, and `flutter analyze` reports no issues. All changes are committed; the latest commit is `5fd7a20`.

---

## Contents

1. [14-topic condition selection (first version)](#1-14-topic-condition-selection-first-version)
2. [Landing page redesign](#2-landing-page-redesign)
3. [Header branding after the landing page](#3-header-branding-after-the-landing-page)
4. [Dynamic clinical assessment engine](#4-dynamic-clinical-assessment-engine)
5. [UI polish after the landing page](#5-ui-polish-after-the-landing-page)
6. [Web responsiveness and PWA](#6-web-responsiveness-and-pwa)
7. [Landing page: ICMR hero and balanced layout](#7-landing-page-icmr-hero-and-balanced-layout)
8. [Documentation and videos](#8-documentation-and-videos)
9. [Tests](#9-tests)
10. [Known issues and open items](#10-known-issues-and-open-items)

---

## 1. 14-topic condition selection (first version)

**Request:** let the clinician pick one or more of 14 neonatal topics instead of choosing between RD and ROP on Home.

- **Home:** the two RD/ROP cards were replaced with one **"Neonatal Care Workflows"** card. Its **Get Started →** opens `/conditions`, and **View source PDFs →** opens References.
- **New feature `condition_selection/`:**
  - `NeonatalCondition` enum with the 14 topics in a fixed order: Triage, Thermal Care, KMC, Fluids & Feeds, Respiratory Distress, ANCS, Sepsis, Hypoglycemia, Jaundice, Seizures, HIE, Transport, ROP, Discharge & Follow-up.
  - `ConditionDefinition` metadata (title, description, status) and `ConditionSelectionController`, the Riverpod selection state.
  - The selection screen, with all 14 as checkboxes, a "Selected: N" counter, **Clear all**, and **Continue** disabled at zero.
- **Only RD and ROP are "Available".** The other 12 are "Coming soon" and show a placeholder message. **No clinical content was invented** for them (see [STW content coverage](STW_CONTENT_COVERAGE_pdf%20me%20nhih%20.md)).
- **Routes `/conditions` and `/workflow`** were added in `app.dart`.

> The first `/workflow` was a step-by-step launcher that opened the existing RD/ROP screens. It was **replaced in section 4** by the dynamic assessment engine; its files (`workflow_controller.dart`, `workflow_steps.dart`, `workflow_summary.dart`, `ModuleWorkflow`, `buildWorkflowPlan`) no longer exist.

---

## 2. Landing page redesign

**Requests:** remove the baby image; make the logos clearly visible at the top; give ICMR more prominence; show logos in the order ICMR, SRHU, AIIMS Delhi, PGIMER, GMCH.

- **Poster removed:** `landingpageimage.png` is no longer used on the landing page.
- **Logos at the top:** the partner logos lead the page, ICMR first in a larger card, then SRHU, AIIMS Delhi, PGIMER and GMCH in one equal-height row.
- **Text block:** an "STW Neo" wordmark (no duplicate ICMR icon), the headline and the "Covers: …" line sit below the logos, with **Continue** at the bottom.
- **Files:** `lib/features/landing/ui/landing_screen.dart` and `institutional_partners_section.dart`.

(Section 7 later reworked the ICMR card into a hero panel.)

---

## 3. Header branding after the landing page

**Request:** remove "STW Neo" from the header on every screen after the landing page, and make the logo bigger.

- **`StwNeoBrand`** (`lib/core/widgets/app_branding.dart`):
  - New options `showTitle` (default **false**), `showLogo` and `stacked`.
  - App bars now show the **ICMR logo (36 px) with the screen name underneath**, e.g. "ROP Screening" or "Select Conditions".
  - The logo scales down instead of overflowing in narrow app bars.
  - The "STW Neo" wordmark appears only on the landing page.
- **Home brand row:** the ICMR logo is 44–52 px tall, with "Based on ICMR / DHR Standard Treatment Workflows" beside it (up to 3 lines).
- **`assets/images/icmr_logo.png`:** empty transparent margins were cropped (1649×522 → 1584×403), so the logo fills its box. The artwork itself is unchanged.
- **Screen-reader label:** changed from "STW Neo ICMR Logo" to "ICMR Logo".

---

## 4. Dynamic clinical assessment engine

**Request:** replace the fixed condition-by-condition flow with a deterministic, data-driven engine:
- shared questions asked once
- conditional questions
- rule-based findings
- several findings at the same time
- one combined summary
- every rule traceable to the STW
- no runtime LLM and no invented clinical rules

### New domain layer (pure Dart, `lib/features/clinical_workflow/domain/`)

| File | Purpose |
|---|---|
| `condition_expr.dart` | Condition language: `AllOf` (AND), `AnyOf` (OR), `Not`, `HasFinding`, and `Compare` with `== != > >= < <= IN CONTAINS EXISTS`. Built with `Var('ga_weeks').ge(34)`. Every comparison on a missing value is false. |
| `clinical_question.dart` | `ClinicalQuestion` (stable id, group, text, type, options, validation, `visibleWhen`, sources, `pastOnly`), `QuestionOption` (with optional image and per-option visibility), and `QuestionGroup` (page title, subtitle, footnote, display order). |
| `clinical_rule.dart` | `ClinicalVariable` (derived values) and `ClinicalRule` (a condition plus a finding builder, with its source). |
| `clinical_finding.dart` | `ClinicalFinding`, `FindingCategory` (Assessment finding, Classification, STW pathway triggered, Screening, Treatment criteria met, Referral, Follow-up, Alert, Criteria not met, Further clinical assessment required) and `FindingLevel`. |
| `source_reference.dart` | STW source metadata: document, ICMR/DHR, August 2026, section, and a "needs clinical review" flag. |
| `assessment_context.dart` | `ClinicalAssessmentContext`: selected topics, answers, derived variables, findings, completed questions and today's date. |
| `workflow_definition.dart` | `StwWorkflow` (groups, `QuestionUse`s, variables, rules) and `PendingWorkflow`. `QuestionUse` says when a workflow needs a question and when it is required. |
| `workflow_registry.dart` | `workflowFor()`: maps each of the 14 topics to its workflow. |
| `assessment_engine.dart` | Resolves the questions of the selected workflows, de-duplicated by id with shared ones first. Recomputes variables → rules → findings → applicable questions. Drops answers to questions that stop applying, repeating until stable. Also handles pages, required questions, page confirmation and progress. |
| `shared_questions.dart` | GA known/uncertain, GA weeks, GA days, birth weight and DOB, asked once for all workflows. Also `describeBabyLine()` and `formatDmy()`. |
| `combined_summary.dart` | `CombinedAssessmentSummary`: per-topic findings, the ROP discharge-card text, and plain text for copy/share. |

### RD and ROP workflows (reuse the existing validated engines)

- **`lib/features/rd/domain/rd_workflow.dart`:**
  - Questions: RD signs with optional RR, the 5 SAS items with STW drawings, other findings (IV-fluid triggers), an optional reassessment gate, support/PEEP/FiO₂/SpO₂, repeat SAS, warning signs and sepsis triggers.
  - Derived values call `initialPlan()`, `reassess()`, `SasScore` and `RdSeverity`.
  - Rules: RD criteria met / not met, immediate actions, mild vs moderate–severe, initial pathway (CPAP or nasal O₂), IV fluids, DON'Ts, plan pending, each reassessment outcome (CPAP failure, surfactant, not improving, improving, stable, off support) and reassessment alerts.
  - Includes `recordRdReassessment()` to keep the SAS trend.
- **`lib/features/rop/domain/rop_workflow.dart`:**
  - Questions: risk factors (only for GA 34–36), follow-up assured, an "examination done?" gate, per-eye zone/stage/plus/A-ROP/anti-VEGF/reactivation/retina status, "left same as right", and the next exam date/place/counselling/facility.
  - Derived values call `ropEligibility()`, `firstScreenTiming()`, `pmaDays()`, `dateAtPma()`, `eyeIndication()` and `buildRopSummary()`.
  - Rules: eligible / not eligible / pending, first screen due or overdue, screen before discharge, per-eye treatment/referral/follow-up/may-stop, treat within 48–72 h, anti-VEGF follow-up to 65 weeks PMA, the "do not discharge without a plan" alert, next exam documented, and family not counselled.
- **Small edits to the existing RD module:**
  - `CaffeineAdvice` now carries its STW wording (`.text`), and `rd_results.dart` uses it.
  - Added `rrThresholdPerMin = 60`.

### State and UI

- **State:** `lib/features/clinical_workflow/state/assessment_controller.dart` (Riverpod) handles start/update selection, answer, confirm page, Back history, record reassessment, and new assessment. Today's date comes from `assessmentTodayProvider`, so tests can override it.
- **UI (`lib/features/clinical_workflow/ui/`):**
  - `workflow_screen.dart`: question pages, progress ("x of y questions answered (more may appear)"), a **findings so far** bottom sheet, and **New assessment**.
  - `question_field.dart`: renders each question type with the app's existing input widgets.
  - `assessment_summary.dart`: the combined summary with `FindingCard`s (category, actions, why, source, clinical-review flag) and **Copy** / **Share**.
- **Removed:** the old workflow files from section 1.
- **Standalone screens:** `/rd` and `/rop` still exist but are no longer linked from the UI. Their tests open them by route.

---

## 5. UI polish after the landing page

- **Home:**
  - The hero's text and photo columns are balanced (6:5) and the headline wraps naturally, with no hard line breaks.
  - The hero is taller and its subtitle is no longer cut off.
  - The workflow card shows availability pills: ✓ Respiratory Distress, ✓ ROP, "12 more coming soon".
  - The three feature icons now show from 680 px height.
- **Topic selection (redesigned):**
  - **Available now (2):** large cards with an icon, the description and a checkbox.
  - **Awaiting approved STW (12):** a compact two-column grid of checkbox tiles (three columns at 560 px and wider).
  - All 14 keep the original order within their section. The selected count and Continue stay fixed at the bottom.
  - The new widget is `TopicSelectTile`.
- **Assessment pages:**
  - "Answered once and used by: Respiratory Distress · ROP" appears once per page instead of under every question.
  - `QuestionGroup.questionOrder` keeps "+ days" next to gestational age.
  - The SAS pages show the STW-required figure credit.
- **Summary:** the "Copy summary" button became **Copy**, so it fits on one line on 390 px phones.

---

## 6. Web responsiveness and PWA

**Requests:** make the app responsive on the web, then make it a PWA that runs well on iPhone. No backend; static hosting only.

### Responsive layout (`lib/core/widgets/responsive.dart`, new)

- **`AppShell`** (wired in `app.dart` via `MaterialApp.router(builder: …)`): on windows wider than ~1100 px (desktop, iPad landscape), the app sits in a centred **1024 px column**. `MediaQuery.size` is narrowed to match, so every layout decision below sees the column width.
- **`PhoneColumn`:** Landing and Home stay phone-proportioned, at most 560 px wide. When the viewport is shorter than 560 px, for example a phone in landscape, they **scroll instead of overflowing**.
- **`MaxWidth`:** the bottom bars on the selection and assessment screens line up with the 820 px content.
- **Workflow screen:** after a browser refresh (answers live in memory only), it shows **"No assessment in progress"** with a **Select conditions** button instead of an empty summary.

### Smaller bundle (`pubspec.yaml`)

- Assets are listed **file by file**. Two byte-identical duplicate PDFs, two unused images and the launcher-icon sources are no longer bundled, saving about 12 MB on Android, iOS and web.

### Web and PWA files (`web/`)

- **`index.html`:**
  - Viewport, description, `theme-color`, manifest link, iOS home-screen meta tags and `apple-touch-icon`.
  - A branded **loading screen**, removed on Flutter's first frame.
  - **pdf.js 4.6.82 loaded locally**.
- **`manifest.json`:** name "SRHU STW — Neonatal Clinical Decision Support", short name **"SRHU STW"** (matches the native apps), standalone, `orientation: any`, white theme, and any + maskable icons.
- **`flutter_bootstrap.js` (new):** loads Flutter without the deprecated Flutter service worker, removes the loading screen, and registers `sw.js`.
- **Icons:** regenerated from the app's own SRHU logo (`Icon-192/512`, `Icon-maskable-192/512`, new `apple-touch-icon.png` at 180 px, and `favicon.png`). They were previously the default Flutter logo.
- **`web/pdfjs/` (new):** `pdf.min.mjs` and `pdf.worker.min.mjs` 4.6.82, so STW PDFs open offline.

### Release build and offline support (`tool/`, new)

- **`tool/build_web.sh`:** runs `flutter build web --release --no-web-resources-cdn --base-href "${BASE_HREF:-/}"`, then generates the service worker.
- **`tool/generate_service_worker.dart` + `tool/sw_template.js`:**
  - Writes `build/web/sw.js` with a precache list and a content-hash version.
  - Precaches the core app files (~7.2 MB) and **only the CanvasKit build that browser needs** (~5.3 MB on Chromium, ~7.0 MB otherwise). The STW PDFs, pdf.js and licences are cached on a best-effort basis.
  - Navigation and entry files are fetched network-first, everything else cache-first. Old caches are cleaned up on update.

### Verified (headless Chrome + widget tests)

- **Installability:** zero manifest or installability errors.
- **Offline:** the service worker activates, the app reloads offline, and the RD STW PDF renders both online and offline.
- **Layouts:** no overflow at 320×568, 390×844 (including 130% text size), iPhone landscape 844×390 and 568×320, iPad 820×1180 and 1180×820, 1366×768 and 1920×1080.
- **Not yet tested:** a real iPhone (Safari and home-screen mode).

---

## 7. Landing page: ICMR hero and balanced layout

**Request:** make the ICMR logo the hero element and move the header slightly lower for a more balanced layout.

- **New `_IcmrHero` panel** (`institutional_partners_section.dart`):
  - Soft white-to-blue gradient, rounded corners, a gentle shadow and generous padding.
  - The ICMR logo spans the full panel width: about 85 px tall on phones, up to 128 px on iPad and desktop.
  - Below it: an accent line, "ICMR" in spaced capitals and the full name.
- **Partners as supporting content:** "Trusted By Leading Medical & Research Institutions" is now a label **above** the four partner cards, whose logos are slightly smaller. The "Developed with…" line wraps to two lines instead of being cut off.
- **Balanced spacing** (`landing_screen.dart`): free space is shared as 2 : 3 : 3 (above the header : between header and title : between title and Continue). On a 390×844 phone the header now starts ~100 px down instead of 16 px.
- **Code cleanup:** removed the unused "featured" styling from `_PartnerCard`.

---

## 8. Documentation and videos

| Item | Location | Notes |
|---|---|---|
| STW content coverage | [`docs/STW_CONTENT_COVERAGE_pdf me nhih .md`](STW_CONTENT_COVERAGE_pdf%20me%20nhih%20.md) | Why 12 topics show "Coming soon": the PDFs only contain the RD and ROP STWs. |
| README / SPEC | `README.md`, `docs/SPEC.md` | Updated for the 14-topic selection, the dynamic assessment engine and the screen flow. The **web/PWA build is not yet in the README**; see [PROJECT_OVERVIEW.md §9](PROJECT_OVERVIEW.md#9-web-pwa-and-deployment). |
| This change log | `docs/CHANGES_MADE.md` | – |
| Project overview | `docs/PROJECT_OVERVIEW.md` | – |
| Short user video | `../STW_Neo_How_To_Use.mp4` (outside the repo) | 1:40, earlier UI. Superseded. |
| Full walkthrough video | `../SRHU_STW_App_Walkthrough.mp4` (outside the repo) | 2:43, 24 steps, captions only. Shows the landing page **before** section 7. |

The videos were built from real app screens captured by temporary widget tests, composed with Python/PIL and encoded with ffmpeg. The capture code was removed from the repo afterwards.

---

## 9. Tests

The total went from **92 → 167**, all passing.

| File | What it covers |
|---|---|
| `condition_expr_test.dart` | Every operator, AND/OR/NOT, and missing-value behaviour. |
| `assessment_engine_test.dart` | Generic engine behaviour on **test-only fixture workflows**: shared questions once, visibility, pruning hidden answers and options, deselection, pages, validation. |
| `rd_workflow_test.dart` | RD criteria positive/negative, RR override, GA ≤34 / >34, BW surrogate, SAS bands, IV fluids, equality with `initialPlan()`, reassessment (CPAP failure, surfactant, not improving, improving), the CPAP-only option, and recording a reassessment. |
| `rop_workflow_test.dart` | Eligibility (including agreement with `ropEligibility()` across a GA/BW grid), risk-factor visibility vs `riskFactorsRelevant()`, timing (due/overdue/window), screen before discharge, exam skipping, treatment/A-ROP/stage 4/observe/may-stop, and documented follow-up. |
| `multi_condition_test.dart` | RD + ROP shared GA/BW asked once, independent findings, deselecting ROP, summary wording, and a source on every rule. |
| `neonatal_condition_test.dart`, `condition_selection_test.dart` | The 14-topic model and the selection controller. |
| `condition_flow_widget_test.dart` | Selection → dynamic assessment → summary in the UI, Back, a pending topic, and a 320×568 layout. |
| Existing tests | `rd_rules_test`, `rop_rules_test`, `sas_test` **unchanged**. `landing_page_test`, `layout_overflow_test`, `widget_smoke_test` and `references_test` were updated for navigation and layout changes only, never for clinical assertions. |
| Helpers | `test_helpers.dart` (`tapVisible`, `openStandaloneModule`) and `assessment_test_utils.dart` (`walk()` answers an assessment page by page). |

---

## 10. Known issues and open items

| # | Item | Notes |
|---|---|---|
| 1 | **Real iPhone not tested** | PWA verified in Chrome only. Test in Safari and from the home screen before release. |
| 2 | **Deploy with `tool/build_web.sh`** | A plain `flutter build web` has no `sw.js` (no offline use) and loads CanvasKit from a CDN. |
| 3 | **Hosting configuration** | HTTPS; serve `.mjs` as `text/javascript` and `.wasm` as `application/wasm`; send `Cache-Control: no-cache` for `sw.js`, `index.html`, `flutter_bootstrap.js`, `version.json` and `manifest.json`. |
| 4 | **ICMR logo rule** | `docs/STW_APP_SPEC_FROM_PDFs.md` §0 says *"Do not use the Government of India emblem or ICMR logo in the app."* The ICMR logo is used prominently at the client's request. Needs confirmation. |
| 5 | **App name** | Home-screen name "SRHU STW" (Android, iOS, PWA) vs "STW Neo" on the landing page and in the videos. |
| 6 | **Clinical review** | Spec open points 6.1–6.9 (GA 34+3 counted as ≤34, "severe distress", "persisting SAS", improving needs all three criteria, ROP reactivation/PAR line, and others) are tagged *Requires clinical review* in the summary. |
| 7 | **Accessibility** | Two SAS options ("1 · Just visible", under Lower chest and Xiphoid) have identical accessible names. |
| 8 | **Cut-off helper text** | The next-ROP-exam date help text is cut after one line. |
| 9 | **Unlinked screens** | `/rd` and `/rop` (standalone RD/ROP tools) and `/about` are not reachable from the UI: re-link them or delete them. |
| 10 | **Repository tidying** | Duplicate PDFs (`Respiratory distress in neonates_New.pdf`, `Retinopathy of Prematurity (ROP).pdf`) and unused images are still on disk, though not bundled. |
| 11 | **12 pending topics** | Each needs its approved ICMR/DHR STW PDF before it can be implemented. |
