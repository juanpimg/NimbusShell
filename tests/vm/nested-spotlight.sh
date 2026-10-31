#!/usr/bin/env bash
# Nested Spotlight (F6-T01): KWin virtual + nimbus-spotlight real (--query)
# en HOME/XDG temporales. Nunca toca ~/.config del host ni su sesión.
# Uso: bash tests/vm/nested-spotlight.sh [--out spikes/nested] [--timeout 90]
#        [--bin apps/nimbus-spotlight/build/nimbus-spotlight] [--query kate]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=90
QUERY="kate"
BIN="apps/nimbus-spotlight/build/nimbus-spotlight"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --query) j=$((i+1)); QUERY="${!j}" ;;
    --bin) j=$((i+1)); BIN="${!j}" ;;
  esac
done
[[ "$QUERY" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: --query solo [A-Za-z0-9._-]" >&2; exit 1; }
[ -x "$REPO_ROOT/$BIN" ] || { echo "ERROR: sin binario $REPO_ROOT/$BIN" >&2; exit 1; }

OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/f6-spotlight.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-spot-XXXXXX)"
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
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-spot" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[n]imbus-spotlight.*nimbus-spot" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[spot] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[spot] runtime=$XDG_RUNTIME_DIR home=$NESTED_HOME log=$LOG" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
QUERY="'"$QUERY"'"
BIN="'"$REPO_ROOT/$BIN"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-spot"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[spot] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[spot] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2
echo "[spot] arranque nimbus-spotlight --query $QUERY ..." | tee -a "$LOG"
"$BIN" --query "$QUERY" --shot "$OUT_ABS/f6-spotlight-grab.png" >>"$LOG" 2>&1 &
SPOT_PID=$!
sleep 9
if kill -0 $SPOT_PID 2>/dev/null; then echo "[spot] spotlight VIVO (pid $SPOT_PID)" | tee -a "$LOG";
else echo "[spot] ERROR: spotlight MUERTO" | tee -a "$LOG"; fi
echo "[spot] DBus org.nimbus.Spotlight:" | tee -a "$LOG"
qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle >>"$LOG" 2>&1 \
  && echo "[spot] toggle OK (oculta)" | tee -a "$LOG" \
  || echo "[spot] WARN: toggle fallo" | tee -a "$LOG"
sleep 1
qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle >>"$LOG" 2>&1 \
  && echo "[spot] toggle OK (muestra)" | tee -a "$LOG" || true
sleep 2
spectacle -b -n -o "$OUT_ABS/f6-spotlight.png" >>"$LOG" 2>&1 \
  && echo "[spot] f6-spotlight.png OK" | tee -a "$LOG" \
  || echo "[spot] WARN: spectacle fallo" | tee -a "$LOG"
ls -la "$OUT_ABS"/f6-spotlight*.png 2>>"$LOG" || true
echo "[spot] latencias:" | tee -a "$LOG"
grep -h "spotlight-latency" "$LOG" > "$OUT_ABS/f6-latency.txt" || true
if [ -s "$OUT_ABS/f6-latency.txt" ]; then cat "$OUT_ABS/f6-latency.txt" | tee -a "$LOG";
else echo "[spot] sin lineas spotlight-latency" | tee -a "$LOG"; fi
grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-qmlerr.txt" || true
if [ -s "$OUT_ABS/f6-qmlerr.txt" ]; then cat "$OUT_ABS/f6-qmlerr.txt" | tee -a "$LOG";
else echo "[spot] 0 errores QML" | tee -a "$LOG"; fi
kill $SPOT_PID $KWIN_PID 2>/dev/null || true
'
echo "[spot] fin. Log: $LOG"
