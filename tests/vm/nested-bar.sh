#!/usr/bin/env bash
# Harness nested para nimbus-bar (F3-T03): KWin virtual + plasmashell
# (fondo) + kate (cliente normal) + nimbus-bar. Replica tests/vm/nested-plasma.sh.
# Seguro: NUNCA --replace, HOME/XDG temporales, sin root, sin instalaciones.
# Uso: bash tests/vm/nested-bar.sh [--out spikes/nested] [--timeout 60] [--bin /ruta/nimbus-bar]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
BAR_BIN="/tmp/nimbus-bar-prefix/bin/nimbus-bar"
WALLPAPER=""
SOCKET="nimbus-bar-test"
BAR_ARGS=""
KWINRC=""
PLUGIN_PATH=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BAR_BIN="${!j}" ;;
    # F11-T02: fondo de alto contraste para probar blur de verdad.
    --wallpaper) j=$((i+1)); WALLPAPER="${!j}" ;;
    # Socket único: permite dos harness en paralelo sin matarse.
    --socket) j=$((i+1)); SOCKET="${!j}" ;;
    # Argumentos del binario (p. ej. --demo-cc --open-cc --demo-media).
    --bar-args) j=$((i+1)); BAR_ARGS="${!j}" ;;
    # F11-T02: kwinrc de prueba (Glass) y plugins extra para KWin.
    --kwinrc) j=$((i+1)); KWINRC="${!j}" ;;
    --plugin-path) j=$((i+1)); PLUGIN_PATH="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-bar-XXXXXX)"
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
export WAYLAND_DISPLAY="$SOCKET"
LOG="$OUT_ABS/nested-bar.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-bar.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # Solo se matan los PID de ESTA ejecución (ver PIDFILE). Nunca por patrón:
  # dos harness concurrentes en worktrees distintas se mataban entre sí.
  rm -rf "$BASE_TMP" || echo "[bar] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[bar] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
BAR_ARGS="'"$BAR_ARGS"'"
KWINRC="'"$KWINRC"'"
PLUGIN_PATH="'"$PLUGIN_PATH"'"
WALLPAPER="'"$WALLPAPER"'"
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
if [ -n "$PLUGIN_PATH" ]; then
  export QT_PLUGIN_PATH="$PLUGIN_PATH:$QT_PLUGIN_PATH"
fi
if [ -n "$KWINRC" ] && [ -f "$KWINRC" ]; then
  mkdir -p "$XDG_CONFIG_HOME"
  cp "$KWINRC" "$XDG_CONFIG_HOME/kwinrc"
  echo "[bar] kwinrc de prueba: $KWINRC" | tee -a "$LOG"
fi
trap "kill \$(jobs -p) 2>/dev/null || true" EXIT

echo "[bar] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --no-lockscreen --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
echo "$KWIN_PID" >> "$PIDFILE"

for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[bar] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[bar] socket OK" | tee -a "$LOG"
sleep 2
# Diagnóstico F11-T02: ¿el compositor anuncia blur al cliente?
if command -v wayland-info >/dev/null 2>&1; then
  echo "[bar] globals wayland (blur):" | tee -a "$LOG"
  wayland-info 2>/dev/null | grep -iE "background_effect|blur|contrast" | tee -a "$LOG"
fi
echo "[bar] efectos KWin cargados:" | tee -a "$LOG"
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadedEffects >>"$LOG" 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectSupported blur >>"$LOG" 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded glass >>"$LOG" 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectSupported glass >>"$LOG" 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect glass >>"$LOG" 2>&1 || true

echo "[bar] arranque plasmashell (fondo) + kate (cliente normal) ..." | tee -a "$LOG"
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
echo "$PLASMA_PID" >> "$PIDFILE"
kate >>"$LOG" 2>&1 &
KATE_PID=$!
echo "$KATE_PID" >> "$PIDFILE"
sleep 10

if [ -n "$WALLPAPER" ]; then
  if [ -f "$WALLPAPER" ]; then
    echo "[bar] fondo de alto contraste: $WALLPAPER" | tee -a "$LOG"
    plasma-apply-wallpaperimage "$WALLPAPER" >>"$LOG" 2>&1 \
      && echo "[bar] wallpaper OK" | tee -a "$LOG" \
      || echo "[bar] WARN: wallpaper fallo" | tee -a "$LOG"
    sleep 3
  else
    echo "[bar] WARN: --wallpaper no existe: $WALLPAPER" | tee -a "$LOG"
  fi
fi

