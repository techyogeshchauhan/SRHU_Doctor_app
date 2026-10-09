# Chatbot manual test sheet

81 scenarios for checking the STW chatbot by hand (Chat screen, Web/PWA or APK).

Expected results are the chatbot's current output, generated from the app code; the box for each question was checked against the evaluation set (`test/chatbot_eval/`). Regenerate this sheet after changing the chatbot.

## How to test

1. Open the Chat screen. Type the question **exactly** as written (copy-paste is fine).
2. Compare with **Expect**. Tick the box if it matches.
3. For every answer, also check the general rules below.

**Every answer must:**

- [ ] show a header with the STW box title given under **Expect**;
- [ ] show only lines copied word for word from that box (compare with "Show full STW box");
- [ ] open the right PDF with **View in PDF**, with the box highlighted;
- [ ] never show advice that is not in the STW PDF.

**Result types:**

| Type | What you see |
| --- | --- |
| Answer | Box title in the header, the answering lines, "Show full STW box", "View in PDF" |
| Patient case | As Answer, plus "Read from your question: …" and a **Start full assessment** button |
| Did you mean… | Header "Did you mean…", a question, one chip per possible box; tapping a chip shows that box |
| Out of scope | Red header "Out of Scope" and: *This information is not covered in the approved STW documents.* |

A **wrong answer** (a box that does not answer the question) is a serious failure: note the question and what was shown. "Did you mean…" or "Out of scope" where an answer was expected is a smaller issue; note it too.

## A. Direct questions: Respiratory Distress (RD)

**A1.** `What signs mean a newborn has respiratory distress?`

- [ ] **Expect:** Answer, box **Diagnostic Criteria: Respiratory Distress in Neonates** (RD STW)
- Lines shown:
  > Presence of ANY ONE: RR >60/min
  > Presence of ANY ONE: Chest retractions
  > Presence of ANY ONE: Nasal ﬂaring
  > Presence of ANY ONE: Grunting

**A2.** `What CPAP pressure should be started in a 30 week baby with distress?`

- [ ] **Expect:** Patient case, box **Initial Respiratory Support for GA ≤34 Weeks (CPAP & Caffeine Citrate)** (RD STW)
- [ ] "Read from your question: GA 30 weeks"
- Lines shown:
  > START CPAP CPAP 5–6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91–95%
  > Start caffeine citrate in neonates <34 weeks who require respiratory support

**A3.** `Which preterm babies need caffeine citrate?`

- [ ] **Expect:** Answer, box **Initial Respiratory Support for GA ≤34 Weeks (CPAP & Caffeine Citrate)** (RD STW)
- Lines shown:
  > START CPAP CPAP 5–6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91–95%
  > Start caffeine citrate in neonates <34 weeks who require respiratory support

**A4.** `When is surfactant indicated?`

- [ ] **Expect:** Answer, box **Surfactant Therapy Indication & Thresholds** (RD STW)
- Lines shown:
  > SURFACTANT <34 weeks on CPAP needing PEEP >6 cm H₂O AND FiO₂ >0.30 to keep SpO₂ between 91-95%

**A5.** `What defines CPAP failure?`

- [ ] **Expect:** Answer, box **CPAP Failure Criteria & Urgent Referral Indication** (RD STW)
- Lines shown:
  > Persistent hypoxemia/high FiO₂ requirement, recurrent apnea, shock or fatigue → Refer urgently

**A6.** `How do I wean CPAP once the baby improves?`

- [ ] **Expect:** Answer, box **Outcome Improving: CPAP and Oxygen Weaning Protocol** (RD STW)
- Lines shown:
  > Wean FiO₂ ﬁrst to 0.21, then reduce CPAP in 1 cm H₂O steps to 4–5 cm H₂O and stop when stable; continue SpO₂ monitoring for 24 h after stopping

**A7.** `How is the Silverman Andersen score graded?`

