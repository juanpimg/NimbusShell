#!/usr/bin/env bash
# F4-T07 nested: verifica kwinrulesrc (kate/konsole/dolphin 1100x700
# centradas, dialogo sin maximizar, maximizar manual OK).
# Seguro en host: sin root, sin instalar, sin ~/.config real, sin --replace.
# Todo en HOME/XDG temporales bajo dbus-run-session, cleanup por trap.
# KWin 6.8 vuelca su log a journald (no a stdout): las medidas de los
# scripts KWin (print N4*) se recogen con journalctl filtrando por PID.
# Uso: bash tests/vm/nested-f4rules.sh [--out spikes/nested] [--timeout 60] [--baseline]
#   --baseline: despliega los dotfiles plasma SIN kwinrulesrc (geometrias por defecto).
set -u
OUT_DIR="spikes/nested"
TIMEOUT=60
BASELINE=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --baseline) BASELINE="yes" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f4rules-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
for f in "$REPO_ROOT/dotfiles/.config/plasma/"*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  if [ -n "$BASELINE" ] && [ "$(basename "$f")" = "kwinrulesrc" ]; then continue; fi
  cp -f "$f" "$NESTED_HOME/.config/"
done
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data" XDG_CACHE_HOME="$BASE_TMP/cache" XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
TAG="rules"; [ -n "$BASELINE" ] && TAG="baseline"
PNG="$OUT_ABS/f4-rules-$TAG.png"
LOG="$OUT_ABS/f4-rules-$TAG.log"
: > "$LOG"
MEASURE="$BASE_TMP/measure.js"
cat > "$MEASURE" <<'EOF'
print("N4HELLO start");
try {
    var wins = workspace.windowList();
    print("N4COUNT " + wins.length);
    for (var i = 0; i < wins.length; i++) {
        try {
            var w = wins[i];
            var cls = "?";
            try { cls = w.resourceClass; } catch (e1) {}
            var g = w.frameGeometry;
            print("N4GEOM caption=" + (w.caption || "").substring(0, 42) + " | class=" + cls
                + " | normal=" + w.normalWindow + " | x=" + g.x + " y=" + g.y
                + " w=" + g.width + " h=" + g.height);
        } catch (e2) { print("N4ERR win " + i + ": " + e2); }
    }
} catch (e3) { print("N4ERR global: " + e3); }
print("N4HELLO end");
EOF
FOCUS="$BASE_TMP/focus-konsole.js"
cat > "$FOCUS" <<'EOF'
var wins = workspace.windowList();
for (var i = 0; i < wins.length; i++) {
    var cls = "";
    try { cls = wins[i].resourceClass; } catch (e) {}
    if (wins[i].normalWindow && cls.indexOf("konsole") !== -1) {
        workspace.activeWindow = wins[i];
        print("N4FOCUS konsole activa");
    }
}
EOF
cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-f4rules" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
  sleep 1
  # Huerfanos activados por dbus (portales/kded/kwallet): no son jobs del
  # inner bash; se matan por env exacto (BASE_TMP es unico por run).
  for p in /proc/[0-9]*; do
    p="${p#/proc/}"
    if tr '\0' ' ' < /proc/"$p"/environ 2>/dev/null | grep -qF "$BASE_TMP"; then
      kill "$p" 2>/dev/null || true
    fi
  done
  sleep 1
  fusermount -u "$RUNTIME_DIR/doc" 2>/dev/null || true
  rm -rf "$BASE_TMP" 2>/dev/null || echo "[f4rules] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
