# Clinical review: ANCS and Neonatal Hypoglycemia modules

**For:** the clinician signing off the two new STW Neo modules before release.
**Sources:** the two ICMR/DHR STW posters (August 2026, single page each), bundled as
`assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf` and
`assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf`. "Box" below means the titled box on the poster.

All on-screen wording is copied from the PDF text layer (`lib/features/ancs/domain/ancs_content.dart`,
`lib/features/hypoglycemia/domain/hypo_content.dart`); only the "ﬁ" ligature is written "fi".
Nothing is taken from outside the PDFs. Where the PDF is unclear, the app uses the PDF wording, marks
the finding **"Requires clinical review"**, and the point is listed under *Open clinical questions*
(IDs A1–A11, H1–H14 are also cited in the code).

Please confirm or correct each row; an "OK" per row is enough.

---

## 1. ANCS — Antenatal Corticosteroids for Preterm Birth

The person assessed is the **pregnant woman**. No name, MRN, date of birth, phone, date or free text is asked.

### 1.1 Questions asked

| # | Question (app) | Answer | Shown when | PDF box |
|---|---|---|---|---|
| 1 | Gestational age (completed weeks) + days | 20–44 wk, 0–6 d | always | WHEN TO GIVE; ELIGIBILITY CRITERIA |
| 2 | "1. High likelihood of preterm birth within the next 7 days due to any one:" — 5 listed causes, tick all that apply | none = no listed cause | GA 24–33 wk | ELIGIBILITY CRITERIA |
| 3 | "2. Gestational age assessed accurately, preferably by early USG" | Yes / No | GA 24–33 wk and a cause ticked | ELIGIBILITY CRITERIA |
| 4 | Clinical chorioamnionitis or systemic maternal infection | Present / Absent | same | ELIGIBILITY CRITERIA; WHEN NOT TO GIVE |
| 5 | "4. Adequate childbirth care is available at the facility or at the referral facility" | Yes / No | same | ELIGIBILITY CRITERIA |
| 6 | "5. Adequate preterm newborn care be ensured(including CPAP) at the facility or the receiving facility" | Yes / No | same | ELIGIBILITY CRITERIA |
| 7 | ACS courses already given: none / one course / a repeat course already given | choice | same | WHEN TO GIVE REPEAT COURSE |
| 8 | Days since the previous ACS course was started | 0–120 | one course given | WHEN TO GIVE REPEAT COURSE |
| 9 | Special situations: multiple pregnancy, fetal growth restriction, hypertensive disorders, diabetes in pregnancy | tick all that apply | same as 3 | SPECIAL SITUATIONS |
| 10 | This facility has at least level II care (CPAP) for preterm infants | Yes / No | same as 3 | REFERRAL/TRANSFER |

### 1.2 Rules and thresholds

| Rule | Implemented as | PDF box / wording |
|---|---|---|
| Eligibility window | completed weeks 24 to 33 (24+0 to 33+6) | WHEN TO GIVE: "Pregnant women at 24+0 to 33+6 weeks of gestation…" |
| ≥34 weeks | **Do NOT give** — "Routine use at ≥34 weeks"; no further questions | WHEN NOT TO GIVE; DON'Ts "…at ≥34+0 weeks" |
| <24 weeks | **ACS eligibility criteria not met** ("Women at 24+0 to 33+6 weeks of gestation"); flagged | see A1 |
| Criterion 1 | any one of: Spontaneous preterm labour…; PPROM without clinical infection; Antepartum Hemorrhage; Severe pre-eclampsia/eclampsia; Planned preterm birth for maternal/fetal indication | ELIGIBILITY CRITERIA 1 |
| No listed cause | **Do NOT give** — "Preterm birth within next 7 days is unlikely"; rest skipped | WHEN NOT TO GIVE; see A2 |
| Criterion 2 not met | criteria not met | ELIGIBILITY CRITERIA 2 |
| Infection present | **Do NOT give** — "Clinical chorioamnionitis or systemic maternal infection" | ELIGIBILITY CRITERIA 3; WHEN NOT TO GIVE |
| Criterion 4 / 5 not met | criteria not met | ELIGIBILITY CRITERIA 4, 5 |
| All five met, no previous course | **GIVE ACS** | ELIGIBILITY CRITERIA |
| One previous course started ≥7 days earlier, all criteria met | **GIVE ONE REPEAT COURSE** (flagged) | WHEN TO GIVE REPEAT COURSE; see A3, A4 |
| One previous course started <7 days earlier | criteria not met: "The previous ACS course was started ≥7 days earlier" | WHEN TO GIVE REPEAT COURSE |
| Repeat course already given | **Do NOT give** — "More than one repeat course" | WHEN NOT TO GIVE; REPEAT COURSE |
| Several "do not give" reasons | all matching reasons are listed | WHEN NOT TO GIVE |
| Special situation ticked | shown; never changes the decision | SPECIAL SITUATIONS |
| No level II care (CPAP) | **REFERRAL/TRANSFER** finding (flagged); does not stop ACS | REFERRAL/TRANSFER; see A5 |

