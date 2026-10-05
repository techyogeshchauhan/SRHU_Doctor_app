# STW Neo — Neonatal Clinical Decision Support

**STW Neo** is a cross-platform mobile application built with [Flutter](https://flutter.dev) that provides bedside decision support for two ICMR / DHR (Indian Council of Medical Research / Department of Health Research) **Standard Treatment Workflows (STWs)**:

1. **Respiratory Distress in Neonates** (ICD-11 KB23)
2. **Retinopathy of Prematurity — ROP** (ICD-11 9B71.3)

The app digitises the paper-based STW algorithms into an interactive, step-by-step clinical tool that clinicians can use at the bedside. **No patient data is stored** — all inputs are kept in memory and cleared when the app is closed.

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
| **Available** | Respiratory Distress, ROP | Questions and rules from the approved STWs, delegated to the existing validated engines |
| **Coming soon** | the other 12 | Selectable; shows *"Clinical workflow content requires the corresponding approved STW."* No questions, rules or recommendations |

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

## Clinical Disclaimer

> This STW has been prepared by national experts of India with feasibility considerations for various levels of healthcare system in the country. These broad guidelines are advisory, and are based on expert opinions and available scientific evidence. There may be variations in the management of an individual patient based on his/her specific condition, as decided by the treating physician. There will be no indemnity for direct or indirect consequences. Kindly visit the website of DHR for more information (stw.icmr.org.in).
>
> © Department of Health Research, Ministry of Health & Family Welfare, Government of India.

---

## Version

`0.1.0+1` — Based on ICMR / DHR STW documents (August 2026).
