from PIL import Image

im = Image.open("assets/pages/KMC-13-10-2026.pdf/1.webp")
W, H = im.size

# Current kmc_dos in regions.json: x=0.00938, y=0.45549, w=0.46069, h=0.08918
old_crop = im.crop((
    int(0.00938 * W),
    int(0.45549 * H),
    int((0.00938 + 0.46069) * W),
    int((0.45549 + 0.08918) * H)
))
old_crop.save("tools/debug_out/crop_kmc_dos_OLD.png")

# Vector drawing for DOs: (0.0, 780.8, 420.7, 887.9) -> norm: x=0.008, y=0.4779, w=0.4910, h=0.0655
new_crop = im.crop((
    int(0.008 * W),
    int(0.4779 * H),
    int((0.008 + 0.4910) * W),
    int((0.4779 + 0.0655) * H)
))
new_crop.save("tools/debug_out/crop_kmc_dos_NEW.png")

print("DOs crops saved.")
