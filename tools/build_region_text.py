#!/usr/bin/env python3
"""
tools/build_region_text.py

Extracts verbatim text for each curated region in assets/regions/regions.json:
1. Opens target PDF with PyMuPDF.
2. For each region, uses page.get_text("words", clip=rect), joins in reading order,
   and cleans bullet symbols / stray line breaks.
3. Saves cleaned verbatim text into regions.json as "text".
4. Flags any region with empty text.
5. Also renders high-resolution cropped images of each region to
   assets/regions/crops/<region_id>.webp for the Result Card display.
"""

import os
import sys
import json
import re
import pymupdf
from PIL import Image

# Force UTF-8 on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDF_DIR = os.path.join(PROJECT_ROOT, "assets", "pdfs")
REGIONS_DIR = os.path.join(PROJECT_ROOT, "assets", "regions")
REGIONS_JSON_PATH = os.path.join(REGIONS_DIR, "regions.json")
CROPS_DIR = os.path.join(REGIONS_DIR, "crops")


def clean_extracted_words(words):
    """
    words is a list of (x0, y0, x1, y1, word, block_no, line_no, word_no).
    Sorts in natural reading order and cleans text.
    """
    if not words:
        return ""

    # Sort by block_no, line_no, word_no
    words_sorted = sorted(words, key=lambda w: (w[5], w[6], w[7]))

    lines = []
    current_line = []
    current_line_key = None

    for w in words_sorted:
        line_key = (w[5], w[6])
        if current_line_key is None:
            current_line_key = line_key

        if line_key != current_line_key:
            if current_line:
                lines.append(" ".join(current_line))
            current_line = []
            current_line_key = line_key

        text = w[4].strip()
        # Clean stray bullet characters while keeping letters, digits, symbols
        text = text.replace("•", "").replace("", "").strip()
        if text:
            current_line.append(text)

    if current_line:
        lines.append(" ".join(current_line))

    # Join lines with clean line breaks
    full_text = "\n".join(lines).strip()
    # Normalize multiple consecutive blank lines
    full_text = re.sub(r"\n{3,}", "\n\n", full_text)
    return full_text


def hidden_text_rects(page):
    """Bounding boxes of text spans painted over by a later filled shape
    (e.g. superseded flowchart labels left under a box). Empty for most
    pages."""
    fills = [
        (d["seqno"], d["rect"])
        for d in page.get_drawings()
        if d.get("fill") is not None and (d.get("fill_opacity") or 1) > 0.5
    ]
    hidden = {}
    for tr in page.get_texttrace():
        box = pymupdf.Rect(tr["bbox"])
        if any(seq > tr["seqno"] and r.contains(box) for seq, r in fills):
            hidden[tr["seqno"]] = box
    return hidden


def visible_text(page, clip_rect, hidden_seqnos):
    """Region text built from the visible characters only (used on pages
    with hidden text). Lines are grouped by vertical overlap, read left to
    right."""
    chars = []
    for tr in page.get_texttrace():
        if tr["seqno"] in hidden_seqnos:
            continue
        for c in tr["chars"]:
            box = pymupdf.Rect(c[3])
            if box.is_empty or not clip_rect.contains(box):
                continue
            chars.append((box, chr(c[0])))
    chars.sort(key=lambda c: (c[0].y0 + c[0].y1) / 2)
    lines = []
    for box, ch in chars:
        mid = (box.y0 + box.y1) / 2
        for line in lines:
            if line["y0"] - 1 <= mid <= line["y1"] + 1:
                line["chars"].append((box, ch))
                break
        else:
            lines.append({"y0": box.y0, "y1": box.y1, "chars": [(box, ch)]})
    out = []
    for line in sorted(lines, key=lambda l: l["y0"]):
        text = "".join(ch for _, ch in sorted(line["chars"], key=lambda c: c[0].x0))
        text = text.replace("•", "").replace("", "")
        text = re.sub(r"\s+", " ", text).strip()
        if text:
            out.append(text)
    return "\n".join(out)


