#!/usr/bin/env bash
# Harness nested para nimbus-bar F3-T07 (tray SNI): KWin virtual +
# plasmashell (watcher SNI real) + 2 fake-sni (items A/B con IconPixmap
# y menú dbusmenu) + nimbus-bar --tray-open-menu (abre el menú del item 0).
# Seguro: NUNCA --replace, HOME/XDG temporales, sin root, sin instalaciones.
# Uso: bash tests/sni/nested-tray.sh [--out spikes/nested] [--timeout 60]
#      [--bin /tmp/nimbus-bar-f3tray/bin/nimbus-bar] [--fake /tmp/fake-sni]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
BAR_BIN="/tmp/nimbus-bar-f3tray/bin/nimbus-bar"
FAKE_BIN="/tmp/fake-sni"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BAR_BIN="${!j}" ;;
    --fake) j=$((i+1)); FAKE_BIN="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-tray-XXXXXX)"
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
# Anti-locker: enmascara el screensaver en el bus de la sesión anidada
# (kscreenlocker_greet --immediateLock se auto-activa al arrancar y
# arruina la captura; HOME temporal, sin efecto en el host).
mkdir -p "$XDG_DATA_HOME/dbus-1/services"
printf '[D-BUS Service]\nName=org.kde.screensaver\nExec=/bin/false\n' \
  > "$XDG_DATA_HOME/dbus-1/services/org.kde.screensaver.service"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-tray-test"
LOG="$OUT_ABS/nested-tray.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-tray.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-tray-test" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[tray] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[tray] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN fake=$FAKE_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
FAKE_BIN="'"$FAKE_BIN"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
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
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[tray] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[tray] ERROR: sin socket" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2

echo "[tray] arranque plasmashell (watcher SNI) ..." | tee -a "$LOG"
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 8
qdbus6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher.ProtocolVersion >>"$LOG" 2>&1 \
  && echo "[tray] watcher OK" | tee -a "$LOG" \
  || echo "[tray] WARN: sin watcher" | tee -a "$LOG"

echo "[tray] arranque fake-sni A + B ..." | tee -a "$LOG"
"$FAKE_BIN" --service org.nimbus.FakeSniA --title "Nimbus A" --letter A >>"$LOG" 2>&1 &
FAKEA_PID=$!
"$FAKE_BIN" --service org.nimbus.FakeSniB --title "Nimbus B" --letter B >>"$LOG" 2>&1 &
FAKEB_PID=$!
sleep 3
echo "[tray] items registrados:" | tee -a "$LOG"
qdbus6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems 2>>"$LOG" | tee -a "$LOG"

echo "[tray] arranque nimbus-bar --tray-open-menu ..." | tee -a "$LOG"
"$BAR_BIN" --tray-open-menu >>"$LOG" 2>&1 &
BAR_PID=$!
sleep 6
if kill -0 $BAR_PID 2>/dev/null; then echo "[tray] nimbus-bar VIVO pid=$BAR_PID" | tee -a "$LOG";
else echo "[tray] ERROR: nimbus-bar muerto" | tee -a "$LOG"; fi

echo "[tray] captura CON tray + menu ..." | tee -a "$LOG"
# Salvaguarda anti-bloqueo: si logind bloqueó la sesión anidada
# (kscreenlocker_greet --immediateLock), se intenta desbloquear.
qdbus6 org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity >>"$LOG" 2>&1 || true
qdbus6 org.kde.screensaver /ScreenSaver org.kde.screensaver.setActive false >>"$LOG" 2>&1 || true
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-tray.png" >>"$LOG" 2>&1 \
  && echo "[tray] f3-tray.png OK" | tee -a "$LOG" \
  || echo "[tray] WARN: captura fallo" | tee -a "$LOG"

echo "[tray] Activate directo al item A (verifica metodo SNI) ..." | tee -a "$LOG"
qdbus6 org.nimbus.FakeSniA /StatusNotifierItem org.kde.StatusNotifierItem.Activate 0 0 >>"$LOG" 2>&1
sleep 1
echo "[tray] Event directo al menu A id=1 ..." | tee -a "$LOG"
qdbus6 org.nimbus.FakeSniA /Menu com.canonical.dbusmenu.Event 1 clicked variant:string: 0 >>"$LOG" 2>&1 || \
  qdbus6 org.nimbus.FakeSniA /Menu com.canonical.dbusmenu.Event 1 clicked "" 0 >>"$LOG" 2>&1 || true
sleep 1
grep -a "fake-sni" "$LOG" | tee -a "$LOG"

ls -la "$OUT_ABS"/f3-tray.png >>"$LOG" 2>&1
echo "$KWIN_PID $PLASMA_PID $FAKEA_PID $FAKEB_PID" > "$PIDFILE"
kill $BAR_PID 2>/dev/null || true
echo "[tray] FIN." | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[tray] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
