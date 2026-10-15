#!/usr/bin/env python3
"""
tools/annotate_region_intents.py

Adds the curated "intents" field to every region in assets/regions/regions.json:
which kinds of question each PDF box answers. The chatbot matches the intent
detected in a question (dose, timing, contraindication, ...) against these.

Intents: definition, criteria, timing, contraindication, dose, schedule,
procedure, management, escalate, wean, stop, refer, signs, prevention, dos,
donts, kpi, abbreviation, documentation, followup, benefit.

Every region must be listed (the script fails otherwise). Idempotent.
"""

import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGIONS = os.path.join(ROOT, "assets", "regions", "regions.json")

INTENTS = {
    # Respiratory distress
    "rd_diagnostic_criteria": ["definition", "signs", "criteria"],
    "rd_immediate_actions": ["management", "procedure"],
    "rd_algorithm_overview": ["criteria", "management"],
    "rd_initial_preterm_cpap_caffeine": ["management", "dose", "criteria"],
    "rd_initial_term_moderate_severe_cpap": ["management", "dose"],
    "rd_reassessment_sepsis": ["schedule", "signs", "criteria"],
    "rd_initial_term_mild_nasal_o2": ["management", "dose"],
    "rd_outcome_improving_weaning": ["wean", "stop"],
    "rd_surfactant_indication": ["criteria", "management"],
    "rd_outcome_not_improving_optimize_cpap": ["escalate", "management"],
    "rd_cpap_failure_referral": ["refer", "definition", "criteria"],
    "rd_clinical_dos": ["dos", "timing"],
    "rd_clinical_donts": ["donts"],
    "rd_kpis": ["kpi"],
    "rd_sas_scoring_guide": ["procedure", "definition"],
    "rd_improving": ["signs"],
    "rd_not_improving": ["signs", "escalate"],
    "rd_abbreviations": ["abbreviation"],
    # ROP
    "rop_whom_to_screen": ["criteria"],
    "rop_how_to_arrange": ["procedure"],
    "rop_treatment_indications": ["criteria", "management", "timing"],
    "rop_when_to_screen": ["timing", "schedule"],
    "rop_prepare_to_screen": ["procedure"],
    "rop_treatment_options": ["management"],
    "rop_how_to_screen": ["procedure"],
    "rop_when_to_stop": ["stop", "followup"],
    "rop_prevention": ["prevention"],
    "rop_clinical_dos": ["dos", "documentation"],
    "rop_clinical_donts": ["donts"],
    "rop_kpis": ["kpi"],
    "rop_key_clinical_message": ["benefit"],
    "rop_introduction": ["definition", "benefit"],
    "rop_abbreviations": ["abbreviation"],
    # ANCS
    "ancs_introduction": ["benefit", "definition"],
    "ancs_when_to_give": ["timing", "criteria"],
    "ancs_eligibility": ["criteria", "timing"],
    "ancs_drug_dose": ["dose"],
    "ancs_when_not_to_give": ["contraindication"],
    "ancs_special_situations": ["criteria"],
    "ancs_repeat_course": ["criteria", "timing"],
    "ancs_documentation": ["documentation"],
    "ancs_referral": ["refer"],
    "ancs_dos": ["dos"],
    "ancs_donts": ["donts", "contraindication"],
    "ancs_kpis": ["kpi"],
    "ancs_abbreviations": ["abbreviation"],
    # Hypoglycemia
    "hypo_whom_to_screen": ["criteria"],
    "hypo_monitoring_schedule": ["schedule", "timing"],
    "hypo_how_to_monitor": ["procedure"],
    "hypo_flowchart_entry": ["definition"],
    "hypo_symptoms": ["signs"],
    "hypo_asymptomatic_branch": ["management"],
    "hypo_recheck_1h": ["schedule", "management"],
    "hypo_symptomatic_branch": ["management", "dose"],
    "hypo_recheck_30min": ["schedule"],
    "hypo_increase_gir": ["escalate", "dose"],
    "hypo_persistent_refractory": ["refer", "definition"],
    "hypo_euglycemic_wean": ["wean"],
    "hypo_stop_iv": ["stop"],
    "hypo_drugs_refractory": ["dose", "management"],
    "hypo_prevention": ["prevention"],
    "hypo_practical_points": ["procedure"],
    "hypo_dos": ["dos"],
    "hypo_donts": ["donts"],
    "hypo_kpis": ["kpi"],
    "hypo_neuro_followup": ["followup"],
    # Neonatal Emergency Triage Assessment and Management
    "triage_initial_assessment": ["procedure", "management"],
    "triage_emergency_signs": ["criteria", "signs"],
    "triage_priority_signs": ["criteria", "signs"],
    "triage_nonurgent_signs": ["criteria", "signs"],
    "triage_emergency_actions": ["management", "procedure", "dose"],
    "triage_priority_actions": ["management", "procedure"],
    "triage_nonurgent_actions": ["management", "procedure", "followup"],
    "triage_shock": ["management", "dose"],
    "triage_severe_dehydration": ["criteria", "management", "dose", "schedule"],
    "triage_seizures": ["management", "dose", "refer"],
    "triage_surgical": ["management", "refer"],
    "triage_persistent_tachycardia": ["criteria", "management", "refer"],
    "triage_hypothermia": ["criteria", "management", "schedule"],
    "triage_hypoglycemia": ["criteria", "management", "dose"],
    "triage_jaundice": ["criteria", "management", "refer"],
    "triage_dos": ["dos"],
    "triage_donts": ["donts", "contraindication"],
    "triage_kpis": ["kpi"],
    "triage_abbreviations": ["abbreviation"],
    "triage_references": ["documentation"],
    # Kangaroo Mother Care
    "kmc_definition": ["definition", "benefit"],
    "kmc_eligibility": ["criteria", "timing"],
    "kmc_exclusions": ["contraindication", "donts"],
    "kmc_position": ["procedure", "management"],
    "kmc_provider": ["criteria", "procedure"],
    "kmc_nutrition": ["management", "procedure"],
    "kmc_discharge": ["criteria", "procedure", "followup"],
    "kmc_before_starting": ["procedure", "criteria"],
    "kmc_monitoring": ["schedule", "procedure"],
    "kmc_transport": ["procedure", "management"],
    "kmc_continue_while_on": ["management", "donts"],
    "kmc_home_counselling": ["dos", "followup", "refer"],
    "kmc_followup": ["followup", "schedule"],
    "kmc_dos": ["dos"],
    "kmc_donts": ["donts", "contraindication"],
    "kmc_kpis": ["kpi"],
    "kmc_in_position": ["procedure", "benefit"],
    "kmc_related_information": ["documentation", "procedure"],
    "kmc_abbreviations": ["abbreviation"],
    "kmc_references": ["documentation"],
}


