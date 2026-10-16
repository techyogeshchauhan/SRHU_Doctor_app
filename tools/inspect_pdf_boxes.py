import json

try:
    import fitz
    has_fitz = True
except ImportError:
    has_fitz = False

print("has_fitz:", has_fitz)

if has_fitz:
    doc = fitz.open("assets/pdfs/KMC-13-10-2026.pdf")
    page = doc[0]
    print("Page rect:", page.rect)
    words = page.get_text("words")
    for w in words:
        if any(term in w[4] for term in ["DON", "spontaneously", "resuscitation", "alternate"]):
            print(f"Word: {w[4]} -> ({w[0]:.1f}, {w[1]:.1f}, {w[2]:.1f}, {w[3]:.1f}) norm_y: {w[1]/page.rect.height:.4f}")
