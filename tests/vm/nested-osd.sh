#!/usr/bin/env bash
# Harness nested para OSD nimbus-bar (F3-T10): KWin virtual + plasmashell
# (fondo) + nimbus-bar --demo-osd volume; muestra volumen vía demo, brillo
# vía DBus org.nimbus.OSD y captura ambas burbujas. Replica
# tests/vm/nested-bar.sh. Seguro: NUNCA --replace, HOME/XDG temporales,
# sin root, sin instalaciones.
# Uso: bash tests/vm/nested-osd.sh [--out spikes/nested] [--timeout 60] [--bin /ruta/nimbus-bar]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
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

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-osd-XXXXXX)"
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
export WAYLAND_DISPLAY="nimbus-osd-test"
LOG="$OUT_ABS/nested-osd.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-osd.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-osd-test" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[osd] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[osd] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
BAR_LOG="$OUT_ABS/nested-osd-bar.log"
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
# Sin esto, este Qt no emite qInfo/qWarning a stderr (quirk F3-T05-fix) y
# el log de la barra quedaría vacío aunque haya errores QML.
export QT_FORCE_STDERR_LOGGING=1
trap "kill \$(jobs -p) 2>/dev/null || true" EXIT

echo "[osd] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --no-lockscreen --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!

for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[osd] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[osd] socket OK" | tee -a "$LOG"
sleep 2

echo "[osd] arranque plasmashell (fondo) ..." | tee -a "$LOG"
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 10

echo "[osd] canales reales en nested (lectura o gap):" | tee -a "$LOG"
echo "[osd] wpctl: $(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>&1 || echo SIN-WPCTL)" | tee -a "$LOG"
echo "[osd] pactl: $(pactl get-sink-volume @DEFAULT_SINK@ 2>&1 | head -1 || echo SIN-PACTL)" | tee -a "$LOG"
echo "[osd] brightnessctl: $(brightnessctl -m 2>&1 | head -1 || echo SIN-BRIGHTNESSCTL)" | tee -a "$LOG"
echo "[osd] sysfs: $(ls -d /sys/class/backlight/* 2>&1 || echo SIN-SYSFS)" | tee -a "$LOG"

echo "[osd] arranque nimbus-bar --demo-osd volume ..." | tee -a "$LOG"
# stdbuf: el log a fichero se pierde si el proceso muere con buffer sin vaciar.
stdbuf -o0 -e0 "$BAR_BIN" --demo-osd volume >>"$BAR_LOG" 2>&1 &
BAR_PID=$!
sleep 4
if kill -0 $BAR_PID 2>/dev/null; then echo "[osd] nimbus-bar VIVO pid=$BAR_PID" | tee -a "$LOG";
else echo "[osd] ERROR: nimbus-bar muerto" | tee -a "$LOG"; tail -20 "$BAR_LOG" | tee -a "$LOG"; fi

echo "[osd] servicio DBus org.nimbus.OSD:" | tee -a "$LOG"
for ((i=0; i<20; i++)); do
  qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show volume 0.7 >>"$BAR_LOG" 2>&1 && break
  sleep 0.5
done
qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show volume 0.7 >>"$LOG" 2>&1 \
  && echo "[osd] DBus show volume OK" | tee -a "$LOG" \
  || echo "[osd] ERROR: DBus show volume fallo" | tee -a "$LOG"
sleep 1
spectacle -b -n -o "$OUT_ABS/f3-osd-volume.png" >>"$LOG" 2>&1 \
  && echo "[osd] f3-osd-volume.png OK" | tee -a "$LOG" \
  || echo "[osd] WARN: captura volumen fallo" | tee -a "$LOG"

qdbus6 org.nimbus.OSD /OSD org.nimbus.OSD.show brightness 0.6 >>"$LOG" 2>&1 \
  && echo "[osd] DBus show brightness OK" | tee -a "$LOG" \
  || echo "[osd] ERROR: DBus show brightness fallo" | tee -a "$LOG"
sleep 1
spectacle -b -n -o "$OUT_ABS/f3-osd-brightness.png" >>"$LOG" 2>&1 \
  && echo "[osd] f3-osd-brightness.png OK" | tee -a "$LOG" \
  || echo "[osd] WARN: captura brillo fallo" | tee -a "$LOG"

echo "[osd] errores QML/bar (si vacio = limpio):" | tee -a "$LOG"
grep -ai "error\|warning\|qml.*fail\|cannot\|no se pudo" "$BAR_LOG" | grep -av "no se pudo registrar" | tee -a "$LOG" || echo "[osd] sin errores QML" | tee -a "$LOG"

ls -la "$OUT_ABS"/f3-osd-*.png >>"$LOG" 2>&1
echo "$KWIN_PID $PLASMA_PID $BAR_PID" > "$PIDFILE"
echo "[osd] FIN." | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[osd] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
