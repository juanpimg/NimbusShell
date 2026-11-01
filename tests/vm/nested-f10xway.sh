#!/usr/bin/env bash
# F10-T06 nested: XWayland + apps legacy (matriz de 8).
# Patron tests/vm/nested-f10apps.sh: HOME/XDG temporales, dbus-run-session,
# kwin_wayland --virtual --no-lockscreen --xwayland. NUNCA --replace,
# ~/.config del host, root ni red. Limpieza por trap.
# Simula la sesion real exportando dotfiles/.config/environment.d/
# 90-nimbus.conf (environment.d lo lee systemd al login; aqui se hace
# `set -a; . fichero` para heredar las mismas 6 variables).
# Uso: bash tests/vm/nested-f10xway.sh [--out spikes/nested] [--timeout 180]
set -u
OUT_DIR="spikes/nested"
TIMEOUT=180
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f10xway-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NH="$BASE_TMP/home"
mkdir -p "$NH/.config" "$BASE_TMP/cache" "$BASE_TMP/state"
LOG="$OUT_ABS/f10-xway-nested.log"
: > "$LOG"
cleanup() {
  ps -eo pid,args | grep "[k]win_wayland --virtual.*f10xway-sock" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[f10xway] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
# Despliegue dotfiles reales al HOME temporal (solo lectura del repo).
cp -f "$REPO_ROOT/dotfiles/.config/plasma/kwinrc" "$NH/.config/" 2>>"$LOG" || echo "[f10xway] WARN: sin kwinrc plasma" | tee -a "$LOG"
cp -f "$REPO_ROOT/dotfiles/.config/kwinrulesrc" "$NH/.config/"
cp -f "$REPO_ROOT/dotfiles/.config/dolphinrc" "$REPO_ROOT/dotfiles/.config/konsolerc" "$NH/.config/" 2>>"$LOG" || true
mkdir -p "$NH/.config/environment.d"
cp -f "$REPO_ROOT/dotfiles/.config/environment.d/90-nimbus.conf" "$NH/.config/environment.d/"
mkdir -p "$NH/F10test"; : > "$NH/F10test/doc.txt"
cp -f "$REPO_ROOT/assets/sequoia-light.jpg" "$NH/F10test/img.jpg"
echo "[f10xway] dotfiles desplegados en $NH" | tee -a "$LOG"
# Mosaico 4x2 via KWin scripting (los --qwindowgeometry los ignoran varias
# apps; las reglas Nimbus centran a 1100x700 y se solaparian sin esto).
LAYOUT_JS="$OUT_ABS/kwin-xway-layout.js"
cat > "$LAYOUT_JS" <<'EOF'
// F10-T06: mosaico 4x2 de las ventanas normales en 1280x800.
var wins = [];
var all = workspace.windowList();
for (var i = 0; i < all.length; i++) {
    if (all[i].normalWindow && !all[i].minimized) wins.push(all[i]);
}
var cols = 4, cw = 320, ch = 380, y0 = 30;
for (var j = 0; j < wins.length && j < 8; j++) {
    wins[j].frameGeometry = {x: (j % cols) * cw, y: y0 + Math.floor(j / cols) * ch, width: cw, height: ch};
}
EOF
export XDG_RUNTIME_DIR
timeout "$TIMEOUT" dbus-run-session -- bash -c '
set -u
export HOME="'"$NH"'" XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache" XDG_STATE_HOME="'"$BASE_TMP"'/state"
# Simula environment.d de la sesion real (mismas 6 variables del dotfile).
set -a; . "$HOME/.config/environment.d/90-nimbus.conf"; set +a
export WAYLAND_DISPLAY="f10xway-sock"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="'"$LOG"'"
OUT_ABS="'"$OUT_ABS"'"
LAYOUT_JS="'"$LAYOUT_JS"'"
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
echo "[f10xway] --- env backend (desde 90-nimbus.conf) ---" | tee -a "$LOG"
for v in QT_QPA_PLATFORM ELECTRON_OZONE_PLATFORM_HINT MOZ_ENABLE_WAYLAND GDK_BACKEND CLUTTER_BACKEND SDL_VIDEODRIVER; do
  echo "  $v=${!v:-<vacia>}" | tee -a "$LOG"
done
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0;i<60;i++)); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[f10xway] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
echo "[f10xway] socket OK; DISPLAY=${DISPLAY:-<vacio>} (kwin levanta XWayland y exporta DISPLAY)" | tee -a "$LOG"
ls "$XDG_RUNTIME_DIR/.X11-unix/" 2>>"$LOG" | tee -a "$LOG" || echo "[f10xway] WARN: sin dir .X11-unix" | tee -a "$LOG"
sleep 2
launch() { # $1=nombre $2...=comando: lanza, espera, informa pid vivo/muerto
  local name="$1"; shift
  "$@" >>"$LOG" 2>&1 &
  local pid=$!
  sleep 5
  if kill -0 $pid 2>/dev/null; then echo "  $name VIVO (pid $pid)" | tee -a "$LOG";
  else echo "  $name MUERTO (pid $pid, ver log)" | tee -a "$LOG"; fi
}
echo "[f10xway] --- matriz 8 apps ---" | tee -a "$LOG"
launch kate kate
launch konsole konsole --profile Nimbus
launch dolphin dolphin --new-window "$HOME/F10test"
launch kcalc kcalc
launch gwenview gwenview "$HOME/F10test/img.jpg"
launch systemsettings systemsettings
launch firefox firefox --new-window about:blank
spectacle --version >>"$LOG" 2>&1 && echo "  spectacle VIVO (binario OK, captura abajo)" | tee -a "$LOG"
echo "[f10xway] ventanas KWin:" | tee -a "$LOG"
qdbus6 org.kde.KWin /KWin supportInformation 2>/dev/null | grep -iE "xwayland|x11|xcb" | head -n 5 | tee -a "$LOG" || echo "[f10xway] WARN: sin linea xwayland en supportInformation" | tee -a "$LOG"
echo "[f10xway] mosaico 4x2 ..." | tee -a "$LOG"
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$LAYOUT_JS" nimbus-xway >>"$LOG" 2>&1
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >>"$LOG" 2>&1
sleep 2
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript nimbus-xway >>"$LOG" 2>&1 || true
sleep 1
timeout 30 spectacle -b -n -o "$OUT_ABS/f10-xway-matrix.png" >>"$LOG" 2>&1 \
  && echo "[f10xway] f10-xway-matrix.png OK" | tee -a "$LOG" \
  || echo "[f10xway] WARN: captura matriz fallo" | tee -a "$LOG"
ls -la "$OUT_ABS/f10-xway-matrix.png" 2>>"$LOG" | tee -a "$LOG"
echo "[f10xway] FIN" | tee -a "$LOG"
kill $(jobs -p) 2>/dev/null || true
' 2>>"$LOG"
RC=$?
pkill -f "f10xway-sock" 2>/dev/null || true
echo "[f10xway] exit=$RC"
ls -la "$OUT_ABS"/f10-xway-matrix.png 2>&1
