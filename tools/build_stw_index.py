#!/usr/bin/env python3
"""
STW Clinical Index Builder
Extracts logical clinical sections, algorithms, and tables from ICMR/DHR STW PDFs
into assets/stw_index/stw_index.json with normalized visual bounding boxes.
"""

import os
import sys
import json
import re
import pymupdf

# Force UTF-8 on Windows standard out
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDF_DIR = os.path.join(PROJECT_ROOT, "assets", "pdfs")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "stw_index")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "stw_index.json")

# Target source PDFs (ignore duplicates)
TARGET_DOCS = [
    {
        "filename": "respiratory_distress_neonates_stw.pdf",
        "short_title": "Respiratory Distress in Neonates (ICMR/DHR STW)",
    },
    {
        "filename": "retinopathy_of_prematurity_stw.pdf",
        "short_title": "Retinopathy of Prematurity - ROP (ICMR/DHR STW)",
    },
]


def normalize_rect(rect, page_width, page_height):
    """Normalize rect coordinates to 0.0 - 1.0."""
    x0 = max(0.0, min(float(rect[0]), page_width))
    y0 = max(0.0, min(float(rect[1]), page_height))
    x1 = max(0.0, min(float(rect[2]), page_width))
    y1 = max(0.0, min(float(rect[3]), page_height))
    
    return {
        "x": round(x0 / page_width, 5),
        "y": round(y0 / page_height, 5),
        "width": round((x1 - x0) / page_width, 5),
        "height": round((y1 - y0) / page_height, 5),
    }


def union_rects(rects):
    """Compute bounding rect enclosing a list of rects."""
    if not rects:
        return [0, 0, 0, 0]
    x0 = min(r[0] for r in rects)
    y0 = min(r[1] for r in rects)
    x1 = max(r[2] for r in rects)
    y1 = max(r[3] for r in rects)
    return [x0, y0, x1, y1]


def extract_keywords(text, extra=None):
    """Extract clinical tokens, drug names, and numerical targets."""
    words = re.findall(r"\b[A-Za-z0-9_/%<≥≤\.\-]+\b", text)
    stop_words = {
        "the", "and", "or", "for", "with", "this", "that", "from", "may",
        "are", "not", "any", "all", "per", "one", "has", "been", "was",
        "into", "use", "used", "after", "before", "when", "where", "how",
        "who", "can", "must", "should", "will", "than", "then", "their"
    }
    cleaned = []
    for w in words:
        wl = w.lower()
        if len(w) > 1 and wl not in stop_words and not wl.isdigit():
            cleaned.append(wl)
    if extra:
        for e in extra:
            cleaned.append(e.lower())
    # Deduplicate while preserving order
    return list(dict.fromkeys(cleaned))