PROBE_JS="$OUT_ABS/probe.js"
PROBE_MONLOG="$OUT_ABS/probe-dbus.log"
: > "$PROBE_MONLOG"
# Canal de salida de los scripts KWin: callDBus -> dbus-monitor (print()
# de scripts cargados por D-Bus no llega al stdout de kwin). El monitor
# captura solo interface org.nimbus.Probe.
dbus-monitor "type='method_call',interface='org.nimbus.Probe'" >>"$PROBE_MONLOG" 2>&1 &
MON_PID=$!
echo "$MON_PID" >> "$PIDFILE"
sleep 1

write_probe() {
  local mode="$1"
  cat > "$PROBE_JS" <<EOF
function rep(s) { callDBus("org.nimbus.Probe", "/Probe", "org.nimbus.Probe", "report", s); }
function findKate() {
    var wl = workspace.windowList();
    for (var i = 0; i < wl.length; i++) {
        if (wl[i].caption.indexOf("Kate") >= 0 || wl[i].caption.indexOf("Bienvenido") >= 0) return wl[i];
    }
    return null;
}
var MODE = "$mode";
try {
    if (MODE == "active") {
        var aw = workspace.activeWindow;
        rep("NIMBUS active=" + (aw ? aw.caption : "(none)"));
    } else if (MODE == "max") {
        var k = findKate();
        if (k) { k.setMaximize(true, true); rep("NIMBUS max-ok caption=" + k.caption); }
        else rep("NIMBUS max-FAIL kate-no-encontrado");
    } else if (MODE == "geom") {
        var k2 = findKate();
        if (k2) rep("NIMBUS geom x=" + k2.x + " y=" + k2.y + " w=" + k2.width + " h=" + k2.height + " caption=" + k2.caption);
        else rep("NIMBUS geom-FAIL kate-no-encontrado");
    } else if (MODE == "restore") {
        var k3 = findKate();
        if (k3) { k3.setMaximize(false, false); rep("NIMBUS restore-ok"); }
        else rep("NIMBUS restore-FAIL");
    }
} catch (err) { rep("NIMBUS " + MODE + "-ERR " + err); }
EOF
}
run_probe() {
  local mode="$1"
  write_probe "$mode"
  local id
  id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$PROBE_JS" "nimbus-$mode" 2>>"$LOG") || { echo "[bar] WARN: loadScript $mode fallo" | tee -a "$LOG"; return 0; }
  qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >>"$LOG" 2>&1 || echo "[bar] WARN: run probe-$mode rc=$?" | tee -a "$LOG"
  sleep 1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "nimbus-$mode" >>"$LOG" 2>&1 || true
  sleep 1
}

echo "[bar] probe ANTES de la barra (foco) ..." | tee -a "$LOG"
run_probe "active"

echo "[bar] arranque nimbus-bar ..." | tee -a "$LOG"
# shellcheck disable=SC2086  # BAR_ARGS es una lista deliberada
"$BAR_BIN" $BAR_ARGS >>"$LOG" 2>&1 &
BAR_PID=$!
echo "$BAR_PID" >> "$PIDFILE"
sleep 4
if kill -0 $BAR_PID 2>/dev/null; then echo "[bar] nimbus-bar VIVO pid=$BAR_PID" | tee -a "$LOG";
else echo "[bar] ERROR: nimbus-bar muerto" | tee -a "$LOG"; fi

echo "[bar] probe DESPUES de la barra (foco) ..." | tee -a "$LOG"
run_probe "active"

echo "[bar] captura CON barra (kate flotante) ..." | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-bar-24.png" >>"$LOG" 2>&1 \
  && echo "[bar] f3-bar-24.png OK" | tee -a "$LOG" \
  || echo "[bar] WARN: captura con barra fallo" | tee -a "$LOG"

echo "[bar] maximizo kate (placement) ..." | tee -a "$LOG"
run_probe "max"
sleep 2
run_probe "geom"

echo "[bar] captura CON barra (kate maximizado) ..." | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-bar-24-max.png" >>"$LOG" 2>&1 \
  && echo "[bar] f3-bar-24-max.png OK" | tee -a "$LOG" \
  || echo "[bar] WARN: captura max fallo" | tee -a "$LOG"

echo "[bar] restauro kate, mato barra, captura SIN barra (diff) ..." | tee -a "$LOG"
run_probe "restore"
sleep 2
kill $BAR_PID 2>/dev/null || true
sleep 3
spectacle -b -n -o "$OUT_ABS/f3-bar-nobar.png" >>"$LOG" 2>&1 \
  && echo "[bar] f3-bar-nobar.png OK" | tee -a "$LOG" \
  || echo "[bar] WARN: captura sin barra fallo" | tee -a "$LOG"

kill $MON_PID 2>/dev/null || true
echo "[bar] resultados sonda:" | tee -a "$LOG"
grep -a "string \"NIMBUS" "$PROBE_MONLOG" | tee -a "$LOG"

ls -la "$OUT_ABS"/f3-bar*.png >>"$LOG" 2>&1
echo "[bar] FIN." | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[bar] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
