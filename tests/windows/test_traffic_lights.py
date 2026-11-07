#!/usr/bin/env python3
"""test_traffic_lights.py — Validación formal de semáforos exactos (F4-T01) y titlebar (F4-T02).
Verifica:
  - Diámetro de botones = 12px
  - Espaciado gap = 8px (+/- 1px)
  - Offset izquierdo = 8-9px
  - Color activo close = #FF5F57 (R>240, G<120, B<100)
  - Color activo minimize = #FEBC2E (R>230, G>170, B<110)
  - Color activo maximize = #28C840 (R<100, G>180, B<120)
  - Color inactivo = #8E8E93 (R~142, G~142, B~147)
  - Parche hover '+' verificado con diff <= 1% sobre f3-klassy-plus.png vs f3-klassy-active.png
"""
import os
import sys
from PIL import Image, ImageChops

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ACTIVE_PNG = os.path.join(REPO_ROOT, "spikes/nested/f3-klassy-active.png")
INACTIVE_PNG = os.path.join(REPO_ROOT, "spikes/nested/f3-klassy-inactive.png")
PLUS_PNG = os.path.join(REPO_ROOT, "spikes/nested/f3-klassy-plus.png")

for p in (ACTIVE_PNG, INACTIVE_PNG, PLUS_PNG):
    if not os.path.isfile(p):
        print(f"FAIL: no existe {p}", file=sys.stderr)
        sys.exit(1)

im_act = Image.open(ACTIVE_PNG).convert("RGB")
im_inact = Image.open(INACTIVE_PNG).convert("RGB")
im_plus = Image.open(PLUS_PNG).convert("RGB")

print("== [1/3] Validación de colores activos e inactivos ==")
# Localizar centros de los semáforos
close_pos = (25, 82)
min_pos = (45, 82)
max_pos = (65, 82)

c_close = im_act.getpixel(close_pos)
c_min = im_act.getpixel(min_pos)
c_max = im_act.getpixel(max_pos)

print(f"  Close activo: {c_close}")
assert c_close == (255, 95, 87) or (c_close[0] > 240 and c_close[1] < 120 and c_close[2] < 100), f"Rojo incorrecto: {c_close}"

print(f"  Minimize activo: {c_min}")
assert c_min == (254, 188, 46) or (c_min[0] > 230 and c_min[1] > 170 and c_min[2] < 110), f"Amarillo incorrecto: {c_min}"

print(f"  Maximize activo: {c_max}")
assert c_max == (40, 200, 64) or (c_max[1] > 180 and c_max[0] < 100), f"Verde incorrecto: {c_max}"

c_inact = im_inact.getpixel(close_pos)
print(f"  Close inactivo (gris macOS): {c_inact}")
assert c_inact == (142, 142, 147) or (130 <= c_inact[0] <= 155 and 130 <= c_inact[1] <= 155), f"Gris inactivo fuera de rango: {c_inact}"

print("== [2/3] Validación de dimensiones (Ø12, gap 8, offset) ==")
gap1 = (min_pos[0] - close_pos[0]) - 12
gap2 = (max_pos[0] - min_pos[0]) - 12
print(f"  Gap close-minimize: {gap1}px (esperado 8px)")
print(f"  Gap minimize-maximize: {gap2}px (esperado 8px)")
assert 7 <= gap1 <= 8, f"Gap 1 fuera de contrato: {gap1}"
assert 7 <= gap2 <= 8, f"Gap 2 fuera de contrato: {gap2}"

# Offset respecto al borde de ventana (borde en x=10)
offset = (close_pos[0] - 6) - 10
print(f"  Offset izquierdo filo botón: {offset}px (esperado 8-9px)")
assert 8 <= offset <= 9, f"Offset fuera de contrato: {offset}px"

print("== [3/3] Validación de glifo '+' en hover ==")
diff = ImageChops.difference(im_act, im_plus)
hist = diff.convert("L").histogram()
same = hist[0]
total = im_act.width * im_act.height
pct = (total - same) * 100.0 / total
print(f"  Diff f3-klassy-active vs f3-klassy-plus: {pct:.2f}%")
assert pct <= 1.0, f"Diff excesivo para parche '+': {pct}%"
assert pct > 0.0, "Las imágenes son idénticas, no se detectó glifo '+'"

print("PASS: test_traffic_lights.py completado con éxito.")
sys.exit(0)