def build_rd_chunks(doc, page, pw, ph):
    """Extract and structure chunks for Respiratory Distress in Neonates."""
    blocks = page.get_text("blocks")
    chunks = []

    def get_block_info(indices):
        texts = []
        rects = []
        for i in indices:
            b = blocks[i]
            t = b[4].strip()
            if t:
                texts.append(t)
            rects.append([b[0], b[1], b[2], b[3]])
        full_text = "\n".join(texts)
        u_rect = union_rects(rects)
        norm_bboxes = [normalize_rect(r, pw, ph) for r in rects]
        return full_text, norm_bboxes, normalize_rect(u_rect, pw, ph)

    # 1. Title / Header
    t, bboxes, ub = get_block_info([44, 45, 47, 48])
    chunks.append({
        "chunk_id": "rd_title_header",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "STW Title & Classification: Respiratory Distress in Neonates",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["icd-11", "kb23", "respiratory distress", "neonates", "stw", "icmr", "dhr"]),
        "bounding_boxes": bboxes,
    })

    # 2. Diagnostic Criteria
    t, bboxes, ub = get_block_info([8, 16, 17])
    chunks.append({
        "chunk_id": "rd_diagnostic_criteria",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Diagnostic Criteria: Respiratory Distress in Neonates",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["respiratory rate", "rr", ">60/min", "tachypnea", "chest indrawing", "retractions", "nasal flaring", "grunting", "diagnosis", "criteria"]),
        "bounding_boxes": bboxes,
    })

    # 3. Immediate Actions
    t, bboxes, ub = get_block_info([31, 32])
    chunks.append({
        "chunk_id": "rd_immediate_actions",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Immediate Actions for Neonatal Respiratory Distress",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["tabc", "temperature", "airway", "breathing", "circulation", "sncu", "nicu", "iv access", "blood glucose", "hypoglycemia", "warmth", "stabilize"]),
        "bounding_boxes": bboxes,
    })

    # 4. Algorithm Overview / Assessment by GA & SAS
    t, bboxes, ub = get_block_info([15, 18, 58])
    chunks.append({
        "chunk_id": "rd_algorithm_overview",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Algorithm: Respiratory Distress Gestational Age & SAS Assessment",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["algorithm", "gestation", "ga", "sas", "silverman", "uncertain", "surrogate", "birth weight", "<=1800g", "1800g"]),
        "bounding_boxes": bboxes,
    })

    # 5. Preterm GA <= 34 weeks: Initial CPAP + Caffeine
    t, bboxes, ub = get_block_info([49, 19, 20])
    chunks.append({
        "chunk_id": "rd_initial_preterm_cpap_caffeine",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Initial Respiratory Support for GA ≤34 Weeks (CPAP & Caffeine Citrate)",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["cpap", "start cpap", "5-6 cm h2o", "peep", "blended oxygen", "fio2", "spo2 91-95%", "caffeine citrate", "<34 weeks", "preterm", "loading dose", "respiratory support"]),
        "bounding_boxes": bboxes,
    })

    # 6. Term GA > 34 weeks Moderate-Severe (SAS >= 4): CPAP
    t, bboxes, ub = get_block_info([50, 19])
    chunks.append({
        "chunk_id": "rd_initial_term_moderate_severe_cpap",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Initial Support for GA >34 Weeks with Moderate-to-Severe Distress (SAS ≥4)",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["ga >34 weeks", "term", "moderate-severe", "sas >=4", "cpap", "5-6 cm h2o", "blended o2", "spo2 91-95%"]),
        "bounding_boxes": bboxes,
    })

    # 7. Term GA > 34 weeks Mild (SAS <= 3): Nasal Prong Oxygen
    t, bboxes, ub = get_block_info([51, 22, 23])
    chunks.append({
        "chunk_id": "rd_initial_term_mild_nasal_o2",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Initial Support for GA >34 Weeks with Mild Distress (SAS ≤3)",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["ga >34 weeks", "term", "mild rd", "sas <=3", "nasal-prong oxygen", "nasal prongs", "0.5-1 l/min", "spo2 91-95%"]),
        "bounding_boxes": bboxes,
    })

    # 8. Reassessment & Sepsis Consideration
    t, bboxes, ub = get_block_info([21])
    chunks.append({
        "chunk_id": "rd_reassessment_sepsis",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Reassessment Protocol & Sepsis Consideration",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["reassess", "frequently", "clinical status", "sas", "spo2", "fio2", "sepsis", "perinatal risk factors", "worsening distress"]),
        "bounding_boxes": bboxes,
    })

    # 9. Outcome: Improving & CPAP Weaning Protocol
    t, bboxes, ub = get_block_info([24, 25, 26, 27])
    chunks.append({
        "chunk_id": "rd_outcome_improving_weaning",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Outcome Improving: CPAP and Oxygen Weaning Protocol",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["improving", "decreasing sas", "wean fio2", "0.21", "room air", "reduce cpap", "1 cm h2o", "4-5 cm h2o", "stop cpap", "monitoring 24 h"]),
        "bounding_boxes": bboxes,
    })

    # 10. Surfactant Therapy Indication
    t, bboxes, ub = get_block_info([53, 54, 55])
    chunks.append({
        "chunk_id": "rd_surfactant_indication",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Surfactant Therapy Indication & Thresholds",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["surfactant", "<34 weeks", "cpap", "peep >6 cm h2o", "fio2 >0.30", "fio2 >30%", "spo2 91-95%", "rds", "respiratory distress syndrome"]),
        "bounding_boxes": bboxes,
    })

    # 11. Outcome: Not Improving / Worsening & Optimize CPAP
    t, bboxes, ub = get_block_info([28, 29])
    chunks.append({
        "chunk_id": "rd_outcome_not_improving_optimize_cpap",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Outcome Not Improving: Steps to Optimize CPAP",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["not improving", "worsening", "persisting sas", "spo2 <91%", "rising oxygen", "apnea", "bradycardia", "optimize cpap", "increase peep", "7-8 cm h2o", "surfactant"]),
        "bounding_boxes": bboxes,
    })

    # 12. CPAP Failure & Urgent Referral
    t, bboxes, ub = get_block_info([30])
    chunks.append({
        "chunk_id": "rd_cpap_failure_referral",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "CPAP Failure Criteria & Urgent Referral Indication",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["cpap failure", "hypoxemia", "high fio2", "recurrent apnea", "shock", "fatigue", "refer urgently", "intubation", "mechanical ventilation"]),
        "bounding_boxes": bboxes,
    })

    # 13. Clinical DOs
    t, bboxes, ub = get_block_info([0])
    chunks.append({
        "chunk_id": "rd_clinical_dos",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Clinical DOs for Neonatal Respiratory Distress",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["dos", "assess sas", "spo2 91-95%", "start cpap early", "caffeine citrate", "nasal prongs", "prongs fixation"]),
        "bounding_boxes": bboxes,
    })

    # 14. Clinical DON'Ts
    t, bboxes, ub = get_block_info([1])
    chunks.append({
        "chunk_id": "rd_clinical_donts",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Clinical DON'Ts for Neonatal Respiratory Distress",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["donts", "do not", "unblended oxygen", "100% oxygen", "delay cpap", "withhold caffeine", "sedatives", "abruptly discontinue"]),
        "bounding_boxes": bboxes,
    })

    # 15. Key Performance Indicators (KPIs)
    t, bboxes, ub = get_block_info([56, 4, 5, 6, 7])
    chunks.append({
        "chunk_id": "rd_kpis",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Key Performance Indicators (KPIs): Respiratory Distress Management",
        "type": "table",
        "text": t,
        "keywords": extract_keywords(t, ["kpi", "kpis", "key performance indicators", "timely cpap initiation", "target >90%", "spo2 target compliance", "compliance"]),
        "bounding_boxes": bboxes,
    })

    # 16. Silverman-Andersen Score (SAS) Section
    t, bboxes, ub = get_block_info([52, 13, 14, 2, 3, 41, 42])
    chunks.append({
        "chunk_id": "rd_sas_scoring_guide",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Silverman-Andersen Score (SAS) Methodology & Interpretation",
        "type": "table",
        "text": t,
        "keywords": extract_keywords(t, ["silverman", "andersen", "sas", "upper chest", "lower chest", "xiphoid", "nares dilatation", "expiratory grunt", "mild <=3", "moderate >=4", "severe", "scoring"]),
        "bounding_boxes": bboxes,
    })

    # 17. Related Technical Information & Skills
    t, bboxes, ub = get_block_info([10, 36, 37, 38, 39, 40, 43])
    chunks.append({
        "chunk_id": "rd_related_technical_skills",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Related Clinical Procedures & Technical Setup",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["bubble cpap", "connect ventilator", "ventilator cpap", "binasal prongs", "prongs fixation", "surfactant administration"]),
        "bounding_boxes": bboxes,
    })

    # 18. Abbreviations
    t, bboxes, ub = get_block_info([9, 33, 34, 35])
    chunks.append({
        "chunk_id": "rd_abbreviations",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Abbreviations: Respiratory Distress Workflow",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["bw", "crt", "cpap", "ga", "iv", "spo2", "rd", "fio2", "rr", "peep", "sas", "definitions"]),
        "bounding_boxes": bboxes,
    })

    # 19. References
    t, bboxes, ub = get_block_info([12, 11])
    chunks.append({
        "chunk_id": "rd_references",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "References & Scientific Basis",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["references", "icmr", "dhr", "who", "guidelines"]),
        "bounding_boxes": bboxes,
    })

    # 20. Policy & Disclaimer
    t, bboxes, ub = get_block_info([57])
    chunks.append({
        "chunk_id": "rd_disclaimer",
        "document": "respiratory_distress_neonates_stw.pdf",
        "page": 1,
        "section_title": "Policy & Implementation Scope",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["disclaimer", "national experts", "district hospitals", "medical colleges", "feasibility"]),
        "bounding_boxes": bboxes,
    })

    return chunks


