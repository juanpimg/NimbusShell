#!/usr/bin/env bash
# Harness nested F3-T06: menú global Qt en nimbus-bar.
# kwin virtual + fake registrar (tests/vm/fake-registrar.py, ver por qué
# en su cabecera) + kate + dolphin + nautilus (GTK, R-GTK) + nimbus-bar
# --demo-appmenu --log-appmenu. Capturas + log DBus como evidencia.
# Seguro: NUNCA --replace, HOME/XDG temporales, sin root, cleanup por trap.
# Uso: bash tests/vm/nested-appmenu.sh [--out spikes/nested] [--timeout 90] [--bin /ruta/nimbus-bar]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=90
BAR_BIN="/tmp/nimbus-bar-f3menu-prefix/bin/nimbus-bar"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BAR_BIN="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-appmenu-XXXXXX)"
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
export WAYLAND_DISPLAY="nimbus-appmenu-test"
LOG="$OUT_ABS/nested-appmenu.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-appmenu.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-appmenu-test" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[appmenu] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[appmenu] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
REPO_ROOT="'"$REPO_ROOT"'"
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

echo "[appmenu] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland --no-lockscreen >>"$LOG" 2>&1 &
KWIN_PID=$!

for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[appmenu] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[appmenu] socket OK" | tee -a "$LOG"
sleep 2

# El greet de bloqueo (--immediateLock) aparece solo en nested y tapa las
# capturas; no forma parte del SUT. Se elimina si aparece.
# (Nota: no mencionar aquí el binario por su nombre literal: pkill -f
#  matchea la cmdline del propio script.)
( while true; do pkill -f "[k]screenlocker_greet" 2>/dev/null; sleep 2; done ) &
LOCKERKILL_PID=$!

echo "[appmenu] fake registrar (ver tests/vm/fake-registrar.py) ..." | tee -a "$LOG"
python3 "$REPO_ROOT/tests/vm/fake-registrar.py" >>"$LOG" 2>&1 &
sleep 2
qdbus6 com.canonical.AppMenu.Registrar /com/canonical/AppMenu/Registrar 2>&1 | head -6 | tee -a "$LOG"

echo "[appmenu] arranque kate + dolphin (Qt) ..." | tee -a "$LOG"
kate >>"$LOG" 2>&1 &
KATE_PID=$!
sleep 8
dolphin >>"$LOG" 2>&1 &
DOLPHIN_PID=$!
sleep 6

echo "[appmenu] export dbusmenu (esperado: kate+dolphin /MenuBar/N) ..." | tee -a "$LOG"
python3 - "$LOG" <<EOF >>"$LOG" 2>&1
import dbus, re, sys
log = open(sys.argv[1], "a")
bus = dbus.SessionBus()
for s in sorted(bus.list_names()):
    ss = str(s)
    if ss.startswith(":") or ss in ("org.freedesktop.DBus",):
        continue
    try:
        root = bus.get_object(ss, "/").Introspect(dbus_interface="org.freedesktop.DBus.Introspectable")
    except Exception:
        continue
    if "dolphin" in ss or "kate" in ss:
        try:
            mb = bus.get_object(ss, "/MenuBar").Introspect(dbus_interface="org.freedesktop.DBus.Introspectable")
            print(f"PYXML {ss} len={len(mb)} nodes={mb.count(chr(60)+chr(110)+chr(111)+chr(100)+chr(101))}", flush=True)
        except Exception as e:
            print(f"PYXML {ss} ERR {e}", flush=True)
    for m in re.finditer(r"<node name=\"([^\"]+)\"", root):
        child = "/" + m.group(1)
        try:
            x = bus.get_object(ss, child).Introspect(dbus_interface="org.freedesktop.DBus.Introspectable")
        except Exception:
            continue
        for m2 in re.finditer(r"<node name=\"([^\"]+)\"", x):
            p = child + "/" + m2.group(1)
            try:
                y = bus.get_object(ss, p).Introspect(dbus_interface="org.freedesktop.DBus.Introspectable")
            except Exception:
                continue
            if "com.canonical.dbusmenu" in y:
                print(f"DBUSMENU {ss} {p}", flush=True)
print("scan FIN", flush=True)
EOF

echo "[appmenu] arranque nimbus-bar --demo-appmenu --log-appmenu ..." | tee -a "$LOG"
"$BAR_BIN" --demo-appmenu --log-appmenu >>"$LOG" 2>&1 &
BAR_PID=$!
sleep 8
if kill -0 $BAR_PID 2>/dev/null; then echo "[appmenu] nimbus-bar VIVO pid=$BAR_PID" | tee -a "$LOG";
else echo "[appmenu] ERROR: nimbus-bar muerto" | tee -a "$LOG"; fi

