#!/usr/bin/env bash
# nested-theme.sh (F3-T11): demo de switch claro/oscuro EN VIVO en Plasma
# anidado, sin reiniciar plasmashell. Seguro en host Plasma Wayland: todo
# vive en un HOME/XDG_RUNTIME temporal bajo dbus-run-session; NUNCA usa
# --replace, no toca ~/.config real, no root, no instala nada.
#
# Flujo: kwin virtual + plasmashell + kate → `nimbus-theme light` (LIVE=1,
# misma sesión) + captura → `nimbus-theme dark` + captura → verifica
# ColorScheme con kreadconfig6 y que el PID de plasmashell no cambió.
#
# Uso: bash tests/vm/nested-theme.sh [--out spikes/nested] [--timeout 120]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=120
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    -h|--help) echo "Uso: bash tests/vm/nested-theme.sh [--out $OUT_DIR] [--timeout $TIMEOUT]"; exit 0 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/nested-theme.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-theme-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/"
done
# Anti-bloqueo: la demo dura minutos sin input; sin esto kscreenlocker
# tapa las capturas (medido en la primera pasada).
kwriteconfig6 --file "$NESTED_HOME/.config/kscreenlockerrc" \
  --group Daemon --key Autolock false
kwriteconfig6 --file "$NESTED_HOME/.config/kscreenlockerrc" \
  --group Daemon --key LockOnResume false
echo "home-temporal=$NESTED_HOME" | tee -a "$LOG"

