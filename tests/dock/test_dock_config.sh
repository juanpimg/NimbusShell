#!/usr/bin/env bash
# test_dock_config.sh — test unitario F5-T08: configuración y persistencia del Dock Krema.
# Sin root, sin red, HOME temporal.
# Verifica: formato INI, claves de paridad macOS Tahoe (zoom 1.6x, tile 48, acrílico 3),
# pins, unpin/re-pin, reorder y reset al preset nimbus.
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCK_PRESET="$REPO_ROOT/packages/dock/kremarc-nimbus"
DOCK_AUTOHIDE="$REPO_ROOT/packages/dock/kremarc-nimbus-autohide"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== dock: archivos de configuración presentes =="
[ -f "$DOCK_PRESET" ] && pass "kremarc-nimbus presente" || fail "falta kremarc-nimbus"
[ -f "$DOCK_AUTOHIDE" ] && pass "kremarc-nimbus-autohide presente" || fail "falta kremarc-nimbus-autohide"

echo "== dock: validación de claves Tahoe 1:1 =="
get_val() {
    local file="$1" key="$2"
    grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2- | tr -d '\r'
}

[ "$(get_val "$DOCK_PRESET" "IconSize")" = "48" ] && pass "IconSize=48" || fail "IconSize != 48"
[ "$(get_val "$DOCK_PRESET" "MaxZoomFactor")" = "1.6" ] && pass "MaxZoomFactor=1.6 (parabólico)" || fail "MaxZoomFactor != 1.6"
[ "$(get_val "$DOCK_PRESET" "Edge")" = "1" ] && pass "Edge=1 (abajo)" || fail "Edge != 1"
[ "$(get_val "$DOCK_PRESET" "Floating")" = "true" ] && pass "Floating=true" || fail "Floating != true"
[ "$(get_val "$DOCK_PRESET" "CornerRadius")" = "12" ] && pass "CornerRadius=12" || fail "CornerRadius != 12"
[ "$(get_val "$DOCK_PRESET" "BackgroundStyle")" = "3" ] && pass "BackgroundStyle=3 (Acrylic Tahoe)" || fail "BackgroundStyle != 3"
[ "$(get_val "$DOCK_PRESET" "BackgroundOpacity")" = "0.6" ] && pass "BackgroundOpacity=0.6" || fail "BackgroundOpacity != 0.6"
[ "$(get_val "$DOCK_PRESET" "VisibilityMode")" = "0" ] && pass "VisibilityMode=0 (fijo)" || fail "VisibilityMode != 0"
[ "$(get_val "$DOCK_AUTOHIDE" "VisibilityMode")" = "1" ] && pass "autohide VisibilityMode=1" || fail "autohide VisibilityMode != 1"
[ "$(get_val "$DOCK_PRESET" "PreviewEnabled")" = "true" ] && pass "PreviewEnabled=true" || fail "PreviewEnabled != true"

echo "== dock: operaciones de pins y persistencia =="
TMP_DIR="$(mktemp -d /tmp/opencode/dock-test-XXXXXX)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

CFG="$TMP_DIR/kremarc"
cp "$DOCK_PRESET" "$CFG"

# 1. Lectura inicial de pins
INITIAL_PINS="$(get_val "$CFG" "PinnedLaunchers")"
[ -n "$INITIAL_PINS" ] && pass "pins iniciales no vacíos ($INITIAL_PINS)" || fail "sin pins iniciales"

# 2. Desanclar (unpin) Kate
UNPINNED="$(echo "$INITIAL_PINS" | sed 's/,*applications:org\.kde\.kate\.desktop,*//g')"
sed -i "s|^PinnedLaunchers=.*|PinnedLaunchers=$UNPINNED|" "$CFG"
CUR_PINS="$(get_val "$CFG" "PinnedLaunchers")"
if [[ "$CUR_PINS" != *"org.kde.kate.desktop"* ]]; then
    pass "unpin kate efectivo"
else
    fail "unpin kate no funcionó"
fi

# 3. Re-anclar (re-pin) Kate al final
REPINNED="$CUR_PINS,applications:org.kde.kate.desktop"
sed -i "s|^PinnedLaunchers=.*|PinnedLaunchers=$REPINNED|" "$CFG"
CUR_PINS="$(get_val "$CFG" "PinnedLaunchers")"
if [[ "$CUR_PINS" == *"org.kde.kate.desktop" ]]; then
    pass "re-pin kate al final efectivo"
else
    fail "re-pin kate al final falló"
fi

# 4. Reordenar pins (invertir lista)
REVERSED="$(python3 -c "pins = '$CUR_PINS'.split(','); print(','.join(reversed(pins)))")"
sed -i "s|^PinnedLaunchers=.*|PinnedLaunchers=$REVERSED|" "$CFG"
CUR_PINS="$(get_val "$CFG" "PinnedLaunchers")"
if [[ "$CUR_PINS" == "applications:org.kde.kate.desktop"* ]]; then
    pass "reorder pins efectivo"
else
    fail "reorder pins falló"
fi

# 5. Reset al preset canónico
cp "$DOCK_PRESET" "$CFG"
RESET_PINS="$(get_val "$CFG" "PinnedLaunchers")"
[ "$RESET_PINS" = "$INITIAL_PINS" ] && pass "reset al preset idéntico al original" || fail "reset difería del original"

echo "== dock: resultado =="
if [ "$FAILS" -eq 0 ]; then
    echo "DOCK VERDE (todos los checks pasan)."
    exit 0
else
    echo "DOCK ROJO ($FAILS fallos)." >&2
    exit 1
fi
