#!/usr/bin/env python3
"""
tools/fix_rd_rop_regions.py

Corrects RD/ROP regions in assets/regions/regions.json whose box was on the
wrong PDF card (the title/aliases described one box, the coordinates - and so
the answer text, crop and "View in PDF" highlight - were another):

  rd_initial_term_mild_nasal_o2         was NOT IMPROVING/WORSENING -> NASAL-PRONG OXYGEN box
  rd_initial_term_moderate_severe_cpap  was NASAL-PRONG OXYGEN      -> START CPAP box (the
                                        GA >34 wk moderate-severe arrow leads to START CPAP)
  rop_how_to_screen                     was WHEN TO STOP SCREENING  -> HOW TO SCREEN box
  rop_when_to_stop                      was HOW TO SCREEN           -> WHEN TO STOP SCREENING box

and adds regions for PDF boxes that had none: rd_improving, rd_not_improving,
rd_abbreviations, rop_introduction, rop_abbreviations.

Boxes are the PDF's own card rectangles (PDF points). Idempotent. Run
tools/build_region_text.py afterwards for the two documents:

    python tools/fix_rd_rop_regions.py
    python tools/build_region_text.py respiratory_distress_neonates_stw.pdf \
        retinopathy_of_prematurity_stw.pdf
"""

import json
import os
import sys

import pymupdf

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGIONS = os.path.join(ROOT, "assets", "regions", "regions.json")
RD = "respiratory_distress_neonates_stw.pdf"
ROP = "retinopathy_of_prematurity_stw.pdf"


def page(doc):
    return pymupdf.open(os.path.join(ROOT, "assets", "pdfs", doc))[0]


def between_headers(doc, top, bottom):
    """Box from the [top] header to just above the [bottom] header."""
    p = page(doc)
    t = p.search_for(top)[0]
    b = [r for r in p.search_for(bottom) if r.y0 > t.y1][0]
    return (0, t.y0 - 2, p.rect.width, b.y0 - 3)


def norm(doc, box):
    p = page(doc)
    w, h = p.rect.width, p.rect.height
    x0, y0, x1, y1 = box
    return {
        "x": round(x0 / w, 5),
        "y": round(y0 / h, 5),
        "w": round((x1 - x0) / w, 5),
        "h": round((y1 - y0) / h, 5),
    }


MOVE = {
    "rd_initial_term_mild_nasal_o2": (RD, (544, 504, 833, 563)),
    "rd_initial_term_moderate_severe_cpap": (RD, (9, 504, 502, 563)),
    "rop_how_to_screen": (ROP, (287, 726, 562, 929)),
    "rop_when_to_stop": (ROP, (4, 726, 285, 929)),
}


def new_regions():
    return [
        dict(id="rd_improving", document=RD, page=1,
             title="Reassessment: Improving (Criteria)", type="algorithm",
             section="Improving", box=(9, 676, 271, 756),
             aliases=["improving", "decreasing sas", "comfortable breathing",
                      "stable support", "sudhar", "improve ho raha"],
             example_questions=[
                 "How do I know the baby with respiratory distress is improving?",
                 "Improving criteria on reassessment of RD",
                 "Baby sudhar raha hai kaise pata karein?"]),
        dict(id="rd_not_improving", document=RD, page=1,
             title="Reassessment: Not Improving / Worsening (Criteria)",
             type="algorithm", section="Not improving/worsening",
             box=(540, 676, 833, 756),
             aliases=["not improving", "worsening", "persisting sas",
                      "increasing sas", "spo2 <91%", "rising oxygen need",
                      "bigad raha", "sudhar nahi"],
             example_questions=[
                 "What are the signs that respiratory distress is worsening?",
                 "When is the baby considered not improving on reassessment?",
                 "Baby ki saans ki takleef bigad rahi hai, kaise pehchanein?"]),
        dict(id="rd_abbreviations", document=RD, page=1,
             title="Respiratory Distress Abbreviations", type="text",
             section="Abbreviations",
             box=between_headers(RD, "ABBREVIATIONS", "REFERENCES"),
             aliases=["abbreviations", "full form", "crt full form",
                      "peep full form", "fio2 full form"],
             example_questions=["What is the full form of CRT?",
                                "PEEP ka full form kya hai?"]),
        dict(id="rop_introduction", document=ROP, page=1,
             title="ROP: What It Is and Why Screening Matters", type="text",
             section="Introduction", box=(21, 190, 665, 251),
             aliases=["what is rop", "retinopathy of prematurity definition",
                      "blindness", "retinal detachment", "rop kya hai"],
             example_questions=["What is retinopathy of prematurity?",
                                "ROP kya hota hai?",
                                "Can ROP cause blindness?"]),
        dict(id="rop_abbreviations", document=ROP, page=1,
             title="ROP Abbreviations", type="text", section="Abbreviations",
             box=between_headers(ROP, "ABBREVIATIONS", "REFERENCES"),
             aliases=["abbreviations", "full form", "par full form",
                      "pma full form", "vegf full form"],
             example_questions=["What is the full form of PMA?",
                                "PAR ka full form kya hai?"]),
    ]


def main():
    with open(REGIONS, encoding="utf-8") as f:
        regions = json.load(f)
    by_id = {r["id"]: r for r in regions}
    for rid, (doc, box) in MOVE.items():
        r = by_id[rid]
        assert r["document"] == doc, rid
        r.update(norm(doc, box))
        print(f"moved {rid} -> {box}")
    added = [r["id"] for r in new_regions()]
    regions = [r for r in regions if r["id"] not in added]
    # Insert each new region after the last region of its document.
    for nr in new_regions():
        box = nr.pop("box")
        entry = {k: nr[k] for k in ("id", "document", "page", "title", "type", "section")}
        entry.update(norm(nr["document"], box))
        entry["aliases"] = nr["aliases"]
        entry["example_questions"] = nr["example_questions"]
        last = max(i for i, r in enumerate(regions) if r["document"] == nr["document"])
        regions.insert(last + 1, entry)
        print(f"added {nr['id']} {[round(v) for v in box]}")
    with open(REGIONS, "w", encoding="utf-8") as f:
        json.dump(regions, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
