#!/usr/bin/env python3
"""Legacy ROP region repair. RD is rebuilt only by update_rd_source.py."""

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
    "rop_how_to_screen": (ROP, (287, 726, 562, 929)),
    "rop_when_to_stop": (ROP, (4, 726, 285, 929)),
}


def new_regions():
    return [
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