- [ ] **Expect:** Answer, box **Silverman-Andersen Score (SAS) Methodology & Parameter Illustrations** (RD STW)
- Lines shown:
  > Figure: The Silverman score for assessing the magnitude of respiratory distress. (From Avery, M.E., and Fletcher, B.D.: The Lung and Its Disorders in the Newborn. Philadelphia, W.B. Saunders Company, 1974) (Courtesy of…

## B. Direct questions: Retinopathy of Prematurity (ROP)

**B1.** `What is ROP?`

- [ ] **Expect:** Answer, box **ROP: What It Is and Why Screening Matters** (ROP STW)
- Lines shown:
  > ROP is a potentially blinding retinal vascular disorder of preterm infants. Severe disease may cause retinal detachment and irreversible vision loss. Optimal quality neonatal care, timely screening and prompt treatment…

**B2.** `Which babies need ROP screening?`

- [ ] **Expect:** Answer, box **Whom to Screen: ROP Screening Eligibility Criteria** (ROP STW)
- Lines shown:
  > Screen if any ONE of the following is present: Gestation <34 weeks
  > Screen if any ONE of the following is present: Birth weight <2000 g
  > Screen if any ONE of the following is present: Gestation 34-36 weeks with speciﬁed risk factors* or an unstable clinical course
  > *Signiﬁcant cardiorespiratory support, prolonged/poorly controlled oxygen therapy, signiﬁcant anemia, blood transfusion, sepsis, poor postnatal weight gain

**B3.** `First ROP screen timing for a 26 week baby`

- [ ] **Expect:** Patient case, box **When to Screen: Timing of First Screening & Follow-up Intervals** (ROP STW)
- [ ] "Read from your question: GA 26 weeks"
- Lines shown:
  > First screen: By 2-3 weeks postnatal age, if GA <28 weeks or BW <1200 g

**B4.** `Eye drops used to dilate pupils before ROP exam`

- [ ] **Expect:** Answer, box **Prepare to Screen: Feeding, Pupillary Dilation & Swaddling** (ROP STW)
- Lines shown:
  > Dilate pupils: phenylephrine 2.5% + tropicamide 0.5-0.8% eye drops (2-3 times at 10 min interval)

**B5.** `Zone II stage 3 with plus disease — treat?`

- [ ] **Expect:** Answer, box **Treatment Indications: ICROP Criteria (Zones, Plus Disease, Urgency)** (ROP STW)
- Lines shown:
  > Zone I: Any stage with plus disease, or stage 3 without plus
  > Zone II: Stage 2-3 with plus disease

**B6.** `When can ROP screening be stopped?`

- [ ] **Expect:** Answer, box **When to Stop Screening: Criteria for Termination of Screening** (ROP STW)
- Lines shown:
  > Stop only when advised by ROP-trained ophthalmologist (retina fully vascularised, or ROP fully regressed)
  > After anti-VEGF treatment, prolonged follow-up at least until 65 weeks PMA is required because of the risk of late reactivation and persistent avascular retina

## C. Direct questions: Antenatal Corticosteroids (ANCS)

**C1.** `Why are antenatal steroids useful?`

- [ ] **Expect:** Answer, box **Introduction: Antenatal Corticosteroids (ACS)** (ANCS STW)
- Lines shown:
  > Antenatal corticosteroid (ACS) therapy is one of the most cost-effective interventions for improving outcomes of preterm birth. When given to women with a high likelihood of preterm birth, it reduces neonatal mortality,…

**C2.** `Dexamethasone dose for antenatal steroids`

- [ ] **Expect:** Answer, box **Drug & Dose: Dexamethasone for ACS** (ANCS STW)
- Lines shown:
  > DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES
  > Betamethasone regimen (12 mg every 24 hours x 2 doses) requires an appropriate acetate + phosphate preparation, which is not available in India. Betamethasone phosphate alone is shorter acting than dexamethasone

**C3.** `Conditions that must all be met before giving ACS`

- [ ] **Expect:** Answer, box **ACS Eligibility Criteria** (ANCS STW)
- Lines shown:
  > GIVE ACS WHEN ALL CONDITIONS ARE MET IN WOMEN AT 24+0 TO 33+6 WEEKS OF GESTATION:

**C4.** `Criteria for a repeat ACS course`

- [ ] **Expect:** Answer, box **When to Give a Repeat ACS Course** (ANCS STW)
- Lines shown:
  > Give ONE repeat course only if ALL criteria are met; neuro-developmental
  > Do NOT give more than one repeat course (More than one repeat course may cause fetal harm, and is not recommended)

**C5.** `Is ACS withheld in twin pregnancy?`

- [ ] **Expect:** Answer, box **Special Situations: Multiple Pregnancy, FGR, Hypertension, Diabetes** (ANCS STW)
- Lines shown:
  > When otherwise eligible, do not withhold ACS because of: multiple pregnancy, fetal growth restriction, hypertensive disorders, or diabetes in pregnancy
  > In diabetes: monitor and optimize maternal glucose control

**C6.** `Can a PHC give the first steroid dose before referral?`

- [ ] **Expect:** Answer, box **Referral / In-utero Transfer for ACS** (ANCS STW)
- Lines shown:
  > Pregnant women with likelihood of early preterm birth should be referred to a facility (in-utero transfer) with at least level II care (CPAP) for preterm infants
  > Level I facilities can give the ﬁrst dose of ACS before referral, provided the pregnant woman meets the eligibility criteria, but referral/transfer should not be delayed to complete the course

## D. Direct questions: Neonatal Hypoglycemia

**D1.** `What glucose level is hypoglycemia in a newborn?`

- [ ] **Expect:** Answer, box **Blood Glucose <45 mg/dL** (Hypoglycemia STW)
- Lines shown:
  > BLOOD GLUCOSE <45 mg/dL

**D2.** `Signs of low sugar in a newborn`

- [ ] **Expect:** Answer, box **Symptoms and Signs of Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Stupor, lethargy, limpness
  > Jitteriness, tremors, convulsions
  > Episodes of cyanosis, apnoea or tachypnoea
  > Weak or high-pitched cry
  > Unable to feed

**D3.** `Treatment of symptomatic neonatal hypoglycemia`

- [ ] **Expect:** Answer, box **Symptomatic or BG <25 mg/dL: IV Bolus and Dextrose Infusion** (Hypoglycemia STW)
- Lines shown:
  > IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute
  > Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min

**D4.** `Maximum glucose infusion rate in the STW`

- [ ] **Expect:** Answer, box **BG <45 mg/dL on IV: Increase GIR (maximum 12 mg/kg/min)** (Hypoglycemia STW)
- Lines shown:
  > BG < 45 mg/dL Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)