### 1.3 Wording shown in results

| Finding | Text (verbatim) | PDF box |
|---|---|---|
| GIVE ACS | "DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES"; "IMPORTANT: Start ACS promptly once eligibility criteria are met, even if the full course may not be completed before birth" | DRUG & DOSE; ELIGIBILITY CRITERIA |
| GIVE ONE REPEAT COURSE | the same dose and IMPORTANT line, plus "Do NOT give more than one repeat course" and "(More than one repeat course may cause fetal harm, and is not recommended)" | WHEN TO GIVE REPEAT COURSE |
| DRUG & DOSE (with any give decision) | "Dexamethasone is preferred: it is effective, low-cost, widely available and more heat-stable"; "Betamethasone regimen (12 mg every 24 hours x 2 doses) requires an appropriate acetate + phosphate preparation, which is not available in India. Betamethasone phosphate alone is shorter acting than dexamethasone" | DRUG & DOSE |
| Do NOT give ACS | "WHEN NOT TO GIVE: <matching line>" | WHEN NOT TO GIVE |
| SPECIAL SITUATIONS | "When otherwise eligible, do not withhold ACS because of: multiple pregnancy, fetal growth restriction, hypertensive disorders, or diabetes in pregnancy"; with diabetes also "In diabetes: monitor and optimize maternal glucose control" and DO "Monitor maternal glucose closely in women with diabetes" | SPECIAL SITUATIONS; DOs |
| REFERRAL/TRANSFER | "Pregnant women with likelihood of early preterm birth should be referred to a facility (in-utero transfer) with at least level II care (CPAP) for preterm infants"; "Level I facilities can give the first dose of ACS before referral, provided the pregnant woman meets the eligibility criteria, but referral/transfer should not be delayed to complete the course" | REFERRAL/TRANSFER |
| DOCUMENTATION (with any give decision) | "Document: gestational age, indication, drug/dose, date and time, initial/repeat course, next dose due"; "Record in: case sheet, MCP card, and referral slip" | DOCUMENTATION |

The **STW reference screen** ("DOs/DON'Ts & KPIs" button) shows every box verbatim: Introduction,
When to give, Eligibility criteria, Drug & dose, When not to give, Special situations, Repeat course
(including the printed fragment, A7), Documentation, Referral/transfer, DOs, DONTs, KPIs, key message,
abbreviations, references, related-information QR titles, and the PDF disclaimer ("Kindly visit the DHR portal…").

KPIs as shown: ACS coverage (Target ≥80%) with the printed formula; "Appropriate ACS use = (formula not
printed in the STW) (Target: ≥95%)" — see A6.

---

## 2. Neonatal Hypoglycemia (ICD-11 KB60.4)

No identifier, date or free text is asked.

### 2.1 Questions asked

