#!/usr/bin/env python3
"""Attach PDF source coordinates to answer segments and sync curated assets.

Run without arguments to audit; --write updates both catalogs and 2x crops.
PDF text matching is restricted to the curated region's vicinity. Unmatched
segments fail the build instead of guessing a rectangle on another card.
"""

import argparse
import copy
import difflib
import json
from pathlib import Path
import re
import unicodedata

import pymupdf
from PIL import Image

from build_region_text import hidden_text_rects

ROOT = Path(__file__).resolve().parents[1]
REGIONS = ROOT / "assets/regions/regions.json"
INDEX = ROOT / "assets/stw_index/stw_index.json"


def tokens(text):
    text = unicodedata.normalize("NFKC", text).lower()
    text = text.replace("’", "").replace("'", "")
    return re.findall(r"[a-z]+|[0-9]|[<>=]", text)


def box(region, page):
    return pymupdf.Rect(
        region["x"] * page.rect.width,
        region["y"] * page.rect.height,
        (region["x"] + region["w"]) * page.rect.width,
        (region["y"] + region["h"]) * page.rect.height,
    )


def normalized(rect, page):
    return dict(zip(("x", "y", "width", "height"), (
        round(rect.x0 / page.rect.width, 6),
        round(rect.y0 / page.rect.height, 6),
        round(rect.width / page.rect.width, 6),
        round(rect.height / page.rect.height, 6),
    )))


def compact_rects(rects):
    """Wrap consecutive lines of one sentence, never a gap / adjacent card."""
    out = []
    for rect in sorted(rects, key=lambda r: (r.y0, r.x0)):
        if out:
            prev = out[-1]
            overlap = min(prev.x1, rect.x1) - max(prev.x0, rect.x0)
            if (rect.y0 <= prev.y1 + min(prev.height, rect.height) * 0.65
                    and overlap >= min(prev.width, rect.width) * 0.5):
                out[-1] |= rect
                continue
        out.append(pymupdf.Rect(rect))
    return out


def source_words(page):
    hidden = hidden_text_rects(page)
    words = []
    pending = []

    def flush():
        if not pending:
            return
        rect = pymupdf.Rect(pending[0][1])
        for _, other in pending[1:]:
            rect |= other
        for token in tokens("".join(c for c, _ in pending)):
            words.append((token, rect, round(rect.y0, 1)))
        pending.clear()

    # get_text("words") includes superseded labels underneath newer cards.
    # Filter by drawing sequence, not by position: visible replacement text
    # often occupies exactly the same rectangle as the hidden original.
    for trace in page.get_texttrace():
        if trace["seqno"] in hidden:
            continue
        for char in trace["chars"]:
            ch, rect = chr(char[0]), pymupdf.Rect(char[3])
            if pending:
                prev = pending[-1][1]
                if (abs(rect.y0 - prev.y0) > max(rect.height, prev.height) * 0.7
                        or rect.x0 < prev.x0 - 1 or rect.x0 > prev.x1 + 2):
                    flush()
            if ch.isspace():
                flush()
            else:
                pending.append((ch, rect))
    flush()
    return words


