import fitz
import json

DOC_MAP = {
    'KMC-13-10-2026.pdf': 'assets/pdfs/KMC-13-10-2026.pdf',
    'Triage_13-10-26.pdf': 'assets/pdfs/Triage_13-10-26.pdf',
    'Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf': 'assets/pdfs/Antenatal_Corticosteroids_for_Preterm_Birth_8th_Oct.pdf',
    'Neonatal_Hypoglycemia_8th_Oct.pdf': 'assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf',
    'respiratory_distress_neonates_stw.pdf': 'assets/pdfs/respiratory_distress_neonates_stw.pdf',
    'retinopathy_of_prematurity_stw.pdf': 'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
}

with open('assets/regions/regions.json', 'r', encoding='utf-8') as f:
    regions = json.load(f)

for doc_name, pdf_path in DOC_MAP.items():
    doc = fitz.open(pdf_path)
    page = doc[0]
    pw, ph = page.rect.width, page.rect.height
    print(f"\n=== {doc_name} (pw={pw:.1f}, ph={ph:.1f}) ===")

    # Also collect drawings
    drawings = page.get_drawings()

    for r in regions:
        if r.get('document') != doc_name:
            continue
        rid = r['id']
        rx, ry, rw, rh = r['x']*pw, r['y']*ph, r['w']*pw, r['h']*ph

        # Check text
        first_text = ''
        for seg in r.get('segments', []):
            t = seg.get('text', '').strip()
            if t:
                first_text = t
                break

        words = first_text.split()
        hits = []
        if len(words) >= 3:
            hits = page.search_for(' '.join(words[:4])) or page.search_for(' '.join(words[:2]))
        elif len(words) >= 1:
            hits = page.search_for(words[0])

        header_hit = None
        if r.get('section'):
            hh = page.search_for(r['section'])
            if hh:
                header_hit = min(hh, key=lambda b: abs(b.y0 - ry))

        expected_y0 = header_hit.y0 if header_hit else (hits[0].y0 if hits else ry)
        dy = ry - expected_y0

        # Check matching drawing rectangle
        matching_drawings = []
        for d in drawings:
            dr = d['rect']
            if abs(dr.x0 - rx) < 30 and abs(dr.y0 - ry) < 50:
                matching_drawings.append(dr)

        if abs(dy) > 20:
            print(f"  {rid:<32}: cur y0={ry:.1f}, text y0={expected_y0:.1f}, diff={dy:+.1f} | norm cur_y={r['y']:.4f}, exp_y={expected_y0/ph:.4f}")
            if matching_drawings:
                md = matching_drawings[0]
                print(f"     -> Matched drawing: ({md.x0:.1f}, {md.y0:.1f}, {md.x1:.1f}, {md.y1:.1f}) norm=(x={md.x0/pw:.4f}, y={md.y0/ph:.4f}, w={(md.x1-md.x0)/pw:.4f}, h={(md.y1-md.y0)/ph:.4f})")