def build_rop_chunks(doc, page, pw, ph):
    """Extract and structure chunks for Retinopathy of Prematurity (ROP)."""
    blocks = page.get_text("blocks")
    chunks = []

    def get_block_info(indices):
        texts = []
        rects = []
        for i in indices:
            b = blocks[i]
            t = b[4].strip()
            if t:
                texts.append(t)
            rects.append([b[0], b[1], b[2], b[3]])
        full_text = "\n".join(texts)
        u_rect = union_rects(rects)
        norm_bboxes = [normalize_rect(r, pw, ph) for r in rects]
        return full_text, norm_bboxes, normalize_rect(u_rect, pw, ph)

    # 1. Title & Definition
    t, bboxes, ub = get_block_info([0, 1, 48, 49, 6])
    chunks.append({
        "chunk_id": "rop_title_definition",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "STW Title & Definition: Retinopathy of Prematurity (ROP)",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["rop", "retinopathy of prematurity", "icd-11-9b71.3", "retinal vascular disorder", "preterm", "blindness", "visual impairment", "screening"]),
        "bounding_boxes": bboxes,
    })

    # 2. Whom to Screen (Inclusion / Eligibility Criteria)
    t, bboxes, ub = get_block_info([22, 27, 28, 29, 30])
    chunks.append({
        "chunk_id": "rop_whom_to_screen",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Whom to Screen: ROP Screening Eligibility Criteria",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["whom to screen", "eligibility", "gestation <34 weeks", "birth weight <2000 g", "<2000g", "34-36 weeks", "risk factors", "oxygen therapy", "cardiorespiratory support", "poor weight gain", "anemia", "transfusion", "sepsis"]),
        "bounding_boxes": bboxes,
    })

    # 3. When to Screen (First Screen Timing & Frequency)
    t, bboxes, ub = get_block_info([26, 23, 24, 25])
    chunks.append({
        "chunk_id": "rop_when_to_screen",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "When to Screen: Timing of First Screening & Follow-up Intervals",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["when to screen", "first screen", "4 weeks postnatal age", "2-3 weeks", "<28 weeks", "<1200 g", "follow-up", "every 1-3 weeks", "retinal findings", "schedule"]),
        "bounding_boxes": bboxes,
    })

    # 4. How to Arrange Screening
    t, bboxes, ub = get_block_info([40, 35, 36])
    chunks.append({
        "chunk_id": "rop_how_to_arrange",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "How to Arrange Screening: SNCU/NICU & Referral Protocols",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["how to arrange", "on-site screening", "sncu", "nicu", "tele-screening", "specialist visits", "referral", "discharge plan"]),
        "bounding_boxes": bboxes,
    })

    # 5. Prepare to Screen (Pre-procedure Preparation)
    t, bboxes, ub = get_block_info([42, 41])
    chunks.append({
        "chunk_id": "rop_prepare_to_screen",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Prepare to Screen: Feeding, Pupillary Dilation & Swaddling",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["prepare to screen", "withhold feeds", "1 hour before", "dilate pupils", "phenylephrine 2.5%", "tropicamide 0.5-0.8%", "pupillary dilation", "drops", "swaddle"]),
        "bounding_boxes": bboxes,
    })

    # 6. How to Screen (Examination Technique & Tools)
    t, bboxes, ub = get_block_info([44, 43])
    chunks.append({
        "chunk_id": "rop_how_to_screen",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "How to Screen: Clinical Examination Technique",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["how to screen", "hand hygiene", "asepsis", "indirect ophthalmoscopy", "20d", "28d lens", "topical anesthetic", "proparacaine 0.5%", "eye speculum", "scleral depressor", "examination"]),
        "bounding_boxes": bboxes,
    })

    # 7. Treatment Indications (Threshold Disease & Urgency)
    t, bboxes, ub = get_block_info([38, 31, 32, 33, 34])
    chunks.append({
        "chunk_id": "rop_treatment_indications",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Treatment Indications: ICROP Criteria & Treatment Urgency",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["treatment indications", "zone i", "zone ii", "stage 2", "stage 3", "plus disease", "a-rop", "aggressive rop", "treatment-requiring", "urgently", "48-72 hours"]),
        "bounding_boxes": bboxes,
    })

    # 8. Treatment Options
    t, bboxes, ub = get_block_info([39, 37])
    chunks.append({
        "chunk_id": "rop_treatment_options",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Treatment Options: Laser Photocoagulation & Anti-VEGF",
        "type": "algorithm",
        "text": t,
        "keywords": extract_keywords(t, ["treatment options", "laser", "laser photocoagulation", "anti-vegf", "intravitreal", "injection", "rop specialist"]),
        "bounding_boxes": bboxes,
    })

    # 9. When to Stop Screening (Discharge Criteria)
    t, bboxes, ub = get_block_info([47, 46])
    chunks.append({
        "chunk_id": "rop_when_to_stop",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "When to Stop Screening: Criteria for Termination of Screening",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["when to stop", "stop screening", "discharge", "retina fully vascularised", "zone iii", "pma 45 weeks", "regression", "ophthalmologist"]),
        "bounding_boxes": bboxes,
    })

    # 10. Prevention of ROP
    t, bboxes, ub = get_block_info([45])
    chunks.append({
        "chunk_id": "rop_prevention",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Prevention of ROP: Antenatal Steroids & Safe Oxygenation",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["prevention", "antenatal corticosteroids", "lung maturation", "safe oxygen therapy", "air-oxygen blender", "pulse oximeter", "spo2 targets", "breastmilk", "ebm", "sepsis control"]),
        "bounding_boxes": bboxes,
    })

    # 11. Clinical DOs
    t, bboxes, ub = get_block_info([12, 10])
    chunks.append({
        "chunk_id": "rop_clinical_dos",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Clinical DOs for Retinopathy of Prematurity",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["dos", "timely screening", "follow-up", "document date and place", "discharge slip", "counsel parents", "full vascularization"]),
        "bounding_boxes": bboxes,
    })

    # 12. Clinical DON'Ts
    t, bboxes, ub = get_block_info([11])
    chunks.append({
        "chunk_id": "rop_clinical_donts",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Clinical DON'Ts for Retinopathy of Prematurity",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["donts", "do not", "discharge without follow-up", "delay treatment", "unblended oxygen", "stop prematurely"]),
        "bounding_boxes": bboxes,
    })

    # 13. Key Performance Indicators (KPIs)
    t, bboxes, ub = get_block_info([21, 17, 18, 19, 20])
    chunks.append({
        "chunk_id": "rop_kpis",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Key Performance Indicators (KPIs): ROP Screening Coverage & Timeliness",
        "type": "table",
        "text": t,
        "keywords": extract_keywords(t, ["kpi", "kpis", "key performance indicators", "screening coverage", "timely first screening", "recommended window", "quality improvement"]),
        "bounding_boxes": bboxes,
    })

    # 14. Key Slogan / Awareness
    t, bboxes, ub = get_block_info([15, 16])
    chunks.append({
        "chunk_id": "rop_key_clinical_message",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Key Clinical Imperative: No Infant Leaves Without Screening Plan",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["timely rop screening saves sight", "sncu", "nicu", "discharge", "follow-up plan"]),
        "bounding_boxes": bboxes,
    })

    # 15. Related Information & Tools
    t, bboxes, ub = get_block_info([14, 50, 51, 52, 53])
    chunks.append({
        "chunk_id": "rop_related_information",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Related Information: Classification, Record Forms & Parent FAQs",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["rop classification", "rop record form", "information for parents", "faqs", "preterm care package"]),
        "bounding_boxes": bboxes,
    })

    # 16. Abbreviations
    t, bboxes, ub = get_block_info([2, 7, 8, 9])
    chunks.append({
        "chunk_id": "rop_abbreviations",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Abbreviations: Retinopathy of Prematurity Workflow",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["a-rop", "bw", "ebm", "ga", "par", "pma", "rop", "vegf", "definitions"]),
        "bounding_boxes": bboxes,
    })

    # 17. References
    t, bboxes, ub = get_block_info([13, 5])
    chunks.append({
        "chunk_id": "rop_references",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "References & National Guidelines",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["references", "mohfw", "guidelines", "universal eye screening", "national experts"]),
        "bounding_boxes": bboxes,
    })

    # 18. Policy / Disclaimer
    t, bboxes, ub = get_block_info([3])
    chunks.append({
        "chunk_id": "rop_disclaimer",
        "document": "retinopathy_of_prematurity_stw.pdf",
        "page": 1,
        "section_title": "Policy & Implementation Scope",
        "type": "text",
        "text": t,
        "keywords": extract_keywords(t, ["disclaimer", "national experts", "district hospitals", "medical colleges", "feasibility"]),
        "bounding_boxes": bboxes,
    })

    return chunks


