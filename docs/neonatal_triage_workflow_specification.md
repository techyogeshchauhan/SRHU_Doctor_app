# Product Requirement Document (PRD): Automated Neonatal Triage & Treatment Workflow

## 1. Overview & Objective
This document outlines the refactoring specifications for the neonatal triage assessment and classification module. 

### Core Objective
Transform the manual triage classification into an automated, rule-based clinical decision-support system. Clinicians should **never** be required to manually categorize a patient as "Emergency" or "Priority." Instead, entering red-flag danger signs or critical laboratory/vital thresholds must automatically classify the neonate as an **Emergency (Red Triage)** and route them directly to targeted treatment protocols and relevant **Standard Treatment Workflow (STW)** guidelines.

---

## 2. Problem Statement & Changes Required

| Current Implementation | Target Implementation |
| :--- | :--- |
| Users are prompted to manually choose: *"Select the category: Continue Priority or Non-Urgent / Emergency"*. | **Eliminate manual classification prompts completely.** Classification must be computed automatically based on vital signs and red-flag indicators. |
| Intermediary confirmation/selection screens clutter the workflow. | **Remove all intermediary screens.** Transition directly from initial assessment/vitals entry to the Emergency Treatment screen. |
| Critical thresholds (e.g., Blood Glucose $< 45\text{ mg/dL}$) do not automatically highlight or deep-link to relevant STW modules. | **Auto-flag specific conditions** (e.g., Hypoglycemia box flagged, Shock protocols highlighted) and provide direct deep links into specific STW treatment steps. |

---

## 3. Detailed Workflow & Screen Specifications

### Screen 1: Neonatal Triage Assessment & Vitals Input

#### 1. Header & Utilities
* **Timer Component:** Persistent elapsed triage timer displayed at the top (`[Timer]`).
* **Fast-Track Toggle:** Quick-action rule: *"Can directly proceed to examination if baby is sick"* (allows bypassing extensive history when presenting with acute distress).

#### 2. History & Baseline Information
* **Maternal H/O:** Maternal history input field.
* **NB H/O:** Newborn history input field.
* **Weight & Gestation:**
  * Weight input (grams / kg).
  * Gestational categorization: Term ($\text{T}$) vs. Preterm ($\text{PT}$).

#### 3. Vital Signs & Danger Signs Entry (Clinical Inputs)
The UI must provide concise, rapid entry for the following parameters:
* **Temperature:** Core body temperature input.
* **Heart Rate (HR):** Numerical input; threshold trigger at $\text{HR} > 200\text{ bpm}$.
* **$\text{SpO}_2$ / Cyanosis:** Oxygen saturation percentage and presence/absence of central cyanosis.
* **Apnea / Gasping:** Boolean / toggle detection for respiratory arrest or gasping respiration.
* **Seizures:** Boolean / toggle detection for active or recent clinical neonatal seizures.
* **Perfusion & Shock Indicators:**
  * Mottling
  * Capillary Refill Time ($\text{CRT} > 3\text{ seconds}$)
  * Weak / thready peripheral pulses
* **RBS (Random Blood Sugar) / Glucose:** Numerical input (e.g., $35\text{ mg/dL}$, $38\text{ mg/dL}$).

---

### Automated Classification Engine (Business Logic)

The system evaluates all inputs in real time:

$$\text{Triage Category} = \begin{cases} 
\mathbf{EMERGENCY\ (Red)}, & \text{if any danger sign is present} \\ 
\mathbf{PRIORITY / ROUTINE}, & \text{otherwise} 
\end{cases}$$

#### Emergency Trigger Conditions (Any single criterion triggers Emergency):
1. $\text{HR} > 200\text{ bpm}$
2. Presence of Central Cyanosis or $\text{SpO}_2 < 90\%$ (or protocol threshold)
3. Apnea or Gasping respiration
4. Active or suspected Seizures
5. Signs of Shock: $\text{CRT} > 3\text{ s}$, Mottling, or Weak Pulses
6. Hypoglycemia: $\text{RBS} < 45\text{ mg/dL}$ (e.g., entries like $35$ or $38\text{ mg/dL}$)

> **Crucial Rule:** As soon as any trigger condition is met, the system suppresses category selection buttons and automatically transitions the state to **Emergency**.

---

### Screen 2: Emergency Treatment & Protocol Linking (TABC + STW)

Direct transition to the acute resuscitation and stabilization view following standard neonatal stabilization frameworks:

#### 1. TABC Framework
* **$\mathbf{T}$ (Temperature Management):** Hypothermia / hyperthermia corrective measures $\rightarrow$ *Direct STW Link*.
* **$\mathbf{A}$ (Airway):** Positioning, suctioning, airway clearance $\rightarrow$ *Direct STW Link*.
* **$\mathbf{B}$ (Breathing):** Bag-and-mask ventilation, oxygen therapy, CPAP $\rightarrow$ *Direct STW Link*.
* **$\mathbf{C}$ (Circulation):** Chest compressions, vascular access, fluid resuscitation $\rightarrow$ *Direct STW Link*.

#### 2. Specific Acute Protocol Cards & Deep Links
* **Shock Protocol Card:**
  * Triggered if Mottling, $\text{CRT} > 3\text{ s}$, or Weak Pulses are noted.
  * Direct prompt: **Shock $\rightarrow$ Fluid Bolus (Normal Saline $10\text{ mL/kg}$)** $\rightarrow$ *Direct STW Shock Link*.
* **Hypoglycemia Card:**
  * Automatically flagged/highlighted when $\text{RBS} \le 45\text{ mg/dL}$.
  * Action: Prompts acute corrective bolus ($10\%\text{ Dextrose at } 2\text{ mL/kg}$) and automatically surfaces the deep link: **STW Hypoglycemia Guidelines**.
* **Respiratory Distress Protocol:**
  * Triggered if Apnea / Gasping / Cyanosis is selected $\rightarrow$ *Direct STW Respiratory Distress Link*.

---

## 4. UI/UX Removal List (What to Delete)

1. **Delete** any dialog or form field titled `"Select Category"`, `"Priority vs Emergency"`, or `"Non-urgent selection"`.
2. **Delete** intermediate confirmation/preview screens between data entry and emergency management.
3. **Remove** redundant triage re-assessments that query the user to re-evaluate conditions already recorded on Screen 1.

---

## 5. Acceptance Criteria for Agent / Developers

1. **Zero-Click Classification:** When a user inputs $\text{HR} = 210$ or toggles `Apnea: Yes`, the application must tag the record as `EMERGENCY` without prompting the user.
2. **Seamless Navigation:** Clicking "Next" or "Proceed" from the vitals screen immediately displays the Emergency Treatment dashboard.
3. **Context-Aware Treatment Links:**
   * If $\text{RBS} = 35$, the `Hypoglycemia` card must render in an active/flagged state with a direct button linking to the corresponding STW document.
   * If `CRT > 3s` or `Weak Pulses` is active, the `Shock -> Bolus` pathway must be explicitly highlighted.
4. **Timer Persistence:** The timer must run continuously without resetting during transitions across triage steps.