**D5.** `When can IV fluids be stopped in hypoglycemia?`

- [ ] **Expect:** Answer, box **Stop IV Fluids (Euglycemic on GIR 4 mg/kg/min)** (Hypoglycemia STW)
- Lines shown:
  > Stop IV ﬂuids when euglycemic on GIR 4 mg/ kg/min and tolerating adequate enteral feeds

**D6.** `Hydrocortisone dose in neonatal hypoglycemia`

- [ ] **Expect:** Answer, box **Drugs for Refractory Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Hydrocortisone: 5 mg/kg/day IV in two divided doses
  > Additional drugs should be administered at a tertiary care hospital with workup for underlying causes

**D7.** `Does a healthy term baby need routine glucose checks?`

- [ ] **Expect:** Answer, box **Whom to Screen for Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Routine blood glucose monitoring is not required in healthy term AGA neonates

## E. Abbreviations

**E1.** `Full form of FiO2`

- [ ] **Expect:** Answer, box **Respiratory Distress Abbreviations** (RD STW)
- Lines shown:
  > FIO2: Fraction of Inspired Oxygen

**E2.** `What does PPROM stand for?`

- [ ] **Expect:** Answer, box **ACS Abbreviations** (ANCS STW)
- Lines shown:
  > PPROM: Preterm Prelabour Rupture of Membranes

**E3.** `Full form of PMA`

- [ ] **Expect:** Answer, box **ROP Abbreviations** (ROP STW)
- Lines shown:
  > PMA: Postmenstrual Age

## F. Hinglish

**F1.** `Preterm bacche ko CPAP kitne pressure pe lagayein?`

- [ ] **Expect:** Answer, box **Initial Respiratory Support for GA ≤34 Weeks (CPAP & Caffeine Citrate)** (RD STW)
- Lines shown:
  > START CPAP CPAP 5–6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91–95%
  > Start caffeine citrate in neonates <34 weeks who require respiratory support

**F2.** `Surfactant kab dena chahiye?`

- [ ] **Expect:** Answer, box **Surfactant Therapy Indication & Thresholds** (RD STW)
- Lines shown:
  > SURFACTANT <34 weeks on CPAP needing PEEP >6 cm H₂O AND FiO₂ >0.30 to keep SpO₂ between 91-95%

**F3.** `ROP screening kab band kar sakte hain?`

