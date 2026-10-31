#!/usr/bin/env bash
# Nested lockscreen Nimbus (F10-T04): greeter REAL kscreenlocker_greet en
# modo --testing dentro de sesion anidada + captura. Seguro en host Plasma
# Wayland: NUNCA usa --replace, no toca ~/.config ni la sesion del host
# (NO loginctl: bloquearia la pantalla real del usuario), no root, no
# instala nada. Todo vive en temporales bajo dbus-run-session con cleanup.
#
# Uso: bash tests/vm/nested-lock.sh [--out spikes/nested] [--timeout 60]
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
LOG="$OUT_ABS/nested-lock.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-lock-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
XDG_DATA_HOME="$BASE_TMP/data"; mkdir -p "$XDG_DATA_HOME"
XDG_CACHE_HOME="$BASE_TMP/cache"; mkdir -p "$XDG_CACHE_HOME"
XDG_STATE_HOME="$BASE_TMP/state"; mkdir -p "$XDG_STATE_HOME"
export XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
WAYLAND_DISPLAY="nimbus-lock"

cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*$WAYLAND_DISPLAY" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[k]screenlocker_greet.*nimbus-lock" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  sleep 1
  ps -eo pid,args | grep "[k]win_wayland --virtual.*$WAYLAND_DISPLAY" | awk "{print \$1}" | xargs -r kill -9 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[lock] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

# 1. Instala el tema en el XDG_DATA_HOME temporal (solo lectura del repo).
THEME_SRC="$REPO_ROOT/packages/themes/nimbus-lockscreen"
THEME_DST="$XDG_DATA_HOME/plasma/look-and-feel/org.nimbus.desktop"
mkdir -p "$(dirname "$THEME_DST")"
cp -r "$THEME_SRC" "$THEME_DST" || { echo "ERROR: no se pudo instalar el tema (cp de $THEME_SRC)" >&2; exit 1; }
[ -f "$THEME_DST/contents/lockscreen/LockScreen.qml" ] || { echo "ERROR: LockScreen.qml ausente tras cp" >&2; exit 1; }
echo "[lock] tema instalado en $THEME_DST" | tee -a "$LOG"

# 2. Despliega dotfiles plasma (incluye kscreenlockerrc Theme=org.nimbus.desktop).
DEPLOYED=0
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
grep -q "Theme=org.nimbus.desktop" "$NESTED_HOME/.config/kscreenlockerrc" \
  || { echo "ERROR: kscreenlockerrc sin Theme=org.nimbus.desktop (reintenta tras commit F10-T04)" >&2; exit 1; }
echo "[lock] $DEPLOYED dotfiles en HOME temporal" | tee -a "$LOG"

# 3. Sesion anidada: kwin virtual + plasmashell + greeter --testing.
dbus-run-session -- bash -c '
set -u
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
LOG="'"$LOG"'"
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

kwin_wayland --virtual --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] \
  || { echo "[lock] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"; exit 1; }
echo "[lock] socket OK" | tee -a "$LOG"
sleep 2
plasmashell >>"$LOG" 2>&1 &
sleep 6
echo "[lock] arranque kscreenlocker_greet --testing ..." | tee -a "$LOG"
QT_QPA_PLATFORM=wayland /usr/lib/kscreenlocker_greet --testing --immediateLock >>"$LOG" 2>&1 &
GREET_PID=$!
sleep 5
if kill -0 $GREET_PID 2>/dev/null; then echo "[lock] greeter VIVO pid=$GREET_PID" | tee -a "$LOG";
else echo "[lock] ERROR: greeter murio (ver $LOG; reintenta con QT_LOGGING_RULES)" | tee -a "$LOG"; exit 1; fi
spectacle -b -n -o "$OUT_ABS/f10-lock.png" >>"$LOG" 2>&1 \
  && echo "[lock] f10-lock.png OK" | tee -a "$LOG" \
  || echo "[lock] WARN: spectacle fallo (intenta ScreenShot2 via qdbus6)" | tee -a "$LOG"
kill $GREET_PID 2>/dev/null || true
echo "[lock] FIN" | tee -a "$LOG"
'
RC=$?
echo "[lock] rc=$RC log=$LOG"
exit $RC
