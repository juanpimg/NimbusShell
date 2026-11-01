#!/usr/bin/env bash
# nested-f10widgets.sh — F10-T01: ClockApp + Now Playing + Tiempo en nested.
# KWin virtual + nimbus-bar (--demo-media --demo-weather, CC y calendario
# abiertos) + nimbus-clock (--demo, pestañas mundo/alarmas). Capturas:
# f10-clock.png, f10-clock-alarm.png, f10-media.png, f10-weather.png.
# Seguro: HOME/XDG temporales, dbus-run-session, NUNCA --replace, sin root,
# sin red (weather en demo; MPRIS sin reproductor en nested = oculto salvo
# demo). Limpieza por trap.
# Uso: bash tests/vm/nested-f10widgets.sh [--out spikes/nested] [--timeout 90]
set -u
OUT_DIR="spikes/nested"
TIMEOUT=90
BAR_BIN="/tmp/opencode/nimbus-build-bar/nimbus-bar"
CLOCK_BIN="/tmp/opencode/nimbus-build-clock/nimbus-clock"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BAR_BIN="${!j}" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
[ -x "$BAR_BIN" ] || { echo "[f10w] ERROR: falta binario barra $BAR_BIN" >&2; exit 1; }
[ -x "$CLOCK_BIN" ] || { echo "[f10w] ERROR: falta binario reloj $CLOCK_BIN" >&2; exit 1; }
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f10w-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NH="$BASE_TMP/home"
mkdir -p "$NH/.config" "$BASE_TMP/cache" "$BASE_TMP/state" "$BASE_TMP/data"
LOG="$OUT_ABS/f10-widgets-nested.log"
: > "$LOG"
cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*f10w-sock" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[f10w] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
echo "[f10w] qmllint (bar+clock) ..." | tee -a "$LOG"
LINT_FAIL=0
for f in "$REPO_ROOT/packages/shell/nimbus-bar/qml/ControlCenter.qml" \
         "$REPO_ROOT/packages/shell/nimbus-bar/qml/Calendar.qml" \
         "$REPO_ROOT/packages/shell/nimbus-bar/qml/Menu.qml" \
         "$REPO_ROOT/packages/shell/nimbus-bar/qml/MediaWidget.qml" \
         "$REPO_ROOT/packages/shell/nimbus-bar/qml/WeatherWidget.qml" \
         "$REPO_ROOT/apps/nimbus-clock/qml/Clock.qml"; do
  if ! qmllint "$f" >>"$LOG" 2>&1; then echo "[f10w] LINT_FAIL $f" | tee -a "$LOG"; LINT_FAIL=1; fi
done
[ "$LINT_FAIL" -eq 0 ] && echo "[f10w] qmllint limpio (6 ficheros)" | tee -a "$LOG"
timeout "$TIMEOUT" dbus-run-session -- bash -c '
set -u
export HOME="'"$NH"'" XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="'"$BASE_TMP"'/data"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache" XDG_STATE_HOME="'"$BASE_TMP"'/state"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="f10w-sock"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="'"$LOG"'"
OUT_ABS="'"$OUT_ABS"'"
BAR_BIN="'"$BAR_BIN"'"
CLOCK_BIN="'"$CLOCK_BIN"'"
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0;i<60;i++)); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[f10w] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
echo "[f10w] barra A: solo CC + demo-media (captura limpia) ..." | tee -a "$LOG"
"$BAR_BIN" --demo-cc --open-cc --demo-media >>"$LOG" 2>&1 &
BAR_PID=$!
sleep 5
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-media.png" >>"$LOG" 2>&1 \
  && echo "[f10w] f10-media.png OK" | tee -a "$LOG" \
  || echo "[f10w] WARN: captura media fallo" | tee -a "$LOG"
kill "$BAR_PID" 2>/dev/null || true; sleep 1
echo "[f10w] barra B: calendario + demo-weather ..." | tee -a "$LOG"
"$BAR_BIN" --demo-calendar --demo-weather >>"$LOG" 2>&1 &
BAR_PID=$!
sleep 5
echo "[f10w] reloj (mundo) ..." | tee -a "$LOG"
"$CLOCK_BIN" --demo --tab mundo >>"$LOG" 2>&1 &
CLOCK_PID=$!
sleep 4
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-clock.png" >>"$LOG" 2>&1 \
  && echo "[f10w] f10-clock.png OK" | tee -a "$LOG" \
  || echo "[f10w] WARN: captura clock fallo" | tee -a "$LOG"
kill "$CLOCK_PID" 2>/dev/null || true; sleep 1
echo "[f10w] reloj (alarmas) ..." | tee -a "$LOG"
"$CLOCK_BIN" --demo --tab alarmas >>"$LOG" 2>&1 &
CLOCK_PID=$!
sleep 4
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-clock-alarm.png" >>"$LOG" 2>&1 \
  && echo "[f10w] f10-clock-alarm.png OK" | tee -a "$LOG" \
  || echo "[f10w] WARN: captura alarm fallo" | tee -a "$LOG"
kill "$CLOCK_PID" 2>/dev/null || true; sleep 1
echo "[f10w] calendario+tiempo (ya abierto por la barra) ..." | tee -a "$LOG"
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-weather.png" >>"$LOG" 2>&1 \
  && echo "[f10w] f10-weather.png OK" | tee -a "$LOG" \
  || echo "[f10w] WARN: captura weather fallo" | tee -a "$LOG"
echo "[f10w] --- errores QML en log ---" | tee -a "$LOG"
QERR=$(grep -ci "qml-warn\|QML-WARN\|TypeError\|ReferenceError\|is not a function\|SyntaxError" "$LOG" || true)
echo "[f10w] QML_ERRORS=$QERR" | tee -a "$LOG"
exit 0
'
RC=$?
echo "[f10w] nested rc=$RC" | tee -a "$LOG"
# Fallos reales fuera del nested: binarios + lint + shellcheck.
shellcheck -S warning tests/vm/nested-f10widgets.sh iso/build-iso.sh 2>&1 | tee -a "$LOG" || true
bash -n iso/build-iso.sh && echo "[f10w] build-iso.sh bash -n OK" | tee -a "$LOG"
iso/build-iso.sh --check >>"$LOG" 2>&1 && echo "[f10w] build-iso --check OK" | tee -a "$LOG" || echo "[f10w] WARN: build-iso --check fallo (ver log)" | tee -a "$LOG"
exit "$RC"