- [ ] **Expect:** Answer, box **When to Stop Screening: Criteria for Termination of Screening** (ROP STW)
- Lines shown:
  > Stop only when advised by ROP-trained ophthalmologist (retina fully vascularised, or ROP fully regressed)
  > After anti-VEGF treatment, prolonged follow-up at least until 65 weeks PMA is required because of the risk of late reactivation and persistent avascular retina

**F4.** `ACS ki dawai kitni aur kitni baar?`

- [ ] **Expect:** Answer, box **Drug & Dose: Dexamethasone for ACS** (ANCS STW)
- Lines shown:
  > DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES
  > Betamethasone regimen (12 mg every 24 hours x 2 doses) requires an appropriate acetate + phosphate preparation, which is not available in India. Betamethasone phosphate alone is shorter acting than dexamethasone

**F5.** `Sugar kam hone par baccha kaisa dikhta hai?`

- [ ] **Expect:** Answer, box **Symptoms and Signs of Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Stupor, lethargy, limpness
  > Jitteriness, tremors, convulsions
  > Episodes of cyanosis, apnoea or tachypnoea
  > Weak or high-pitched cry
  > Unable to feed

**F6.** `GIR kitna tak badha sakte hain?`

- [ ] **Expect:** Answer, box **BG <45 mg/dL on IV: Increase GIR (maximum 12 mg/kg/min)** (Hypoglycemia STW)
- Lines shown:
  > BG < 45 mg/dL Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)

## G. Negation and look-alike pairs (each pair must give DIFFERENT boxes)

Consecutive rows are pairs that differ by one word; each pair must land on different boxes.

**G1.** `Steroid injection kis hafte se kis hafte tak?`

- [ ] **Expect:** Answer, box **When to Give ACS** (ANCS STW)
- Lines shown:
  > Pregnant women at 24+0 to 33+6 weeks of gestation with a high likelihood of preterm birth within the next 7 days

**G2.** `When not to give ACS`

- [ ] **Expect:** Answer, box **When NOT to Give ACS** (ANCS STW)
- Lines shown:
  > Clinical chorioamnionitis or systemic maternal infection
  > Preterm birth within next 7 days is unlikely
  > Routine use at ≥34 weeks
  > More than one repeat course

**G3.** `Whom to screen for ROP`

- [ ] **Expect:** Answer, box **Whom to Screen: ROP Screening Eligibility Criteria** (ROP STW)
- Lines shown:
  > Screen if any ONE of the following is present: Gestation <34 weeks
  > Screen if any ONE of the following is present: Birth weight <2000 g
  > Screen if any ONE of the following is present: Gestation 34-36 weeks with speciﬁed risk factors* or an unstable clinical course

**G4.** `When to stop ROP screening`

- [ ] **Expect:** Answer, box **When to Stop Screening: Criteria for Termination of Screening** (ROP STW)
- Lines shown:
  > Stop only when advised by ROP-trained ophthalmologist (retina fully vascularised, or ROP fully regressed)
  > After anti-VEGF treatment, prolonged follow-up at least until 65 weeks PMA is required because of the risk of late reactivation and persistent avascular retina

**G5.** `Increase GIR`

- [ ] **Expect:** Answer, box **BG <45 mg/dL on IV: Increase GIR (maximum 12 mg/kg/min)** (Hypoglycemia STW)
- Lines shown:
  > BG < 45 mg/dL Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)

**G6.** `Reduce GIR`

- [ ] **Expect:** Answer, box **BG ≥45 mg/dL on IV: Euglycemic for 24 Hours, Reduce GIR** (Hypoglycemia STW)
- Lines shown:
  > Reduce GIR by 2 mg/ kg/min every 6 hours

**G7.** `Hydrocortisone dose`

- [ ] **Expect:** Answer, box **Drugs for Refractory Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Hydrocortisone: 5 mg/kg/day IV in two divided doses
  > Additional drugs should be administered at a tertiary care hospital with workup for underlying causes

**G8.** `Dexamethasone dose`

- [ ] **Expect:** Answer, box **Drug & Dose: Dexamethasone for ACS** (ANCS STW)
- Lines shown:
  > DEXAMETHASONE SODIUM PHOSPHATE 6mg IM EVERY 12 HOURS X 4 DOSES
  > Betamethasone regimen (12 mg every 24 hours x 2 doses) requires an appropriate acetate + phosphate preparation, which is not available in India. Betamethasone phosphate alone is shorter acting than dexamethasone

