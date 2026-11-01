#!/usr/bin/env bash
# F6-T07 nested: foco visible de teclado + Orca en nimbus-spotlight/Apps.
# Patrón tests/vm/nested-spotlight.sh: KWin virtual + HOME/XDG temporales
# (dbus-run-session). NUNCA toca ~/.config del host, su sesión, root ni red.
# Uso: bash tests/vm/nested-f6a11y.sh [--out spikes/nested] [--timeout 90]
#        [--spot-bin /tmp/.../nimbus-spotlight] [--apps-bin /tmp/.../nimbus-apps]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=90
SPOT_BIN=""
APPS_BIN=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --spot-bin) j=$((i+1)); SPOT_BIN="${!j}" ;;
    --apps-bin) j=$((i+1)); APPS_BIN="${!j}" ;;
  esac
done
[ -n "$SPOT_BIN" ] || SPOT_BIN="/tmp/opencode/f6a11y-spot/nimbus-spotlight"
[ -n "$APPS_BIN" ] || APPS_BIN="/tmp/opencode/f6a11y-apps/nimbus-apps"
[ -x "$SPOT_BIN" ] || { echo "ERROR: sin binario $SPOT_BIN" >&2; exit 1; }
[ -x "$APPS_BIN" ] || { echo "ERROR: sin binario $APPS_BIN" >&2; exit 1; }

OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/f6-a11y-nested.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-a11y-XXXXXX)"
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
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-a11y" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[a11y] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[a11y] runtime=$XDG_RUNTIME_DIR home=$NESTED_HOME log=$LOG" | tee -a "$LOG"
echo "[a11y] orca: $(command -v orca || echo 'NO instalado en el host')" | tee -a "$LOG"

timeout "$TIMEOUT" dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
SPOT_BIN="'"$SPOT_BIN"'"
APPS_BIN="'"$APPS_BIN"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-a11y"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[a11y] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<60; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[a11y] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2
# Foco visible: --demo abre con el campo enfocado (forceActiveFocus) y el
# anillo blanco 2px queda en la captura propia (--shot = píxeles reales).
echo "[a11y] spotlight --demo --query kate --shot f6-a11y-focus.png ..." | tee -a "$LOG"
"$SPOT_BIN" --demo --query "kate" --shot "$OUT_ABS/f6-a11y-focus.png" >>"$LOG" 2>&1 &
SPOT_PID=$!
sleep 9
if kill -0 $SPOT_PID 2>/dev/null; then echo "[a11y] spotlight VIVO (pid $SPOT_PID)" | tee -a "$LOG";
else echo "[a11y] ERROR: spotlight MUERTO" | tee -a "$LOG"; fi
# Apps: --demo --shot captura propia y sale (rc=0 esperado).
echo "[a11y] nimbus-apps --demo --shot f6-a11y-apps.png ..." | tee -a "$LOG"
"$APPS_BIN" --demo --shot "$OUT_ABS/f6-a11y-apps.png" >>"$LOG" 2>&1 &
APPS_PID=$!
for ((i=0; i<20; i++)); do
  kill -0 $APPS_PID 2>/dev/null || break
  sleep 0.5
done
if [ -e "$OUT_ABS/f6-a11y-apps.png" ]; then echo "[a11y] f6-a11y-apps.png OK" | tee -a "$LOG";
else echo "[a11y] WARN: sin captura de Apps" | tee -a "$LOG"; fi
# Orca: arranque en nested si existe (usa el AT-SPI del bus temporal).
if command -v orca >/dev/null 2>&1; then
  echo "[a11y] orca presente: arranque de prueba ..." | tee -a "$LOG"
  timeout 8 orca --replace >>"$LOG" 2>&1 &
  ORCA_PID=$!
  sleep 6
  if kill -0 $ORCA_PID 2>/dev/null; then
    echo "[a11y] orca VIVO" | tee -a "$LOG"
    timeout 20 spectacle -b -n -o "$OUT_ABS/f6-a11y-orca.png" >>"$LOG" 2>&1 \
      && echo "[a11y] f6-a11y-orca.png OK" | tee -a "$LOG" \
      || echo "[a11y] WARN: spectacle-orca fallo" | tee -a "$LOG"
    kill $ORCA_PID 2>/dev/null || true
  else
    echo "[a11y] orca no sobrevivió (sin captura)" | tee -a "$LOG"
  fi
else
  echo "[a11y] orca NO instalado: sin f6-a11y-orca.png (preparado: roles/nombres/announce en QML)" | tee -a "$LOG"
fi
ls -la "$OUT_ABS"/f6-a11y-*.png 2>>"$LOG" || true
grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-a11y-qmlerr.txt" || true
if [ -s "$OUT_ABS/f6-a11y-qmlerr.txt" ]; then cat "$OUT_ABS/f6-a11y-qmlerr.txt" | tee -a "$LOG";
else echo "[a11y] 0 errores QML" | tee -a "$LOG"; fi
kill $SPOT_PID $KWIN_PID 2>/dev/null || true
' 2>>"$LOG"
RC=$?
# Bracket: no autodispararse (el cmdline del runner contiene este script).
pkill -f "[n]imbus-a11y" 2>/dev/null || true
echo "[a11y] exit=$RC"
ls -la "$OUT_ABS"/f6-a11y-*.png 2>&1
