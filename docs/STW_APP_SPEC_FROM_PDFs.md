# Neonatal STW App: Source-of-Truth Spec (extracted from the two PDFs)

Sources (both: ICMR / Department of Health Research, MoHFW, Govt. of India, August 2026):
1. **Standard Treatment Workflow: Respiratory Distress in Neonates** (ICD-11 KB23)
2. **Standard Treatment Workflow: Retinopathy of Prematurity (ROP)** (ICD-11 9B71.3)

## 0. Golden rules for the app

1. The app implements **only what is written in these two PDFs**. No extra thresholds, no extra advice, no derived severity bands, no extra drug doses.
2. Where the PDF is ambiguous, show the PDF wording and let the clinician decide. Never guess. Ambiguities are listed in section 6.
3. All clinical text (DOs, DON'Ts, criteria, KPIs, abbreviations, references, disclaimer) is shown exactly as written below.
4. The app is decision support and a documentation aid. It does not replace the treating physician (see disclaimer, section 5).
5. Do not use the Government of India emblem or ICMR logo in the app.

---

## 1. Module A: Respiratory Distress (RD) in Neonates

### 1.1 Definition: when RD is present
RD is present if **ANY ONE** of these is present:
- RR > 60/min
- Chest retractions
- Nasal flaring
- Grunting

### 1.2 Immediate actions (show as a checklist)
- Assess and stabilize **TABC** (temperature, airway, breathing, circulation)
- Admit to SNCU/NICU
  - Provide thermal care
  - Attach pulse oximeter
  - Monitor HR, RR, SpO₂ and CRT; grade severity using the Silverman-Andersen score (SAS)
- Feed enterally if stable
  - Direct breastfeed if **mild** distress; gastric-tube feeds if **moderate** distress, or on CPAP
- IV fluids if **severe** distress, recurrent apnea, poor perfusion, or abdominal signs

### 1.3 Inputs the app may ask
| Input | Used for |
|---|---|
| Gestational age (GA) in weeks | Choosing the pathway |
| Birth weight (BW), only if GA is uncertain | "If GA is uncertain, BW ≤ 1800 g may be used as an operational surrogate" (surrogate for GA ≤ 34 weeks) |
| 5 SAS items (each grade 0, 1, 2) | SAS total and mild vs moderate-severe |
| SpO₂, FiO₂, PEEP (cm H₂O) | Reassessment, surfactant criteria |
| Tick boxes (see 1.7 to 1.9) | Improving / not improving / CPAP failure |

### 1.4 Silverman-Andersen Score (SAS)
Each of the 5 items is graded 0, 1 or 2. SAS total = sum of the 5 grades.

| Item | Grade 0 | Grade 1 | Grade 2 |
|---|---|---|---|
| Upper chest | Synchronized | Lag on inspiration | See-saw |
| Lower chest | No retractions | Just visible | Marked |
| Xiphoid retractions | None | Just visible | Marked |
| Nares dilatation | None | Minimal | Marked |
| Expiratory grunt | None | Heard with stethoscope | Audible |

Figure credit (must be shown with the figure): *The Silverman score for assessing the magnitude of respiratory distress. (From Avery, M.E., and Fletcher, B.D.: The Lung and Its Disorders in the Newborn. Philadelphia, W.B. Saunders Company, 1974) (Courtesy of W.A. Silverman).*

Severity classes that exist in the PDF (and only these):
- **Mild RD: SAS ≤ 3**
- **Moderate-severe RD: SAS ≥ 4**

The PDF does not split moderate from severe by SAS value. The app must not do that.

### 1.5 Algorithm: choosing initial support
"RESPIRATORY DISTRESS: Assess gestation (GA) + SAS"

| Pathway | Condition | Action |
|---|---|---|
| 1 | GA ≤ 34 weeks, any respiratory distress | **START CPAP** |
| 2 | GA > 34 weeks, moderate-severe RD (SAS ≥ 4) | **START CPAP** |
| 3 | GA > 34 weeks, mild RD (SAS ≤ 3) | **NASAL-PRONG OXYGEN 0.5-1 L/min**, titrate to SpO₂ 91-95% |

**START CPAP** box: CPAP 5-6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91-95%. Start caffeine citrate in neonates < 34 weeks who require respiratory support.

Then (all pathways): **REASSESS FREQUENTLY**: clinical status, SAS, SpO₂, FiO₂ requirement. Consider sepsis if perinatal risk factors, systemic illness, worsening distress or rising FiO₂ (see STW: Sepsis in Neonates).

### 1.6 Target
Maintain **SpO₂ 91-95%** at all times (the PDF banner: "ASSESS SAS • PROVIDE APPROPRIATE RESPIRATORY SUPPORT • TARGET SpO₂ 91-95% • ESCALATE SUPPORT PROMPTLY IF NOT IMPROVING").

### 1.7 IMPROVING (show when the clinician confirms all three)
- Decreasing SAS
- SpO₂ 91-95% on stable/reducing support
- Comfortable breathing

Action: Wean FiO₂ first to 0.21, then reduce CPAP in 1 cm H₂O steps to 4-5 cm H₂O and stop when stable; continue SpO₂ monitoring for 24 h after stopping.

### 1.8 NOT IMPROVING / WORSENING (show if any of these is present)
- Persisting/increasing SAS
- SpO₂ < 91% or rising oxygen need
- Recurrent apnea/bradycardia
- Fatigue, shock or deterioration

Action: **OPTIMIZE CPAP**
- Increase PEEP stepwise up to 7-8 cm H₂O
- Titrate FiO₂ to target SpO₂ 91-95%
- Look for/treat underlying cause
- Consider surfactant if criteria met (see 1.9)

### 1.9 SURFACTANT criteria (all must be true)
- GA < 34 weeks
- on CPAP needing PEEP > 6 cm H₂O
- AND FiO₂ > 0.30 to keep SpO₂ between 91-95%

### 1.10 CPAP FAILURE
Persistent hypoxemia/high FiO₂ requirement, recurrent apnea, shock or fatigue → **Refer urgently**.
(Clinician-ticked criteria only. The app must not auto-declare failure from a number.)

### 1.11 DOs
- Assess severity using SAS and monitor SpO₂ continuously
- Maintain SpO₂ 91%-95%.
- Start CPAP within 30 minutes
- Administer surfactant within 2 hours

### 1.12 DON'Ts
- DO NOT give unmonitored supplemental oxygen.
- DO NOT perform routine CBC, CRP, Chest X-ray or blood gas in uncomplicated mild RD
- DO NOT give IV fluids, antibiotics, or blood products routinely
- DO NOT delay mechanical ventilation or referral in case of CPAP failure

### 1.13 Key Performance Indicators (KPIs)
- **Timely CPAP initiation (%)** = (Neonates ≤ 34 weeks with RD started on CPAP within 30 min of diagnosis or admission ÷ Neonates ≤ 34 weeks diagnosed with RD) × 100. Target > 90%
- **SpO₂ target compliance (%)** = (Neonates receiving supplemental oxygen or CPAP with continuous pulse oximetry and SpO₂ in target range ÷ Neonates receiving supplemental oxygen or CPAP) × 100. Target > 90%

### 1.14 Related information (links to be supplied)
How to set up a bubble CPAP · How to connect a ventilator CPAP · How to fix binasal prongs · Silverman-Andersen scoring · Surfactant administration

### 1.15 Abbreviations
BW: Birth Weight · CRT: Capillary Refill Time · CPAP: Continuous Positive Airway Pressure · GA: Gestational Age · IV: Intravenous · SpO₂: Peripheral Oxygen Saturation · RD: Respiratory Distress · FiO₂: Fraction of Inspired Oxygen · RR: Respiratory Rate · PEEP: Positive End-Expiratory Pressure · SAS: Silverman-Andersen Score

### 1.16 Reference
1. Oxygen therapy in neonates, and Surfactant Replacement therapy in neonates. Evidence-based Clinical Practice Guidelines. National Neonatology Forum India. Available at www.nnfi.org/cpg

---

## 2. Module B: Retinopathy of Prematurity (ROP)

Intro text: *ROP is a potentially blinding retinal vascular disorder of preterm infants. Severe disease may cause retinal detachment and irreversible vision loss. Optimal quality neonatal care, timely screening and prompt treatment can prevent most ROP-related blindness.*

### 2.1 Whom to screen
Screen if **ANY ONE** of the following is present:
- Gestation < 34 weeks
- Birth weight < 2000 g
- Gestation 34-36 weeks with specified risk factors* or an unstable clinical course

\*Significant cardiorespiratory support, prolonged/poorly controlled oxygen therapy, significant anemia, blood transfusion, sepsis, poor postnatal weight gain.

### 2.2 When to screen
**First screen**
- By 4 weeks postnatal age
- By 2-3 weeks postnatal age, if GA < 28 weeks or BW < 1200 g
- If already overdue, screen ASAP
- If follow-up uncertain, screen before discharge even if not due

**Repeat screen**
- As per advice by ROP-trained ophthalmologist according to retinal findings, usually every 1-3 weeks
- Posterior or progressive disease/suspected A-ROP may require review within 1 week or sooner

### 2.3 How to arrange screening
- **Preferred:** On-site screening in SNCU/NICU by an ROP-trained ophthalmologist/tele-screening team with appropriate monitoring
- **If unavailable:** Arrange scheduled specialist visits, or safe referral to the nearest designated ROP screening centre

### 2.4 Prepare to screen (checklist)
- Withhold feeds: 1 hour before screening
- Dilate pupils: phenylephrine 2.5% + tropicamide 0.5-0.8% eye drops (2-3 times at 10 min interval)
- Swaddle, proparacaine eye drops, EBM/oral 25% dextrose for analgesia
- Maintain temperature and monitor SpO₂

### 2.5 How to screen (checklist)
- Strict hand hygiene and asepsis
- Examine both eyes by indirect ophthalmoscopy (20D/28D lens); use speculum/scleral indentation as required
- Wide-field retinal imaging/tele-screening may be used where available
- Monitor for apnea, bradycardia, desaturation and feed intolerance
- Document ROP findings and the date/place of the next examination

### 2.6 Treatment indications
- **Zone I:** Any stage with plus disease, or stage 3 without plus
- **Zone II:** Stage 2-3 with plus disease
- **Aggressive ROP (A-ROP):** Urgent treatment
- Reactivation/significant PAR after anti-VEGF; stage 2-3; stage 4-5 (see open point 6.9)
- **Advanced ROP (Stage 4-5):** Requires referral for surgery

**Treatment-requiring ROP should be treated urgently, preferably within 48-72 hours of the decision to treat.**

### 2.7 Treatment options
- Laser photocoagulation and/or intravitreal anti-VEGF injection, as decided by the ROP specialist based on zone and disease characteristics
- Vitreo-retinal surgery for advanced ROP

### 2.8 When to stop screening
- Stop **only** when advised by ROP-trained ophthalmologist (retina fully vascularised, or ROP fully regressed)
- After anti-VEGF treatment, prolonged follow-up at least until **65 weeks PMA** is required because of the risk of late reactivation and persistent avascular retina (PAR)

### 2.9 Prevention
- Antenatal corticosteroids for fetal lung maturation
- Safe oxygen therapy: use air-oxygen blenders and continuous pulse oximetry; target SpO₂ 91-95%
- Prevent and promptly treat sepsis
- Ensure mother's own milk, optimal nutrition and adequate postnatal growth
- Avoid unnecessary blood transfusions

### 2.10 DOs
- Ensure timely ROP screening and follow-up
- Document the date and place of next screening in discharge card
- Counsel the family regarding need for follow-up and risk of vision loss if screening is delayed

### 2.11 DON'Ts
- DO NOT discharge/transfer an at-risk neonate without a documented ROP follow-up plan
- DO NOT delay referral/treatment when indicated
- DO NOT stop ROP follow-up without advice of ROP-trained ophthalmologist

### 2.12 KPIs
- **ROP screening coverage (%)** = (Eligible infants who received at least one ROP eye examination ÷ Total eligible infants for ROP screening) × 100
- **Timely first ROP screening (%)** = (Eligible infants screened within the recommended first-screen window ÷ Eligible infants due for first screening) × 100
- All SNCUs/NICUs should periodically assess the KPIs and undertake quality improvement measures to achieve 95-100% compliance

Banner: **TIMELY ROP SCREENING SAVES SIGHT: NO ELIGIBLE INFANT SHOULD LEAVE THE SNCU/NICU WITHOUT SCREENING OR A DOCUMENTED FOLLOW-UP PLAN**

### 2.13 Related information (links to be supplied)
1. ROP classification · 2. ROP record form · 3. Information for parents and FAQs · 4. Preterm care package

### 2.14 Abbreviations
A-ROP: Aggressive ROP · BW: Birth weight · EBM: Expressed Breastmilk · GA: Gestational Age · PAR: Persistent Avascular Retina · PMA: Postmenstrual Age · ROP: Retinopathy of Prematurity · VEGF: Vascular Endothelial Growth Factor

### 2.15 References
1. MoHFW, Government of India. Guidelines for Universal Eye Screening in Newborns Including Retinopathy of Prematurity. RBSK. Available at: nhm.gov.in
2. National Neonatology Forum of India. Screening and Management of Retinopathy of Prematurity: Clinical Practice Guideline. Available at: nnfi.org/cpg.php

---

## 3. What the app is allowed to compute (direct applications of the PDF only)

| Feature | Rule from PDF |
|---|---|
| SAS total | Sum of the 5 item grades (0-2 each) |
| Mild vs moderate-severe | SAS ≤ 3 = mild; SAS ≥ 4 = moderate-severe |
| RD pathway | Table in 1.5 |
| Surfactant criteria met | GA < 34 wk AND on CPAP AND PEEP > 6 AND FiO₂ > 0.30 (SpO₂ 91-95%) |
| SpO₂ in target range | 91-95% |
| ROP eligibility | Rules in 2.1 |
| ROP first-screen deadline | DOB + 4 weeks; or DOB + 2-3 weeks if GA < 28 wk or BW < 1200 g; if past the deadline show "overdue: screen ASAP" |
| ROP treatment-indicated flag | Zone/stage/plus rules in 2.6 |
| Post anti-VEGF follow-up | At least until 65 weeks PMA (PMA = GA at birth + postnatal age) |
| KPI percentages | Formulas in 1.13 and 2.12 |
| Discharge warning | Show the DON'T (no discharge/transfer of an at-risk neonate without a documented ROP follow-up plan) until next-screening date and place are entered |

## 4. What the app must NOT do (not in the PDFs)

- Split moderate and severe RD by SAS value (e.g. 4-6 / 7-10)
- Treat SAS ≤ 3 on its own as "improving"
- Auto-declare CPAP failure from a number (e.g. SpO₂ < 91% at PEEP 8)
- Say "escalate to CPAP" for nasal-prong oxygen, or "reduce FiO₂" for high SpO₂
- Invent "due soon" windows (e.g. within 7 days) for ROP
- Auto-fill the next ROP exam date (e.g. +2, +7, +14 days). The clinician enters it
- Show drug doses other than those written in the PDFs (phenylephrine 2.5%, tropicamide 0.5-0.8%, 25% dextrose, caffeine citrate named without dose)
- Show any treatment advice not written above

## 5. Disclaimer (show on landing page and in About)

*This STW has been prepared by national experts of India with feasibility considerations for various levels of healthcare system in the country. These broad guidelines are advisory, and are based on expert opinions and available scientific evidence. There may be variations in the management of an individual patient based on his/her specific condition, as decided by the treating physician. There will be no indemnity for direct or indirect consequences. Kindly visit the website of DHR for more information (stw.icmr.org.in). © Department of Health Research, Ministry of Health & Family Welfare, Government of India.*

Source line: "Based on ICMR / DHR Standard Treatment Workflows, August 2026".

## 6. Open points (PDF is ambiguous: confirm with supervisor, do not guess)

1. **GA boundary:** the PDF says "GA ≤ 34 weeks" and "GA > 34 weeks". The app currently uses completed weeks (so 34+3 counts as ≤ 34). Confirm whether to use completed weeks or weeks+days.
2. **"Moderate" and "severe" distress** (feeding and IV-fluid lines in 1.2): the PDF defines only mild (SAS ≤ 3) and moderate-severe (SAS ≥ 4). Proposed handling: feeding follows mild vs moderate-severe; "severe distress" for IV fluids is a clinician tick box, not a SAS cut-off.
3. **"Persisting SAS"** in Not improving: the PDF gives no numeric rule. Proposed handling: SAS higher than the previous reading = increasing; equal and ≥ 4 = persisting; lower = decreasing (never "persisting").
4. **Improving:** the PDF lists three bullets without saying "all". Proposed handling: require all three.
5. **Nasal-prong pathway when not improving:** the PDF flowchart shows both pathways joining the same Reassess and Not improving boxes, whose action is "Optimize CPAP". Proposed handling: show the PDF box as written, no extra escalation text.
6. **Surfactant "PEEP > 6"** vs "CPAP 5-6 cm H₂O" start: PEEP above 6 is reached only after increasing PEEP. No change needed, just keep both numbers as written.
7. **"Within 30 minutes" / "within 2 hours":** the PDF does not state the starting point for surfactant's 2 hours. Show the time rule as written.
8. **BW surrogate:** "BW ≤ 1800 g may be used" only when GA is uncertain. Show as an optional input.
9. **ROP treatment line "Reactivation/significant PAR after anti-VEGF; stage 2-3; stage 4-5":** the PDF text is not clear on how these combine. Show the line as written; do not auto-decide.
