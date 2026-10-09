# STW Neo — Neonatal Clinical Decision Support

**STW Neo** is a cross-platform mobile application built with [Flutter](https://flutter.dev) that provides bedside decision support for four ICMR / DHR (Indian Council of Medical Research / Department of Health Research) **Standard Treatment Workflows (STWs)**:

1. **Respiratory Distress in Neonates** (ICD-11 KB23)
2. **Retinopathy of Prematurity — ROP** (ICD-11 9B71.3)
3. **Antenatal Corticosteroids for Preterm Birth — ANCS** (August 2026)
4. **Neonatal Hypoglycemia** (ICD-11 KB60.4, August 2026)

The app digitises the paper-based STW algorithms into an interactive, step-by-step clinical tool that clinicians can use at the bedside. **No patient identifiers leave the device** — dates (date of birth, exam dates) and free-text entries (facility, SNCU/CR number) stay in memory only. Other answers, findings and quiz attempts are queued for the de-identified sync described under *Database & Offline Sync* below.

---

## What Does It Do?

### Dynamic clinical assessment

From Home, **Get Started** opens a checklist of 14 neonatal topics: Triage, Thermal Care, KMC, Fluids & Feeds, Respiratory Distress, ANCS, Sepsis, Hypoglycemia, Jaundice, Seizures, HIE, Transport, ROP, Discharge & Follow-up. The clinician ticks one or more and taps **Continue**.

Selecting a topic means "assess this workflow", **not** "the baby has this condition". Findings come only from STW rules applied to the answers.

```
14-topic selection
  → ClinicalAssessmentContext (selected topics, answers, derived variables, findings, completed questions)
  → question resolver: questions of the selected workflows, de-duplicated by id (shared ones first)
  → visibility conditions (AND / OR / NOT, ==, !=, >, >=, <, <=, IN, CONTAINS, EXISTS, finding(...))
  → answer → derived variables (existing rd_rules / sas / rop_rules functions) → rule engine → findings
  → questions activated or skipped; answers to questions that no longer apply are dropped
  → repeat until no applicable unanswered question remains
  → combined Clinical Assessment Summary (copy / share)
```

- **Shared questions are asked once.** With RD + ROP, gestational age and birth weight appear once on the *Baby details* page and both workflows use the same answers.
- **Questions are skipped when irrelevant.** No RD signs → no GA/SAS/support questions for RD. Not eligible for ROP screening → no timing, examination or eye questions.
- **Several findings can coexist**, e.g. *Respiratory distress criteria met*, *START CPAP*, *Screening eligible — SCREEN FOR ROP*.
- **Removing a topic** drops its questions, answers and findings; answers to shared questions still used by other topics are kept.
- **Every question, rule and finding carries its STW source** (document, ICMR/DHR, August 2026, section). Rules that apply an ambiguous STW line are marked *Requires clinical review*.

| Status | Topics | Behaviour |
|---|---|---|
| **Available** | Respiratory Distress, ANCS, Hypoglycemia, ROP | Questions and rules from the approved STWs, delegated to the existing validated engines |
| **Coming soon** | the other 10 | Selectable; shows *"Clinical workflow content requires the corresponding approved STW."* No questions, rules or recommendations |

The standalone RD and ROP screens described below are still in the app (routes `/rd`, `/rop`) but are no longer linked from the assessment flow.

### Respiratory Distress (RD) Module

| Step | What the clinician does | What the app does |
|---|---|---|
| **Diagnose** | Ticks one or more signs — RR >60/min, chest retractions, nasal flaring, grunting | Confirms Respiratory Distress criteria are met |
| **Enter GA** | Enters gestational age (weeks + days), or birth weight if GA is uncertain | Classifies baby as **≤34 weeks** or **>34 weeks** (uses BW ≤1800 g as surrogate when GA unknown) |
| **Grade severity** | Grades all 5 items of the **Silverman-Andersen Score (SAS)** — each 0/1/2, with visual illustrations | Calculates total SAS (0–10), classifies as **Mild (≤3)** or **Moderate–Severe (≥4)** |
| **Get initial plan** | Reviews the generated treatment plan | Produces a complete initial management plan: respiratory support mode (CPAP / nasal O₂), caffeine advice, feeding guidance, IV fluid indications, and "Do NOT" reminders — all with cited reasoning |
| **Reassess** | Enters follow-up SpO₂, updated SAS, and clinical flags (apnea, shock, fatigue, etc.) | Determines outcome: **Improving → wean**, **Not improving → optimise**, **CPAP failure → refer urgently**, or **Surfactant indicated** — with step-by-step actions |

### ROP Screening Module

| Step | What the clinician does | What the app does |
|---|---|---|
| **Eligibility** | Enters GA, birth weight, and risk factors | Determines if ROP screening criteria are met (GA <34 wk, BW <2000 g, or GA 34–36 wk with risk factors) |
| **Timing** | Enters date of birth | Calculates first screening date (2–3 weeks for early window; 4 weeks otherwise), flags overdue cases, and computes postmenstrual age |
| **Findings** | Records per-eye findings — Zone (I/II/III), Stage (0–5), Plus disease, A-ROP, clock hours | Classifies each eye and determines treatment indication based on ICROP staging |
| **Outcome** | Reviews the treatment/follow-up plan | Generates recommendation: **Treatment required** (laser / anti-VEGF), **Follow-up schedule** with next exam date, or **Discharge from screening** — with PMA-based follow-up intervals |

### ANCS Module (Antenatal Corticosteroids)

The person assessed is the **pregnant woman** (maternal GA; no identifiers). Asks GA (weeks + days), the five eligibility criteria, previous ACS courses, special situations and whether the facility has level II care (CPAP). Outputs, verbatim from the STW: **GIVE ACS** (dexamethasone sodium phosphate 6 mg IM every 12 hours × 4 doses, with the IMPORTANT note and documentation checklist), **GIVE ONE REPEAT COURSE**, **Do NOT give** with every matching WHEN NOT TO GIVE reason, special-situation advice and **REFERRAL/TRANSFER**. Rules: `lib/features/ancs/domain/`.

### Neonatal Hypoglycemia Module

Whom to screen (8 STW risk groups) and the monitoring schedule, then the flowchart from **BG <45 mg/dL**: asymptomatic & BG ≥25 → supervised feeding and 1-hour re-check; symptomatic or BG <25 → IV bolus 2 ml/kg 10% dextrose + GIR 6 mg/kg/min (bolus volume shown with its formula when a weight is entered); on IV glucose → increase GIR by 2 (max 12), wean after 24 h euglycemia, stop IV fluids on GIR 4 with adequate enteral feeds; persistent/refractory → refer + hydrocortisone. Rules: `lib/features/hypoglycemia/domain/`.

Every rule, threshold, dose and wording of both modules is listed with its PDF box in [CLINICAL_REVIEW.md](CLINICAL_REVIEW.md), with the open clinical questions that need sign-off before release. Each module also has 8 MCQs + 6 case scenarios written only from its PDF, and a verbatim **STW reference** screen (DOs/DON'Ts, KPIs, abbreviations, references, disclaimer).

### Additional Features

- **Institutional Partners Section** — Landing page displays the 5 collaborating institutions (ICMR, SRHU, AIIMS Delhi, PGIMER, GMCH) with their logos
- **Adding a new STW** — define its questions, variables and rules as a `StwWorkflow` (see `rd_workflow.dart`), register it in `workflowFor()` and mark the topic `available` in `conditionDefinitions`; the selection screen, engine and summary need no changes
- **Source PDF Viewer** — Embedded viewer for the original STW documents directly within the app
- **References Screen** — Quick access to both STW source PDFs
- **Clinical Disclaimer** — Full DHR/ICMR advisory disclaimer accessible from the home screen
- **About Screen** — App description and attribution information
- **Share** — Clinicians can share assessment summaries

---

## Institutional & Research Partners

| Institution | Role |
|---|---|
| **ICMR** — Indian Council of Medical Research | Primary STW author; app branding |
| **SRHU** — Swami Rama Himalayan University, Dehradun | Development partner |
| **AIIMS Delhi** — All India Institute of Medical Sciences, New Delhi | Expert panel / clinical review |
| **PGIMER** — Postgraduate Institute of Medical Education & Research, Chandigarh | Expert panel / clinical review |
| **GMCH** — Government Medical College & Hospital, Chandigarh | Expert panel / clinical review |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart SDK ≥3.5.0) |
| State Management | Flutter Riverpod |
| Navigation | GoRouter |
| PDF Rendering | pdfx |
| Sharing | share_plus |
| Fonts | Poppins, Inter (bundled) |
| Platforms | Android, iOS, Web |
| **Responsive Design** | **Fully optimized for mobile, tablet, and desktop web** |

---

## Project Structure

```
neonatal_stw/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── app.dart                           # MaterialApp, GoRouter routes, theme
│   ├── content/
│   │   └── stw_content.dart               # Static STW text (disclaimer, DOs/DON'Ts, algorithm)
│   ├── core/
│   │   ├── theme.dart                     # AppTheme colours, typography, design tokens
│   │   ├── config/                        # App configuration
│   │   └── widgets/
│   │       └── app_branding.dart          # Reusable StwNeoBrand header (ICMR logo + screen name; "STW Neo" wordmark on Landing only)
│   ├── features/
│   │   ├── condition_selection/           # 14-condition checklist
│   │   │   ├── domain/neonatal_condition.dart     # NeonatalCondition enum + ConditionDefinition registry
│   │   │   ├── state/condition_selection_controller.dart
│   │   │   └── ui/condition_selection_screen.dart # /conditions
│   │   ├── clinical_workflow/             # Dynamic assessment engine
│   │   │   ├── domain/                        # Pure Dart
│   │   │   │   ├── assessment_context.dart    # ClinicalAssessmentContext
│   │   │   │   ├── assessment_engine.dart     # Question resolver + rule engine + pruning
│   │   │   │   ├── condition_expr.dart        # AND/OR/NOT and comparison conditions
│   │   │   │   ├── clinical_question.dart     # ClinicalQuestion, QuestionGroup, options
│   │   │   │   ├── clinical_rule.dart         # ClinicalVariable, ClinicalRule
│   │   │   │   ├── clinical_finding.dart      # ClinicalFinding, categories, levels
│   │   │   │   ├── shared_questions.dart      # GA, birth weight, DOB (asked once)
│   │   │   │   ├── source_reference.dart      # STW source metadata
│   │   │   │   ├── workflow_definition.dart   # StwWorkflow / PendingWorkflow, QuestionUse
│   │   │   │   ├── workflow_registry.dart     # workflowFor(): topic → workflow
│   │   │   │   └── combined_summary.dart      # CombinedAssessmentSummary
│   │   │   ├── state/assessment_controller.dart # Riverpod: answers, pages, Back, reassessment loop
│   │   │   └── ui/                            # /workflow: question pages, findings sheet, summary
│   │   ├── landing/ui/
│   │   │   ├── landing_screen.dart                # Landing / splash screen
│   │   │   └── institutional_partners_section.dart # 5 partner logos + names
│   │   ├── home/
│   │   │   └── home_screen.dart           # Home dashboard, module cards, About screen
│   │   ├── rd/                            # Respiratory Distress module
│   │   │   ├── domain/
│   │   │   │   ├── rd_rules.dart          # Pure-Dart decision engine (diagnosis → plan → reassess)
│   │   │   │   ├── rd_workflow.dart       # RD questions, variables and rules for the assessment engine
│   │   │   │   └── sas.dart               # Silverman-Andersen Score model
│   │   │   ├── state/                     # Riverpod state management
│   │   │   └── ui/
│   │   │       ├── rd_screen.dart         # RD wizard screen
│   │   │       ├── sas_calculator.dart    # Visual SAS grading UI with illustrations
│   │   │       └── rd_results.dart        # Treatment plan display
│   │   ├── rop/                           # ROP Screening module
│   │   │   ├── domain/
│   │   │   │   ├── rop_rules.dart         # Pure-Dart decision engine (eligibility → timing → findings)
│   │   │   │   └── rop_workflow.dart      # ROP questions, variables and rules for the assessment engine
│   │   │   ├── state/                     # Riverpod state management
│   │   │   └── ui/
│   │   │       ├── rop_screen.dart        # ROP wizard + reference screen
│   │   │       ├── screening_steps.dart   # Eligibility & timing steps
│   │   │       ├── findings_step.dart     # Per-eye findings input
│   │   │       └── summary_step.dart      # Treatment / follow-up outcome
│   │   ├── references/ui/
│   │   │   ├── references_screen.dart     # List of source PDFs
│   │   │   └── pdf_viewer_screen.dart     # In-app PDF viewer
│   │   └── splash/                        # Splash screen
│   └── shared/                            # Shared utilities
├── assets/
│   ├── fonts/                             # Poppins & Inter font families
│   ├── images/                            # Logos, hero image, SAS illustrations
│   │   ├── sas/                           # 15 SAS grade illustrations (5 items × 3 grades)
│   │   └── landing/                       # Landing page assets
│   └── pdfs/                              # Original STW PDFs (RD & ROP)
├── test/
│   ├── neonatal_condition_test.dart       # 14-condition model
│   ├── condition_selection_test.dart      # Selection controller
│   ├── condition_expr_test.dart           # Condition operators and missing-value semantics
│   ├── assessment_engine_test.dart        # Shared questions, visibility, pruning, pages (fixtures)
│   ├── rd_workflow_test.dart              # RD branches through the engine
│   ├── rop_workflow_test.dart             # ROP branches through the engine
│   ├── multi_condition_test.dart          # RD + ROP shared answers, deselection, summary
│   ├── condition_flow_widget_test.dart    # Selection → dynamic assessment → summary (UI)
│   ├── rd_rules_test.dart                 # Unit tests for RD decision logic
│   ├── rop_rules_test.dart                # Unit tests for ROP decision logic
│   ├── sas_test.dart                      # Unit tests for SAS scoring
│   ├── landing_page_test.dart             # Widget tests for landing & home screens
│   ├── widget_smoke_test.dart             # End-to-end widget smoke tests
│   ├── layout_overflow_test.dart          # Responsive layout overflow tests
│   └── references_test.dart               # References screen tests
└── pubspec.yaml
```

---

## Architecture

The app follows a **feature-first** architecture with clean separation of concerns:

```
feature/
├── domain/    # Pure Dart — decision rules, models, no Flutter imports
├── state/     # Riverpod providers and controllers
└── ui/        # Flutter widgets and screens
```

**Key design decision:** All clinical decision logic lives in `domain/` as pure Dart with zero Flutter dependencies. This means every branching rule (diagnosis criteria, SAS severity thresholds, CPAP failure conditions, surfactant criteria, ROP treatment indications, follow-up intervals) can be **unit-tested independently** without a widget test harness.

---

## Responsive Design

The application is **fully responsive** and optimized for web deployment across all device sizes:

### Screen Support
- **Mobile (320px - 768px)**: Optimized single-column layouts with touch-friendly controls
- **Tablet (768px - 1200px)**: Enhanced layouts with adaptive spacing and multi-column grids
- **Desktop (1200px+)**: Maximum-width constraints with centered content for optimal readability

### Key Features
- **Adaptive Breakpoints**: Smart layout adjustments at 6 breakpoints (mobile, mobile landscape, tablet, tablet landscape, desktop, large desktop)
- **Touch Targets**: All interactive elements meet WCAG AA guidelines (minimum 48x48 dp)
- **Responsive Typography**: Text scales appropriately with improved line heights (1.5) for readability
- **Progressive Enhancement**: Mobile-first approach with enhancements for larger screens
- **Flexible Grids**: Automatic column adjustment based on available space
- **Smart Padding**: Context-aware spacing that adapts to screen size

### Responsive Components
The app includes comprehensive responsive utilities:
- `ResponsiveBuilder`: Build different layouts for mobile/tablet/desktop
- `ResponsiveGrid`: Auto-adjusting grid layouts
- `ResponsiveRowColumn`: Switches between row and column based on breakpoint
- `ResponsivePadding`: Adaptive spacing
- Context extensions for easy responsive checks (`context.isMobile`, `context.isTablet`, etc.)

See [RESPONSIVE_DESIGN.md](docs/RESPONSIVE_DESIGN.md) for detailed documentation.

---

## Getting Started

### Prerequisites

- Flutter SDK ≥3.5.0 ([install guide](https://docs.flutter.dev/get-started/install))
- An Android or iOS device/emulator, or a web browser

### Run the app

```bash
# Clone and enter the project
cd neonatal_stw

# Get dependencies
flutter pub get

# Run on a connected device or emulator
flutter run

# Run on web
flutter run -d chrome
```

### Run tests

```bash
# All tests (unit + widget)
flutter test

# Only the RD decision-logic unit tests
flutter test test/rd_rules_test.dart

# Only the ROP decision-logic unit tests
flutter test test/rop_rules_test.dart
```

---

---

## STW Clinical Assistant & Grounded Retrieval (Goal A)

**STW Neo** includes a zero-hallucination, offline-first Clinical Assistant strictly grounded in the approved ICMR / DHR STW PDFs:
- **Zero Hallucination**: Answers are strictly extracted verbatim from the source documents. If a query is not covered in the approved STW documents, the system replies with: *"This information is not covered in the approved STW documents."*
- **Visual PDF Highlighting**: Every bot answer includes a source badge (Document, Page, Section Title) and a **"View in PDF"** action. Tapping it navigates to the exact PDF page, centers the viewport, and renders a translucent amber overlay (`#F59E0B` with 35% fill and amber border) over the exact normalized bounding box coordinates.
- **Hybrid Lexical Search**: Powered by on-device BM25 ranking with clinical synonym expansion (`assets/stw_index/clinical_synonyms.json`), entity boosting for vital thresholds (e.g. `20 mg/kg`, `5 cm H2O`), and whole-word regex matching.

### Running the STW Index Build Script

The pre-built index extracts text blocks, tables, and flowchart algorithms using PyMuPDF (`fitz`):

```bash
# 1. Install prerequisites (Python 3.10+)
pip install pymupdf

# 2. Run the indexer from project root
python tools/build_stw_index.py
```

The script will:
- Parse `assets/pdfs/respiratory_distress_neonates_stw.pdf` and `assets/pdfs/retinopathy_of_prematurity_stw.pdf`.
- Extract logical clinical blocks and compute normalized `(0.0 - 1.0)` bounding boxes relative to page dimensions.
- Verify that 100% of chunk texts exist verbatim within the source PDF pages.
- Output the indexed knowledge base to `assets/stw_index/stw_index.json`.

---

## Database & Offline Sync (Goal B)

The application persists de-identified clinical screening workflows, MCQ evaluations, and chatbot query logs via a secure Node.js + Express REST API backed by **MongoDB Atlas** using an offline-first queue:
- **Strictly De-Identified**: No patient names, hospital numbers (MRNs), or dates of birth are collected or stored.
- **Offline-First Resilience**: All writes are first committed locally to Hive (IndexedDB on Web/PWA, binary storage on mobile). When network connectivity is established, a background sync worker flushes pending operations via idempotent REST operations with client-generated UUIDs.
- **Architecture**: The Flutter app communicates ONLY via REST endpoints (`/sessions`, `/screenings`, `/chat-logs`) and never stores MongoDB credentials directly.

### Release builds (Web, PWA, APK)

Web/PWA and the APK are built from this one project with the same settings
file, `build.env` (git-ignored: `API_BASE_URL=https://…`, `API_KEY=…`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy_web.ps1   # Web + PWA: build, commit, push; server: git pull
powershell -ExecutionPolicy Bypass -File scripts\build_apk.ps1    # APK: dist\STW-Neo-<version>.apk
```

See [docs/RELEASE.md](docs/RELEASE.md). For development, pass the same values
with `--dart-define` to `flutter run`:

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=API_KEY=your-client-api-key
```

*Note: If `--dart-define` parameters are omitted (e.g., in air-gapped hospital tablets or unit test runners), the app gracefully operates in local-only offline mode with full functionality.*

---

## Adding a New Disease STW PDF in the Future

When ICMR / DHR releases an approved STW PDF for another neonatal condition (e.g., Sepsis, Jaundice):
1. **Add PDF**: Place the approved PDF in `assets/pdfs/<disease_code>_stw.pdf`.
2. **Re-run Indexer**: Run `python tools/build_stw_index.py`. The script will parse the new PDF, generate bounding boxes, and rebuild `assets/stw_index/stw_index.json`. The chatbot will immediately be able to answer questions grounded in the new STW.
3. **Activate in Database**: In the database, mark the disease active in the `diseases` collection:
   ```json
   { "code": "<disease_code>", "isActive": true }
   ```
4. **Implement Workflow**: Define the clinical decision rules in `lib/features/<disease_code>/domain/` following the existing `rd_workflow.dart` pattern and update `status: ConditionStatus.available` in `lib/features/condition_selection/domain/neonatal_condition.dart`.

---

### Regions for the ANCS and Hypoglycemia PDFs

The chatbot and "View in PDF" use the curated regions in `assets/regions/regions.json`. For the two 8th-Oct posters they are defined in `tools/add_ancs_hypo_regions.py` (boxes taken from the PDF's own card rectangles, English + Hinglish aliases):

```bash
python tools/render_pages.py Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf Neonatal_Hypoglycemia_8th_Oct.pdf
python tools/add_ancs_hypo_regions.py
python tools/build_region_text.py Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf Neonatal_Hypoglycemia_8th_Oct.pdf
```

Passing file names limits each script to those documents, so the RD/ROP pages and regions are left untouched. `build_region_text.py` skips text hidden under a later-drawn box (the hypoglycemia flowchart has such duplicate labels).

## PDF Layout & Bounding Box Verification Notes

The two bundled STW documents have unique layout characteristics:
1. **Single-Page Poster Format**: Both `respiratory_distress_neonates_stw.pdf` and `retinopathy_of_prematurity_stw.pdf` are tall clinical posters ($841.89 \times 1633.68$ pt, aspect ratio $\approx 0.5153$) rather than multi-page A4 books.
2. **Normalized Coordinates**: All bounding box coordinates in `stw_index.json` are stored as normalized fractions `[0.0, 1.0]` of the page width and height (`x, y, width, height`). This allows the visual highlight overlay in `PdfViewerScreen` to align at any zoom level, pixel density, or device orientation.
3. **Algorithm & Flowchart Boxes**: Decision trees and flowcharts (e.g. *Algorithm for Retinopathy of Prematurity Management* and *Algorithm for Assessment and Management of Respiratory Distress*) are extracted as unified regions spanning their enclosing cards. Clinicians can verify the boundaries in `assets/stw_index/stw_index.json`.

---

## Clinical Disclaimer

> This STW has been prepared by national experts of India with feasibility considerations for various levels of healthcare system in the country. These broad guidelines are advisory, and are based on expert opinions and available scientific evidence. There may be variations in the management of an individual patient based on his/her specific condition, as decided by the treating physician. There will be no indemnity for direct or indirect consequences. Kindly visit the website of DHR for more information (stw.icmr.org.in).
>
> © Department of Health Research, Ministry of Health & Family Welfare, Government of India.

---

## Version

`0.1.0+1` — Based on ICMR / DHR STW documents (August 2026).

