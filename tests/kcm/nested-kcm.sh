#!/usr/bin/env bash
# F8-T01 — Harness nested para el KCM Nimbus (sin VM, sin root).
# Aislado como tests/vm/nested-plasma.sh: KWin virtual + HOME/XDG temporales,
# overlay del KCM vía QT_PLUGIN_PATH/XDG_DATA_DIRS, cleanup por trap.
# NUNCA toca la sesión del host (~/.config intacto), no instala nada.
#
# Uso: bash tests/kcm/nested-kcm.sh [--out spikes/nested] [--timeout 60]
#        [--prefix /tmp/nimbus-kcm-prefix]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
PREFIX="/tmp/nimbus-kcm-prefix"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --prefix) j=$((i+1)); PREFIX="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
SHOT="$OUT_ABS/f8-kcm.png"
LOG="$OUT_ABS/f8-kcm.log"
: > "$LOG"

if [ ! -f "$PREFIX/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_nimbus.so" ]; then
  echo "ERROR: falta $PREFIX/.../kcm_nimbus.so (compila e instala primero)" | tee -a "$LOG" >&2
  exit 1
fi

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-kcm-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

cleanup() {
  local p
  for p in $(cat "$OUT_ABS/.kcm.pids" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
  sleep 1
  for p in $(cat "$OUT_ABS/.kcm.pids" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-kcm" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[kcm] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
: > "$OUT_ABS/.kcm.pids"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
SHOT="'"$SHOT"'"
LOG="'"$LOG"'"
TIMEOUT="'"$TIMEOUT"'"
PREFIX="'"$PREFIX"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME"'/.config"
export XDG_DATA_HOME="'"$NESTED_HOME"'/.local/share"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache"
export XDG_STATE_HOME="'"$BASE_TMP"'/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
# Aislar la cascada KConfig: sin esto se hereda XDG_CONFIG_DIRS del host
# (kdedefaults con Sweet) y el KCM lee tema claro (F8-T01: Sweet no es dark).
export XDG_CONFIG_DIRS="'"$BASE_TMP"'/xdg-sys"
mkdir -p "$XDG_CONFIG_DIRS"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-kcm"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export QT_PLUGIN_PATH="'"$PREFIX"'/usr/lib/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export XDG_DATA_DIRS="'"$PREFIX"'/usr/share:/usr/share"
export QML_IMPORT_PATH=/usr/lib/qt6/qml
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[kcm] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[kcm] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[kcm] socket OK" | tee -a "$LOG"
sleep 2

echo "[kcm] kbuildsycoca6 ..." | tee -a "$LOG"
kbuildsycoca6 --noincremental >>"$LOG" 2>&1 || true

# Sin bloqueo de pantalla en la sesion anidada (el greet tapa la captura).
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false >>"$LOG" 2>&1 || true
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false >>"$LOG" 2>&1 || true
# Iconos Breeze (en HOME virgen cae a hicolor y los Kirigami.Icon salen vacíos).
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze >>"$LOG" 2>&1 || true

echo "[kcm] arranque kcmshell6 kcm_nimbus ..." | tee -a "$LOG"
kcmshell6 kcm_nimbus >>"$LOG" 2>&1 &
KCM_PID=$!
sleep 6
if kill -0 $KCM_PID 2>/dev/null; then
  echo "[kcm] kcmshell6 VIVO (pid $KCM_PID)" | tee -a "$LOG"
else
  echo "[kcm] ERROR: kcmshell6 murio" | tee -a "$LOG"
fi

echo "[kcm] captura spectacle ..." | tee -a "$LOG"
# Si el greet del locker aparecio, matarlo: es sesion temporal sin secretos.
pkill -9 -f "[k]screenlocker_greet" 2>/dev/null || true
sleep 2
spectacle -b -n -o "$SHOT" >>"$LOG" 2>&1 \
  && echo "[kcm] captura OK: $SHOT" | tee -a "$LOG" \
  || echo "[kcm] WARN: spectacle fallo ($?)" | tee -a "$LOG"

echo "$KWIN_PID $KCM_PID" > "'"$OUT_ABS"'/.kcm.pids"
echo "[kcm] FIN" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[kcm] dbus-run-session exit=$RC" | tee -a "$LOG"

echo "--- errores QML en log ---" | tee -a "$LOG"
QMLERRS=$(grep -ciE "qml.*(error|no se puede|not found|no such)|TypeError|ReferenceError|is not a type|failed to load|QQmlApplicationEngine.*fail" "$LOG" || true)
echo "QML_ERRORS=$QMLERRS" | tee -a "$LOG"
ls -la "$SHOT" 2>/dev/null | tee -a "$LOG" || echo "[kcm] ERROR: sin captura" | tee -a "$LOG"
exit $RC
