Hi Claude,

Please implement/refactor the Neonatal Emergency Triage module based on the PRD specification below.

### Key Objectives:
1. **Remove Manual Selection Screens:** Completely remove the intermediate screens/options where users manually select triage category (Emergency, Priority, Non-urgent).
2. **Automated Triage Logic:** 
   - When danger signs (Apnea/Gasping, HR > 200 bpm, SpO2 drop/Cyanosis, Seizures, CRT > 3s / Mottling / Weak pulse) are present, automatically classify as "Emergency" (Red).
   - If baby is sick, allow direct skip from History to Examination.
3. **Automated STW Deep-Linking:**
   - On low RBS/Blood Glucose (e.g., < 40 or 45 mg/dL), automatically flag Hypoglycemia and route directly to the STW Hypoglycemia treatment link.
   - For poor perfusion (CRT > 3s, weak pulse, mottling), flag Shock and link to Bolus/Resuscitation protocol.
   - Map T-A-B-C treatment steps directly to their respective STW clinical protocol links.

---

### Full Specification (neonatal_triage_requirements.md):

# Neonatal Triage & Emergency Assessment Module - Requirements Specification

## 1. Overview & Context
This document specifies the technical and clinical workflow requirements for updating the neonatal triage module. The goal is to eliminate manual triage categorization by clinicians, automate risk classification based on danger signs and clinical vitals, and provide immediate deep-links to Standard Treatment Workflows (STW).

---

## 2. Screen 1: Primary Assessment & Danger Signs Input

### 2.1 Header & Baseline Information
- **Timer Widget:** Visible at the top to track assessment and resuscitation response times.
- **Patient History & Demographics:**
  - `Maternal H/O` (Maternal History)
  - `NB H/O` (Newborn History)
  - `Weight`
  - `Gestation`: Radio button / dropdown (`Term [T]` vs `Pre-term [PT]`)
- **Direct Skip Capability:** If `baby is sick` is flagged or immediately evident, allow direct jump to physical examination and vital entry without blocking for exhaustive maternal/birth history.

### 2.2 Vitals & Emergency Danger Signs (Input Fields)
Provide structured fields/toggles for the following critical indicators:
1. `Temperature` (°C / °F)
2. `Heart Rate` (HR) — auto-flag if `> 200 bpm`
3. `SpO2 / Cyanosis` — pulse oximetry value and visual cyanosis flag
4. `Apnea / Gasping` — Boolean / toggle
5. `Seizures` — Boolean / toggle
6. `Perfusion Indicators`:
   - `Mottling` (Yes/No)
   - `Capillary Refill Time (CRT)` (Flag if `> 3 seconds`)
   - `Weak Pulse` (Yes/No)
7. `Random Blood Sugar (RBS / Glucose)` (mg/dL)

---

## 3. Automated Classification Engine (No Manual Selection)

### 3.1 Business Logic
- **DEPRECATE / REMOVE:**
  - Intermediate confirmation screen: `"Select the category: Emergency / Priority / Non-urgent"`.
  - Manual triaging dropdowns/radio groups.
- **AUTOMATED RULE:**
  - If **ANY** of the following evaluate to TRUE:
    - `Apnea / Gasping == TRUE`
    - `HR > 200 bpm`
    - `SpO2 < Threshold OR Cyanosis == TRUE`
    - `Seizures == TRUE`
    - `CRT > 3s OR Mottling == TRUE OR Weak Pulse == TRUE`
  - $\rightarrow$ Immediately trigger status: **EMERGENCY (Red Code)**.

---

## 4. Screen 2: Emergency Treatment & STW Deep-Linking

Bypass all confirmation dialogs upon emergency condition match and navigate directly to the **Emergency Treatment Dashboard**.

### 4.1 T-A-B-C Protocol & Protocol Links
Display actionable protocol cards with deep-links to clinical guidelines (STW):
- **T (Temperature):** Hypothermia / Hyperthermia management protocol.
- **A (Airway):** Airway clearance and positioning guidelines.
- **B (Breathing):** Oxygenation and positive pressure ventilation protocol.
- **C (Circulation):** Perfusion management.
  - If `Mottling`, `CRT > 3s`, or `Weak Pulse` are present $\rightarrow$ Flag **Shock** and provide direct link to `Shock -> Bolus Management`.
- **Respi (Respiratory):** Respiratory distress management STW link.

### 4.2 Glucose / Hypoglycemia Automated Workflow
- When user inputs `RBS` (e.g., $35\text{ mg/dL}$ or $38\text{ mg/dL}$):
  1. System checks against hypoglycemia threshold (e.g., $< 45\text{ mg/dL}$ or gestational cut-off).
  2. Automatically flag and highlight the **Hypoglycemia Alert Box**.
  3. Render direct CTA/link: **`STW Hypoglycemia Protocol`** (bolus IV dextrose, infusion, re-testing schedule).

---

### Your Task:
Please inspect our current codebase/workflow and provide the necessary code updates (UI form components, state management, validation logic, and automated routing) to satisfy these requirements.