def locate(text, words, seed):
    """Find verbatim runs, allowing PDF column/line ordering to split a unit."""
    query = tokens(text)
    # A small expansion finds clipped final lines, but excludes distant cards.
    vicinity = seed + (-16, -32, 16, 32)
    local = [w for w in words if vicinity.intersects(w[1])]
    source = [w[0] for w in local]
    exact = [i for i in range(len(source) - len(query) + 1)
             if source[i:i + len(query)] == query]
    if exact:
        start = min(exact, key=lambda i: abs(local[i][1].y0 - seed.y0))
        found = local[start:start + len(query)]
        coverage = 1
    else:
        # Formula labels / numerators / denominators are sometimes stored in
        # separate PDF text streams, in a different order from reading order.
        # Match each remaining verbatim run independently, never fuzzy words.
        blocks = []
        remaining = [(0, len(query))]
        while remaining:
            m = difflib.SequenceMatcher(None, query, source, autojunk=False)
            candidates = [(m.find_longest_match(start, end, 0, len(source)), start, end)
                          for start, end in remaining]
            b, start, end = max(candidates, key=lambda c: c[0].size)
            remaining.remove((start, end))
            if not b.size:
                continue
            run = query[b.a:b.a + b.size]
            occurrences = [i for i in range(len(source) - len(run) + 1)
                           if source[i:i + len(run)] == run]
            anchor = (sum(local[v.b][1].y0 for v in blocks) / len(blocks)
                      if blocks else (seed.y0 + seed.y1) / 2)
            chosen = min(occurrences, key=lambda i: abs(local[i][1].y0 - anchor))
            b = difflib.Match(b.a, chosen, b.size)
            blocks.append(b)
            if start < b.a:
                remaining.append((start, b.a))
            if b.a + b.size < end:
                remaining.append((b.a + b.size, end))
        found = [local[i] for b in blocks for i in range(b.b, b.b + b.size)]
        coverage = sum(b.size for b in blocks) / max(1, len(query))
    if coverage < 1 or not found:
        return [], coverage
    # Each PDF line is independent: never enclose an adjacent table column
    # or the empty gap between two flowchart cards in a single rectangle.
    lines = {}
    for _, rect, line in found:
        if line in lines:
            lines[line] |= rect
        else:
            lines[line] = pymupdf.Rect(rect)
    return compact_rects(lines.values()), coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    regions = json.loads(REGIONS.read_text(encoding="utf-8"))
    original = copy.deepcopy(regions)
    overrides = json.loads((ROOT / "tools/pdf_evidence_overrides.json").read_text(encoding="utf-8"))
    documents = {}
    failures = []
    for region in regions:
        key = (region["document"], region["page"])
        if key not in documents:
            doc = pymupdf.open(ROOT / "assets/pdfs" / region["document"])
            page = doc[region["page"] - 1]
            documents[key] = (doc, page, source_words(page))
        _, page, words = documents[key]
        seed = box(region, page)
        override = overrides.get(region["id"], {})
        content = []
        for n, segment in enumerate(region.get("segments", [])):
            if "highlight_points" in override:
                points = override["highlight_points"][:1] if segment.get("header") else override["highlight_points"][1:]
                rects, coverage = [pymupdf.Rect(p) for p in points], 1
            elif "segments_points" in override:
                rects, coverage = [pymupdf.Rect(override["segments_points"][n])], 1
            elif override.get("whole_illustration"):
                rects, coverage = [pymupdf.Rect(override["region_points"])], 1
            else:
                text = segment["text"]
                if region["id"] == "triage_donts" and text == "DON Ts":
                    text = "DON'Ts"
                rects, coverage = locate(text, words, seed)
            if not rects:
                failures.append((region["id"], round(coverage, 3), segment["text"]))
            else:
                segment["bounding_boxes"] = [normalized(r, page) for r in rects]
                content.extend(rects)
            if segment.get("label"):
                labels, _ = locate(segment["label"], words, seed)
                if labels:
                    segment["label_bounding_boxes"] = [normalized(r, page) for r in labels]
                    content.extend(labels)
        # Include the actual section heading, even if it is not an answer unit.
        heading = None
        if region["id"].endswith("_kpis"):
            heading = "KEY PERFORMANCE INDICATORS"
        elif region["id"].endswith("_abbreviations"):
            heading = "ABBREVIATIONS"
        elif region["id"] == "kmc_continue_while_on":
            heading = "CONTINUE KMC WHILE ON"
        elif region["id"] in ("kmc_dos", "kmc_donts"):
            heading = "DO’s" if region["id"] == "kmc_dos" else "DON’Ts"
        if heading:
            hits = [r for r in page.search_for(heading)
                    if (seed + (-8, -32, 8, 32)).intersects(r)]
            content.extend(hits)
        if "region_points" in override:
            tight = pymupdf.Rect(override["region_points"])
        elif content:
            tight = pymupdf.Rect(content[0])
            for rect in content[1:]:
                tight |= rect
            tight = (tight + (-0.75, -0.75, 0.75, 0.75)) & page.rect
        else:
            tight = seed
        nb = normalized(tight, page)
        region.update(x=nb["x"], y=nb["y"], w=nb["width"], h=nb["height"])
        region["pw"] = round(page.rect.width, 2)
        region["ph"] = round(page.rect.height, 2)
        if "highlight_points" in override:
            region["bounding_boxes"] = [normalized(pymupdf.Rect(p), page)
                                        for p in override["highlight_points"]]
        if "preview_points" in override:
            region["preview_bounds"] = normalized(pymupdf.Rect(override["preview_points"]), page)
    for failure in failures:
        print(failure)
    print(f"{len(regions)} regions; {len(failures)} unmatched segments")
    if failures:
        raise SystemExit("No assets written: resolve unmatched PDF evidence first.")
    index = []
    for region in regions:
        item = copy.deepcopy(region)
        item["chunk_id"] = region["id"]
        item["section_title"] = region["title"]
        item["bounding_boxes"] = region.get("bounding_boxes") or [{
            "x": region["x"], "y": region["y"],
            "width": region["w"], "height": region["h"],
        }]
        index.append(item)
    if args.write:
        for region in regions:
            _, page, _ = documents[(region["document"], region["page"])]
            preview = region.get("preview_bounds")
            clip = box(dict(x=preview["x"], y=preview["y"], w=preview["width"], h=preview["height"]), page) if preview else box(region, page)
            pix = page.get_pixmap(matrix=pymupdf.Matrix(2, 2), clip=clip)
            Image.frombytes("RGB", (pix.width, pix.height), pix.samples).save(
                ROOT / region["crop_image"], format="WEBP", quality=90)
        for path, data in ((REGIONS, regions), (INDEX, index)):
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    else:
        if regions != original:
            raise SystemExit("Region evidence is stale. Run with --write.")
        if index != json.loads(INDEX.read_text(encoding="utf-8")):
            raise SystemExit("Fallback index is stale. Run with --write.")
        for region in regions:
            _, page, _ = documents[(region["document"], region["page"])]
            preview = region.get("preview_bounds")
            clip = box(dict(x=preview["x"], y=preview["y"], w=preview["width"], h=preview["height"]), page) if preview else box(region, page)
            expected = (clip * pymupdf.Matrix(2, 2)).irect
            with Image.open(ROOT / region["crop_image"]) as image:
                if image.size != (expected.width, expected.height):
                    raise SystemExit(f"{region['id']}: crop does not match 2x source bounds")
        print("Both catalogs and all 2x crops are synchronized.")
    for doc, _, _ in documents.values():
        doc.close()


if __name__ == "__main__":
    main()