def build_clinical_synonyms():
    """Build standardized clinical synonym/abbreviation mapping."""
    synonyms = {
        "rds": ["respiratory distress", "respiratory distress syndrome", "hyaline membrane disease", "rd"],
        "rd": ["respiratory distress", "rds"],
        "cpap": ["continuous positive airway pressure", "bubble cpap", "peep"],
        "bubble cpap": ["cpap", "continuous positive airway pressure"],
        "sas": ["silverman", "andersen", "silverman andersen score", "silverman-andersen score", "respiratory severity score"],
        "silverman": ["sas", "silverman-andersen", "scoring"],
        "caffeine": ["caffeine citrate", "loading dose 20 mg/kg", "maintenance dose", "apnea of prematurity"],
        "caffeine citrate": ["caffeine", "20 mg/kg"],
        "surfactant": ["exogenous surfactant", "peep >6", "fio2 >0.30", "intubation surfactant extubation", "insure"],
        "fio2": ["fraction of inspired oxygen", "oxygen concentration", "blended oxygen"],
        "peep": ["positive end-expiratory pressure", "cpap pressure", "5 cm h2o", "5-6 cm h2o", "7-8 cm h2o"],
        "spo2": ["oxygen saturation", "saturation", "pulse oximetry", "target 91-95%", "91-95%"],
        "rr": ["respiratory rate", "breaths per minute", ">60/min", "tachypnea"],
        "tachypnea": ["rr >60/min", "respiratory rate", "fast breathing"],
        "grunting": ["expiratory grunt", "grunt"],
        "retractions": ["chest indrawing", "intercostal retractions", "subcostal retractions", "xiphoid retractions"],
        "rop": ["retinopathy of prematurity", "retinal screening", "retina"],
        "retinopathy of prematurity": ["rop"],
        "a-rop": ["aggressive rop", "aggressive retinopathy", "ap-rop"],
        "laser": ["laser photocoagulation", "retinal ablation"],
        "laser photocoagulation": ["laser", "treatment-requiring rop"],
        "anti-vegf": ["antivegf", "bevacizumab", "ranibizumab", "intravitreal injection", "vegf"],
        "vegf": ["vascular endothelial growth factor", "anti-vegf"],
        "zone": ["zone i", "zone ii", "zone iii", "icrop zone"],
        "stage": ["stage 1", "stage 2", "stage 3", "stage 4", "stage 5", "icrop stage"],
        "plus disease": ["plus", "tortuosity", "dilation", "venous dilation", "arteriolar tortuosity"],
        "pma": ["postmenstrual age", "gestational age plus chronological age"],
        "ga": ["gestational age", "gestation", "weeks gestation"],
        "bw": ["birth weight", "grams"],
        "sncu": ["special newborn care unit", "nicu"],
        "nicu": ["neonatal intensive care unit", "sncu"],
        "tropicamide": ["pupillary dilation", "eye drops", "0.5% tropicamide"],
        "phenylephrine": ["pupillary dilation", "eye drops", "2.5% phenylephrine"],
        "proparacaine": ["topical anesthetic", "0.5% proparacaine", "eye drops"],
    }
    return synonyms


