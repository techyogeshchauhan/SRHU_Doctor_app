import json
import os
import pymupdf
from PIL import Image

REGIONS_PATH = "assets/regions/regions.json"
STW_INDEX_PATH = "assets/stw_index/stw_index.json"
CROPS_DIR = "assets/regions/crops"

# 1. Update regions.json
with open(REGIONS_PATH, "r", encoding="utf-8") as f:
    regions = json.load(f)

for r in regions:
    rid = r["id"]
    if rid == "kmc_donts":
        r["x"] = 0.5057
        r["y"] = 0.4782
        r["w"] = 0.4850
        r["h"] = 0.0653
    elif rid == "kmc_dos":
        r["x"] = 0.0080
        r["y"] = 0.4779
        r["w"] = 0.4910
        r["h"] = 0.0655
    elif rid == "kmc_followup":
        r["h"] = 0.0846
        # Clean segments
        for seg in r.get("segments", []):
            if "DON’Ts" in seg.get("text", "") or "DON'Ts" in seg.get("text", ""):
                seg["text"] = seg["text"].replace(" DON’Ts", "").replace(" DON'Ts", "").strip()
        if "DON’Ts" in r.get("text", "") or "DON'Ts" in r.get("text", ""):
            r["text"] = r["text"].replace("\nDON’Ts", "").replace("\nDON'Ts", "").strip()
    elif rid == "hypo_dos":
        r["x"] = 0.0100
        r["y"] = 0.7631
        r["w"] = 0.4450
        r["h"] = 0.0465
    elif rid == "hypo_donts":
        r["x"] = 0.4701
        r["y"] = 0.7631
        r["w"] = 0.5150
        r["h"] = 0.0465
    elif rid == "hypo_kpis":
        r["x"] = 0.0150
        r["y"] = 0.8107
        r["w"] = 0.9650
        r["h"] = 0.0565

with open(REGIONS_PATH, "w", encoding="utf-8") as f:
    json.dump(regions, f, indent=2, ensure_ascii=False)
print("Updated regions.json successfully.")

# 2. Update stw_index.json
with open(STW_INDEX_PATH, "r", encoding="utf-8") as f:
    index = json.load(f)

for item in index:
    iid = item.get("chunk_id") or item.get("id")
    if iid == "kmc_donts":
        item["x"] = 0.5057
        item["y"] = 0.4782
        item["w"] = 0.4850
        item["h"] = 0.0653
    elif iid == "kmc_dos":
        item["x"] = 0.0080
        item["y"] = 0.4779
        item["w"] = 0.4910
        item["h"] = 0.0655
    elif iid == "kmc_followup":
        item["h"] = 0.0850
        for seg in item.get("segments", []):
            if "DON’Ts" in seg.get("text", "") or "DON'Ts" in seg.get("text", ""):
                seg["text"] = seg["text"].replace(" DON’Ts", "").replace(" DON'Ts", "").strip()
        if "DON’Ts" in item.get("text", "") or "DON'Ts" in item.get("text", ""):
            item["text"] = item["text"].replace("\nDON’Ts", "").replace("\nDON'Ts", "").strip()

with open(STW_INDEX_PATH, "w", encoding="utf-8") as f:
    json.dump(index, f, indent=2, ensure_ascii=False)
print("Updated stw_index.json successfully.")

# 3. Regenerate WebP crops for the updated regions
TARGET_CROPS = {
    "kmc_donts": "assets/pdfs/KMC-13-10-2026.pdf",
    "kmc_dos": "assets/pdfs/KMC-13-10-2026.pdf",
    "kmc_followup": "assets/pdfs/KMC-13-10-2026.pdf",
    "hypo_dos": "assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf",
    "hypo_donts": "assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf",
    "hypo_kpis": "assets/pdfs/Neonatal_Hypoglycemia_8th_Oct.pdf",
}

for r in regions:
    rid = r["id"]
    if rid in TARGET_CROPS:
        pdf_path = TARGET_CROPS[rid]
        doc = pymupdf.open(pdf_path)
        page = doc[r.get("page", 1) - 1]
        pw, ph = page.rect.width, page.rect.height

        x0 = r["x"] * pw
        y0 = r["y"] * ph
        x1 = (r["x"] + r["w"]) * pw
        y1 = (r["y"] + r["h"]) * ph
        clip_rect = pymupdf.Rect(x0, y0, x1, y1)

        crop_mat = pymupdf.Matrix(2.0, 2.0)
        pix = page.get_pixmap(matrix=crop_mat, clip=clip_rect)
        if pix.width > 0 and pix.height > 0:
            crop_path = os.path.join(CROPS_DIR, f"{rid}.webp")
            img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
            img.save(crop_path, format="WEBP", quality=90)
            print(f"Regenerated crop: {crop_path} ({pix.width}x{pix.height})")
        doc.close()
