#!/usr/bin/env python3
"""
tools/debug_bbox.py

Diagnostic tool for STW Neo PDF Viewer.
1. Renders each PDF page with PyMuPDF (pixmap).
2. Draws every chunk bbox from assets/stw_index/stw_index.json as a red rectangle.
3. Saves output PNGs to tools/debug_out/.
4. Inspects page geometry (rect, mediabox, cropbox, rotation) and compares bboxes with actual text/drawings.
5. Scans for dosage patterns (mg/kg, mcg/kg, mL/kg, etc.) across both PDFs.
"""

import os
import sys
import json
import re
import pymupdf

# Force UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDF_DIR = os.path.join(PROJECT_ROOT, "assets", "pdfs")
INDEX_PATH = os.path.join(PROJECT_ROOT, "assets", "stw_index", "stw_index.json")
OUT_DIR = os.path.join(PROJECT_ROOT, "tools", "debug_out")


def diagnose():
    os.makedirs(OUT_DIR, exist_ok=True)

    if not os.path.exists(INDEX_PATH):
        print(f"Error: Index file not found at {INDEX_PATH}")
        return

    with open(INDEX_PATH, "r", encoding="utf-8") as f:
        chunks = json.load(f)

    print(f"Loaded {len(chunks)} chunks from {INDEX_PATH}")

    # Group chunks by (document, page)
    doc_chunks = {}
    for c in chunks:
        key = (c["document"], c["page"])
        doc_chunks.setdefault(key, []).append(c)

    # 1. Render and draw bboxes on pages
    for (doc_name, page_num), p_chunks in sorted(doc_chunks.items()):
        pdf_path = os.path.join(PDF_DIR, doc_name)
        if not os.path.exists(pdf_path):
            print(f"Warning: PDF file not found: {pdf_path}")
            continue

        doc = pymupdf.open(pdf_path)
        page_index = page_num - 1
        if page_index < 0 or page_index >= len(doc):
            print(f"Warning: Page {page_num} out of range for {doc_name}")
            continue

        page = doc[page_index]
        pw = page.rect.width
        ph = page.rect.height

        print(f"\n=======================================================")
        print(f"Document: {doc_name} | Page {page_num}")
        print(f"  page.rect     : {page.rect}")
        print(f"  page.mediabox : {page.mediabox}")
        print(f"  page.cropbox  : {page.cropbox}")
        print(f"  page.rotation : {page.rotation}")
        print(f"  Dimensions    : {pw:.2f} x {ph:.2f} pt")
        print(f"  Chunks on page: {len(p_chunks)}")

        # Create a fresh copy to draw all bboxes
        doc_copy = pymupdf.open(pdf_path)
        page_copy = doc_copy[page_index]

        # Draw each chunk's bounding boxes
        for chunk in p_chunks:
            cid = chunk["chunk_id"]
            bboxes = chunk.get("bounding_boxes", [])
            for bi, b in enumerate(bboxes):
                # Un-normalize bbox (0..1) back to page points
                x0 = b["x"] * pw
                y0 = b["y"] * ph
                x1 = (b["x"] + b["width"]) * pw
                y1 = (b["y"] + b["height"]) * ph
                rect = pymupdf.Rect(x0, y0, x1, y1)

                # Draw red rectangle with border
                shape = page_copy.new_shape()
                shape.draw_rect(rect)
                shape.finish(color=(1, 0, 0), width=1.5)
                # Small label
                shape.insert_text(
                    pymupdf.Point(x0 + 2, max(y0 - 2, 10)),
                    f"{cid}:{bi}",
                    fontsize=6,
                    color=(0.8, 0, 0),
                )
                shape.commit()

        # Render full page to PNG at 1.5x resolution for clear visual inspection
        mat = pymupdf.Matrix(1.5, 1.5)
        pix = page_copy.get_pixmap(matrix=mat)
        safe_name = os.path.splitext(doc_name)[0]
        out_png = os.path.join(OUT_DIR, f"{safe_name}_page_{page_num}_all_bboxes.png")
        pix.save(out_png)
        print(f"  Saved full annotated page: {out_png} ({pix.width}x{pix.height} px)")
        doc_copy.close()

        # Also render individual crops for key evaluation chunks
        key_chunk_ids = [
            "rd_initial_preterm_cpap_caffeine",
            "rd_surfactant_indication",
            "rd_sas_scoring_guide",
            "rop_whom_to_screen",
            "rop_treatment_indications",
            "rop_related_information",
        ]
        for chunk in p_chunks:
            cid = chunk["chunk_id"]
            if cid in key_chunk_ids:
                doc_single = pymupdf.open(pdf_path)
                p_single = doc_single[page_index]
                bboxes = chunk.get("bounding_boxes", [])
                min_x, min_y, max_x, max_y = pw, ph, 0, 0
                for b in bboxes:
                    x0 = b["x"] * pw
                    y0 = b["y"] * ph
                    x1 = (b["x"] + b["width"]) * pw
                    y1 = (b["y"] + b["height"]) * ph
                    min_x = min(min_x, x0)
                    min_y = min(min_y, y0)
                    max_x = max(max_x, x1)
                    max_y = max(max_y, y1)
                    s = p_single.new_shape()
                    s.draw_rect(pymupdf.Rect(x0, y0, x1, y1))
                    s.finish(color=(1, 0, 0), width=2)
                    s.commit()

                # Add 40pt padding for visual context crop
                crop_rect = pymupdf.Rect(
                    max(0, min_x - 40),
                    max(0, min_y - 40),
                    min(pw, max_x + 40),
                    min(ph, max_y + 40),
                )
                pix_crop = p_single.get_pixmap(matrix=pymupdf.Matrix(2.0, 2.0), clip=crop_rect)
                crop_png = os.path.join(OUT_DIR, f"crop_{cid}.png")
                pix_crop.save(crop_png)
                print(f"  Saved key chunk crop: {crop_png} for {cid}")
                doc_single.close()

    # 2. Dosage pattern completeness scan across both PDFs
    print("\n=======================================================")
    print("DOSAGE COMPLETENESS CHECK (Scanning for dose units across STW PDFs)")
    print("=======================================================")
    dose_pattern = re.compile(
        r"(\d+(?:\.\d+)?\s*(?:mg|mcg|µg|ml|mL|iu|IU|units?|drops?)(?:/(?:kg|dose|day|hr|hour|min))?)",
        re.IGNORECASE,
    )

    findings = []
    for doc_info in [
        {"file": "respiratory_distress_neonates_stw.pdf", "title": "Respiratory Distress"},
        {"file": "retinopathy_of_prematurity_stw.pdf", "title": "Retinopathy of Prematurity"},
    ]:
        p_path = os.path.join(PDF_DIR, doc_info["file"])
        if not os.path.exists(p_path):
            continue
        pdf = pymupdf.open(p_path)
        for page_idx, page in enumerate(pdf):
            blocks = page.get_text("blocks")
            for b in blocks:
                text = b[4].strip()
                matches = dose_pattern.findall(text)
                if matches:
                    # Look for drug/clinical context
                    for line in text.split("\n"):
                        m_line = dose_pattern.findall(line)
                        if m_line:
                            findings.append({
                                "document": doc_info["file"],
                                "page": page_idx + 1,
                                "matched_dose": ", ".join(m_line),
                                "context": line.strip()[:100],
                            })
        pdf.close()

    if findings:
        print(f"Found {len(findings)} dose occurrences:")
        print(f"{'Document':<35} | {'Page':<4} | {'Dose Pattern':<20} | {'Context'}")
        print("-" * 100)
        for f in findings:
            print(f"{f['document']:<35} | {f['page']:<4} | {f['matched_dose']:<20} | {f['context']}")
    else:
        print("No dosage patterns (mg/kg, mcg/kg, mL/kg) found in documents.")


if __name__ == "__main__":
    diagnose()
