import fitz

doc = fitz.open("assets/pdfs/KMC-13-10-2026.pdf")
page = doc[0]
pw, ph = page.rect.width, page.rect.height

# Let's inspect all blocks on page 1
blocks = page.get_text("blocks")
print(f"Total blocks: {len(blocks)}")
for i, b in enumerate(blocks):
    text = b[4].strip()
    if "DON" in text or "initiate KMC" in text:
        print(f"\nBlock {i}:")
        print(f"Rect in pt: ({b[0]:.1f}, {b[1]:.1f}, {b[2]:.1f}, {b[3]:.1f})")
        print(f"Norm rect: x={b[0]/pw:.5f}, y={b[1]/ph:.5f}, w={(b[2]-b[0])/pw:.5f}, h={(b[3]-b[1])/ph:.5f}")
        print("Text snippet:", text[:100].replace('\n', ' '))
