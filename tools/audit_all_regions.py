import fitz
import json

doc_kmc = fitz.open("assets/pdfs/KMC-13-10-2026.pdf")
page_kmc = doc_kmc[0]
pw_kmc, ph_kmc = page_kmc.rect.width, page_kmc.rect.height

doc_triage = fitz.open("assets/pdfs/Triage_13-10-26.pdf")
page_triage = doc_triage[0]
pw_triage, ph_triage = page_triage.rect.width, page_triage.rect.height

with open("assets/regions/regions.json", "r", encoding="utf-8") as f:
    regions = json.load(f)

print("=== CHECKING KMC REGIONS ===")
for r in regions:
    if r.get("document") == "KMC-13-10-2026.pdf":
        rx = r["x"] * pw_kmc
        ry = r["y"] * ph_kmc
        rw = r["w"] * pw_kmc
        rh = r["h"] * ph_kmc
        print(f"\nRegion: {r['id']} ({r['title']})")
        print(f"  Current norm: x={r['x']:.5f}, y={r['y']:.5f}, w={r['w']:.5f}, h={r['h']:.5f}")
        print(f"  Current pt:   x0={rx:.1f}, y0={ry:.1f}, x1={rx+rw:.1f}, y1={ry+rh:.1f}")

        # Find words within this region vs words containing its key phrases
        # Let's find words that match the segment text
        target_words = []
        for seg in r.get("segments", []):
            text = seg.get("text", "")
            first_words = " ".join(text.split()[:4])
            if first_words:
                target_words.append(first_words)
        print(f"  Target phrases: {target_words[:2]}")

print("\n=== CHECKING TRIAGE REGIONS ===")
for r in regions:
    if r.get("document") == "Triage_13-10-26.pdf":
        rx = r["x"] * pw_triage
        ry = r["y"] * ph_triage
        rw = r["w"] * pw_triage
        rh = r["h"] * ph_triage
        print(f"\nRegion: {r['id']} ({r['title']})")
        print(f"  Current norm: x={r['x']:.5f}, y={r['y']:.5f}, w={r['w']:.5f}, h={r['h']:.5f}")
        print(f"  Current pt:   x0={rx:.1f}, y0={ry:.1f}, x1={rx+rw:.1f}, y1={ry+rh:.1f}")
