from PIL import Image

im = Image.open("assets/pages/KMC-13-10-2026.pdf/1.webp")
W, H = im.size

# Current kmc_donts in regions.json: x=0.50984, y=0.45549, w=0.48401, h=0.08734
old_crop = im.crop((
    int(0.50984 * W),
    int(0.45549 * H),
    int((0.50984 + 0.48401) * W),
    int((0.45549 + 0.08734) * H)
))
old_crop.save("tools/debug_out/crop_kmc_donts_OLD.png")

# Proposed new kmc_donts: x=0.5057, y=0.4782, w=0.4850, h=0.0653
new_crop = im.crop((
    int(0.5057 * W),
    int(0.4782 * H),
    int((0.5057 + 0.4850) * W),
    int((0.4782 + 0.0653) * H)
))
new_crop.save("tools/debug_out/crop_kmc_donts_NEW.png")

print(f"Old crop saved: {old_crop.size}")
print(f"New crop saved: {new_crop.size}")
