#!/usr/bin/env python3
"""Diff de la barra superior contra golden (regiones estables)."""
import sys
from PIL import Image, ImageChops

def region_diff(a, b, box):
    ca, cb = a.crop(box), b.crop(box)
    if ca.size != cb.size:
        return 1.0
    d = ImageChops.difference(ca, cb)
    raw = d.tobytes()
    return sum(raw) / (len(raw) * 255)

if len(sys.argv) < 3:
    print("Uso: topbar-golden.py <golden.png> <actual.png>", file=sys.stderr)
    sys.exit(2)

gold = Image.open(sys.argv[1]).convert("RGB")
cur = Image.open(sys.argv[2]).convert("RGB")
# Si el golden es un recorte de la barra (h=24), box y<=24; si cur es dual monitor, Virtual-1 es 0..1280.
boxes = [(0, 0, 40, 24), (1000, 0, 1180, 24)]
worst = max(region_diff(gold, cur, b) for b in boxes)
print(f"golden_diff={worst:.4f} (limite 0.15)")
sys.exit(0 if worst < 0.15 else 1)