BULLETS = ("•", "◦", "▪", "", "")


def _is_header(text):
    """Box/section heading: all-caps words without numbers (e.g. 'DRUG & DOSE')."""
    letters = [c for c in text if c.isalpha()]
    return (
        bool(letters)
        and all(c.isupper() for c in letters)
        and not any(c.isdigit() for c in text)
        and len(text.split()) <= 6
    )


def build_segments(page, clip_rect, lines=None):
    """Logical answer units of a region, verbatim.

    A new segment starts at each bullet / numbered item; wrapped continuation
    lines are joined. Lines ending with ':' become the label of the bullets
    under them; '◦' sub-bullets take the preceding bullet as label. Box
    headings are kept with "header": true so they are never shown as answers.
    [lines] (plain strings) is used instead of the PDF line structure for
    regions with hidden text.
    """
    if lines is None:
        lines = []
        for b in page.get_text("dict", clip=clip_rect)["blocks"]:
            for l in b.get("lines", []):
                t = "".join(sp["text"] for sp in l["spans"])
                if t.strip():
                    lines.append(t)
    segments = []
    label = None
    parent = None
    for raw in lines:
        t = re.sub(r"\s+", " ", raw).strip()
        if not t:
            continue
        bullet = t[0] in BULLETS
        sub = t[0] == "◦"
        body = t.lstrip("".join(BULLETS)).strip()
        numbered = re.match(r"^\d+\.\s", body) is not None
        if _is_header(body):
            segments.append({"text": body, "header": True})
            label = None
            continue
        if body.endswith(":") and not bullet:
            segments.append({"text": body, "header": True})
            label = body
            continue
        cur = segments[-1] if segments else None
        starts_new = (
            bullet
            or numbered
            or cur is None
            or cur.get("header")
        )
        if starts_new:
            seg = {"text": body}
            if sub and parent:
                seg["label"] = parent
            elif label and not numbered:
                seg["label"] = label
            if numbered:
                label = body if body.endswith(":") else None
            if bullet and not sub:
                parent = body
            segments.append(seg)
        else:
            # Wrapped continuation of the current item.
            cur["text"] = (cur["text"] + " " + body).strip()
            if parent is not None and cur.get("label") is None:
                parent = cur["text"]
    return segments


OVERRIDES_PATH = os.path.join(PROJECT_ROOT, "tools", "region_segment_overrides.json")


def _words(text):
    return re.findall(r"[0-9A-Za-zÀ-￿]+", text.lower())


def check_override(rid, region_text, segments):
    """Overrides may only re-cut the region's own words: every word of every
    override segment must occur in the PDF text of the region."""
    available = {}
    for w in _words(region_text):
        available[w] = available.get(w, 0) + 1
    used = {}
    for s in segments:
        for w in _words(s["text"]) + _words(s.get("label", "")):
            used[w] = used.get(w, 0) + 1
    missing = sorted(w for w in used if w not in available)
    if missing:
        raise SystemExit(f"Override for {rid} uses words not in the PDF text: {missing}")


def split_abbreviations(text):
    """'BW: Birth Weight CRT: Capillary ...' -> one segment per abbreviation."""
    body = " ".join(l for l in text.split("\n") if l.strip() != "ABBREVIATIONS")
    body = re.sub(r"\s+", " ", body).strip()
    parts = re.split(r"\s(?=[A-Z][A-Za-z0-9₀-₉\-]*:\s)", body)
    return [{"text": p.strip()} for p in parts if p.strip()]