echo "[f4rules] kreadconfig6 (HOME temporal):" | tee "$LOG"
for k in count rules; do echo "  General/$k=$(kreadconfig6 --file kwinrulesrc --group General --key $k 2>>"$LOG")" | tee -a "$LOG"; done
dbus-run-session -- bash -c '
set -u
export HOME="'"$NESTED_HOME"'" XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'" XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'" XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'" XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="nimbus-f4rules" XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
export QT_LOGGING_RULES="kwin_core.debug=true"
TIMEOUT="'"$TIMEOUT"'" LOG="'"$LOG"'" PNG="'"$PNG"'" MEASURE="'"$MEASURE"'" FOCUS="'"$FOCUS"'" TAG="'"$TAG"'"
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
kscript() { # $1=js $2=nombre: loadScript->Script<id>.run->unload (print va a journald)
  local id
  id=$(timeout 30 qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$1" "$2" 2>>"$LOG") || { echo "[f4rules] WARN: loadScript $2 fallo" | tee -a "$LOG"; return 1; }
  timeout 30 qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run >>"$LOG" 2>&1 || echo "[f4rules] WARN: run $2/$id fallo" | tee -a "$LOG"
  sleep 1
  timeout 30 qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$2" >>"$LOG" 2>&1 || true
}
collect() { # vuelca lineas N4* del kwin anidado (por PID) al LOG
  sleep 2
  journalctl --user _PID="$KWINPID" --since=-5min 2>/dev/null | grep -a -E "N4(HELLO|COUNT|GEOM|ERR|SET|FOCUS)" | tail -12 | tee -a "$LOG"
}
echo "[f4rules] arranque kwin (--no-lockscreen: la sesion nested arranca bloqueada por defecto) ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --no-lockscreen --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWINPID=$!
for ((i=0; i<TIMEOUT*2; i++)); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[f4rules] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
echo "[f4rules] kwin pid=$KWINPID" | tee -a "$LOG"
( while true; do
    timeout 10 qdbus6 org.kde.screensaver /ScreenSaver org.freedesktop.ScreenSaver.SimulateUserActivity >/dev/null 2>&1 || true
    sleep 15
  done ) &
echo "[f4rules] anti-idle SimulateUserActivity cada 15s" | tee -a "$LOG"
sleep 2
plasmashell >>"$LOG" 2>&1 &
sleep 3
kate >>"$LOG" 2>&1 &
sleep 2
konsole >>"$LOG" 2>&1 &
sleep 2
dolphin >>"$LOG" 2>&1 &
sleep 2
kdialog --msgbox "Nimbus F4-T07: dialogo de prueba" >>"$LOG" 2>&1 &
sleep 14
for round in 1 2; do
  echo "[f4rules] medida $round (kate/konsole/dolphin esperan 1100x700 centradas):" | tee -a "$LOG"
  kscript "$MEASURE" "n4m$round"
  collect
  if [ "$round" = "1" ]; then
    echo "[f4rules] captura temprana (antes del bloqueo ~60s) ..." | tee -a "$LOG"
    timeout 60 spectacle -b -n -o "$PNG" >>"$LOG" 2>&1 && echo "[f4rules] $(basename "$PNG") OK" | tee -a "$LOG" || echo "[f4rules] WARN: spectacle fallo" | tee -a "$LOG"
  fi
  sleep 8
done
echo "[f4rules] Rule found (kwin_core debug):" | tee -a "$LOG"
journalctl --user _PID="$KWINPID" --since=-5min 2>/dev/null | grep -a "Rule found" | tee -a "$LOG" || true
echo "[f4rules] maximizar-manual konsole (accion Window Maximize):" | tee -a "$LOG"
kscript "$FOCUS" n4focus
timeout 30 qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Window Maximize" 2>&1 | tee -a "$LOG"
sleep 4
kscript "$MEASURE" n4mmax
collect
echo "[f4rules] des-maximizar (toggle):" | tee -a "$LOG"
timeout 30 qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Window Maximize" 2>&1 | tee -a "$LOG"
sleep 3
kscript "$MEASURE" n4munmax
collect
echo "[f4rules] desbloqueo + captura tardia (diagnostico) ..." | tee -a "$LOG"
timeout 10 qdbus6 org.kde.screensaver /ScreenSaver org.freedesktop.ScreenSaver.SetActive False >>"$LOG" 2>&1 || true
sleep 1
timeout 60 spectacle -b -n -o "${PNG%.png}-late.png" >>"$LOG" 2>&1 && echo "[f4rules] tardia OK" | tee -a "$LOG" || echo "[f4rules] WARN: spectacle fallo" | tee -a "$LOG"
pkill -f "kdialog.*F4-T07" 2>/dev/null || true
ls -la "$PNG" "${PNG%.png}-late.png" | tee -a "$LOG"
'
echo "[f4rules] fin ($TAG)."
