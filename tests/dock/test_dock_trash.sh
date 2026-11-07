#!/usr/bin/env bash
# test_dock_trash.sh — F5-T09: validación de papelera, stacks y badges del Dock.
# Sin root, sin red, HOME temporal.
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== dock: validación de archivos .desktop de papelera y descargas =="
TRASH_DESK="$REPO_ROOT/packages/dock/launchers/org.nimbus.dock.trash.desktop"
DOWNLOADS_DESK="$REPO_ROOT/packages/dock/launchers/org.nimbus.dock.downloads.desktop"

for d in "$TRASH_DESK" "$DOWNLOADS_DESK"; do
    if [ -f "$d" ]; then
        if desktop-file-validate "$d" >/dev/null 2>&1; then
            pass "desktop-file-validate $(basename "$d")"
        else
            fail "desktop-file-validate falló en $(basename "$d")"
        fi
    else
        fail "falta $d"
    fi
done

echo "== dock: ciclo de vida de nimbus-trash =="
TRASH_SCRIPT="$REPO_ROOT/scripts/nimbus-trash"
if [ ! -x "$TRASH_SCRIPT" ]; then
    fail "scripts/nimbus-trash ausente o no ejecutable"
    exit 1
fi

TMP_HOME="$(mktemp -d /tmp/opencode/trash-test-XXXXXX)"
cleanup() { rm -rf "$TMP_HOME"; }
trap cleanup EXIT

DATA_DIR="$TMP_HOME/.local/share"
mkdir -p "$DATA_DIR/Trash/files" "$DATA_DIR/Trash/info" "$DATA_DIR/applications"
cp "$TRASH_DESK" "$DATA_DIR/applications/org.nimbus.dock.trash.desktop"

# 1. Estado vacío inicial
STATUS_EMPTY="$("$TRASH_SCRIPT" --status --json --home "$TMP_HOME")"
STATE="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['state'])" "$STATUS_EMPTY")"
COUNT="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$STATUS_EMPTY")"

if [ "$STATE" = "empty" ] && [ "$COUNT" -eq 0 ]; then
    pass "papelera vacía detectada correctamente (count=0, state=empty)"
else
    fail "estado inicial no es empty ($STATUS_EMPTY)"
fi

# 2. Actualizar icono en estado vacío
"$TRASH_SCRIPT" --update-icon --home "$TMP_HOME" >/dev/null 2>&1
CURRENT_ICON="$(grep '^Icon=' "$DATA_DIR/applications/org.nimbus.dock.trash.desktop" | cut -d= -f2)"
if [ "$CURRENT_ICON" = "user-trash" ]; then
    pass "icono refleja estado vacío: user-trash"
else
    fail "icono no es user-trash ($CURRENT_ICON)"
fi

# 3. Llenar papelera con archivos simulados
touch "$DATA_DIR/Trash/files/documento1.pdf"
touch "$DATA_DIR/Trash/files/foto.png"

STATUS_FULL="$("$TRASH_SCRIPT" --status --json --home "$TMP_HOME")"
STATE_FULL="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['state'])" "$STATUS_FULL")"
COUNT_FULL="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$STATUS_FULL")"

if [ "$STATE_FULL" = "full" ] && [ "$COUNT_FULL" -eq 2 ]; then
    pass "papelera llena detectada correctamente (count=2, state=full)"
else
    fail "estado no refleja papelera llena ($STATUS_FULL)"
fi

# 4. Actualizar icono en estado lleno
"$TRASH_SCRIPT" --update-icon --home "$TMP_HOME" >/dev/null 2>&1
CURRENT_ICON_FULL="$(grep '^Icon=' "$DATA_DIR/applications/org.nimbus.dock.trash.desktop" | cut -d= -f2)"
if [ "$CURRENT_ICON_FULL" = "user-trash-full" ]; then
    pass "icono refleja estado lleno: user-trash-full"
else
    fail "icono no es user-trash-full ($CURRENT_ICON_FULL)"
fi

# 5. Vaciar papelera
"$TRASH_SCRIPT" --empty --home "$TMP_HOME" >/dev/null 2>&1
STATUS_EMPTIED="$("$TRASH_SCRIPT" --status --json --home "$TMP_HOME")"
COUNT_EMPTIED="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$STATUS_EMPTIED")"

if [ "$COUNT_EMPTIED" -eq 0 ]; then
    pass "papelera vaciada correctamente tras --empty"
else
    fail "papelera no se vació ($STATUS_EMPTIED)"
fi

CURRENT_ICON_EMPTIED="$(grep '^Icon=' "$DATA_DIR/applications/org.nimbus.dock.trash.desktop" | cut -d= -f2)"
if [ "$CURRENT_ICON_EMPTIED" = "user-trash" ]; then
    pass "icono restaurado automáticamente a user-trash tras --empty"
else
    fail "icono tras empty no es user-trash ($CURRENT_ICON_EMPTIED)"
fi

# 6. Aislamiento respecto a XDG_DATA_HOME ambiental
TMP_HOST_SHARE="$(mktemp -d /tmp/opencode/host-share-XXXXXX)"
mkdir -p "$TMP_HOST_SHARE/Trash/files"
touch "$TMP_HOST_SHARE/Trash/files/host_trash_item"
STATUS_ISO="$(XDG_DATA_HOME="$TMP_HOST_SHARE" "$TRASH_SCRIPT" --status --json --home "$TMP_HOME")"
COUNT_ISO="$(python3 -c "import json, sys; d=json.loads(sys.argv[1]); print(d['count'])" "$STATUS_ISO")"
rm -rf "$TMP_HOST_SHARE"

if [ "$COUNT_ISO" -eq 0 ]; then
    pass "aislamiento respecto a XDG_DATA_HOME ambiental verificado (--home respetado)"
else
    fail "aislamiento falló: --home leyó XDG_DATA_HOME externo ($STATUS_ISO)"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "DOCK TRASH VERDE (todos los checks pasan)."
    exit 0
else
    echo "DOCK TRASH ROJO ($FAILS fallos)." >&2
    exit 1
fi
