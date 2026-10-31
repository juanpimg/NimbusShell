#!/usr/bin/env bash
# Harness Plasma anidado (sin VM): KWin virtual + plasmashell/krunner/kate.
# Seguro en host Plasma Wayland: NUNCA usa --replace, no toca ~/.config,
# no root, no instala nada. Todo vive en un XDG_RUNTIME_DIR temporal
# bajo dbus-run-session. Limpieza garantizada por trap.
#
# Uso: bash tests/vm/nested-plasma.sh [--out spikes/nested] [--timeout 60]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"

# Runtime temporal aislado (0700 lo exige Wayland). NUNCA ~/.config del host:
# se redirigen XDG_* a temporales para que plasmashell/kwin no escriban en casa.
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-nested-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_CONFIG_HOME="$BASE_TMP/config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-nested"
LOG="$OUT_ABS/nested-plasma.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested.pids"
: > "$PIDFILE"
cleanup() {
  # Mata hijos conocidos (pidfile que escribe el subshell interno) + patron
  # kwin virtual de ESTA sesion anidada. El patron usa [n] para no
  # autocoincidir con el propio pkill. No toca la sesion del host.
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-nested" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[nested] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[nested] runtime=$XDG_RUNTIME_DIR log=$LOG" | tee -a "$LOG"

# Todo lo grafico corre dentro de un bus D-Bus privado.
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
# Al salir este subshell, matar TODOS los hijos (kwin/plasmashell/krunner/kate):
# sin esto sobreviven al fin de dbus-run-session y ensucian la sesion del host.
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[nested] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
echo "$KWIN_PID" > "$OUT_ABS/.kwin.pid"

# Espera al socket del compositor anidado (sin --replace: jamas toca el KWin del host).
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[nested] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  echo "KWIN_OK=no" > "$OUT_ABS/result.env"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[nested] socket OK: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
sleep 2

echo "[nested] arranque plasmashell (sin flags: plasmashell-6 no acepta --no-startup-id) ..." | tee -a "$LOG"
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
echo "[nested] arranque krunner ..." | tee -a "$LOG"
krunner >>"$LOG" 2>&1 &
KRUNNER_PID=$!
echo "[nested] arranque kate ..." | tee -a "$LOG"
kate >>"$LOG" 2>&1 &
KATE_PID=$!
sleep 8

echo "[nested] procesos:" | tee -a "$LOG"
for p in $KWIN_PID $PLASMA_PID $KRUNNER_PID $KATE_PID; do
  if kill -0 $p 2>/dev/null; then echo "  pid $p VIVO ($(ps -o comm= -p $p 2>/dev/null))" | tee -a "$LOG";
  else echo "  pid $p MUERTO" | tee -a "$LOG"; fi
done

echo "[nested] supportInformation KWin:" | tee -a "$LOG"
qdbus6 org.kde.KWin /KWin supportInformation >>"$LOG" 2>&1 || echo "[nested] WARN: supportInformation fallo ($?)" | tee -a "$LOG"

echo "[nested] captura spectacle ..." | tee -a "$LOG"
if spectacle -b -n -o "$OUT_ABS/nested-plasma.png" >>"$LOG" 2>&1; then
  echo "[nested] spectacle OK" | tee -a "$LOG"
else
  echo "[nested] WARN: spectacle fallo ($?). Intento via org.kde.KWin.ScreenShot2 (qdbus6) — ver log." | tee -a "$LOG"
  qdbus6 org.kde.KWin /Screenshot org.kde.kwin.Screenshot.captureScreenshot 2>>"$LOG" || true
fi
ls -la "$OUT_ABS" >>"$LOG" 2>&1
echo "$KWIN_PID $PLASMA_PID $KRUNNER_PID $KATE_PID" > "$PIDFILE"
echo "KWIN_PID=$KWIN_PID PLASMA_PID=$PLASMA_PID KRUNNER_PID=$KRUNNER_PID KATE_PID=$KATE_PID" > "$OUT_ABS/result.env"
echo "[nested] FIN. Ver $OUT_ABS/nested-plasma.png" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[nested] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
