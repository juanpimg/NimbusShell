#!/usr/bin/env bash
# Nested About/Help (F10-T01 + F11-T06): nimbus-about y nimbus-help reales
# en KWin virtual + HOME/XDG temporales. Nunca toca ~/.config del host.
# Uso: bash tests/vm/nested-about.sh [--out spikes/nested] [--timeout 90]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=90
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
  esac
done

ABOUT_BIN="/tmp/opencode/nb-about/nimbus-about"
HELP_BIN="/tmp/opencode/nb-help/nimbus-help"
[ -x "$ABOUT_BIN" ] || { echo "ERROR: sin binario $ABOUT_BIN" >&2; exit 1; }
[ -x "$HELP_BIN" ] || { echo "ERROR: sin binario $HELP_BIN" >&2; exit 1; }

OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/f10-about.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-about-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-about" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[n]imbus-about.*nimbus-about-" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[n]imbus-help.*nimbus-about-" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[about] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[about] runtime=$XDG_RUNTIME_DIR home=$NESTED_HOME log=$LOG" | tee -a "$LOG"

# Menú: verifica que lanza los binarios (estático, sin layer-shell).
echo "[about] menú:" | tee -a "$LOG"
grep -c 'cmd: "nimbus-about"' "$REPO_ROOT/packages/shell/nimbus-bar/qml/Menu.qml" | tee -a "$LOG"
grep -c 'cmd: "nimbus-help"' "$REPO_ROOT/packages/shell/nimbus-bar/qml/Menu.qml" | tee -a "$LOG"
grep -c 'sequence: "Escape"' "$REPO_ROOT/packages/shell/nimbus-bar/qml/Menu.qml" | tee -a "$LOG"

timeout 150 dbus-run-session -- bash -c 'set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
ABOUT_BIN="'"$ABOUT_BIN"'"
HELP_BIN="'"$HELP_BIN"'"
LOG="'"$LOG"'"
REPO_ROOT="'"$REPO_ROOT"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export NIMBUS_REPO_ROOT="'"$REPO_ROOT"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-about"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[about] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[about] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2
echo "[about] arranque nimbus-about --shot ..." | tee -a "$LOG"
"$ABOUT_BIN" --shot "$OUT_ABS/f10-about-grab.png" >>"$LOG" 2>&1 &
ABOUT_PID=$!
echo "[about] arranque nimbus-help --shot ..." | tee -a "$LOG"
"$HELP_BIN" --tab shortcuts --shot "$OUT_ABS/f10-help-grab.png" >>"$LOG" 2>&1 &
HELP_PID=$!
sleep 9
if kill -0 $ABOUT_PID 2>/dev/null; then echo "[about] about VIVO (pid $ABOUT_PID)" | tee -a "$LOG";
else echo "[about] ERROR: about MUERTO" | tee -a "$LOG"; fi
if kill -0 $HELP_PID 2>/dev/null; then echo "[about] help VIVO (pid $HELP_PID)" | tee -a "$LOG";
else echo "[about] ERROR: help MUERTO" | tee -a "$LOG"; fi
sleep 2
spectacle -b -n -o "$OUT_ABS/f10-about.png" >>"$LOG" 2>&1 \
  && echo "[about] f10-about.png OK" | tee -a "$LOG" \
  || echo "[about] WARN: spectacle fallo" | tee -a "$LOG"
sleep 1
spectacle -b -n -o "$OUT_ABS/f10-help.png" >>"$LOG" 2>&1 \
  && echo "[about] f10-help.png OK" | tee -a "$LOG" \
  || echo "[about] WARN: spectacle fallo" | tee -a "$LOG"
ls -la "$OUT_ABS"/f10-*.png 2>>"$LOG" || true
grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f10-qmlerr.txt" || true
if [ -s "$OUT_ABS/f10-qmlerr.txt" ]; then cat "$OUT_ABS/f10-qmlerr.txt" | tee -a "$LOG";
else echo "[about] 0 errores QML" | tee -a "$LOG"; fi
kill -9 $ABOUT_PID $HELP_PID $KWIN_PID 2>/dev/null || true
# El wrapper kwin_wayland re-ejecuta el binario real: mata por socket para
# no dejar compositor huérfano que retenga el bus de sesión.
pkill -9 -f "kwin_wayland --virtual.*nimbus-about" 2>/dev/null || true
sleep 1
'
kill -9 $(ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-about" | awk "{print \$1}") 2>/dev/null || true
echo "[about] fin. Log: $LOG"