| # | Question (app) | Answer | Shown when | PDF box |
|---|---|---|---|---|
| 1 | Risk factors present — the 8 WHOM TO SCREEN lines verbatim | tick all that apply | always | WHOM TO SCREEN FOR HYPOGLYCEMIA |
| 2 | Blood glucose (BG) | 0–600 mg/dL, optional | always | HOW TO MONITOR BLOOD GLUCOSE |
| 3 | Look for the following symptoms and signs — 5 lines verbatim; none = asymptomatic | tick | BG <45 | LOOK FOR THE FOLLOWING SYMPTOMS AND SIGNS |
| 4 | Current weight (optional) | 300–6000 g | BG <45 | used only for the bolus volume (H8) |
| 5 | Record the 1-hour re-check BG now? → BG at 1-hour re-check; "Symptoms develop" | yes/no; mg/dL; switch | supervised-feeding branch | RE-CHECK BG AFTER 1 HOUR |
| 6 | Record a BG re-check on IV glucose now? → Current GIR; Latest re-check BG | yes/no; 1–20 mg/kg/min; mg/dL | IV glucose started | flowchart |
| 7 | "Persistent (GIR requirement >3-7 days)" / "Refractory (GIR > 10-12 mg/kg/min for 24 hours)" | tick | re-check BG <45 | flowchart; see H5 |
| 8 | "Euglycemic for 24 hours on IV fluids"; then "Tolerating adequate enteral feeds" | switches | re-check BG ≥45 | flowchart |

### 2.2 Rules and thresholds

| Rule | Implemented as | PDF wording |
|---|---|---|
| Risk factor ticked | **At-risk infant — screen**: schedule "At-risk infants: 1, 2, 6, 12, 24, 48, 72 hours"; IDM only: "*in IDM, monitoring can be stopped between 24-36 hours provided feeding is established"; "Infants on IV fluids: Every 6-8 hours"; "BG should be measured pre-feeding"; "Measure BG using a point-of-care glucometer" | SCHEDULE; HOW TO MONITOR |
| No risk factor ticked | "Routine blood glucose monitoring is not required in healthy term AGA neonates" (flagged) | WHOM TO SCREEN; see H1 |
| Flowchart entry | BG **<45** mg/dL | "BLOOD GLUCOSE <45 mg/dL" |
| BG ≥45 | "BG ≥45 mg/dL — hypoglycemia flowchart not triggered" (flagged) | see H2 |
| BG <45 | "Low value (<45 mg/dL): send a blood sample to the lab"; "DO NOT delay treatment for lab confirmation" | HOW TO MONITOR |
| Asymptomatic and BG ≥25 (25–44) | **ASYMPTOMATIC & BG ≥25 mg/dL**: "Immediate supervised feeding"; "Breastfeeding or a measured volume of expressed breastmilk (Formula milk if EBM not available) by paladai or gavage"; "RE-CHECK BG AFTER 1 HOUR" | ASYMPTOMATIC & BG ≥25 mg/dL |
| Any symptom, or BG <25 | **SYMPTOMATIC OR BG < 25 mg/dL**: "IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute"; "Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min"; "Re-check BG every 30 min until 2 consecutive values are ≥45 mg/dL, then every 6 h" | SYMPTOMATIC OR BG < 25 mg/dL; flowchart |
| 1-hour re-check BG ≥45, no symptoms | "If BG ≥ 45 mg/dL": "Continue feeds"; "Continue BG monitoring 6 hourly for 24 hours" | RE-CHECK BG AFTER 1 HOUR |
| 1-hour re-check BG <45, or symptoms develop | "Start IV glucose infusion" + 30-min re-check line (flagged: no bolus or starting GIR shown) | "Start IV glucose infusion if: BG < 45 mg/dL OR Symptoms develop"; see H3 |
| On IV, re-check BG <45, GIR <12 | "Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)"; shows "GIR x → min(x+2, 12)" | flowchart; see H11 |
| On IV, BG <45, GIR ≥12 | "BG < 45 mg/dL at the maximum GIR (12 mg/kg/min)" with the persistent/refractory line | flowchart |
| GIR entered >12 | alert "STW: maximum 12 mg/kg/min" | flowchart; see H12 |
| Persistent or refractory ticked | **REFER**: "Consider ENDOCRINE/ METABOLIC disorders & REFER to higher centre" and **DRUGS FOR REFRACTORY HYPOGLYCEMIA**: "Hydrocortisone: 5 mg/kg/day IV in two divided doses"; "Additional drugs should be administered at a tertiary care hospital with workup for underlying causes" | flowchart; DRUGS box; see H5, H6 |
| On IV, BG ≥45, not yet euglycemic 24 h | 30-min re-check line; "After: Euglycemic for 24 hours on IV fluids → Reduce GIR…" | flowchart |
| Euglycemic 24 h, GIR >4 | "Reduce GIR by 2 mg/ kg/min every 6 hours"; "Increase oral feeds"; "Monitor BG every 6 hours"; stop criterion line | flowchart |
| Euglycemic, GIR = 4, tolerating feeds | **Stop IV fluids** | "Stop IV fluids when euglycemic on GIR 4 mg/ kg/min and tolerating adequate enteral feeds" |
| Euglycemic, GIR = 4, not tolerating feeds | "Stop criteria not yet met" + stop line, increase oral feeds, monitor 6-hourly | same |
| Euglycemic, GIR <4 | "GIR below 4 mg/kg/min — not addressed by the STW" (flagged; no stop advice) | see H4 |
| IV glucose started | PRACTICAL POINTS shown verbatim (5 lines) | PRACTICAL POINTS |
| Symptoms recorded (initial or developed) or persistent ticked | "NEONATES WITH SYMPTOMATIC, SEVERE, RECURRENT OR PERSISTENT HYPOGLYCEMIA SHOULD RECEIVE STRUCTURED NEURODEVELOPMENTAL FOLLOW-UP" (flagged) | follow-up banner; see H7 |

