# STW Neo — Neonatal Clinical Decision Support

**STW Neo** is a cross-platform mobile application built with [Flutter](https://flutter.dev) that provides bedside decision support for two ICMR / DHR (Indian Council of Medical Research / Department of Health Research) **Standard Treatment Workflows (STWs)**:

1. **Respiratory Distress in Neonates** (ICD-11 KB23)
2. **Retinopathy of Prematurity — ROP** (ICD-11 9B71.3)

The app digitises the paper-based STW algorithms into an interactive, step-by-step clinical tool that clinicians can use at the bedside. **No patient data is stored** — all inputs are kept in memory and cleared when the app is closed.

---

## What Does It Do?

### Multi-condition workflow

From Home, **Get Started** opens a checklist of 14 neonatal conditions / care areas: Triage, Thermal Care, KMC, Fluids & Feeds, Respiratory Distress, ANCS, Sepsis, Hypoglycemia, Jaundice, Seizures, HIE, Transport, ROP, Discharge & Follow-up. The clinician ticks one or more and taps **Continue**. The app then builds one combined workflow:

```
Baby details (GA, birth weight, DOB — asked once, only what the selected workflows need)
  → each selected condition, in the order above
  → Clinical Assessment Summary (copy / share)
```

| Status | Conditions | Behaviour |
|---|---|---|
| **Available** | Respiratory Distress, ROP | Opens the existing RD / ROP module described below; the summary reuses its results |
| **Coming soon** | the other 12 | Selectable, but shows only *"Clinical workflow content will be added from the corresponding approved STW."* No clinical questions or recommendations are generated |

Going back to the selection keeps the ticks. Removing a condition discards anything recorded for it, so it cannot appear in the summary.

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
- **Adding a new STW** — add its questions as a `QuestionnaireWorkflow` (or a dedicated module) in `workflowFor()` and mark the condition `available` in `conditionDefinitions`; the selection screen, orchestration and summary need no changes
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
│   │       └── app_branding.dart          # Reusable StwNeoBrand widget (ICMR logo + "STW Neo")
│   ├── features/
│   │   ├── condition_selection/           # 14-condition checklist
│   │   │   ├── domain/neonatal_condition.dart     # NeonatalCondition enum + ConditionDefinition registry
│   │   │   ├── state/condition_selection_controller.dart
│   │   │   └── ui/condition_selection_screen.dart # /conditions
│   │   ├── clinical_workflow/             # Orchestrates the selected conditions
│   │   │   ├── domain/
│   │   │   │   ├── workflow_definition.dart   # workflowFor() registry, buildWorkflowPlan()
│   │   │   │   ├── clinical_question.dart     # Data-driven questions + ShowWhen branching (for future STWs)
│   │   │   │   └── combined_summary.dart      # Plain-text combined summary
│   │   │   ├── state/workflow_controller.dart # Plan, current step, answers; prunes removed conditions
│   │   │   └── ui/                            # /workflow: steps, module launch, placeholders, summary
│   │   ├── landing/ui/
│   │   │   ├── landing_screen.dart                # Landing / splash screen
│   │   │   └── institutional_partners_section.dart # 5 partner logos + names
│   │   ├── home/
│   │   │   └── home_screen.dart           # Home dashboard, module cards, About screen
│   │   ├── rd/                            # Respiratory Distress module
│   │   │   ├── domain/
│   │   │   │   ├── rd_rules.dart          # Pure-Dart decision engine (diagnosis → plan → reassess)
│   │   │   │   └── sas.dart               # Silverman-Andersen Score model
│   │   │   ├── state/                     # Riverpod state management
│   │   │   └── ui/
│   │   │       ├── rd_screen.dart         # RD wizard screen
│   │   │       ├── sas_calculator.dart    # Visual SAS grading UI with illustrations
│   │   │       └── rd_results.dart        # Treatment plan display
│   │   ├── rop/                           # ROP Screening module
│   │   │   ├── domain/
│   │   │   │   └── rop_rules.dart         # Pure-Dart decision engine (eligibility → timing → findings)
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
│   ├── workflow_plan_test.dart            # Orchestration, pruning, questionnaire branching
│   ├── condition_flow_widget_test.dart    # Selection → workflow → summary widget flow
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