cleanup() {
  local p
  for p in $(cat "$OUT_ABS/.nested-theme.pids" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
  sleep 1
  for p in $(cat "$OUT_ABS/.nested-theme.pids" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  rm -rf "$BASE_TMP" || echo "WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
: > "$OUT_ABS/.nested-theme.pids"

export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_CONFIG_HOME="$BASE_TMP/config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

cat > "$BASE_TMP/inner.sh" <<'INNER'
set -u
export HOME="__NH__"
export XDG_RUNTIME_DIR="__RT__"
export XDG_CONFIG_HOME="__NH__/.config"
export XDG_DATA_HOME="__DT__"
export XDG_CACHE_HOME="__CH__"
export XDG_STATE_HOME="__SH__"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="__WD__"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export PATH="__REPO__/scripts:$PATH"
OUT_ABS="__OUT__"
PIDFILE="__PIDF__"
LOG="__LOG__"
THEME="__REPO__/scripts/nimbus-theme"
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "__WD__" --xwayland >>"$LOG" 2>&1 &
for ((i=0; i<120; i++)); do
  if [ -e "$XDG_RUNTIME_DIR/__WD__" ]; then break; fi
  sleep 0.5
done
[ -e "$XDG_RUNTIME_DIR/__WD__" ] || { echo "ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
echo "$PLASMA_PID" >> "$PIDFILE"
kate >>"$LOG" 2>&1 &
echo "$!" >> "$PIDFILE"
sleep 6
echo "PLASMA_PID=$PLASMA_PID" | tee -a "$LOG"
echo "greeters tras arranque: $(pgrep -c -f "[k]screenlocker_greet" || true)" | tee -a "$LOG"
# NOTA: no matar el greeter: KWin muestra "bloqueador dañado" si está
# bloqueado sin greeter vivo. Solo se registra su presencia.
qdbus6 org.freedesktop.ScreenSaver /ScreenSaver \
  org.freedesktop.ScreenSaver.Inhibit "nested-theme" "demo sin bloqueo" >>"$LOG" 2>&1 || true
# Anti-idle: sin input físico el Timeout del kscreenlocker taparía las
# capturas; se simula actividad cada 5 s hasta que muera plasmashell.
( while kill -0 "$PLASMA_PID" 2>/dev/null; do
    qdbus6 org.freedesktop.ScreenSaver /ScreenSaver \
      org.freedesktop.ScreenSaver.SimulateUserActivity >/dev/null 2>&1 || true
    sleep 5
  done ) &

echo "=== switch light (en vivo) ===" | tee -a "$LOG"
"$THEME" light 2>&1 | tee -a "$LOG"
echo "greeters tras light: $(pgrep -c -f "[k]screenlocker_greet" || true)" | tee -a "$LOG"
sleep 3
CS1="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
echo "ColorScheme tras light: $CS1" | tee -a "$LOG"
echo "locked antes shot-light: $(qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>&1)" | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-theme-live-light.png" >>"$LOG" 2>&1 \
  && echo "shot light OK" | tee -a "$LOG" || echo "WARN: shot light fallo" | tee -a "$LOG"

echo "=== switch dark (en vivo, sin reinicio) ===" | tee -a "$LOG"
"$THEME" dark 2>&1 | tee -a "$LOG"
echo "greeters tras dark: $(pgrep -c -f "[k]screenlocker_greet" || true)" | tee -a "$LOG"
sleep 3
CS2="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
echo "ColorScheme tras dark: $CS2" | tee -a "$LOG"
echo "locked antes shot-dark: $(qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.GetActive 2>&1)" | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-theme-live-dark.png" >>"$LOG" 2>&1 \
  && echo "shot dark OK" | tee -a "$LOG" || echo "WARN: shot dark fallo" | tee -a "$LOG"

if kill -0 "$PLASMA_PID" 2>/dev/null; then
  echo "PLASMA_ALIVE pid=$PLASMA_PID (0 reinicios)" | tee -a "$LOG"
else
  echo "ERROR: plasmashell murio (pid $PLASMA_PID)" | tee -a "$LOG"
  exit 1
fi
echo "CS_LIGHT=$CS1 CS_DARK=$CS2" | tee -a "$LOG"
[ "$CS1" = "NimbusTahoeLight" ] && [ "$CS2" = "NimbusTahoe" ] \
  && echo "SWITCH_OK" | tee -a "$LOG" || { echo "SWITCH_FAIL" | tee -a "$LOG"; exit 1; }
INNER

WD="nimbus-theme"
sed -i -e "s#__NH__#$NESTED_HOME#g" -e "s#__RT__#$RUNTIME_DIR#g" \
  -e "s#__DT__#$XDG_DATA_HOME#g" -e "s#__CH__#$XDG_CACHE_HOME#g" \
  -e "s#__SH__#$XDG_STATE_HOME#g" -e "s#__WD__#$WD#g" \
  -e "s#__REPO__#$REPO_ROOT#g" -e "s#__OUT__#$OUT_ABS#g" \
  -e "s#__PIDF__#$OUT_ABS/.nested-theme.pids#g" -e "s#__LOG__#$LOG#g" \
  "$BASE_TMP/inner.sh"
bash -n "$BASE_TMP/inner.sh"

# Sin pipe a tail: los nietos del bus (portales, kded) heredan stdout y el
# pipe no vería EOF nunca (colgó la primera pasada). Log a fichero + tail.
# El greeter de kscreenlocker es inestable en kwin virtual bajo carga
# (pantalla "bloqueador dañado"); se reintenta la demo hasta 3 veces con
# puertas de brillo (rechaza capturas casi negras).
shot_ok() {
  python3 - "$OUT_ABS/f3-theme-live-light.png" "$OUT_ABS/f3-theme-live-dark.png" <<'PYEOF' 2>/dev/null
import sys
from PIL import Image, ImageStat
for p in sys.argv[1:]:
    m = ImageStat.Stat(Image.open(p).convert("L")).mean[0]
    print(p, round(m, 1))
    if m < 40:
        sys.exit(1)
PYEOF
}
ATTEMPT=0
RC=1
while [ "$ATTEMPT" -lt 3 ] && [ "$RC" != "0" ]; do
  ATTEMPT=$((ATTEMPT+1))
  echo "intento $ATTEMPT/3" | tee -a "$LOG"
  rm -f "$OUT_ABS/f3-theme-live-light.png" "$OUT_ABS/f3-theme-live-dark.png"
  if dbus-run-session -- bash "$BASE_TMP/inner.sh" >>"$LOG" 2>&1 \
     && [ -f "$OUT_ABS/f3-theme-live-light.png" ] \
     && [ -f "$OUT_ABS/f3-theme-live-dark.png" ] \
     && shot_ok >>"$LOG" 2>&1; then
    RC=0
  else
    echo "intento $ATTEMPT no válido (switch o capturas), reintentando..." | tee -a "$LOG"
    RC=1
  fi
done
tail -20 "$LOG"
echo "rc=$RC intentos=$ATTEMPT log: $LOG"
exit "$RC"