**G9.** `ROP DOs`

- [ ] **Expect:** Answer, box **Clinical DOs for Retinopathy of Prematurity** (ROP STW)
- Lines shown:
  > Ensure timely ROP screening and follow-up
  > Document the date and place of next screening in discharge card
  > Counsel the family regarding need for follow-up and risk of vision loss if screening is delayed

**G10.** `ROP DON'Ts`

- [ ] **Expect:** Answer, box **Clinical DON'Ts for Retinopathy of Prematurity** (ROP STW)
- Lines shown:
  > DO NOT discharge/transfer an at-risk neonate without a documented ROP follow-up plan
  > DO NOT delay referral/treatment when indicated
  > DO NOT stop ROP follow-up without advice of ROP-trained ophthalmologist

**G11.** `Are antibiotics given routinely in respiratory distress?`

- [ ] **Expect:** Answer, box **Clinical DON'Ts for Neonatal Respiratory Distress** (RD STW)
- Lines shown:
  > DO NOT give IV ﬂuids, antibiotics, or blood products routinely

**G12.** `Can dextrose water replace breastfeeding?`

- [ ] **Expect:** Answer, box **Prevention of Hypoglycemia** (Hypoglycemia STW)
- Lines shown:
  > Support mother for early initiation and regular breastfeeding
  > Do not feed dextrose solutions as a substitute for breastmilk

## H. Patient cases (values are read from the question and run through the STW rules)

Check that **"Read from your question"** shows the values you typed, and that **Start full assessment** opens the disease selection with that condition.

**H1.** `Baby glucose 32 mg/dL, no symptoms, what next?`

- [ ] **Expect:** Patient case, box **Asymptomatic & BG ≥25 mg/dL: Supervised Feeding** (Hypoglycemia STW)
- [ ] "Read from your question: BG 32 mg/dL · no symptoms"
- Lines shown:
  > Immediate supervised feeding
  > Breastfeeding or a measured volume of expressed breastmilk (Formula milk if EBM not available) by paladai or gavage

**H2.** `BG 24, no symptoms`

- [ ] **Expect:** Patient case, box **Symptomatic or BG <25 mg/dL: IV Bolus and Dextrose Infusion** (Hypoglycemia STW)
- [ ] "Read from your question: BG 24 mg/dL · no symptoms"
- Lines shown:
  > IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute
  > Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min

**H3.** `BG 40 and the baby is jittery`

- [ ] **Expect:** Patient case, box **Symptomatic or BG <25 mg/dL: IV Bolus and Dextrose Infusion** (Hypoglycemia STW)
- [ ] "Read from your question: BG 40 mg/dL · symptoms present"
- Lines shown:
  > IV bolus: 2 ml/kg of 10% of dextrose slowly over 1 minute
  > Start IV infusion of dextrose at a glucose infusion rate (GIR) of 6 mg/kg/min

**H4.** `BG 45 without symptoms`

- [ ] **Expect:** Patient case, box **Blood Glucose <45 mg/dL** (Hypoglycemia STW)
- [ ] "Read from your question: BG 45 mg/dL · no symptoms"
- [ ] Note: "Requires clinical review: The flowchart starts at BG <45 mg/dL; the STW gives no other action for BG ≥45 mg/dL than the monitoring schedule."
- Lines shown:
  > BLOOD GLUCOSE <45 mg/dL

**H5.** `1 hour after feeding the BG is 38`

- [ ] **Expect:** Patient case, box **Re-check BG After 1 Hour** (Hypoglycemia STW)
- [ ] "Read from your question: 1-hour re-check BG 38 mg/dL"
- Lines shown:
  > Start IV glucose infusion if: BG < 45 mg/dL OR Symptoms develop

**H6.** `On GIR 8 and BG still 40`

- [ ] **Expect:** Patient case, box **BG <45 mg/dL on IV: Increase GIR (maximum 12 mg/kg/min)** (Hypoglycemia STW)
- [ ] "Read from your question: GIR 8 mg/kg/min · BG 40 mg/dL"
- Lines shown:
  > BG < 45 mg/dL Increase GIR by 2 mg/ kg/min (maximum 12 mg/kg/min)

**H7.** `On GIR 4, sugar normal for 24 hours and feeding well`