echo "[appmenu] lineas appmenu: del log ..." | tee -a "$LOG"
grep -a "appmenu:" "$LOG" | head -30 | tee -a "$LOG"

echo "[appmenu] foco a kate + captura (menu global Kate) ..." | tee -a "$LOG"
cat > "$OUT_ABS/focus-kate.js" <<JSEOF
try {
    var wl = workspace.windowList();
    for (var i = 0; i < wl.length; i++) {
        if (wl[i].resourceClass.indexOf("kate") >= 0) { workspace.activeWindow = wl[i]; }
    }
} catch (err) {}
JSEOF
KID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$OUT_ABS/focus-kate.js" "nimbus-focus-k" 2>>"$LOG") || true
qdbus6 org.kde.KWin "/Scripting/Script$KID" org.kde.kwin.Script.run >>"$LOG" 2>&1 || true
sleep 5
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "nimbus-focus-k" >>"$LOG" 2>&1 || true
grep -a "activa pid=.*app=Kate" "$LOG" | tail -1 | tee -a "$LOG"
grep -a "GetLayout .* tops=" "$LOG" | tail -1 | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-appmenu-kate.png" >>"$LOG" 2>&1 \
  && echo "[appmenu] f3-appmenu-kate.png OK" | tee -a "$LOG" \
  || echo "[appmenu] WARN: captura kate fallo" | tee -a "$LOG"

echo "[appmenu] foco a dolphin + captura ..." | tee -a "$LOG"
qdbus6 org.kde.KWin /KWin org.kde.KWin.getWindowInfo "" 2>>"$LOG" | head -2 >>"$LOG" || true
cat > "$OUT_ABS/focus-dolphin.js" <<JSEOF
try {
    var wl = workspace.windowList();
    for (var i = 0; i < wl.length; i++) {
        if (wl[i].resourceClass.indexOf("dolphin") >= 0) { workspace.activeWindow = wl[i]; }
    }
} catch (err) {}
JSEOF
FID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$OUT_ABS/focus-dolphin.js" "nimbus-focus" 2>>"$LOG") || true
qdbus6 org.kde.KWin "/Scripting/Script$FID" org.kde.kwin.Script.run >>"$LOG" 2>&1 || true
sleep 4
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "nimbus-focus" >>"$LOG" 2>&1 || true
spectacle -b -n -o "$OUT_ABS/f3-appmenu-dolphin.png" >>"$LOG" 2>&1 \
  && echo "[appmenu] f3-appmenu-dolphin.png OK" | tee -a "$LOG" \
  || echo "[appmenu] WARN: captura dolphin fallo" | tee -a "$LOG"

echo "[appmenu] nautilus (GTK): no debe romper, menu vacio/oculto ..." | tee -a "$LOG"
nautilus --new-window >>"$LOG" 2>&1 &
NAUTILUS_PID=$!
sleep 8
cat > "$OUT_ABS/focus-nautilus.js" <<JSEOF
try {
    var wl = workspace.windowList();
    for (var i = 0; i < wl.length; i++) {
        if (wl[i].resourceClass.toLowerCase().indexOf("nautilus") >= 0
            || wl[i].resourceClass.toLowerCase().indexOf("org.gnome") >= 0) { workspace.activeWindow = wl[i]; }
    }
} catch (err) {}
JSEOF
NID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$OUT_ABS/focus-nautilus.js" "nimbus-focus-n" 2>>"$LOG") || true
qdbus6 org.kde.KWin "/Scripting/Script$NID" org.kde.kwin.Script.run >>"$LOG" 2>&1 || true
sleep 4
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "nimbus-focus-n" >>"$LOG" 2>&1 || true
if kill -0 $BAR_PID 2>/dev/null; then echo "[appmenu] barra VIVA tras nautilus" | tee -a "$LOG";
else echo "[appmenu] ERROR: barra murio con nautilus" | tee -a "$LOG"; fi
spectacle -b -n -o "$OUT_ABS/f3-appmenu-gtk.png" >>"$LOG" 2>&1 \
  && echo "[appmenu] f3-appmenu-gtk.png OK" | tee -a "$LOG" \
  || echo "[appmenu] WARN: captura gtk fallo" | tee -a "$LOG"

echo "[appmenu] lineas appmenu finales ..." | tee -a "$LOG"
grep -a "appmenu:" "$LOG" | tail -20 | tee -a "$LOG"
ls -la "$OUT_ABS"/f3-appmenu*.png >>"$LOG" 2>&1
echo "$KWIN_PID $KATE_PID $DOLPHIN_PID $NAUTILUS_PID" > "$PIDFILE"
echo "[appmenu] FIN." | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[appmenu] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
