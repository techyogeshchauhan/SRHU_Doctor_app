import fitz
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DOC_MAP = {
    "KMC-13-10-2026.pdf": "assets/pdfs/KMC-13-10-2026.pdf",
    "Triage_13-10-26.pdf": "assets/pdfs/Triage_13-10-26.pdf",
    "Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf": "assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf",
    "Neonatal_Hypoglycemia_8th_Oct.pdf": "assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf",
    "respiratory_distress_neonates_stw.pdf": "assets/pdfs/respiratory_distress_neonates_stw.pdf",
    "retinopathy_of_prematurity_stw.pdf": "assets/pdfs/retinopathy_of_prematurity_stw.pdf",
    "Retinopathy of Prematurity (ROP).pdf": "assets/pdfs/Retinopathy of Prematurity (ROP).pdf",
}

with open("assets/regions/regions.json", "r", encoding="utf-8") as f:
    regions = json.load(f)

for doc_name, pdf_path in DOC_MAP.items():
    if not os.path.exists(pdf_path):
        continue
    doc = fitz.open(pdf_path)
    page = doc[0]
    pw, ph = page.rect.width, page.rect.height
    print(f"\n================ {doc_name} (pw={pw:.1f}, ph={ph:.1f}) ================")

    doc_regions = [r for r in regions if r.get("document") == doc_name]
    for r in doc_regions:
        rid = r["id"]
        hits = []
        for seg in r.get("segments", []):
            text = seg.get("text", "").strip()
            words = text.split()
            if len(words) >= 3:
                phrase = " ".join(words[:min(5, len(words))])
                h = page.search_for(phrase)
                if h:
                    hits.extend(h)
                else:
                    h = page.search_for(" ".join(words[:3]))
                    if h:
                        hits.extend(h)
        if not hits and r.get("section"):
            h = page.search_for(r["section"])
            if h:
                hits.extend(h)

        if hits:
            min_x = min(h.x0 for h in hits)
            min_y = min(h.y0 for h in hits)
            max_x = max(h.x1 for h in hits)
            max_y = max(h.y1 for h in hits)

            cur_y0 = r["y"] * ph
            cur_y1 = (r["y"] + r["h"]) * ph
            cur_x0 = r["x"] * pw
            cur_x1 = (r["x"] + r["w"]) * pw

            diff_y0 = cur_y0 - min_y
            diff_y1 = cur_y1 - max_y

            # Print if difference is significant (> 15 pt)
            if abs(diff_y0) > 15 or abs(diff_y1) > 20:
                print(f"Region: {rid:<32} cur: [y0={cur_y0:.1f}, y1={cur_y1:.1f}] text: [y0={min_y:.1f}, y1={max_y:.1f}] diff_y0={diff_y0:+.1f}, diff_y1={diff_y1:+.1f}")
