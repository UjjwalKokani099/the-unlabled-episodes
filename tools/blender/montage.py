"""Joins preview frames side by side: python3 tools/blender/montage.py out.png a.png b.png ..."""
import sys
from PIL import Image
ims = [Image.open(p) for p in sys.argv[2:]]
out = Image.new("RGB", (sum(i.width for i in ims), max(i.height for i in ims)))
x = 0
for i in ims:
    out.paste(i, (x, 0))
    x += i.width
out.save(sys.argv[1])
