# Neonatal STW app: UI/UX and functional spec

**Source documents:** ICMR/DHR Standard Treatment Workflows (August 2026)
- *Respiratory Distress in Neonates*, ICD-11 KB23
- *Retinopathy of Prematurity (ROP)*, ICD-11 9B71.3

**Status:** v0.1, working Flutter prototype (Android / iOS / web)

> **Authoritative source:** [`docs/STW_APP_SPEC_FROM_PDFs.md`](STW_APP_SPEC_FROM_PDFs.md) is the single source of truth extracted directly from the two PDFs. If anything in this SPEC.md conflicts with that file, the PDF-extracted spec wins.

---

## 1. What the app is

Each STW is a one-page **decision tree**. Every branch depends on a few discrete bedside findings: SAS grade per item, gestation band, current respiratory support, and ROP zone/stage/plus. The app turns each page into an **interactive form**:

1. The doctor records findings with **radio buttons, checkboxes, number fields and date pickers**.
2. The applicable STW step appears **live** as a colour-coded recommendation, with the rule that triggered it shown under **"Why"**.
3. The relevant DOs/DON'Ts appear in context. The full STW text is always one tap away (Reference).

**Stateless by design.** Nothing is saved. Data stays in memory for the current baby and is cleared by **New baby** or when the app closes. The ROP module ends with a **copy/share text summary** for the discharge card. That summary is how the STW requirement to "document date and place of next screening" is met.

Recommendations are advisory. The STW disclaimer is shown on every screen and in full under About.

---

## 2. Screens

```
Landing (SRHU STW) ─┬─ Respiratory Distress ─┬─ Assess (diagnose → gestation → SAS → initial plan)
                       │                        ├─ Reassess (support, PEEP/FiO₂/SpO₂, repeat SAS → next step)
                       │                        └─ Reference (DOs/DON'Ts, algorithm, KPIs, abbreviations, Source PDF)
                       ├─ ROP Screening ──────── wizard: 1 Eligibility → 2 Timing → 3 Prepare → 4 Findings → 5 Follow-up
                       │                         (+ Reference, Source PDF)
                       ├─ References ─────────── 2 original STW PDF cards + in-app pinch-zoom viewer + cited sources
                       ├─ Disclaimer (bottom sheet)
                       └─ Home ───────────────── Current baby card & module overview (via app bar Home icon)
```

**Landing page ("SRHU STW").** Single-screen entry point designed without scrolling to fit screens from 320x568 up to 412x915 and tablets:
- **Brand Row:** Free SRHU logo (`assets/images/logo212.png`, 36-40 px, no box/border), "SRHU" (blue) + "STW" (navy) title, and "Based on ICMR / DHR Standard Treatment Workflows" subtitle.
- **Hero:** Soft blue-white wave bottom edge (`_HeroWaveClipper`), headline "Better Care for Every New Beginning", gradient-blended baby newborn photo with gentle breathing and floating heart animations.
- **Module Cards:** Side-by-side cards with press animation for "Respiratory Distress in Neonates" (lungs image/badge, direct blue "Get Started →" button) and "Retinopathy of Prematurity (ROP)" (eye image/badge, direct pink "Get Started →" button).
- **Feature Row:** 4 trust indicators ("Based on STW Workflows", "Guideline-Aligned", "For Medical Students & Doctors", "Practical Clinical Support"), hidden automatically on compact screens <680 px high.
- **Footer:** Handwritten motto "Small Steps, Brighter Tomorrows" with heart ribbon doodle, alongside tappable text links for "Disclaimer" (bottom sheet) and "References".
- **Home Access:** The existing Home screen remains accessible via the Home icon in both modules' app bars.

**Home.** Two module cards, each showing a one-line live status. Below them is the **Current baby** card: GA weeks + days, birth weight, date of birth. Both modules share these details, so they are entered once.

**Phones:** a sticky **recommendation bar** at the bottom always shows the current advice; tap it for the full detail. **Tablets (≥900 px):** the form is on the left and the live result on the right.

**Colour meaning.** Colour is never the only signal; each colour comes with an icon and text.

| Colour | Meaning | Examples |
|---|---|---|
| Green | Improving / no action needed | Wean support; not eligible for ROP screening |
| Amber | Act or monitor | Start CPAP; not improving |
| Pink | Specific treatment | Surfactant; treatment-requiring ROP |
| Red | Failure / urgent | CPAP failure → refer; A-ROP; screening overdue; no follow-up plan |
| Blue | Information / input still needed | Recommendation pending |

---

## 3. Where radio buttons and other inputs are used

Radio buttons are used wherever the STW gives **mutually exclusive** categories. Checkboxes are used where it says **"any one of"**.

### Respiratory Distress