- [ ] **Expect:** Patient case, box **Stop IV Fluids (Euglycemic on GIR 4 mg/kg/min)** (Hypoglycemia STW)
- [ ] "Read from your question: GIR 4 mg/kg/min · blood glucose normal · euglycemic for 24 hours · tolerating feeds"
- Lines shown:
  > Stop IV ﬂuids when euglycemic on GIR 4 mg/ kg/min and tolerating adequate enteral feeds

**H8.** `BG 30 aur symptoms nahi, kya karein`

- [ ] **Expect:** Patient case, box **Asymptomatic & BG ≥25 mg/dL: Supervised Feeding** (Hypoglycemia STW)
- [ ] "Read from your question: BG 30 mg/dL · no symptoms"
- Lines shown:
  > Immediate supervised feeding
  > Breastfeeding or a measured volume of expressed breastmilk (Formula milk if EBM not available) by paladai or gavage

**H9.** `Can I give ACS at 35 weeks?`

- [ ] **Expect:** Patient case, box **When NOT to Give ACS** (ANCS STW)
- [ ] "Read from your question: GA 35 weeks"
- Lines shown:
  > Routine use at ≥34 weeks

**H10.** `30 weeks with PPROM, should steroids be given?`

- [ ] **Expect:** Patient case, box **ACS Eligibility Criteria** (ANCS STW)
- [ ] "Read from your question: GA 30 weeks · pprom"
- Lines shown:
  > GIVE ACS WHEN ALL CONDITIONS ARE MET IN WOMEN AT 24+0 TO 33+6 WEEKS OF GESTATION:
  > 1. High likelihood of preterm birth within the next 7 days due to any one: PPROM without clinical infection

**H11.** `Woman at 30 weeks with chorioamnionitis — give dexamethasone?`

- [ ] **Expect:** Patient case, box **When NOT to Give ACS** (ANCS STW)
- [ ] "Read from your question: GA 30 weeks · clinical chorioamnionitis / systemic infection"
- Lines shown:
  > Clinical chorioamnionitis or systemic maternal infection

**H12.** `First ACS course was 10 days ago, now 31 weeks with APH`

- [ ] **Expect:** Patient case, box **When to Give a Repeat ACS Course** (ANCS STW)
- [ ] "Read from your question: GA 31 weeks · aph · previous course 10 days ago"
- Lines shown:
  > High likelihood of preterm birth within the next 7 days
  > The previous ACS course was started ≥7 days earlier

**H13.** `38 week baby with SAS 2`

- [ ] **Expect:** Patient case, box **Initial Support for GA >34 Weeks with Mild Distress (SAS ≤3)** (RD STW)
- [ ] "Read from your question: GA 38 weeks · SAS 2 (Mild)"
- Lines shown:
  > NASAL-PRONG OXYGEN 0.5–1 L/min
  > Titrate to SpO₂ 91–95%

**H14.** `37 week baby with SAS 6`

- [ ] **Expect:** Patient case, box **Initial Support for GA >34 Weeks with Moderate-to-Severe Distress (SAS ≥4)** (RD STW)
- [ ] "Read from your question: GA 37 weeks · SAS 6 (Moderate–severe)"
- Lines shown:
  > START CPAP CPAP 5–6 cm H₂O; use blended O₂ and titrate FiO₂ to maintain SpO₂ 91–95%
  > Start caffeine citrate in neonates <34 weeks who require respiratory support

**H15.** `29 weeks on CPAP with PEEP 7 and FiO2 0.40`

- [ ] **Expect:** Patient case, box **Surfactant Therapy Indication & Thresholds** (RD STW)
- [ ] "Read from your question: GA 29 weeks · PEEP 7 cm H₂O · FiO₂ 40%"
- Lines shown:
  > SURFACTANT <34 weeks on CPAP needing PEEP >6 cm H₂O AND FiO₂ >0.30 to keep SpO₂ between 91-95%

**H16.** `Baby born at 30 weeks, 1400 g — ROP screening needed?`

- [ ] **Expect:** Patient case, box **Whom to Screen: ROP Screening Eligibility Criteria** (ROP STW)
- [ ] "Read from your question: GA 30 weeks · birth weight 1400 g — meets: Gestation 30 weeks (<34); Birth weight 1400 g (<2000 g)"
- Lines shown:
  > Screen if any ONE of the following is present: Gestation <34 weeks
  > Screen if any ONE of the following is present: Birth weight <2000 g
  > Screen if any ONE of the following is present: Gestation 34-36 weeks with speciﬁed risk factors* or an unstable clinical course

