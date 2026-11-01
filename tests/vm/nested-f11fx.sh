#!/usr/bin/env bash
# Nested F11 animaciones+glass (F11-T01/T02): KWin virtual + plasmashell/
# krunner/kate con los dotfiles Plasma del repo. Seguro en host Plasma
# Wayland: NUNCA usa --replace, no toca ~/.config ni la sesion del host
# (NO loginctl: bloquearia la pantalla real), no root, no instala nada.
# Todo vive en temporales bajo dbus-run-session con cleanup por trap.
#
# Notas de aislamiento (medidas 2026-11-01 con el host bloqueado):
# - `kwin_wayland --no-lockscreen`: el KWin anidado hereda el estado lock
#   del host y levantaba kscreenlocker_greet propio (--immediateLock);
#   el flag lo evita sin tocar la sesion del usuario.
# - Se desexportan XDG_SESSION_ID/PATH/SEAT*: impedian el espejo de lock.
#
# Uso: bash tests/vm/nested-f11fx.sh [--out spikes/nested] [--timeout 90]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=90
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/nested-f11fx.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f11fx-XXXXXX)"
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
DEPLOYED=0
PLASMA_DOTFILES="$REPO_ROOT/dotfiles/.config/plasma"
for f in "$PLASMA_DOTFILES"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
PIDFILE="$OUT_ABS/.f11fx.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-f11fx" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[f11fx] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[f11fx] home-temporal=$NESTED_HOME ($DEPLOYED ficheros plasma)" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
LOG="'"$LOG"'"
unset XDG_SESSION_ID XDG_SESSION_PATH XDG_SEAT XDG_SEAT_PATH
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-f11fx"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[f11fx] kwinrc F11 desplegado:" | tee -a "$LOG"
grep -E "^\[|Enabled=|Animation|Duration|Fade|Border" "$HOME/.config/kwinrc" | tee -a "$LOG"

echo "[f11fx] arranque kwin_wayland --virtual --no-lockscreen ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland --no-lockscreen >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[f11fx] ERROR: sin socket" | tee -a "$LOG"
  exit 1
fi
sleep 2
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
krunner >>"$LOG" 2>&1 &
KRUNNER_PID=$!
kate >>"$LOG" 2>&1 &
KATE_PID=$!
sleep 8

echo "[f11fx] inventario efectos (loaded/supported):" | tee -a "$LOG"
for e in magiclamp glide fade scale maximize blur overview squash slide translucency sheet; do
  v=$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded "$e" 2>>"$LOG") || v="rc=$?"
  s=$(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectSupported "$e" 2>>"$LOG") || s="rc=$?"
  echo "  $e=$v/$s" | tee -a "$LOG"
done

shot() { spectacle -b -n -o "$OUT_ABS/$1" >>"$LOG" 2>&1 && echo "[f11fx] $1 OK" | tee -a "$LOG" || echo "[f11fx] WARN: $1 fallo" | tee -a "$LOG"; }
kwinscript() {
  echo "$1" > "$OUT_ABS/.fx.js"
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$OUT_ABS/.fx.js" fx-run >>"$LOG" 2>&1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >>"$LOG" 2>&1
  sleep "$2"
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript fx-run >>"$LOG" 2>&1 || true
}

# --- F11-T01: reapertura (glide+scale+fade) en rafaga ---
kill $KATE_PID 2>/dev/null || true
sleep 1
kate >>"$LOG" 2>&1 &
KATE_PID=$!
shot f11-anim-open-1.png
sleep 1
shot f11-anim-open-2.png

# --- F11-T01: minimizar (Magic Lamp) + restaurar ---
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (ws2[i].normalWindow && c.indexOf(\"Kate\") !== -1) { ws.activeWindow = ws2[i]; ws2[i].minimized = true; break; } }" 0
sleep 0.15
shot f11-anim-min-flight.png
sleep 1.5
shot f11-anim-min-done.png
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = false; ws.activeWindow = ws2[i]; break; } }" 0
sleep 1
shot f11-anim-restored.png

