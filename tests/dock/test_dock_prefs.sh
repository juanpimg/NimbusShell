#!/usr/bin/env bash
# test_dock_prefs.sh — F5-T10: validación de preferencias y persistencia del Dock.
# Sin root, sin red, HOME temporal.
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCK_SCRIPT="$REPO_ROOT/scripts/nimbus-dock"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== dock prefs: comprobación de script =="
if [ -x "$DOCK_SCRIPT" ]; then
    pass "scripts/nimbus-dock ejecutable"
else
    fail "scripts/nimbus-dock ausente o no ejecutable"
    exit 1
fi

TMP_HOME="$(mktemp -d /tmp/opencode/dock-prefs-test-XXXXXX)"
cleanup() { rm -rf "$TMP_HOME"; }
trap cleanup EXIT

# 1. Comprobación inicial
if "$DOCK_SCRIPT" --check --home "$TMP_HOME" >/dev/null 2>&1; then
    pass "--check inicial OK"
else
    fail "--check inicial falló"
fi

# 2. Modificación de tamaño
"$DOCK_SCRIPT" --size 64 --home "$TMP_HOME" >/dev/null 2>&1
SIZE="$("$DOCK_SCRIPT" --get IconSize --home "$TMP_HOME")"
if [ "$SIZE" = "64" ]; then
    pass "--size 64 persistido correctamente"
else
    fail "--size 64 no se guardó ($SIZE)"
fi

# 2b. Rechazo de tamaño fuera de rango
if "$DOCK_SCRIPT" --size 120 --home "$TMP_HOME" >/dev/null 2>&1; then
    fail "--size 120 debió ser rechazado"
else
    pass "--size 120 rechazado correctamente"
fi

# 3. Modificación de zoom
"$DOCK_SCRIPT" --zoom 1.8 --home "$TMP_HOME" >/dev/null 2>&1
ZOOM="$("$DOCK_SCRIPT" --get MaxZoomFactor --home "$TMP_HOME")"
if [ "$ZOOM" = "1.8" ]; then
    pass "--zoom 1.8 persistido correctamente"
else
    fail "--zoom 1.8 no se guardó ($ZOOM)"
fi

# 3b. Rechazo de zoom fuera de rango o inválido
if "$DOCK_SCRIPT" --zoom 2.5 --home "$TMP_HOME" >/dev/null 2>&1; then
    fail "--zoom 2.5 debió ser rechazado"
else
    pass "--zoom 2.5 rechazado correctamente"
fi

if "$DOCK_SCRIPT" --zoom 0.5 --home "$TMP_HOME" >/dev/null 2>&1; then
    fail "--zoom 0.5 debió ser rechazado"
else
    pass "--zoom 0.5 rechazado correctamente"
fi

if "$DOCK_SCRIPT" --zoom invalid --home "$TMP_HOME" >/dev/null 2>&1; then
    fail "--zoom invalid debió ser rechazado"
else
    pass "--zoom invalid rechazado correctamente"
fi

# 4. Modificación de posición
"$DOCK_SCRIPT" --position left --home "$TMP_HOME" >/dev/null 2>&1
EDGE_LEFT="$("$DOCK_SCRIPT" --get Edge --home "$TMP_HOME")"
if [ "$EDGE_LEFT" = "2" ]; then
    pass "--position left -> Edge=2"
else
    fail "--position left falló ($EDGE_LEFT)"
fi

"$DOCK_SCRIPT" --position right --home "$TMP_HOME" >/dev/null 2>&1
EDGE_RIGHT="$("$DOCK_SCRIPT" --get Edge --home "$TMP_HOME")"
if [ "$EDGE_RIGHT" = "3" ]; then
    pass "--position right -> Edge=3"
else
    fail "--position right falló ($EDGE_RIGHT)"
fi

"$DOCK_SCRIPT" --position bottom --home "$TMP_HOME" >/dev/null 2>&1
EDGE_BOTTOM="$("$DOCK_SCRIPT" --get Edge --home "$TMP_HOME")"
if [ "$EDGE_BOTTOM" = "1" ]; then
    pass "--position bottom -> Edge=1"
else
    fail "--position bottom falló ($EDGE_BOTTOM)"
fi

# 5. Modificación de autohide
"$DOCK_SCRIPT" --autohide on --home "$TMP_HOME" >/dev/null 2>&1
VIS_ON="$("$DOCK_SCRIPT" --get VisibilityMode --home "$TMP_HOME")"
if [ "$VIS_ON" = "1" ]; then
    pass "--autohide on -> VisibilityMode=1"
else
    fail "--autohide on falló ($VIS_ON)"
fi

"$DOCK_SCRIPT" --autohide off --home "$TMP_HOME" >/dev/null 2>&1
VIS_OFF="$("$DOCK_SCRIPT" --get VisibilityMode --home "$TMP_HOME")"
if [ "$VIS_OFF" = "0" ]; then
    pass "--autohide off -> VisibilityMode=0"
else
    fail "--autohide off falló ($VIS_OFF)"
fi

# 6. Modificación de tema visual
"$DOCK_SCRIPT" --theme solid --home "$TMP_HOME" >/dev/null 2>&1
BG_SOLID="$("$DOCK_SCRIPT" --get BackgroundStyle --home "$TMP_HOME")"
if [ "$BG_SOLID" = "1" ]; then
    pass "--theme solid -> BackgroundStyle=1"
else
    fail "--theme solid falló ($BG_SOLID)"
fi

"$DOCK_SCRIPT" --theme acrylic --home "$TMP_HOME" >/dev/null 2>&1
BG_ACRYLIC="$("$DOCK_SCRIPT" --get BackgroundStyle --home "$TMP_HOME")"
if [ "$BG_ACRYLIC" = "3" ]; then
    pass "--theme acrylic -> BackgroundStyle=3"
else
    fail "--theme acrylic falló ($BG_ACRYLIC)"
fi

# 7. Salida JSON completa
JSON_DUMP="$("$DOCK_SCRIPT" --json --home "$TMP_HOME")"
if python3 -c "import json, sys; d=json.loads(sys.argv[1]); assert d['IconSize']=='64' and d['BackgroundStyle']=='3'" "$JSON_DUMP" 2>/dev/null; then
    pass "--json exporta configuración completa parseable"
else
    fail "--json export falló ($JSON_DUMP)"
fi

# 8. Comprobación de copias de seguridad
BKP_COUNT="$(find "$TMP_HOME/.config" -maxdepth 1 -type d -name 'nimbusshell-backup-dock-*' | wc -l)"
if [ "$BKP_COUNT" -gt 0 ]; then
    pass "copias de seguridad creadas ($BKP_COUNT backups)"
else
    fail "no se crearon backups en ~/.config"
fi

# 9. Reset al preset canónico
"$DOCK_SCRIPT" --reset --home "$TMP_HOME" >/dev/null 2>&1
RESET_SIZE="$("$DOCK_SCRIPT" --get IconSize --home "$TMP_HOME")"
RESET_ZOOM="$("$DOCK_SCRIPT" --get MaxZoomFactor --home "$TMP_HOME")"
if [ "$RESET_SIZE" = "48" ] && [ "$RESET_ZOOM" = "1.6" ]; then
    pass "--reset restablece tamaño 48 y zoom 1.6 canónicos"
else
    fail "--reset no restableció valores canónicos (size=$RESET_SIZE zoom=$RESET_ZOOM)"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "DOCK PREFS VERDE (todos los checks pasan)."
    exit 0
else
    echo "DOCK PREFS ROJO ($FAILS fallos)." >&2
    exit 1
fi
