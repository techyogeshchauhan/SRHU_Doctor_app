# Project Overview: SRHU STW (STW Neo)

Neonatal clinical decision support built in Flutter. It turns the ICMR/DHR **Standard Treatment Workflows (STWs)** into an interactive bedside assessment for Android, iOS and the web (installable as a PWA on iPhone/iPad).

> For the history of what was changed and why, see [CHANGES_MADE.md](CHANGES_MADE.md).

---

## Contents

1. [What the app is](#1-what-the-app-is)
2. [Status at a glance](#2-status-at-a-glance)
3. [User flow](#3-user-flow)
4. [Main features](#4-main-features)
5. [Architecture](#5-architecture)
6. [Project structure](#6-project-structure)
7. [The assessment engine in detail](#7-the-assessment-engine-in-detail)
8. [Clinical content implemented](#8-clinical-content-implemented)
9. [Web, PWA and deployment](#9-web-pwa-and-deployment)
10. [Development setup and commands](#10-development-setup-and-commands)
11. [Testing](#11-testing)
12. [Conventions and rules for contributors](#12-conventions-and-rules-for-contributors)
13. [Known issues and next steps](#13-known-issues-and-next-steps)

---

## 1. What the app is

| | |
|---|---|
| **Purpose** | Help doctors, nurses and medical students apply the ICMR/DHR STWs for newborns at the bedside: answer a short set of questions and get the STW recommendations, with the reason and source for each. |
| **Clinical sources** | Two one-page STW PDFs (August 2026), bundled in `assets/pdfs/`: *Respiratory Distress in Neonates* (ICD-11 KB23) and *Retinopathy of Prematurity* (ICD-11 9B71.3). The verbatim extraction is `docs/STW_APP_SPEC_FROM_PDFs.md`. |
| **Names** | Installed app / home-screen name: **SRHU STW**. In-app wordmark on the landing page: **STW Neo**. Dart package: `neonatal_stw`. |
| **Platforms** | Android, iOS, web (desktop and mobile browsers), and PWA (installable, works offline). |

### Design principles (do not break these)

1. **No backend.** All logic and content are in the Flutter project. There is no API, database, auth or Firebase SDK. The web build is static files.
2. **Nothing is stored.** Patient data lives in memory only and is cleared when the app closes, the page reloads, or **New assessment** is used.
3. **No invented clinical content.** Every question, threshold and recommendation comes from an approved STW and cites its section. Topics without an approved STW stay "Coming soon".
4. **Deterministic.** Decisions come from plain-Dart rules. There is no LLM or heuristic at runtime.
5. **Clinical logic is pure Dart** in `domain/` folders with no Flutter imports, so every rule is unit-testable.
6. **Advisory only.** The ICMR/DHR disclaimer is shown, and management is decided by the treating physician.

---

## 2. Status at a glance

| Area | Status |
|---|---|
| 14-topic selection | ✅ Working. Respiratory Distress and ROP are **available**; the other 12 are **"Coming soon"** (no STW supplied, see [STW content coverage](STW_CONTENT_COVERAGE_pdf%20me%20nhih%20.md)). |
| Dynamic assessment (RD + ROP) | ✅ Working: shared questions asked once, conditional questions, rule-based findings, combined summary. |
| RD clinical logic | ✅ Initial plan (CPAP / nasal O₂, caffeine, feeding, IV fluids), severity, reassessment (improving, not improving, CPAP failure, surfactant). |
| ROP clinical logic | ✅ Eligibility, first-screen timing, per-eye treatment indications, follow-up, stop criteria, discharge-card text. |
| Summary, copy and share | ✅ |
| References and PDF viewer | ✅ Including offline on web. |
| Responsive layout | ✅ Phone, landscape phone, tablet and desktop; verified for overflow at 8 sizes. |
| PWA (install + offline) | ✅ Verified in Chrome. ⚠️ Not yet tested on a real iPhone. |
| Standalone RD/ROP screens (`/rd`, `/rop`) | ⚠️ Still work, but no longer linked from the UI. |
| `flutter analyze` / `flutter test` | ✅ No issues / **167 tests passing**. |

---

## 3. User flow

```
Landing ──Continue──► Home ──Get Started──► Select Conditions ──Continue──► Clinical Assessment ──► Summary
                       │                     (tick 1+ of 14)                 (one page at a time)       │
                       ├─ References ──► View PDF (STW poster, zoom/share)                              ├─ Copy / Share
                       └─ Disclaimer (bottom sheet)                                                     ├─ Record SAS & reassess again (RD)
                                                                                                         └─ New assessment (restart icon)
```

Step by step (example: Respiratory Distress + ROP + Sepsis selected):

1. **Landing** (`/`): the ICMR hero panel, partner institutions, the "STW Neo" wordmark and **Continue**.
2. **Home** (`/home`): hero, the "Neonatal Care Workflows" card with availability pills, **Get Started**, and Disclaimer / References links.
3. **Select Conditions** (`/conditions`): "Available now" (RD, ROP) and "Awaiting approved STW" (12). Tick any number, then **Continue**. Ticking a topic means *assess it*; it is not a diagnosis.
4. **Clinical Assessment** (`/workflow`): the engine shows one **page** (question group) at a time:
   - **Baby details:** GA known/uncertain, GA weeks (+ days), birth weight, and date of birth (asked only once ROP eligibility is known). Asked **once** and shared by RD and ROP.
   - **RD:** signs (RR optional) → if any sign: SAS (5 items with drawings) → other findings → reassessment now? → (if yes) support/PEEP/FiO₂/SpO₂/comfortable → repeat SAS → warning signs → sepsis triggers.
   - **ROP:** risk factors (only for GA 34–36) → if eligible: follow-up assured → examination done? → (if yes) exam date, right eye, left eye ("same as right" option) → next examination date/place, counselling, facility, SNCU no.
   - **Sepsis:** no questions (awaiting its STW).
   - **Required fields** are marked `*`; **Continue** stays disabled until they're answered. **Back** steps through earlier pages; from the first page it returns to the selection with the ticks kept.
   - **Progress** reads "x of y questions answered (more may appear)". The **findings icon** opens "Findings so far" at any time.
5. **Summary:** baby details, topics assessed (labelled *not diagnoses*), questions answered, and per-topic finding cards (category, actions, *Why*, STW source, *Requires clinical review* where relevant). It also includes the ROP discharge-card text and the pending-topic placeholder, plus **Copy** / **Share**.
6. **New assessment** (restart icon) clears everything for the next baby.

---

## 4. Main features

| Feature | Where |
|---|---|
| Landing page with the ICMR hero and partner logos (ICMR, SRHU, AIIMS Delhi, PGIMER, GMCH) | `features/landing/ui/` |
| Home dashboard: hero, workflow card, availability, disclaimer sheet, references link | `features/home/home_screen.dart` (also contains `AboutScreen`) |
| 14-topic selection with status and checkboxes | `features/condition_selection/` |
| Dynamic assessment engine, question pages, findings sheet, summary | `features/clinical_workflow/` |
| RD and ROP clinical rules and their workflow definitions | `features/rd/domain/`, `features/rop/domain/` |
| Standalone RD and ROP tools (legacy, unlinked) | `features/rd/ui/`, `features/rop/ui/` |
| References screen and in-app PDF viewer (pdfx; pinch-zoom, share) | `features/references/ui/` |
| STW text (disclaimer, DOs/DON'Ts, checklists, references) | `content/stw_content.dart` |
| Responsive shell, phone column, max-width helpers | `core/widgets/responsive.dart` |
| Theme, colours (`Tone`), typography (Poppins, Inter) | `core/theme.dart` |
| Shared inputs (`NumberField`, `DateField`, `CheckList`, `RadioChoiceGroup`), cards, banners | `core/widgets/` |
| PWA: manifest, icons, loading screen, offline service worker | `web/`, `tool/` |

---

## 5. Architecture

### Layers

Each feature follows the same split:

```
feature/
├── domain/   pure Dart: models, rules, workflow definitions (no Flutter imports)
├── state/    Riverpod Notifiers/Providers (in-memory only)
└── ui/       Flutter widgets: render state, call controllers, no clinical rules
```

| Concern | Technology |
|---|---|
| State | `flutter_riverpod` 2.x (`NotifierProvider`, `Provider`) |
| Navigation | `go_router` 14.x, **hash URLs on web** (`/#/home`), so no server rewrites are needed |
| PDF | `pdfx` (native PdfRenderer / CGPDF; pdf.js on web) |
| Sharing | `share_plus` (Web Share API on web) |
| Dates | `intl` |
| Files | `path_provider` (native only, for PDF sharing) |

### Routes (`lib/app.dart`)

| Path | Screen | Linked from |
|---|---|---|
| `/` | `LandingScreen` | App start |
| `/home` | `HomeScreen` | Landing → Continue (`context.go`, so back exits) |
| `/conditions` | `ConditionSelectionScreen` | Home → Get Started |
| `/workflow` | `WorkflowScreen` (assessment and summary) | Selection → Continue |
| `/references` | `ReferencesScreen` | Home footer, Home card "View source PDFs →" |
| `/pdf-viewer` | `PdfViewerScreen` (`extra: {path, title}`) | References → View PDF |
| `/about` | `AboutScreen` | – |
| `/rd`, `/rop`, `/rop/reference` | Standalone RD/ROP tools | **Not linked** (kept; covered by tests) |

`MaterialApp.router(builder: …)` wraps everything in `AppShell`, which gives wide windows a centred 1024 px column.

### Data flow of an assessment

```
ConditionSelectionController (Set<NeonatalCondition>)
        │ Continue → AssessmentController.start(selected)
        ▼
AssessmentController (Riverpod)
        │ answer(questionId, value) / confirmPage() / back()
        ▼
AssessmentEngine.evaluate(selected, answers, completed, today)     ← pure Dart
   1. resolve(): questions of the selected StwWorkflows, de-duplicated by id
   2. derived variables (ClinicalVariable.compute → rd_rules / rop_rules)
   3. rules (ClinicalRule.when → FindingContent) → findings
   4. applicable questions (question.visibleWhen AND any workflow's QuestionUse.when)
   5. drop answers of non-applicable questions; repeat until stable
        ▼
ClinicalAssessmentContext (answers, variables, findings, completed, today)
        ▼
WorkflowScreen: current page = first group with an unconfirmed applicable question
                 → none left → AssessmentSummaryView (CombinedAssessmentSummary)
```

---

## 6. Project structure

```
SRHU_Doctor_app/
├── lib/
│   ├── main.dart                         ProviderScope + NeonatalStwApp
│   ├── app.dart                          GoRouter routes, theme, AppShell
│   ├── content/stw_content.dart          Verbatim STW text (disclaimer, DOs/DON'Ts, checklists, refs)
│   ├── core/
│   │   ├── theme.dart                    AppTheme colours/typography, Tone (success/warning/treat/danger/info)
│   │   └── widgets/
│   │       ├── app_branding.dart         StwNeoBrand: ICMR logo + screen name (wordmark on landing only)
│   │       ├── inputs.dart               CheckList, NumberField, IntStepper, Fio2Slider, DateField
│   │       ├── layout.dart               SectionCard, ResultCard, AlertBanner, StatusChip, DisclaimerFooter, ResponsiveSplit, RecommendationBar
│   │       ├── radio_choice_group.dart   RadioChoiceGroup / ChoiceOption (supports images)
│   │       └── responsive.dart           Breakpoints, AppShell, PhoneColumn, MaxWidth
│   ├── shared/
│   │   ├── baby_context.dart             Baby provider + GA/BW fields (used by the standalone RD/ROP tools)
│   │   └── reference_view.dart           Reference tab rendering
│   └── features/
│       ├── landing/ui/                   landing_screen.dart, institutional_partners_section.dart (_IcmrHero)
│       ├── home/home_screen.dart         HomeScreen, AboutScreen, hero, workflow card, disclaimer sheet
│       ├── condition_selection/
│       │   ├── domain/neonatal_condition.dart       14 topics, ConditionDefinition, status, pendingStwMessage
│       │   ├── state/condition_selection_controller.dart
│       │   └── ui/condition_selection_screen.dart   Available-now cards + awaiting grid (TopicSelectTile)
│       ├── clinical_workflow/
│       │   ├── domain/
│       │   │   ├── condition_expr.dart        Cond: AllOf / AnyOf / Not / HasFinding / Compare, Var builder
│       │   │   ├── clinical_question.dart     ClinicalQuestion, QuestionOption, QuestionGroup, QuestionType
│       │   │   ├── clinical_rule.dart         ClinicalVariable, ClinicalRule
│       │   │   ├── clinical_finding.dart      ClinicalFinding, FindingContent, FindingCategory, FindingLevel
│       │   │   ├── source_reference.dart      SourceReference (.rd / .rop / .dataEntry)
│       │   │   ├── assessment_context.dart    ClinicalAssessmentContext
│       │   │   ├── assessment_engine.dart     AssessmentEngine (resolve, evaluate, pages, progress)
│       │   │   ├── workflow_definition.dart   StwWorkflow, PendingWorkflow, QuestionUse
│       │   │   ├── workflow_registry.dart     workflowFor(topic)
│       │   │   ├── shared_questions.dart      GA/BW/DOB questions, describeBabyLine, formatDmy
│       │   │   └── combined_summary.dart      CombinedAssessmentSummary, TopicSummary
│       │   ├── state/assessment_controller.dart   AssessmentController, assessmentTodayProvider
│       │   └── ui/
│       │       ├── workflow_screen.dart       Pages, progress, findings sheet, New assessment, refresh state
│       │       ├── question_field.dart        Renders one ClinicalQuestion
│       │       └── assessment_summary.dart    Summary view, FindingCard, Copy/Share
│       ├── rd/
│       │   ├── domain/rd_rules.dart       Validated RD engine: criteria, Gestation, initialPlan, reassess
│       │   ├── domain/sas.dart            Silverman-Andersen Score, RdSeverity
│       │   ├── domain/rd_workflow.dart    RD questions, variables, rules for the engine
│       │   ├── state/rd_controller.dart   (standalone RD tool)
│       │   └── ui/                        (standalone RD tool: rd_screen, sas_calculator, rd_results)
│       ├── rop/
│       │   ├── domain/rop_rules.dart      Validated ROP engine: eligibility, timing, PMA, eyeIndication, summary text
│       │   ├── domain/rop_workflow.dart   ROP questions, variables, rules for the engine
│       │   ├── state/rop_controller.dart  (standalone ROP tool)
│       │   └── ui/                        (standalone ROP tool: wizard steps)
│       └── references/ui/                 references_screen.dart, pdf_viewer_screen.dart
├── assets/
│   ├── fonts/                            Poppins, Inter
│   ├── images/                           Partner logos, hero photo, SAS chart, sas/ (15 grade drawings)
│   └── pdfs/                             The two STW PDFs (plus 2 duplicates, not bundled)
├── web/                                  index.html, manifest.json, flutter_bootstrap.js, icons/, pdfjs/
├── tool/                                 build_web.sh, generate_service_worker.dart, sw_template.js
├── test/                                 167 tests (see §11)
├── docs/                                 SPEC, STW extraction, ROP supporting docs, coverage, this file, change log
├── android/, ios/                        Native shells (app label "SRHU STW")
└── pubspec.yaml                          Dependencies; assets listed file by file
```

---

## 7. The assessment engine in detail

### Core concepts

| Concept | Meaning |
|---|---|
| **Topic** (`NeonatalCondition`) | One of the 14 selectable areas. *Selected ≠ diagnosed.* |
| **Workflow** (`StwWorkflow` / `PendingWorkflow`) | What a topic asks and decides. Pending topics have nothing. |
| **Question** (`ClinicalQuestion`) | Defined once with a stable `id`; stores its answer under `variable` (defaults to `id`). |
| **QuestionUse** | How one workflow uses a question: `when` it's needed and whether it's `required` / `requiredWhen`. A question shared by RD and ROP (e.g. GA) has one definition and two uses. |
| **Group** (`QuestionGroup`) | A page. Questions of the same group are shown together; `questionOrder` sets their display order. |
| **Variable** (`ClinicalVariable`) | A derived value, computed by calling the validated `rd_rules` / `rop_rules` functions. |
| **Rule** (`ClinicalRule`) | `when` (a `Cond`) → `then` (`FindingContent`), plus a `SourceReference`. Rules run in order and may test earlier findings with `HasFinding`. |
| **Finding** (`ClinicalFinding`) | A rule result: category, level, title, actions, why, source. Several can coexist. |
| **Context** (`ClinicalAssessmentContext`) | The single snapshot of the whole assessment. |

### Engine behaviour

- **Shared questions:** used by two or more selected workflows, they come **first** and appear once.
- **Applicable questions:** visible (global `visibleWhen`) **and** needed by at least one selected workflow (`QuestionUse.when`).
- **Pruning:** after every change, answers to non-applicable questions and hidden option values are **dropped**, repeated until stable. Stale answers can never affect a rule; deselecting a topic removes its answers and findings but keeps shared answers still in use.
- **Pages:** the next page is the group of the first applicable unconfirmed question. Confirming a page stores "no"/"none" for unanswered switches and checklists, and marks its questions completed.
- **Missing values:** in `Cond`, every comparison on a missing value is false (use `Var(x).exists()`). `Not(...)` of an unknown comparison is therefore true.

### How to add a new STW topic (e.g. Sepsis)

> Only with the **approved STW document**. Every question text, option, threshold and recommendation must come from it, with its section in `SourceReference`.

1. **Add the source PDF** to `assets/pdfs/`, list it in `pubspec.yaml`, and add it to the References screen.
2. **Create `lib/features/sepsis/domain/sepsis_workflow.dart`**, modelled on `rd_workflow.dart`:

```dart
// Structure only: texts and rules below are placeholders, not clinical content.
const _src = SourceReference(document: 'Sepsis in Neonates', section: '§x.y …');

const qExample = ClinicalQuestion(
  id: 'sepsis_example',
  group: 'sepsis_page',
  question: '<question text from the STW>',
  type: QuestionType.boolean,
  sources: [_src],
);

final sepsisWorkflow = StwWorkflow(
  NeonatalCondition.sepsis,
  source: const SourceReference(document: 'Sepsis in Neonates', section: 'Whole document'),
  groups: const [babyGroup, QuestionGroup('sepsis_page', '<page title>')],
  uses: [
    const QuestionUse(qGaKnown, required: true), // reuse shared questions when the STW needs them
    const QuestionUse(qExample, required: true),
  ],
  variables: const [],
  rules: [
    ClinicalRule(
      id: 'sepsis.example',
      topic: NeonatalCondition.sepsis,
      when: const Var('sepsis_example').eq(true),
      source: _src,
      then: (r) => const FindingContent(
        category: FindingCategory.assessment,
        level: FindingLevel.action,
        title: '<finding wording from the STW>',
      ),
    ),
  ],
);
```

3. **Register it** in `workflow_registry.dart`: `NeonatalCondition.sepsis => sepsisWorkflow,`.
4. **Mark it available** in `neonatal_condition.dart`: `status: ConditionStatus.available` and a `description`.
5. **Add tests** like `rd_workflow_test.dart`, using `walk()` from `test/assessment_test_utils.dart`.

The selection screen, engine, pages, findings sheet and summary pick it up automatically.

---

## 8. Clinical content implemented

Section numbers refer to `docs/STW_APP_SPEC_FROM_PDFs.md`.

### Respiratory Distress (`rd_rules.dart`, `sas.dart`, `rd_workflow.dart`)

| Decision | Rule |
|---|---|
| RD present (§1.1) | ANY ONE of RR >60/min, chest retractions, nasal flaring, grunting. A measured RR decides the RR sign. |
| Gestation (§1.3, §1.5) | GA ≤34 vs >34 (completed weeks). If GA is uncertain, BW ≤1800 g is the surrogate. |
| Severity (§1.4) | SAS total: mild ≤3, moderate–severe ≥4 (no further split). |
| Initial support (§1.5) | GA ≤34 → START CPAP. GA >34 + SAS ≥4 → CPAP. GA >34 + SAS ≤3 → nasal-prong O₂ 0.5–1 L/min. Caffeine if <34 wk. Feeding / IV fluids per §1.2. DON'Ts per §1.12. |
| Reassessment (§1.7–1.10) | In order: CPAP failure (clinician-ticked) → refer; surfactant (<34 wk, CPAP, PEEP >6, FiO₂ >0.30); not improving → optimise; improving (SAS down + SpO₂ 91–95 + comfortable) → wean; otherwise stable. Alerts: SpO₂ >95, consider sepsis. |

### ROP (`rop_rules.dart`, `rop_workflow.dart`)

| Decision | Rule |
|---|---|
| Eligibility (§2.1) | GA <34, or BW <2000 g, or GA 34–36 with a risk factor or unstable course. |
| First screen (§2.2) | By 4 weeks; by 2–3 weeks if GA <28 or BW <1200 g; overdue → screen ASAP; follow-up uncertain → screen before discharge. |
| Per eye (§2.6, §2.8) | A-ROP → urgent; stage 4–5 → surgery referral; reactivation after anti-VEGF with stage 2–3 → treat; Zone I with plus or stage 3 → treat; Zone II stage 2–3 + plus → treat; otherwise observe; regressed/vascularised → may stop (only if advised; not before 65 wk PMA after anti-VEGF). |
| Follow-up (§2.10–2.11) | "Do not discharge without a documented plan" until a date and place are entered; counselling reminder; discharge-card text. |

Ambiguous STW lines (spec §6, open points 6.1–6.9) are implemented as documented and tagged **Requires clinical review** in the summary.

---

## 9. Web, PWA and deployment

The deployed app is **static files only**; no server-side code is needed.

### Build

```bash
# Release web/PWA build with offline support (root of a domain):
FLUTTER=~/flutter/bin/flutter DART=~/flutter/bin/dart tool/build_web.sh
# Served from a sub-path, e.g. https://host/stw/:
BASE_HREF=/stw/ tool/build_web.sh
# Output: build/web/
```

`tool/build_web.sh` runs `flutter build web --release --no-web-resources-cdn` (CanvasKit bundled, no CDN), then `dart run tool/generate_service_worker.dart` (writes `build/web/sw.js`).

> ⚠️ A plain `flutter build web --release` works online, but has **no offline support** (no `sw.js`) and loads CanvasKit from Google's CDN.

### What the PWA consists of

| File | Role |
|---|---|
| `web/index.html` | Meta tags (viewport, theme colour, iOS home-screen), manifest link, loading screen, local pdf.js |
| `web/manifest.json` | Name "SRHU STW", standalone, any orientation, white theme, any + maskable icons |
| `web/flutter_bootstrap.js` | Loads Flutter, removes the loading screen on first frame, registers `sw.js` |
| `web/icons/` | 192/512 + maskable 192/512 + `apple-touch-icon.png` (180) from the SRHU logo |
| `web/pdfjs/` | pdf.js 4.6.82 (`pdf.min.mjs`, `pdf.worker.min.mjs`) for the PDF viewer, offline |
| `tool/sw_template.js` → `build/web/sw.js` | Precache: core (~7.2 MB) + the CanvasKit variant for that browser (~5.3–7 MB); STW PDFs, pdf.js and licences best-effort. Network-first (4 s timeout, then cache) for app code; cache-first for PDFs, page images and pdf.js; old caches removed on update. |

### Web-specific behaviour

- **URLs:** hash URLs (`/#/conditions`); a refresh or deep link works on any static host without rewrites.
- **Refresh:** reloading during an assessment shows **"No assessment in progress"**, because answers are memory-only by design.
- **First visit:** must be online; after that the app and the STW PDFs work offline.
- **Install:** Android/desktop Chrome → *Install app*. iPhone/iPad Safari → *Share → Add to Home Screen*. HTTPS is required (localhost is exempt).
- **Sharing:** uses the Web Share API: fine on iOS and Android, but may do nothing in some desktop browsers. **Copy** always works.

### Hosting configuration

Required on every host: **HTTPS**, `.mjs` → `text/javascript`, `.wasm` → `application/wasm`, and `Cache-Control: no-cache` for `sw.js`, `index.html`, `flutter_bootstrap.js`, `version.json` and `manifest.json`.

**Nginx (VPS):** add `text/javascript mjs;` to `/etc/nginx/mime.types` (older default lists don't include it) and check that `application/wasm wasm;` is present.

```nginx
server {
    listen 443 ssl http2;
    server_name stw.example.org;          # your domain
    root /var/www/srhu-stw;               # contents of build/web
    gzip on;
    gzip_types application/javascript text/javascript application/wasm application/json;

    location ~* ^/(sw\.js|index\.html|flutter_bootstrap\.js|version\.json|manifest\.json)$ {
        add_header Cache-Control "no-cache";
    }
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**Netlify / Cloudflare Pages:** publish `build/web`. Headers via a `_headers` file; put it in `web/` so every build copies it:

```
/sw.js
  Cache-Control: no-cache
/index.html
  Cache-Control: no-cache
/flutter_bootstrap.js
  Cache-Control: no-cache
/version.json
  Cache-Control: no-cache
/manifest.json
  Cache-Control: no-cache
```

**Firebase Hosting** (static hosting only; no Firebase SDK):

```json
{
  "hosting": {
    "public": "build/web",
    "headers": [
      { "source": "/@(sw.js|index.html|flutter_bootstrap.js|version.json|manifest.json)",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }] }
    ]
  }
}
```

**Vercel:** deploy the pre-built folder (`vercel deploy build/web --prod`) with a `vercel.json` inside it setting the same `no-cache` headers. Vercel's build machines don't have Flutter installed.

---

## 10. Development setup and commands

| | |
|---|---|
| Flutter | 3.47.6 stable (Dart 3.13), installed at `~/flutter` on the dev machine. `pubspec.lock` needs Flutter ≥3.38.4. |
| Get packages | `flutter pub get` |
| Run (device) | `flutter run` |
| Run (web) | `flutter run -d chrome` (debug; no service worker) |
| Analyze | `flutter analyze` (must report no issues) |
| Test | `flutter test` |
| Web release | `scripts\deploy_web.ps1` (Windows) or `tool/build_web.sh`; see docs/RELEASE.md |
| Android release | `scripts\build_apk.ps1` (same `build.env` and version as Web; see docs/RELEASE.md) |
| iOS release | `flutter build ipa` (macOS + Xcode) |
| Launcher icons | `dart run flutter_launcher_icons` (sources: `assets/images/logo_icon.png`, `logo_adaptive_foreground.png`) |

---

## 11. Testing

167 tests; run with `flutter test`.

| Test file | Covers |
|---|---|
| `rd_rules_test`, `sas_test`, `rop_rules_test` | The validated clinical engines (unchanged from the original project). |
| `condition_expr_test` | Condition operators, AND/OR/NOT, missing values. |
| `assessment_engine_test` | Engine mechanics on test-only fixture workflows: shared questions, visibility, pruning, pages, validation. |
| `rd_workflow_test`, `rop_workflow_test` | Every RD/ROP branch through the engine, cross-checked against `rd_rules` / `rop_rules`. |
| `multi_condition_test` | RD + ROP shared answers, independent findings, deselection, summary wording, sources on all rules. |
| `neonatal_condition_test`, `condition_selection_test` | 14-topic model and selection state. |
| `condition_flow_widget_test` | UI: selection → assessment → summary, Back, pending topic, 320×568. |
| `landing_page_test`, `layout_overflow_test`, `widget_smoke_test`, `references_test` | Landing/Home layout at several sizes, partner order, standalone RD/ROP tools, References/PDF navigation. |

Helpers: `test/test_helpers.dart` (`tapVisible`, `openStandaloneModule`) and `test/assessment_test_utils.dart` (`walk()` answers an assessment page by page as the UI does; `testToday` fixes the date).

---

## 12. Conventions and rules for contributors

- **Clinical logic stays in `domain/`:** pure Dart, no Flutter imports, and never inside widgets.
- **Every clinical question and rule has a `SourceReference`** to the STW section. Mark ambiguous readings with `needsClinicalReview: true` and a `note`.
- **Reuse the validated engines** (`rd_rules.dart`, `rop_rules.dart`) through `ClinicalVariable`s rather than re-implementing thresholds.
- **Never add clinical content without an approved STW.** Unsupported topics remain `PendingWorkflow`.
- **No storage, no backend, no analytics** of patient data.
- **Style:** match the surrounding code; run `dart format` on files you change, plus `flutter analyze` and `flutter test` before committing.
- **New assets** must be listed explicitly in `pubspec.yaml`.
- **Layout:** keep widths within `Breakpoints` (`responsive.dart`); check new screens at 320×568, landscape phone, tablet and desktop.

---

## 13. Known issues and next steps

See the full list in [CHANGES_MADE.md §10](CHANGES_MADE.md#10-known-issues-and-open-items). The most important:

1. **Real iPhone:** test the PWA on a real iPhone (Safari and home screen).
2. **Hosting:** deploy with `tool/build_web.sh` and the hosting settings in §9.
3. **ICMR logo rule:** confirm that use of the ICMR logo is permitted (the STW spec says not to use it).
4. **App name:** settle on one name ("SRHU STW" vs "STW Neo").
5. **Remaining 12 topics:** obtain their approved STWs (Sepsis is referenced by the RD STW) and implement them using §7.
6. **Clinical review:** have a clinician review the open points tagged *Requires clinical review*.