# Extra aliases (English/Hinglish wording clinicians use for a box that its
# PDF text does not contain). Added if missing.
EXTRA_ALIASES = {
    "rop_prepare_to_screen": ["pain relief", "analgesia", "before the exam",
                              "withhold feeds", "pupil dilation"],
    "hypo_practical_points": ["underlying causes", "causes of hypoglycemia"],
    "rd_reassessment_sepsis": ["suspect sepsis", "sepsis in respiratory distress"],
    "rop_clinical_donts": ["discharge without follow-up plan"],
}


def main():
    with open(REGIONS, encoding="utf-8") as f:
        regions = json.load(f)
    ids = {r["id"] for r in regions}
    missing = ids - INTENTS.keys()
    unknown = INTENTS.keys() - ids
    if missing or unknown:
        raise SystemExit(f"missing: {sorted(missing)} unknown: {sorted(unknown)}")
    for r in regions:
        r["intents"] = INTENTS[r["id"]]
        for a in EXTRA_ALIASES.get(r["id"], []):
            if a not in r["aliases"]:
                r["aliases"].append(a)
    with open(REGIONS, "w", encoding="utf-8") as f:
        json.dump(regions, f, indent=2, ensure_ascii=False)
    print(f"annotated {len(regions)} regions")


if __name__ == "__main__":
    main()