### 2.3 Weight-based calculation (needs sign-off, H8)

Only one dose figure is computed: **bolus volume = 2 ml/kg × weight (kg)**, shown with the formula,
exact (no rounding), e.g. "Bolus volume = 2 ml/kg × 1.234 kg = 2.468 ml of 10% dextrose (straight
multiplication of the STW per-kg value; verify before giving)". Only on the SYMPTOMATIC OR BG < 25 branch
and only when a weight is entered. No GIR-to-ml/h, dextrose-concentration or hydrocortisone mg
calculation is done; GIR calculation and heel-prick technique are QR codes in the PDF and the app says
"see the QR code in the STW PDF".

The reference screen shows every box verbatim: whom to screen, schedule, how to monitor, symptoms, both
branches, the IV flowchart, drugs, prevention, practical points, DO's, DON'Ts, KPIs (both ≥90%), the
follow-up banner, abbreviations, references and the PDF disclaimer.

---

## 3. MCQs and case scenarios

8 MCQs + 6 case scenarios per module (`lib/features/follow_up/data/ancs_follow_up_data.dart`,
`hypo_follow_up_data.dart`). Every correct answer and explanation quotes the PDF and each item shows
"Source: ICMR/DHR STW "…" (August 2026), <box>". Distractors are deliberately not STW statements.
Please check each item, in particular `ancs_case_5` (uses "likelihood of early preterm birth" for a
woman at 29+3 weeks, A5) and `hypo_case_6` (refractory definition, H5).

## 4. Chatbot / "View in PDF"

33 regions (13 ANCS, 20 Hypoglycemia) in `assets/regions/regions.json`, drawn on the PDF's own card
rectangles and checked visually against the rendered pages. Region text is extracted from the PDF;
hidden duplicate labels under the hypoglycemia flowchart boxes are excluded (H9). Each finding's
"View PDF" opens the right PDF scrolled to and highlighting its box.

---

## 5. Open clinical questions

### ANCS

| ID | Question | App behaviour meanwhile |
|---|---|---|
| A1 | GA **<24+0 weeks** is outside the window but not listed under WHEN NOT TO GIVE. What should be shown? | "ACS eligibility criteria not met: Women at 24+0 to 33+6 weeks of gestation"; flagged. |
| A2 | Is "none of the five listed causes" the same as WHEN NOT TO GIVE "Preterm birth within next 7 days is unlikely"? Could other causes count? | Treated as the same; "Do NOT give" with that line. |
| A3 | The repeat-course box lists three criteria (GA window, high likelihood, ≥7 days). Must eligibility criteria 2–5 also be met for a repeat course? | App also requires criteria 2–5 (conservative reading); flagged. |
| A4 | Is the repeat course the same regimen as DRUG & DOSE (6 mg IM 12-hourly × 4)? The STW gives only one regimen. | Shows the DRUG & DOSE regimen; flagged. |
| A5 | "Likelihood of **early** preterm birth" (REFERRAL/TRANSFER) is not defined. | Referral shown when criterion 1 is met within 24+0–33+6 weeks and the facility lacks level II care (CPAP); flagged. |
| A6 | KPI "Appropriate ACS use" has a target (≥95%) but no printed formula. | Shown as "(formula not printed in the STW)". |
| A7 | Repeat-course box line ends with a stray fragment: "…ALL criteria are met; neuro-developmental". | Reference screen shows it as printed; findings use "Give ONE repeat course only if ALL criteria are met". |
| A8 | Criterion 1 text reads "…regular contractions with cervical change consider (dilatation or effacement)" — stray "consider"? | Shown as printed. |
| A9 | GA days do not change any ANCS decision (window and ≥34 cut-off are in whole weeks: 33+6 eligible, 34+0 not). Confirm. | As described; days are recorded for documentation. |
| A10 | GA input accepts 20–44 weeks (data validation only, not a clinical rule). | As described. |
| A11 | Special situations and facility level are asked only when GA is in the window and a cause is ticked. | As described. |

