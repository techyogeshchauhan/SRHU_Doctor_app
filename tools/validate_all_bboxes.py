import fitz
import json
import os

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

print(f"Total regions in regions.json: {len(regions)}")

discrepancies = []

for r in regions:
    doc_name = r.get("document")
    pdf_path = DOC_MAP.get(doc_name)
    if not pdf_path or not os.path.exists(pdf_path):
        continue

    doc = fitz.open(pdf_path)
    page_num = r.get("page", 1) - 1
    if page_num >= len(doc):
        continue
    page = doc[page_num]
    pw, ph = page.rect.width, page.rect.height

    # Target text
    text_content = r.get("text", "")
    segments = [s.get("text", "") for s in r.get("segments", []) if s.get("text")]

    # Search for occurrences of key phrases in the PDF page
    rects = []
    # Try searching for title / section
    title = r.get("title", "")
    section = r.get("section", "")

    # Search segment phrases
    matched_search_rects = []
    for phrase in segments[:6]:
        # Search for first 3-6 words
        words = phrase.strip().split()
        if not words:
            continue
        search_term = " ".join(words[:min(5, len(words))])
        # clean term
        search_term = search_term.replace("\n", " ").strip()
        if len(search_term) < 4:
            continue
        hits = page.search_for(search_term)
        if hits:
            matched_search_rects.extend(hits)
        else:
            # fallback: search individual distinctive words
            for w in words:
                if len(w) > 6:
                    w_hits = page.search_for(w)
                    if w_hits:
                        matched_search_rects.extend(w_hits)
                        break

    if not matched_search_rects and title:
        hits = page.search_for(title)
        if hits:
            matched_search_rects.extend(hits)

    if matched_search_rects:
        min_x = min(hit.x0 for hit in matched_search_rects)
        min_y = min(hit.y0 for hit in matched_search_rects)
        max_x = max(hit.x1 for hit in matched_search_rects)
        max_y = max(hit.y1 for hit in matched_search_rects)

        # Normalized text bounding box
        text_nx = min_x / pw
        text_ny = min_y / ph
        text_nw = (max_x - min_x) / pw
        text_nh = (max_y - min_y) / ph

        cur_x = r["x"]
        cur_y = r["y"]
        cur_w = r["w"]
        cur_h = r["h"]

        # Check if current box differs significantly from actual text
        y_diff_top = cur_y - text_ny
        y_diff_bottom = (cur_y + cur_h) - (text_ny + text_nh)

        # If top of box starts > 2% of page above text or below text
        if abs(y_diff_top) > 0.015 or abs(y_diff_bottom) > 0.02:
            discrepancies.append({
                "id": r["id"],
                "doc": doc_name,
                "title": r["title"],
                "cur": (round(cur_x, 4), round(cur_y, 4), round(cur_w, 4), round(cur_h, 4)),
                "text_bound": (round(text_nx, 4), round(text_ny, 4), round(text_nw, 4), round(text_nh, 4)),
                "y_diff_top": round(y_diff_top, 4),
            })

print(f"\nFound {len(discrepancies)} regions with significant vertical offset:")
for d in discrepancies:
    print(f"- {d['id']} ({d['title']}) [{d['doc']}]:")
    print(f"    Current:    x={d['cur'][0]}, y={d['cur'][1]}, w={d['cur'][2]}, h={d['cur'][3]}")
    print(f"    Text bbox:  x={d['text_bound'][0]}, y={d['text_bound'][1]}, w={d['text_bound'][2]}, h={d['text_bound'][3]}")
    print(f"    y_diff_top: {d['y_diff_top']}")