**H17.** `Birth weight 1100 g, when is the first eye exam?`

- [ ] **Expect:** Patient case, box **When to Screen: Timing of First Screening & Follow-up Intervals** (ROP STW)
- [ ] "Read from your question: birth weight 1100 g"
- Lines shown:
  > First screen: By 2-3 weeks postnatal age, if GA <28 weeks or BW <1200 g

## I. "Did you mean…" (the chatbot is unsure and asks back)

These currently ask back instead of answering. Check that the chips are listed and that tapping the **first chip** shows the box named.

**I1.** `Baby ka sugar low hai, kya karein?`

- [ ] **Expect:** Did you mean… — "Please share the blood glucose value (mg/dL) and whether any symptoms or signs are present — the STW branch depends on both."
- [ ] Chips: **Asymptomatic & BG ≥25 mg/dL: Supervised Feeding** · **Symptomatic or BG <25 mg/dL: IV Bolus and Dextrose Infusion**
- [ ] Tap **Asymptomatic & BG ≥25 mg/dL: Supervised Feeding**: that box is shown as an answer

**I2.** `How soon must CPAP be started?`

- [ ] **Expect:** Did you mean… — "Which of these do you mean?"
- [ ] Chips: **Clinical DOs for Neonatal Respiratory Distress** · **Outcome Improving: CPAP and Oxygen Weaning Protocol**
- [ ] Tap **Clinical DOs for Neonatal Respiratory Distress**: that box is shown as an answer

**I3.** `When to give ACS`

- [ ] **Expect:** Did you mean… — "Which of these do you mean?"
- [ ] Chips: **When to Give ACS** · **When to Give a Repeat ACS Course**
- [ ] Tap **When to Give ACS**: that box is shown as an answer

**I4.** `How to screen for ROP`

- [ ] **Expect:** Did you mean… — "Which of these do you mean?"
- [ ] Chips: **How to Screen: Clinical Examination Technique** · **Prepare to Screen: Feeding, Pupillary Dilation & Swaddling**
- [ ] Tap **How to Screen: Clinical Examination Technique**: that box is shown as an answer

## J. Out of scope (no approved STW in the app)

**J1.** `Phototherapy threshold for neonatal jaundice`

- [ ] **Expect:** Out of scope ("not covered")

**J2.** `Antibiotics for neonatal sepsis`

- [ ] **Expect:** Out of scope ("not covered")

**J3.** `Jaundice me phototherapy kab dein?`

- [ ] **Expect:** Out of scope ("not covered")

**J4.** `Vitamin K dose at birth`

- [ ] **Expect:** Out of scope ("not covered")

**J5.** `How to bake chocolate cake`

- [ ] **Expect:** Out of scope ("not covered")

**J6.** `hello`

- [ ] **Expect:** Out of scope ("not covered")

**J7.** `asdfgh qwerty`

- [ ] **Expect:** Out of scope ("not covered")

## K. Traps (an STW drug or word, but a different condition or patient)

**K1.** `dexamethasone for croup`

- [ ] **Expect:** Out of scope ("not covered")

**K2.** `Hydrocortisone dose for adrenal crisis in adults`

- [ ] **Expect:** Out of scope ("not covered")

**K3.** `Insulin dose for gestational diabetes`

- [ ] **Expect:** Out of scope ("not covered")

**K4.** `Diabetic retinopathy laser treatment`

- [ ] **Expect:** Out of scope ("not covered")

**K5.** `adult cpap pressure`

- [ ] **Expect:** Out of scope ("not covered")

**K6.** `Normal blood sugar for adults fasting`

- [ ] **Expect:** Out of scope ("not covered")

## UI checks

- [ ] Suggested query chips (empty chat and above the input) send the question.
- [ ] "Show full STW box" expands to the whole box text and its picture.
- [ ] The refresh icon (top right) clears the chat.
- [ ] Works offline (airplane mode) for all of the above; questions are logged and uploaded when back online.
- [ ] Phone width: long answers wrap, nothing is cut off.

## Problems found

| Test | Question | What was shown | Expected |
| --- | --- | --- | --- |
|  |  |  |  |
