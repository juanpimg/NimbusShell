#!/usr/bin/env bash
# Harness nested F11-T03 (estados, dark/light, acento): KWin virtual +
# plasmashell (fondo) + nimbus-bar con demos + matriz de estados QML.
# Seguro: NUNCA --replace, HOME/XDG temporales, sin root, sin instalaciones.
# Fases: light (menu+cc) / dark (menu+cc) / accent (menu+osd, --accent
# naranja) / matriz light+dark (matriz QML, foco real autoforzado).
# Uso: bash tests/vm/nested-f11states.sh [--out spikes/nested] [--timeout 120] [--bin /ruta/nimbus-bar]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=120
BAR_BIN="/tmp/nimbus-bar-prefix/bin/nimbus-bar"
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

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f11states-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_CONFIG_HOME="$BASE_TMP/config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
NESTED_HOME="$BASE_TMP/home"
mkdir -p "$NESTED_HOME/.config"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-f11states"
LOG="$OUT_ABS/nested-f11states.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-f11states.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-f11states" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[f11] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[f11] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
BASE_TMP="'"$BASE_TMP"'"
REPO_ROOT="'"$REPO_ROOT"'"
BAR_LOG="$OUT_ABS/nested-f11states-bar.log"
: > "$BAR_LOG"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export QT_FORCE_STDERR_LOGGING=1
trap "kill \$(jobs -p) 2>/dev/null || true" EXIT

echo "[f11] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --no-lockscreen --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!

for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[f11] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[f11] socket OK" | tee -a "$LOG"
sleep 2

echo "[f11] arranque plasmashell (fondo) ..." | tee -a "$LOG"
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 10

# kdeglobals lo leen kreadconfig (XDG_CONFIG_HOME y HOME): sembrar en ambos.
seed_scheme() {
  kwriteconfig6 --file "$XDG_CONFIG_HOME/kdeglobals" --group KDE --key ColorScheme "$1" >>"$LOG" 2>&1
  kwriteconfig6 --file "$HOME/.config/kdeglobals" --group KDE --key ColorScheme "$1" >>"$LOG" 2>&1
  echo "[f11] scheme=$1 lee=$(kreadconfig6 --file kdeglobals --group KDE --key ColorScheme 2>/dev/null)" | tee -a "$LOG"
}

run_bar() {
  # $1=nombre fase, resto=args barra
  local name="$1"; shift
  echo "[f11] fase $name: nimbus-bar $*" | tee -a "$LOG"
  # stdbuf: el log a fichero se pierde si el proceso muere con buffer sin vaciar.
  stdbuf -o0 -e0 "$BAR_BIN" "$@" >>"$BAR_LOG" 2>&1 &
  BAR_PID=$!
  sleep 6
  if kill -0 $BAR_PID 2>/dev/null; then echo "[f11] $name VIVO pid=$BAR_PID" | tee -a "$LOG";
  else echo "[f11] ERROR: $name barra muerta" | tee -a "$LOG"; tail -20 "$BAR_LOG" | tee -a "$LOG"; return 1; fi
  # OSD se auto-oculta a 1.5s: re-dispararlo por DBus justo antes del shot.
  if [ -n "${OSD_HOOK:-}" ]; then
    qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show volume 0.7 >>"$LOG" 2>&1 || true
    sleep 1
  fi
  spectacle -b -n -o "$OUT_ABS/f11-states-$name.png" >>"$LOG" 2>&1 \
    && echo "[f11] f11-states-$name.png OK" | tee -a "$LOG" \
    || echo "[f11] WARN: captura $name fallo" | tee -a "$LOG"
  kill $BAR_PID 2>/dev/null || true
  sleep 2
}

seed_scheme BreezeLight
run_bar light --demo-menu --demo-cc
seed_scheme BreezeDark
run_bar dark --demo-menu --demo-cc
OSD_HOOK=1 run_bar accent --demo-menu --demo-osd volume --accent "#FF9F0A"

echo "[f11] matriz de estados QML (mismo NimbusTokens) ..." | tee -a "$LOG"
mkdir -p "$BASE_TMP/f11imports/F11Matrix" "$BASE_TMP/f11m"
cp "$REPO_ROOT/packages/shell/nimbus-bar/qml/NimbusTokens.qml" "$BASE_TMP/f11imports/F11Matrix/"
printf "module F11Matrix\nsingleton NimbusTokens 1.0 NimbusTokens.qml\n" > "$BASE_TMP/f11imports/F11Matrix/qmldir"
sed -e "s/@DARK@/false/" "$REPO_ROOT/tests/vm/f11-states-matrix.qml.tmpl" > "$BASE_TMP/f11m/matrix-light.qml"
sed -e "s/@DARK@/true/" "$REPO_ROOT/tests/vm/f11-states-matrix.qml.tmpl" > "$BASE_TMP/f11m/matrix-dark.qml"
export QML_IMPORT_PATH="$BASE_TMP/f11imports"
export QT_ASSUME_STDERR_HAS_CONSOLE=1
qmlscene6 "$BASE_TMP/f11m/matrix-light.qml" >>"$LOG" 2>&1 &
MAT_PID=$!
sleep 4
spectacle -b -n -o "$OUT_ABS/f11-states-matrix-light.png" >>"$LOG" 2>&1 \
  && echo "[f11] f11-states-matrix-light.png OK" | tee -a "$LOG" \
  || echo "[f11] WARN: captura matriz-light fallo" | tee -a "$LOG"
kill $MAT_PID 2>/dev/null || true
sleep 1
qmlscene6 "$BASE_TMP/f11m/matrix-dark.qml" >>"$LOG" 2>&1 &
MAT_PID=$!
sleep 4
spectacle -b -n -o "$OUT_ABS/f11-states-matrix-dark.png" >>"$LOG" 2>&1 \
  && echo "[f11] f11-states-matrix-dark.png OK" | tee -a "$LOG" \
  || echo "[f11] WARN: captura matriz-dark fallo" | tee -a "$LOG"
kill $MAT_PID 2>/dev/null || true
sleep 1

echo "[f11] errores QML/bar (si vacio = limpio):" | tee -a "$LOG"
grep -ai "referenceerror\|typeerror\|qml.*error\|cannot.*create\|failed to" "$BAR_LOG" | tee -a "$LOG" || echo "[f11] sin errores QML" | tee -a "$LOG"

ls -la "$OUT_ABS"/f11-states-*.png >>"$LOG" 2>&1
echo "$KWIN_PID $PLASMA_PID" > "$PIDFILE"
echo "[f11] FIN." | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[f11] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
