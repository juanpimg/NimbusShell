#!/usr/bin/env python3
"""Diff de la barra superior contra golden (regiones estables)."""
import sys
from PIL import Image, ImageChops

def region_diff(a, b, box):
    ca, cb = a.crop(box), b.crop(box)
    if ca.size != cb.size:
        return 1.0
    d = ImageChops.difference(ca, cb)
    px = list(d.getdata())
    total = sum(sum(p[:3]) for p in px)
    return total / (len(px) * 3 * 255)

gold = Image.open(sys.argv[1]).convert("RGB")
cur = Image.open(sys.argv[2]).convert("RGB")
h = min(gold.height, cur.height)
# Logo N (0..40) y status icons (1000..1180); app title y reloj se excluyen.
boxes = [(0, 0, 40, 24), (1000, 0, 1180, 24)]
worst = max(region_diff(gold, cur, b) for b in boxes)
print(f"golden_diff={worst:.4f} (limite 0.15)")
sys.exit(0 if worst < 0.15 else 1)