def build_region_data(only_documents=None):
    os.makedirs(REGIONS_DIR, exist_ok=True)
    os.makedirs(CROPS_DIR, exist_ok=True)

    if not os.path.exists(REGIONS_JSON_PATH):
        print(f"Error: {REGIONS_JSON_PATH} not found.")
        sys.exit(1)

    with open(REGIONS_JSON_PATH, "r", encoding="utf-8") as f:
        regions = json.load(f)

    print(f"Loaded {len(regions)} regions from {REGIONS_JSON_PATH}")

    # Group by document
    docs = {}
    for r in regions:
        doc_name = r["document"]
        if only_documents and doc_name not in only_documents:
            continue
        if doc_name not in docs:
            pdf_path = os.path.join(PDF_DIR, doc_name)
            if not os.path.exists(pdf_path):
                print(f"Warning: PDF {pdf_path} does not exist.")
                continue
            docs[doc_name] = pymupdf.open(pdf_path)

    empty_regions = []
    overrides = {}
    if os.path.exists(OVERRIDES_PATH):
        with open(OVERRIDES_PATH, "r", encoding="utf-8") as f:
            overrides = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    hidden_by_doc = {name: hidden_text_rects(d[0]) for name, d in docs.items()}

    for idx, r in enumerate(regions):
        doc_name = r["document"]
        page_num = r.get("page", 1)
        rid = r["id"]

        if only_documents and doc_name not in only_documents:
            continue
        if doc_name not in docs:
            print(f"Skipping {rid}: Document {doc_name} unavailable")
            continue

        doc = docs[doc_name]
        page = doc[page_num - 1]
        pw = page.rect.width
        ph = page.rect.height

        # Calculate clip rect in PDF points
        x0 = r["x"] * pw
        y0 = r["y"] * ph
        x1 = (r["x"] + r["w"]) * pw
        y1 = (r["y"] + r["h"]) * ph
        clip_rect = pymupdf.Rect(x0, y0, x1, y1)

        hidden = hidden_by_doc.get(doc_name) if page_num == 1 else None
        if hidden and any(clip_rect.intersects(b) for b in hidden.values()):
            # Skip text hidden under flowchart boxes (duplicate labels).
            cleaned_text = visible_text(page, clip_rect, hidden)
            r["segments"] = build_segments(
                page, clip_rect, lines=cleaned_text.split("\n")
            )
        else:
            # Extract words inside the region clip
            words = page.get_text("words", clip=clip_rect)
            cleaned_text = clean_extracted_words(words)
            r["segments"] = build_segments(page, clip_rect)
        r["text"] = cleaned_text
        if rid.endswith("_abbreviations"):
            r["segments"] = split_abbreviations(cleaned_text)
        if rid in overrides:
            check_override(rid, cleaned_text, overrides[rid])
            r["segments"] = overrides[rid]

        # Add crop image path for result card
        crop_filename = f"{rid}.webp"
        crop_path = os.path.join(CROPS_DIR, crop_filename)
        rel_crop_path = f"assets/regions/crops/{crop_filename}".replace("\\", "/")
        r["crop_image"] = rel_crop_path

        # Generate cropped image at 2.0x scale for crisp viewing on result card
        crop_mat = pymupdf.Matrix(2.0, 2.0)
        pix_crop = page.get_pixmap(matrix=crop_mat, clip=clip_rect)
        if pix_crop.width > 0 and pix_crop.height > 0:
            crop_img = Image.frombytes("RGB", [pix_crop.width, pix_crop.height], pix_crop.samples)
            crop_img.save(crop_path, format="WEBP", quality=90)

        if not cleaned_text:
            empty_regions.append(rid)
            print(f"  [FLAGGED EMPTY TEXT] Region #{idx+1}: {rid} ({r['title']})")
        else:
            word_count = len(cleaned_text.split())
            print(f"  [{idx+1}/{len(regions)}] {rid}: {word_count} words extracted -> {crop_path}")

    # Close open documents
    for doc in docs.values():
        doc.close()

    # Save updated regions.json
    with open(REGIONS_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(regions, f, indent=2, ensure_ascii=False)

    print(f"\nSaved updated text and crop references to {REGIONS_JSON_PATH}")
    if empty_regions:
        print(f"WARNING: {len(empty_regions)} regions had empty extracted text: {empty_regions}")
    else:
        print("SUCCESS: All regions have non-empty verbatim extracted text.")


if __name__ == "__main__":
    # Optional: document file names to (re)build; others are left as they are.
    build_region_data(only_documents=sys.argv[1:] or None)