| STW element | Control |
|---|---|
| RR >60, chest retractions, nasal flaring, grunting ("any one") | Checkboxes; an optional RR number field ticks "RR >60" automatically |
| Immediate actions (TABC, admit, thermal care, pulse oximeter, monitor) | Checklist |
| GA known / GA uncertain | **Radio** (uncertain → birth weight ≤1800 g is used as surrogate) |
| GA (weeks + days), birth weight (g) | Number fields with range checks |
| **SAS: Upper chest, Lower chest, Xiphoid, Nares, Grunt, each grade 0/1/2** | **Radio group per item, with the STW drawing beside each grade.** Live total 0–10 and severity (Mild ≤3, Moderate–severe ≥4) |
| Severe distress (clinician judgement), recurrent apnea, poor perfusion, abdominal signs | Checkboxes (decide IV fluids per STW) |
| Current support: CPAP / Nasal-prong O₂ / Off support | **Radio** |
| PEEP 4–8 cm H₂O | −/+ stepper |
| FiO₂ 0.21–1.00 | Slider |
| SpO₂ % | Number field (target 91–95 shown) |
| Comfortable breathing | Checkbox (required for improving status) |
| Repeat SAS | Same radio groups; trend ↑/↓/= against the previous SAS |
| Rising O₂ need, apnea/bradycardia, fatigue, shock, deterioration, persistent hypoxemia | Checkboxes |
| Sepsis triggers | Checkboxes |

### ROP

| STW element | Control |
|---|---|
| GA, birth weight | Number fields |
| 34–36 wk risk factors (6 + unstable course) | Checkboxes, shown only when GA is 34–36 |
| Date of birth | Date picker → postnatal age, PMA, first-screen due date (not yet due / overdue) |
| Follow-up after discharge assured? Yes / No / Uncertain | **Radio** |
| Prepare / how to screen | Checklist + dilating-drop timer (10-min interval, up to 3 doses) |
| Right eye / Left eye | Segmented toggle, with "same findings for other eye" |
| **Zone I / II / III** | **Radio** |
| **Stage: No ROP / 1 / 2 / 3 / 4 / 5** | **Radio** |
| **Plus disease: No plus / Plus present** | **Radio** |
| A-ROP suspected, progressive disease, prior anti-VEGF, reactivation/PAR | Switches |
| Retina status: immature / active ROP / regressed / fully vascularised | **Radio** |
| Next exam date, place, family counselled | Date picker (doctor-selected with STW reference intervals shown), text field, checkbox |

---

## 4. Decision rules implemented

GA thresholds use **completed weeks** (34+5 counts as 34 weeks).

### Respiratory Distress: initial plan
- No sign ticked → "Does not meet RD criteria"; the rest of the form is disabled.
- **GA ≤34 wk** (or GA uncertain and BW ≤1800 g), any RD → **START CPAP 5–6 cm H₂O**, blended O₂, SpO₂ 91–95%, within 30 min.
- **GA >34 wk and SAS ≥4** → **START CPAP** (moderate–severe).
- **GA >34 wk and SAS ≤3** → **Nasal-prong O₂ 0.5–1 L/min** (mild).
- **Caffeine citrate** if GA <34 wk. If GA is uncertain and the BW surrogate applies: "if GA <34 wk".
- **Feeding:** mild → direct breastfeed; moderate–severe or on CPAP → gastric-tube feeds; **IV fluids** if severe distress (clinician judgement checkbox), recurrent apnea, poor perfusion or abdominal signs.
- **DON'Ts in context:** mild RD → no routine CBC/CRP/CXR/blood gas; always → no unmonitored O₂.

### Respiratory Distress: reassessment (first match wins)
1. **CPAP failure** (on CPAP): persistent hypoxemia/high FiO₂ requirement, recurrent apnea/bradycardia, shock or fatigue (clinician-ticked checkboxes) → **refer urgently; do not delay ventilation or referral** (no automatic SpO₂/PEEP cutoff).
2. **Surfactant:** <34 wk **and** on CPAP **and** PEEP >6 **and** FiO₂ >0.30.
3. **Not improving / worsening:** SAS increasing, or SAS persisting ≥4 (only if no previous SAS or current == previous and ≥4; decreasing SAS is never categorized as not improving), SpO₂ <91%, rising O₂ need, apnea, fatigue/shock, deterioration. On CPAP → **optimise CPAP**: the next PEEP step is shown (up to 7–8), plus titrate FiO₂, find the cause, and consider surfactant. On nasal O₂ → **NOT IMPROVING / WORSENING**: verbatim STW box content (titrate O₂ to 91–95%, look for/treat cause, consider sepsis) without invented escalation instructions.
4. **Improving:** decreasing SAS (current < previous) **AND** SpO₂ 91–95% on stable/reducing support **AND** comfortable breathing ticked (SAS ≤3 alone does not count as improving; SpO₂ outside 91–95 does not improve) → **weaning helper**. FiO₂ goes down first to 0.21, then PEEP drops 1 cm H₂O at a time to 4–5, then CPAP stops, followed by 24 h of SpO₂ monitoring.
5. Otherwise **stable**: continue and reassess.
- Side alerts: SpO₂ >95% → "SpO₂ above target range (91–95%)" (neutral alert; no instruction to reduce FiO₂); any sepsis trigger → "Consider sepsis".
- "Record SAS & start next reassessment" keeps the SAS trend for the session.

