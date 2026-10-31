#!/usr/bin/env bash
# Harness Plasma anidado (sin VM): KWin virtual + plasmashell/krunner/kate.
# Seguro en host Plasma Wayland: NUNCA usa --replace, no toca ~/.config,
# no root, no instala nada. Todo vive en un XDG_RUNTIME_DIR temporal
# bajo dbus-run-session. Limpieza garantizada por trap.
#
# Uso: bash tests/vm/nested-plasma.sh [--out spikes/nested] [--timeout 60]
#        [--krunner <query>] [--expose|--overview] [--home <dir>]
#        [--plasma-src <dir>] (fuente de dotfiles plasma; defecto: repo propio)
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
KRUNNER_QUERY=""
DO_EXPOSE=""
NESTED_HOME_ARG=""
PLASMA_SRC=""
KLASSY=""
KLASSY_PREFIX="/tmp/klassy-prefix"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --krunner) j=$((i+1)); KRUNNER_QUERY="${!j}" ;;
    --expose|--overview) DO_EXPOSE="yes" ;;
    --home) j=$((i+1)); NESTED_HOME_ARG="${!j}" ;;
    --plasma-src) j=$((i+1)); PLASMA_SRC="${!j}" ;;
    --klassy) KLASSY="yes" ;;
  esac
