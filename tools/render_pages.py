#!/usr/bin/env python3
"""
tools/render_pages.py

Renders every page of assets/pdfs/*.pdf with PyMuPDF to
assets/pages/<doc>/<page>.webp at a fixed width of 1600 px.
Saves assets/pages/pages.json with {document, page, width, height}.
Original PDFs remain bundled in assets/pdfs/ for the Download / share button.
"""

import os
import sys
import json
import pymupdf
from PIL import Image

# Force UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDF_DIR = os.path.join(PROJECT_ROOT, "assets", "pdfs")
PAGES_DIR = os.path.join(PROJECT_ROOT, "assets", "pages")
PAGES_JSON_PATH = os.path.join(PAGES_DIR, "pages.json")

# Target canonical STW PDFs
TARGET_PDFS = [
    "respiratory_distress_neonates_stw.pdf",
    "retinopathy_of_prematurity_stw.pdf",
]


def render_all_pages(target_width=1600, only=None):
    """Renders every PDF, or only the file names in [only]; with [only],
    entries for other documents in pages.json are kept."""
    os.makedirs(PAGES_DIR, exist_ok=True)
    pages_meta = []
    if only and os.path.exists(PAGES_JSON_PATH):
        with open(PAGES_JSON_PATH, "r", encoding="utf-8") as f:
            pages_meta = [e for e in json.load(f) if e["document"] not in only]

    for filename in sorted(os.listdir(PDF_DIR)):
        if not filename.lower().endswith(".pdf"):
            continue
        if only and filename not in only:
            continue

        # Focus primarily on the two canonical ICMR STW documents
        # (while supporting any valid PDF in the folder)
        pdf_path = os.path.join(PDF_DIR, filename)
        doc = pymupdf.open(pdf_path)
        print(f"\nProcessing {filename} ({len(doc)} pages)...")

        # Create output directory for doc
        doc_out_dir = os.path.join(PAGES_DIR, filename)
        os.makedirs(doc_out_dir, exist_ok=True)

        for page_idx in range(len(doc)):
            page_num = page_idx + 1
            page = doc[page_idx]

            # Calculate zoom scale for fixed 1600 px width
            pw_pt = page.rect.width
            ph_pt = page.rect.height
            scale = target_width / pw_pt
            matrix = pymupdf.Matrix(scale, scale)

            pix = page.get_pixmap(matrix=matrix)
            rendered_w = pix.width
            rendered_h = pix.height

            # Convert to WebP using Pillow
            img = Image.frombytes("RGB", [rendered_w, rendered_h], pix.samples)
            webp_name = f"{page_num}.webp"
            webp_path = os.path.join(doc_out_dir, webp_name)
            img.save(webp_path, format="WEBP", quality=90)

            rel_img_path = f"assets/pages/{filename}/{webp_name}".replace("\\", "/")
            print(f"  Page {page_num}: {rendered_w}x{rendered_h} px -> {webp_path}")

            entry = {
                "document": filename,
                "page": page_num,
                "width": rendered_w,
                "height": rendered_h,
                "pt_width": round(pw_pt, 2),
                "pt_height": round(ph_pt, 2),
                "image_path": rel_img_path,
            }
            pages_meta.append(entry)

        doc.close()

    # Save pages.json
    with open(PAGES_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(pages_meta, f, indent=2, ensure_ascii=False)

    print(f"\nSuccessfully rendered {len(pages_meta)} pages to {PAGES_DIR}")
    print(f"Saved metadata to {PAGES_JSON_PATH}")


if __name__ == "__main__":
    # Optional: file names in assets/pdfs to render (default: all).
    render_all_pages(target_width=1600, only=sys.argv[1:] or None)