### ROP
- **Eligible** if GA <34 wk, **or** BW <2000 g, **or** GA 34–36 wk with ≥1 risk factor / unstable course.
- **First screen due:** by day 21 (window day 14–21) if GA <28 wk or BW <1200 g, otherwise by day 28. Status: not yet due / **overdue → screen ASAP** (no "due within 7 days" status). If follow-up is not assured → "screen before discharge even if not due".
- **Per eye, first match wins:** A-ROP → **urgent**; stage 4–5 → **refer for vitreo-retinal surgery**; reactivation/PAR after anti-VEGF with stage 2–3 → **treat**; Zone I with plus (stage ≥1) or Zone I stage 3 → **treat**; Zone II stage 2–3 with plus → **treat**; otherwise **no treatment now**. Review within 1 week if Zone I or progressive, else every 1–3 weeks as advised.
- Any treatment → "treat within 48–72 h; laser and/or anti-VEGF per specialist".
- **Stopping:** shown only for fully vascularised/regressed retina, and worded "only if advised by an ROP-trained ophthalmologist". After anti-VEGF it is blocked until **65 weeks PMA**, with that date calculated.
- **Follow-up step:** Doctor picks the next exam date (no auto-suggested dates). Verbatim STW guidance displayed next to date picker ("usually every 1–3 weeks", "posterior or progressive disease / suspected A-ROP may require review within 1 week or sooner", "treatment-requiring ROP: treat within 48–72 hours of decision"). A red **"DO NOT discharge/transfer without a documented follow-up plan"** banner shows until date and place are entered. The discharge-card summary can be copied or shared.

---

## 5. Points to confirm with the supervisor

| # | Item | Current behaviour |
|---|---|---|
| 1 | GA completed weeks vs decimal days (e.g. GA 34+3 weeks) | Treated as "≤34 weeks" based on completed weeks |
| 2 | ROP line "Reactivation/significant PAR after anti-VEGF; stage 2–3; stage 4–5" | Ambiguous in the PDF; currently read as reactivation with stage 2–3 → treat; stage 4–5 → surgery referral |
| 3 | Related-information QR codes (bubble CPAP setup, ROP record form, etc.) | The QR images in the PDF could not be decoded; they appear as "link to be added" |
| 4 | "Administer surfactant within 2 hours": 2 hours from what? | Shown as the STW wording, with no timer |

---

## 6. Not included (by the stateless decision)

- No patient records, history across sessions, or sync.
- **KPIs** (timely CPAP initiation, SpO₂ compliance, ROP coverage, timely first screen) are shown as definitions only. Calculating them requires stored records. A future version with local storage could compute them directly from the same inputs.

---

## 7. References and Source STW PDFs

The app bundles the two official ICMR/DHR Standard Treatment Workflow PDFs as offline assets:
- `assets/pdfs/respiratory_distress_neonates_stw.pdf` (*Respiratory Distress in Neonates*, ICD-11 KB23, August 2026)
- `assets/pdfs/retinopathy_of_prematurity_stw.pdf` (*Retinopathy of Prematurity (ROP)*, ICD-11 9B71.3, August 2026)

### Key Features:
- **Explicit On-Demand Access:** PDFs never open automatically. Clinicians open a PDF only by tapping "View PDF" or "Source PDF".
- **Dedicated References Screen (`/references`):**
  - Two summary cards (one per PDF) with ICD-11 codes and direct "View PDF" actions.
  - "Sources cited in the STWs" section documenting the verbatim external clinical guidelines referenced in the source workflows (NNF India CPGs, MoHFW RBSK Universal Eye Screening).
  - Official STW disclaimer.
- **Entry Points:**
  - Landing screen: secondary "References & Source STW PDFs" link.
  - Home screen: "References & STW Documents" navigation card and app bar action.
  - Respiratory Distress module: "Source PDF" action in app bar and direct "View PDF" card in the Reference tab.
  - ROP module: "Source PDF" action in app bar and direct "View PDF" card in the Reference screen.
- **In-App PDF Viewer (`/pdf-viewer`):**
  - Full-screen high-fidelity rendering powered by `pdfx` (offline asset rendering).
  - Smooth pinch-to-zoom, double-tap zoom, and scrolling for dense one-page poster readability.
  - Landscape and portrait orientations supported.
  - "Open in another app / Share" action exports the asset to temporary storage and invokes the system viewer/share sheet.
  - Loading indicators and graceful error handling with retry.

