import fitz

doc = fitz.open("assets/pdfs/KMC-13-10-2026.pdf")
page = doc[0]
pw, ph = page.rect.width, page.rect.height

# Check drawings (vector rects) around y=700 to 950
paths = page.get_drawings()
print(f"Total drawings: {len(paths)}")
for p in paths:
    r = p["rect"]
    if 740 <= r.y0 <= 850 or 740 <= r.y1 <= 950:
        print(f"Drawing rect: ({r.x0:.1f}, {r.y0:.1f}, {r.x1:.1f}, {r.y1:.1f}) norm: (x={r.x0/pw:.4f}, y={r.y0/ph:.4f}, w={(r.x1-r.x0)/pw:.4f}, h={(r.y1-r.y0)/ph:.4f}) fill={p.get('fill')} color={p.get('color')}")
