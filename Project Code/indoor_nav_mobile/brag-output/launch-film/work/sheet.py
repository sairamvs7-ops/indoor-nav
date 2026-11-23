import sys
from pathlib import Path
from PIL import Image, ImageDraw
fs = sorted(Path(sys.argv[1]).glob("*.png"), key=lambda f: float(f.stem))
cols = 4
rows = (len(fs) + cols - 1) // cols
c = Image.new("RGB", (480 * cols, 270 * rows), "black"); d = ImageDraw.Draw(c)
for i, f in enumerate(fs):
    x, y = (i % cols) * 480, (i // cols) * 270
    c.paste(Image.open(f), (x, y)); d.text((x + 6, y + 4), f.stem + "s", fill=(255, 0, 0))
c.save(Path(sys.argv[1]) / "sheet.jpg")