### Neonatal Hypoglycemia

| ID | Question | App behaviour meanwhile |
|---|---|---|
| H1 | Shown when no WHOM TO SCREEN item is ticked: "Routine blood glucose monitoring is not required in healthy term AGA neonates". The STW line is about *healthy term AGA* neonates, which "no listed risk factor" may not be. | Shown with "Requires clinical review". |
| H2 | No action is printed for a **first BG ≥45 mg/dL** apart from the monitoring schedule. | "BG ≥45 mg/dL — flowchart not triggered" (+ schedule line if at risk); flagged. |
| H3 | After the 1-hour re-check ("Start IV glucose infusion if: BG < 45 mg/dL OR Symptoms develop"), the arrow goes straight to the 30-min re-check box: **no bolus and no starting GIR** are printed for this path. | Shows only "Start IV glucose infusion" + 30-min re-check; flagged. No bolus/GIR advice. |
| H4 | Stop rule says "on GIR **4** mg/kg/min". A GIR below 4 is not addressed. | Stop only at exactly GIR 4; GIR <4 → "not addressed by the STW"; flagged. |
| H5 | "Persistent (GIR requirement **>3-7 days**)" and "Refractory (GIR **> 10-12** mg/kg/min for 24 hours)" are ranges. Which cut-offs? | Clinician ticks the line as printed; the app does not compute either. |
| H6 | The DRUGS FOR **REFRACTORY** HYPOGLYCEMIA box follows the persistent-**or**-refractory box. Do the drugs also apply to persistent hypoglycemia? | Shown for either tick (follows the arrow); flagged. |
| H7 | Neurodevelopmental follow-up: "severe" and "recurrent" are not defined. | Shown when symptoms were recorded or persistent is ticked; flagged. |
| H8 | **Sign-off needed** for the bolus volume calculation (2 ml/kg × weight, formula shown, exact). | Shown only with a weight entered; flagged. |
| H9 | The PDF contains hidden duplicate text under flowchart boxes (e.g. "Increase GIR @ 2 mg/kg/min till max GIR 12 mg/kg/min"). Please confirm the visible text is the approved wording. | Visible text used everywhere; hidden text excluded from chatbot answers. |
| H10 | Symptoms are asked only when BG <45 (they follow the BLOOD GLUCOSE <45 mg/dL box). Symptoms with BG ≥45 are not addressed. | As described. |
| H11 | "Increase GIR by 2 (maximum 12)": from 11 the app shows 12 (cap), not 13. | As described. |
| H12 | GIR input accepts 1–20 mg/kg/min (validation only); values >12 trigger "STW: maximum 12 mg/kg/min". | As described. |
| H13 | SGA/LGA (INTERGROWTH-21st percentiles) are judged by the clinician; the app does not compute percentiles. | As described. |
| H14 | The at-risk finding lists both schedule rows (at-risk 1–72 h and "Infants on IV fluids: Every 6-8 hours") regardless of IV status. | As described. |

### Both

- The 8th-Oct PDFs' disclaimer says "Kindly visit the **DHR portal**"; the RD/ROP screens use the older
  "website of DHR" wording. The new reference screens show the new wording verbatim.
- The `D:/Medical-app-pdf/` folder also has 8th-Oct versions of the RD and ROP STWs; the app still
  bundles the earlier RD/ROP PDFs (not changed in this work).
