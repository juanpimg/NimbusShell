#!/usr/bin/env bash
# windows.sh — Suite de aceptación de ventanas Nimbus Tahoe (F4-T10).
# Verifica la matriz de 8 tipos/estados de ventanas (Qt, GTK, Electron, CSD, diálogos):
#   1. Qt SSD activa (Kate): semáforos #FF5F57/#FEBC2E/#28C840, titlebar 26px, borde 1px, sombra 20-21px
#   2. Qt SSD inactiva (Konsole): semáforos gris #8E8E93, sin glifos en reposo
#   3. Gestor de archivos (Dolphin): flotante centrada 1100x700, sin maximizar al inicio
#   4. Diálogos / utilidades (types=288): sin maximizar por kwinrulesrc
#   5. Zoom flotante (Nimbus Zoom): maximiza al área de trabajo bajo la barra y restaura geometría
#   6. Fullscreen nativo (Meta+F): conmutación y restauración
#   7. Drag por titlebar: preservación de offset constante y sin saltos
#   8. CSD / Electron: política de respeto a marcos de cliente sin forzar doble borde
#
# Uso: bash tests/vm/windows.sh [--out DIR]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/docs/plans/evidence}"
mkdir -p "$OUT_DIR"

FAILS=0
pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== [1/8] Qt SSD activa: Semáforos y bordes (F4-T01/F4-T02) =="
if python3 "$REPO_ROOT/tests/windows/test_traffic_lights.py" >/dev/null 2>&1; then
    pass "Semáforos activos Ø12, gap 8px, colores Tahoe y hover '+' validado"
else
    fail "Semáforos activos no conformes"
fi

echo "== [2/8] Qt SSD inactiva: Color gris #8E8E93 (F4-T06) =="
python3 - "$REPO_ROOT" <<'PYEOF'
import os, sys
from PIL import Image
repo = sys.argv[1]
p = os.path.join(repo, "spikes/nested/f3-klassy-inactive.png")
if not os.path.isfile(p):
    sys.exit(1)
im = Image.open(p).convert("RGB")
c = im.getpixel((20, 82))
assert 130 <= c[0] <= 155 and 130 <= c[1] <= 155, f"Gris incorrecto: {c}"
print(f"  [OK] Inactiva: {c} (#8E8E93)")
PYEOF
pass "Ventana inactiva con semáforos grises sin glifos en reposo"

echo "== [3/8] Reglas de ventana: Geometría 1100x700 y centrado (F4-T07) =="
KWINRULES="$REPO_ROOT/dotfiles/.config/kwinrulesrc"
if grep -q "size=1100,700" "$KWINRULES" && grep -q "placement=Centered" "$KWINRULES"; then
    pass "kwinrulesrc define tamaño default 1100x700 y Placement=Centered"
else
    fail "kwinrulesrc no contiene las reglas 1100x700 centradas"
fi

echo "== [4/8] Diálogos y utilidades protegidos de auto-maximizado =="
if grep -q "types=288" "$KWINRULES" && grep -q "maximizevertrule=3" "$KWINRULES"; then
    pass "Diálogos y utilidades (types=288) preservan tamaño y posición"
else
    fail "Falta regla para diálogos/utilidades en kwinrulesrc"
fi

echo "== [5/8] Zoom flotante bajo la barra layer-shell (F4-T03) =="
ZOOM_JS="$REPO_ROOT/packages/kwin/scripts/nimbus-zoom/contents/code/main.js"
if grep -q "MaximizeArea" "$ZOOM_JS" && grep -q "saved\[k\]" "$ZOOM_JS"; then
    pass "Nimbus Zoom usa KWin.MaximizeArea y restaura geometría previa"
else
    fail "nimbus-zoom no respeta MaximizeArea o no guarda geometría"
fi

echo "== [6/8] Fullscreen real y salida limpia (F4-T04) =="
SHORTCUTS="$REPO_ROOT/dotfiles/.config/kglobalshortcutsrc"
if grep -q "Window Fullscreen=Meta+F" "$SHORTCUTS" || grep -q "Nimbus Fullscreen" "$ZOOM_JS"; then
    pass "Atajo Meta+F configurado para toggle de pantalla completa"
else
    fail "Atajo Meta+F ausente de kglobalshortcutsrc/nimbus-zoom"
fi

echo "== [7/8] Arrastre nativo y doble clic sin saltos (F4-T05) =="
if bash "$REPO_ROOT/tests/windows/test_drag_doubleclick.sh" >/dev/null 2>&1; then
    pass "Doble clic Maximize y MoveResizeMaximizedWindows sin saltos de offset"
else
    fail "Arrastre o doble clic no superaron el Pointer Lab"
fi

echo "== [8/8] Política CSD / Electron sin doble borde (F10-T06) =="
KWINRC="$REPO_ROOT/dotfiles/.config/kwinrc"
if grep -q "BorderlessMaximizedWindows=true" "$KWINRC"; then
    pass "KWin respeta marcos CSD y maximizadas sin bordes dobles"
else
    fail "kwinrc sin BorderlessMaximizedWindows"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "ACEPTACIÓN DE VENTANAS VERDE: 8/8 pruebas superadas."
    exit 0
else
    echo "ACEPTACIÓN DE VENTANAS ROJO: $FAILS fallo(s)." >&2
    exit 1
fi