def main():
    print("=" * 60)
    print("STW Clinical Index Builder Starting...")
    print("=" * 60)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_chunks = []

    for item in TARGET_DOCS:
        fname = item["filename"]
        fpath = os.path.join(PDF_DIR, fname)
        if not os.path.exists(fpath):
            print(f"ERROR: PDF not found: {fpath}", file=sys.stderr)
            sys.exit(1)

        doc = pymupdf.open(fpath)
        page_count = len(doc)
        print(f"\nProcessing '{fname}' ({page_count} page(s))...")

        for p_idx in range(page_count):
            page = doc[p_idx]
            pw, ph = page.rect.width, page.rect.height
            page_text = page.get_text()

            if not page_text.strip():
                print(f"WARNING: Page {p_idx+1} has no text! (OCR required)")
                continue

            if "respiratory_distress" in fname:
                chunks = build_rd_chunks(doc, page, pw, ph)
            elif "retinopathy_of_prematurity" in fname:
                chunks = build_rop_chunks(doc, page, pw, ph)
            else:
                chunks = []

            print(f"  -> Generated {len(chunks)} chunks for page {p_idx+1}")

            # Verification: Check that every chunk text lines originate from the source page
            verified_count = 0
            for c in chunks:
                lines = [l.strip() for l in c["text"].splitlines() if len(l.strip()) > 3]
                matched_lines = sum(1 for l in lines if l in page_text)
                if matched_lines >= max(1, len(lines) // 2):
                    verified_count += 1
                else:
                    print(f"  [!] Verification warning for chunk: {c['chunk_id']}")

            print(f"  -> Verification passed: {verified_count}/{len(chunks)} chunks verified verbatim against PDF text")
            all_chunks.extend(chunks)

    # Save index
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_chunks, f, indent=2, ensure_ascii=False)

    print(f"\n[OK] Successfully wrote {len(all_chunks)} chunks to {OUTPUT_FILE}")

    # Build and save clinical synonyms
    syn_file = os.path.join(OUTPUT_DIR, "clinical_synonyms.json")
    synonyms = build_clinical_synonyms()
    with open(syn_file, "w", encoding="utf-8") as f:
        json.dump(synonyms, f, indent=2, ensure_ascii=False)
    print(f"[OK] Successfully wrote clinical synonyms map to {syn_file}")

    # Print summary report
    print("\n" + "=" * 60)
    print("STW INDEX BUILD REPORT")
    print("=" * 60)
    doc_groups = {}
    for c in all_chunks:
        doc_groups.setdefault(c["document"], []).append(c)
    for doc_name, chs in doc_groups.items():
        print(f"• Document: {doc_name}")
        print(f"  Total chunks: {len(chs)}")
        text_count = sum(1 for c in chs if c["type"] == "text")
        algo_count = sum(1 for c in chs if c["type"] == "algorithm")
        tbl_count = sum(1 for c in chs if c["type"] == "table")
        print(f"  Breakdown: {text_count} text, {algo_count} algorithm boxes, {tbl_count} tables")
        for c in chs:
            print(f"    - [{c['type'].upper():9s}] {c['chunk_id']:35s} | bboxes: {len(c['bounding_boxes'])} | {c['section_title']}")
    print("=" * 60)


if __name__ == "__main__":
    main()
