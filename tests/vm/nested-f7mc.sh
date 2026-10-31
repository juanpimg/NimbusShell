#!/usr/bin/env bash
# Harness F7 Mission Control anidado: KWin virtual + plasmashell +
# kate/konsole/dolphin + nimbus-missioncontrol real + capturas.
# Seguro en host Plasma Wayland: NUNCA usa --replace, no toca ~/.config,
# no root, no instala nada. HOME/XDG temporales bajo dbus-run-session.
# Limpieza garantizada por trap.
#
# Uso: bash tests/vm/nested-f7mc.sh [--out spikes/nested] [--mc-bin <bin>]
# Requiere: build previo (cmake -B build -S apps/nimbus-missioncontrol).
set -u
OUT_DIR="spikes/nested"
MCBIN=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --mc-bin) j=$((i+1)); MCBIN="${!j}" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
if [ -z "$MCBIN" ]; then
  for c in "$REPO_ROOT/build/apps/nimbus-missioncontrol/nimbus-missioncontrol" \
           "$REPO_ROOT/build/nimbus-missioncontrol" /tmp/opencode/mc-build/nimbus-missioncontrol; do
    [ -x "$c" ] && MCBIN="$c" && break
  done
fi
if [ ! -x "$MCBIN" ]; then echo "ERROR: sin binario nimbus-missioncontrol (usa --mc-bin)" >&2; exit 1; fi
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f7mc-XXXXXX)"
chmod 700 "$BASE_TMP"
export F7BASE="$BASE_TMP" F7LOG="$OUT_ABS/f7mc-nested.log"
export F7OUT="$OUT_ABS" F7MCBIN="$MCBIN"
: > "$F7LOG"
export XDG_RUNTIME_DIR="$BASE_TMP/rt"
export XDG_CONFIG_HOME="$BASE_TMP/c" XDG_DATA_HOME="$BASE_TMP/d"
export XDG_CACHE_HOME="$BASE_TMP/ch" XDG_STATE_HOME="$BASE_TMP/s"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=nimbus-f7mc
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
dbus-run-session -- bash "$REPO_ROOT/tests/vm/nested-f7mc-inner.sh" >>"$F7LOG" 2>&1
RC=$?
grep -E "f7\]|nimbus-mc\[" "$F7LOG" | sort -u | head -20
# Caza restos de ESTA sesión anidada (patrón con [n] para no autocoincidir;
# nunca toca el KWin del host) y reintenta el borrado.
ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-f7mc" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
sleep 1
rm -rf "$BASE_TMP" || echo "[f7] WARN: no se pudo borrar $BASE_TMP" >&2
exit $RC