# --- F11-T01: vuelo Magic Lamp a camara lenta (solo evidencia morfologica;
# configura 2000ms via reconfigure, captura a mitad, restaura 350ms) ---
kwriteconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration "2000" >>"$LOG" 2>&1
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect "magiclamp" >>"$LOG" 2>&1
echo "[f11fx] reconfigure magiclamp rc=$?" | tee -a "$LOG"
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (ws2[i].normalWindow && c.indexOf(\"Kate\") !== -1) { ws.activeWindow = ws2[i]; ws2[i].minimized = true; break; } }" 0
sleep 1.0
shot f11-anim-lamp-slow.png
sleep 2
shot f11-anim-lamp-slow-done.png
kwriteconfig6 --file kwinrc --group Effect-magiclamp --key AnimationDuration "350" >>"$LOG" 2>&1
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect "magiclamp" >>"$LOG" 2>&1
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = false; ws.activeWindow = ws2[i]; break; } }" 0
sleep 1

# --- F11-T01: Overview (stock; duracion via AnimationSpeed) ---
qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Overview" >>"$LOG" 2>&1
sleep 2
shot f11-anim-overview.png
qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Overview" >>"$LOG" 2>&1 || true
sleep 1

# --- F11-T02: glass sobre FONDO (kate minimizada: blur traslucido visible) ---
qdbus6 org.kde.krunner /App org.kde.krunner.App.query "kate" >>"$LOG" 2>&1
sleep 2
shot f11-glass.png
qdbus6 org.kde.krunner /App org.kde.krunner.App.toggleDisplay >>"$LOG" 2>&1 || true
sleep 1
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (ws2[i].normalWindow && c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = true; break; } }" 0
sleep 1
qdbus6 org.kde.krunner /App org.kde.krunner.App.query "kate" >>"$LOG" 2>&1
sleep 2
shot f11-glass-wallpaper.png
qdbus6 org.kde.krunner /App org.kde.krunner.App.toggleDisplay >>"$LOG" 2>&1 || true
sleep 1
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = false; ws.activeWindow = ws2[i]; break; } }" 0
sleep 1

# --- A9: reduce motion + reduce transparency (canal F8-T05), captura ---
kwriteconfig6 --file kwinrc --group Compositing --key AnimationSpeed "0" >>"$LOG" 2>&1
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled "false" >>"$LOG" 2>&1
qdbus6 org.kde.KWin /KWin reconfigure >>"$LOG" 2>&1
sleep 2
echo "[f11fx] reducido: AnimationSpeed=$(kreadconfig6 --file kwinrc --group Compositing --key AnimationSpeed 2>>"$LOG") blurEnabled=$(kreadconfig6 --file kwinrc --group Plugins --key blurEnabled 2>>"$LOG")" | tee -a "$LOG"
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (ws2[i].normalWindow && c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = true; break; } }" 0
sleep 1
qdbus6 org.kde.krunner /App org.kde.krunner.App.query "kate" >>"$LOG" 2>&1
sleep 2
shot f11-glass-reduced-wallpaper.png
qdbus6 org.kde.krunner /App org.kde.krunner.App.toggleDisplay >>"$LOG" 2>&1 || true
sleep 1
kwinscript "var ws = workspace; var ws2 = ws.windowList(); for (var i = 0; i < ws2.length; i++) { var c = ws2[i].caption || \"\"; if (c.indexOf(\"Kate\") !== -1) { ws2[i].minimized = false; ws.activeWindow = ws2[i]; break; } }" 0
sleep 1
qdbus6 org.kde.krunner /App org.kde.krunner.App.query "kate" >>"$LOG" 2>&1
sleep 2
shot f11-glass-reduced.png
qdbus6 org.kde.krunner /App org.kde.krunner.App.toggleDisplay >>"$LOG" 2>&1 || true

echo "[f11fx] crash-check:" | tee -a "$LOG"
CRASH=0
for p in $KWIN_PID $PLASMA_PID $KRUNNER_PID $KATE_PID; do
  if kill -0 $p 2>/dev/null; then echo "  pid $p VIVO ($(ps -o comm= -p $p 2>/dev/null))" | tee -a "$LOG";
  else echo "  pid $p MUERTO" | tee -a "$LOG"; CRASH=$((CRASH+1)); fi
done
echo "[f11fx] CRASHES=$CRASH" | tee -a "$LOG"
echo "$KWIN_PID $PLASMA_PID $KRUNNER_PID $KATE_PID" > "$PIDFILE"
echo "[f11fx] FIN" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[f11fx] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
