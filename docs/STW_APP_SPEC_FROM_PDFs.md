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

## 1. Respiratory Distress in Neonates

Single source: `assets/pdfs/respiratory_distress_neonates_stw.pdf`, byte-for-byte copy of `Respiratory_Distress_STW_Final 15-10-26.pdf`. Replaces all earlier RD content. Printed date: August 2026.

### RESPIRATORY DISTRESS

- Presence of ANY ONE: RR ≥60/min; Chest retractions; Nasal flaring; Grunting

### IMMEDIATE ACTIONS

- Apnoea/gasping, poor effort or shock: Stabilize immediately; ventilate when indicated
- Maintain TABC; provide warmth; admit to SNCU/NICU
- Attach pulse oximeter; monitor HR, RR, SpO₂ and CRT; assess SAS
- Feed when stable: breastfeed if mild RD; OG feeds when appropriate on CPAP; decompress stomach
- Withhold feeds; give IV fluids for severe RD, recurrent apnoea, poor perfusion or abdominal concerns

### ALGORITHM

- ASSESS GESTATIONAL AGE (GA)* + SILVERMAN–ANDERSEN SCORE (SAS)
- *If GA is uncertain, BW ≤1800 g may be used as an operational surrogate
- GA ≤34 weeks Any respiratory distress
- GA >34 weeks Moderate–severe RD (SAS ≥4)
- GA >34 weeks Mild RD (SAS ≤3)

### START CPAP

- CPAP 5–6 cm H₂O; blended oxygen; titrate FiO₂ to SpO₂ 91–95%
- Caffeine citrate for babies <34 weeks requiring respiratory support, as per protocol

### NASAL PRONGS OXYGEN

- If SpO₂ <91%: 0.5–1 L/min; Titrate to SpO₂ 91–95%

### MONITORING

- Monitor SpO₂ continuously while on oxygen/CPAP
- Reassess clinical status, SAS and FiO₂ requirement within 15–30 min of starting/changing support
- Reassess at least 1 hourly while on respiratory support; immediately if any worsening

### IMPROVING

- Decreasing SAS; SpO₂ 91–95% on stable/reducing support; Comfortable breathing

### NOT IMPROVING / WORSENING

- Persisting/increasing SAS
- SpO₂ <91% or rising oxygen need
- Recurrent apnoea/bradycardia
- Consider sepsis (Refer to sepsis STW)

### EARLY RESCUE SURFACTANT

- Suspected worsening RDS in a preterm neonate <34 weeks, AND FiO₂ >0.30 on CPAP ≥6 cm H₂O to maintain SpO₂ 91–95%
- Give promptly when indicated—before established CPAP failure

### WEAN WHEN STABLE

- Comfortable breathing; no significant apnoea; low oxygen requirement
- Reduce FiO₂, then CPAP as per protocol
- Trial off when stable on CPAP 5 cm H₂O and FiO₂ 0.21–0.25
- Monitor SpO₂ for 24 h after stopping

### OPTIMIZE RESPIRATORY SUPPORT

- If on Nasal Prongs oxygen, rising oxygen need or distress: Start CPAP
- Check prongs, circuit and delivered pressure
- Increase CPAP up to 7–8 cm H₂O; Titrate FiO₂
- Exclude pneumothorax (Transillumination, X-ray)
- Consider surfactant

### CPAP FAILURE — ESCALATE PROMPTLY

- Persistent hypoxaemia/rising FiO₂ despite optimized CPAP, recurrent apnoea, shock or fatigue
- Escalate support; intubate/ventilate when indicated; stabilize and refer urgently

### DOs

- Assess severity using SAS; monitor SpO₂ continuously
- Maintain SpO₂ 91–95%
- Start CPAP within 30 min of identification of indication
- Give early rescue surfactant promptly when indicated

### DON’Ts

- Do NOT give unmonitored supplemental oxygen
- Do NOT order routine CBC/CRP, chest X-ray or blood gas in
- uncomplicated mild RD
- Do NOT give IV fluids, antibiotics or blood products routinely
- Do NOT delay ventilation or referral when CPAP fails

### KEY PERFORMANCE INDICATORS (KPIs)

- Timely CPAP initiation (%)
- Eligible neonates with RD started on CPAP within 30 min of
- identification
- All neonates with RD meeting the STW criteria for CPAP
- × 100
- Target >90%
- Continuous pulse-oximetry coverage (%)
- Neonates receiving oxygen or CPAP with documented
- continuous pulse oximetry
- All neonates receiving oxygen or CPAP
- × 100
- Target >90%

### RELATED INFORMATION

- Bubble CPAP setup
- Fixing binasal prongs
- SAS scoring
- Surfactant
- administration

### SILVERMAN–ANDERSEN SCORE

- SAS: Avery & Fletcher (1974); W. A. Silverman

### ABBREVIATIONS

- BW: Birth weight
- CPAP: Continuous positive airway pressure
- CRT: Capillary refill time
- GA: Gestational age
- FiO₂: Fraction of inspired oxygen
- PEEP: Positive end-expiratory pressure
- RD: Respiratory distress
- RR: Respiratory rate
- SAS: Silverman–Andersen score
- SpO₂: Peripheral oxygen saturation
- TABC: Temperature, airway, breathing, circulation

### REFERENCES

- 1. National Neonatology Forum India. Oxygen Therapy in Neonates; Surfactant Replacement Therapy in Neonates. Evidence-based Clinical Practice Guidelines. nnfi.org/cpg.php
- 2. Sweet DG et al. European Consensus Guidelines on the Management of Respiratory Distress Syndrome: 2022 Update. Neonatology. 2023;120:3–23.

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
| Surfactant criteria met | Suspected worsening RDS AND confirmed GA <34 wk AND CPAP ≥6 cm H₂O AND FiO₂ >0.30 to maintain SpO₂ 91–95% |
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
- Add numerical surfactant deadlines or CPAP-weaning increments absent from the revised RD PDF
- Invent "due soon" windows (e.g. within 7 days) for ROP
- Auto-fill the next ROP exam date (e.g. +2, +7, +14 days). The clinician enters it
- Show drug doses other than those written in the PDFs (phenylephrine 2.5%, tropicamide 0.5-0.8%, 25% dextrose, caffeine citrate named without dose)
- Show any treatment advice not written above

## 5. Disclaimer (show on landing page and in About)

*This STW has been prepared by national experts of India with feasibility considerations for various levels of healthcare system in the country. These broad guidelines are advisory, and are based on expert opinions and available scientific evidence. There may be variations in the management of an individual patient based on his/her specific condition, as decided by the treating physician. There will be no indemnity for direct or indirect consequences. Kindly visit the website of DHR for more information (stw.icmr.org.in). © Department of Health Research, Ministry of Health & Family Welfare, Government of India.*

Source line: "Based on ICMR / DHR Standard Treatment Workflows, August 2026".

## 6. Open points (PDF is ambiguous: confirm with supervisor, do not guess)

RD decisions follow the revised source above; superseded RD open points have been removed. The unchanged GA split retains the existing completed-week convention. Severe RD for feeding remains clinician assessed because no separate SAS cutoff is specified.

9. **ROP treatment line "Reactivation/significant PAR after anti-VEGF; stage 2-3; stage 4-5":** the PDF text is not clear on how these combine. Show the line as written; do not auto-decide.