done
if [ -n "$KRUNNER_QUERY" ] && [[ ! "$KRUNNER_QUERY" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: --krunner solo admite [A-Za-z0-9._-]" >&2; exit 1
fi
# Orden del test de efectos: el flag pedido primero.
SC_LIST="Expose Overview"
for arg in "$@"; do
  if [ "$arg" = "--overview" ]; then SC_LIST="Overview Expose"; fi
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
# --home: HOME temporal para la sesion anidada. Despliega los dotfiles Plasma
# reales (excluye READMEs) a $HOME/.config y redirige XDG_CONFIG_HOME alli,
# para que plasmashell los herede. NUNCA toca el HOME del host.
NESTED_HOME="$BASE_TMP/home"
if [ -n "$NESTED_HOME_ARG" ]; then
  mkdir -p "$NESTED_HOME_ARG"
  NESTED_HOME="$NESTED_HOME_ARG"
fi
mkdir -p "$NESTED_HOME/.config"
DEPLOYED=0
PLASMA_DOTFILES="${PLASMA_SRC:-$REPO_ROOT/dotfiles/.config/plasma}"
for f in "$PLASMA_DOTFILES"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
if [ -n "$NESTED_HOME_ARG" ]; then
  XDG_CONFIG_HOME="$NESTED_HOME/.config"
  export XDG_CONFIG_HOME
fi
# --klassy: decoracion Klassy compilada en host (solo lectura). Activa la
# deco en el kwinrc del HOME temporal y expone plugin+lib+dato al nested.
FOCUS_SCRIPT=""
LAYOUT_SCRIPT=""
if [ -n "$KLASSY" ]; then
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file kwinrc \
    --group org.kde.kdecoration2 --key library org.kde.klassy
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file kwinrc \
    --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file kwinrc \
    --group org.kde.kdecoration2 --key ButtonsOnRight ""
  # Semáforos: claves reales de klassy-decoration.kcfg (solo estas).
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file klassy/klassyrc \
    --group Windeco --key ButtonShape ShapeSmallCircle
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file klassy/klassyrc \
    --group ButtonSizing --key ButtonSpacingLeft 8
  FOCUS_SCRIPT="$OUT_ABS/kwin-focus-toggle.js"
  cat > "$FOCUS_SCRIPT" <<'EOF'
// Flip de foco para el harness: activa la primera ventana normal que no
// sea la actualmente activa. Sin ydotool en el host; solo sesion anidada.
var wins = workspace.windowList();
var cur = workspace.activeWindow;
for (var i = 0; i < wins.length; i++) {
    if (wins[i] !== cur && wins[i].normalWindow && !wins[i].minimized) {
        workspace.activeWindow = wins[i];
        break;
    }
}
EOF
  LAYOUT_SCRIPT="$OUT_ABS/kwin-layout.js"
  cat > "$LAYOUT_SCRIPT" <<'EOF'
// Mosaico kate-izq/konsole-der + activa konsole (kate queda inactive
// visible). Los flags --qwindowgeometry los ignora el shell; esto no.
var wins = workspace.windowList();
var kate = null, kon = null;
for (var i = 0; i < wins.length; i++) {
    if (!wins[i].normalWindow) continue;
    var c = wins[i].caption || "";
    if (c.indexOf("Kate") !== -1) kate = wins[i];
    if (c.indexOf("Konsole") !== -1) kon = wins[i];
}
if (kate) kate.frameGeometry = {x: 10, y: 70, width: 620, height: 460};
if (kon) kon.frameGeometry = {x: 650, y: 70, width: 620, height: 460};
if (kon) workspace.activeWindow = kon;
EOF
  echo "[nested] klassy: deco=org.kde.klassy en $NESTED_HOME/.config/kwinrc" | tee -a "$LOG"
fi
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
echo "[nested] home-temporal=$NESTED_HOME ($DEPLOYED ficheros plasma desplegados desde $PLASMA_DOTFILES)" | tee -a "$LOG"

# Todo lo grafico corre dentro de un bus D-Bus privado.
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
KLASSY="'"$KLASSY"'"
KLASSY_PREFIX="'"$KLASSY_PREFIX"'"
FOCUS_SCRIPT="'"$FOCUS_SCRIPT"'"
LAYOUT_SCRIPT="'"$LAYOUT_SCRIPT"'"
TIMEOUT="'"$TIMEOUT"'"
KRUNNER_QUERY="'"$KRUNNER_QUERY"'"
DO_EXPOSE="'"$DO_EXPOSE"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
if [ -n "$KLASSY" ]; then
  export QT_PLUGIN_PATH="$KLASSY_PREFIX/lib/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
  export LD_LIBRARY_PATH="$KLASSY_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export XDG_DATA_DIRS="$KLASSY_PREFIX/share:/usr/share"
fi
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
# --- F0-T04: Expose/Overview + latencia (ANTES que krunner: el popup
# de krunner robaria foco y taparia el grid del efecto) ---
if [ -n "$DO_EXPOSE" ]; then
  EXPOSE_USED=""
  SC_LIST="'"$SC_LIST"'"
  for SC in $SC_LIST; do
    T0=$(date +%s%N)
    qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "$SC" >>"$LOG" 2>&1
    SRC=$?
    T1=$(date +%s%N)
    echo "[nested] invokeShortcut $SC rc=$SRC latencia_ms=$(( (T1-T0)/1000000 ))" | tee -a "$LOG"
    if [ $SRC -eq 0 ] && [ -z "$EXPOSE_USED" ]; then
      EXPOSE_USED="$SC"
      sleep 2
      SHOT="f0-expose.png"; [ "$SC" = "Overview" ] && SHOT="f0-overview.png"
      spectacle -b -n -o "$OUT_ABS/$SHOT" >>"$LOG" 2>&1 \
        && echo "[nested] $SHOT OK ($SC)" | tee -a "$LOG" \
        || echo "[nested] WARN: captura $SHOT fallo" | tee -a "$LOG"
      # Cierra el efecto invocando de nuevo (toggle) y no prueba mas
      # atajos para no dejar estado abierto.
      qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "$SC" >>"$LOG" 2>&1 || true
      sleep 1
      break
    fi
  done
  [ -z "$EXPOSE_USED" ] && echo "[nested] ERROR: ni Expose ni Overview respondieron" | tee -a "$LOG"
fi
# --- F0-T04: KRunner query + latencia ---
if [ -n "$KRUNNER_QUERY" ]; then
  echo "[nested] krunner query \"$KRUNNER_QUERY\" ..." | tee -a "$LOG"
  T0=$(date +%s%N)
  qdbus6 org.kde.krunner /App org.kde.krunner.App.query "$KRUNNER_QUERY" >>"$LOG" 2>&1
  QRC=$?
  T1=$(date +%s%N)
  echo "[nested] krunner query rc=$QRC latencia_ms=$(( (T1-T0)/1000000 ))" | tee -a "$LOG"
  sleep 2
  spectacle -b -n -o "$OUT_ABS/f0-krunner.png" >>"$LOG" 2>&1 \
    && echo "[nested] f0-krunner.png OK" | tee -a "$LOG" \
    || echo "[nested] WARN: captura f0-krunner fallo" | tee -a "$LOG"
  # Cierra el popup (estado conocido: abierto) para no tapar lo siguiente.
  qdbus6 org.kde.krunner /App org.kde.krunner.App.toggleDisplay >>"$LOG" 2>&1 || true
  sleep 1
fi
# --- F2-T03: verifica herencia de configs en el HOME temporal ---
echo "[nested] F2-T03 kreadconfig6 (HOME=$HOME):" | tee -a "$LOG"
echo "  SingleClick=$(kreadconfig6 --file kdeglobals --group KDE --key SingleClick 2>>"$LOG")" | tee -a "$LOG"
echo "  ButtonsOnLeft=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft 2>>"$LOG")" | tee -a "$LOG"
echo "  ButtonsOnRight=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight 2>>"$LOG")" | tee -a "$LOG"
echo "  panelHeight=$(kreadconfig6 --file plasmashellrc --group General --key panelHeight 2>>"$LOG")" | tee -a "$LOG"
echo "  thickness=$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group Panel --key thickness 2>>"$LOG")" | tee -a "$LOG"
echo "  floating=$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group Panel --key floating 2>>"$LOG")" | tee -a "$LOG"
echo "  FreeFloating=$(kreadconfig6 --file krunnerrc --group General --key FreeFloating 2>>"$LOG")" | tee -a "$LOG"
grep -hE "^(thickness|floating|location|formfactor)=" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | sort | uniq -c | tee -a "$LOG" || true
echo "  CtrlBindings=$(grep -ciE "ctrl" "$HOME/.config/kglobalshortcutsrc" 2>/dev/null || echo "sin-fichero")" | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f2-panel.png" >>"$LOG" 2>&1 \
  && echo "[nested] f2-panel.png OK" | tee -a "$LOG" \
  || echo "[nested] WARN: captura f2-panel fallo" | tee -a "$LOG"
# --- F3/F4: Klassy (kate izq + konsole der, flip de foco via KWin scripting) ---
KONSOLE_PID=""
if [ -n "$KLASSY" ]; then
  echo "[nested] klassy: reposiciona kate+konsole ..." | tee -a "$LOG"
  kill $KATE_PID 2>/dev/null || true
  sleep 1
  kate --qwindowgeometry 620x460+10+60 >>"$LOG" 2>&1 &
  KATE_PID=$!
  konsole --qwindowgeometry 620x460+650+60 >>"$LOG" 2>&1 &
  KONSOLE_PID=$!
  sleep 4
  echo "[nested] klassy en supportInformation:" | tee -a "$LOG"
  qdbus6 org.kde.KWin /KWin supportInformation 2>/dev/null | grep -iE "klassy|decoration" | tee -a "$LOG" || echo "[nested] WARN: sin mencion a Klassy" | tee -a "$LOG"
  # Sonda runtime: reescribe spacing + reconfigure (fire-and-forget con
  # timeout: el metodo es Q_NOREPLY y qdbus esperaria en vano).
  echo "[nested] klassy runtime reconfigure (spacing 8->20) ..." | tee -a "$LOG"
  kwriteconfig6 --file klassy/klassyrc --group ButtonSizing --key ButtonSpacingLeft 20 >>"$LOG" 2>&1
  timeout 8 qdbus6 org.kde.KWin /KWin reconfigure >>"$LOG" 2>&1 || true
  sleep 2
  echo "[nested] klassy layout (mosaico + foco konsole) ..." | tee -a "$LOG"
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$LAYOUT_SCRIPT" nimbus-layout >>"$LOG" 2>&1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >>"$LOG" 2>&1
  sleep 2
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript nimbus-layout >>"$LOG" 2>&1 || true
  sleep 1
  spectacle -b -n -o "$OUT_ABS/f3-klassy-inactive.png" >>"$LOG" 2>&1 \
    && echo "[nested] f3-klassy-inactive.png OK (konsole activa esperada)" | tee -a "$LOG" \
    || echo "[nested] WARN: captura inactive fallo" | tee -a "$LOG"
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$FOCUS_SCRIPT" nimbus-focus >>"$LOG" 2>&1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >>"$LOG" 2>&1
  sleep 2
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript nimbus-focus >>"$LOG" 2>&1 || true
  spectacle -b -n -o "$OUT_ABS/f3-klassy-active.png" >>"$LOG" 2>&1 \
    && echo "[nested] f3-klassy-active.png OK (kate activa esperada)" | tee -a "$LOG" \
    || echo "[nested] WARN: captura active fallo" | tee -a "$LOG"
fi
echo "$KWIN_PID $PLASMA_PID $KRUNNER_PID $KATE_PID $KONSOLE_PID" > "$PIDFILE"
echo "KWIN_PID=$KWIN_PID PLASMA_PID=$PLASMA_PID KRUNNER_PID=$KRUNNER_PID KATE_PID=$KATE_PID" > "$OUT_ABS/result.env"
echo "[nested] FIN. Ver $OUT_ABS/nested-plasma.png" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[nested] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
