#!/usr/bin/env bash
# Harness nested para el servidor FDO de notificaciones de nimbus-bar
# (F3-T12, R-NOTIF-SERVER). KWin virtual + nimbus-bar SIN plasmashell
# (nombre org.freedesktop.Notifications libre) + notify-send real.
# Seguro: SIN --replace, HOME/XDG temporales, sin root, sin instalaciones.
# Plantilla: tests/vm/nested-bar.sh (ya con --no-lockscreen).
# Uso: bash tests/vm/nested-notifications.sh [--out spikes/nested] [--timeout 60] [--bin /ruta/nimbus-bar]
set -u

OUT_DIR="spikes/nested"
TIMEOUT=60
BAR_BIN="/tmp/nimbus-bar-notif-prefix/bin/nimbus-bar"
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

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-notif-XXXXXX)"
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
INNER_TMP="$BASE_TMP/inner"
mkdir -p "$INNER_TMP"
export INNER_TMP
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-notif-test"
LOG="$OUT_ABS/nested-notifications.log"
: > "$LOG"

PIDFILE="$OUT_ABS/.nested-notifications.pids"
: > "$PIDFILE"
cleanup() {
  local p
  if [ -f "$PIDFILE" ]; then
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill "$p" 2>/dev/null || true; done
    sleep 1
    for p in $(cat "$PIDFILE" 2>/dev/null); do kill -9 "$p" 2>/dev/null || true; done
  fi
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-notif-test" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[notif] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[notif] runtime=$XDG_RUNTIME_DIR log=$LOG bin=$BAR_BIN" | tee -a "$LOG"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
PIDFILE="'"$PIDFILE"'"
TIMEOUT="'"$TIMEOUT"'"
BAR_BIN="'"$BAR_BIN"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
TMP_INNER="'"$INNER_TMP"'"
export TMP_INNER
export WAYLAND_DISPLAY
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap "kill \$(jobs -p) 2>/dev/null || true" EXIT

DEST=org.freedesktop.Notifications
OBJ=/org/freedesktop/Notifications
IFACE=org.freedesktop.Notifications
PASS=0; FAIL=0
check() { # check <nombre> <condicion-true-1/0>
  if [ "$2" = "1" ]; then PASS=$((PASS+1)); echo "[notif] PASS: $1" | tee -a "$LOG";
  else FAIL=$((FAIL+1)); echo "[notif] FAIL: $1" | tee -a "$LOG"; fi
}
hcount() { # nº de notificaciones activas (extensión Nimbus HistoryCount)
  gdbus call --session --dest "$DEST" --object-path "$OBJ" \
    --method org.freedesktop.DBus.Properties.Get "$IFACE" HistoryCount 2>>"$LOG" \
    | grep -o "[0-9]*" | tail -1
}

echo "[notif] arranque kwin_wayland --virtual (SIN plasmashell: nombre libre) ..." | tee -a "$LOG"
kwin_wayland --virtual --width 1280 --height 800 --no-lockscreen --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!

for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[notif] ERROR: sin socket $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
echo "[notif] socket OK" | tee -a "$LOG"
sleep 2

echo "[notif] arranque nimbus-bar ..." | tee -a "$LOG"
"$BAR_BIN" >>"$LOG" 2>&1 &
BAR_PID=$!
sleep 5
if kill -0 $BAR_PID 2>/dev/null; then echo "[notif] nimbus-bar VIVO pid=$BAR_PID" | tee -a "$LOG";
else echo "[notif] ERROR: nimbus-bar muerto" | tee -a "$LOG"; fi

echo "[notif] 1) GetServerInformation ..." | tee -a "$LOG"
INFO=$(qdbus6 "$DEST" "$OBJ" "$IFACE.GetServerInformation" 2>>"$LOG")
echo "$INFO" | tee -a "$LOG"
echo "$INFO" | grep -q "Nimbus" && echo "$INFO" | grep -q "NimbusOS" \
  && echo "$INFO" | grep -q "1.0" && echo "$INFO" | grep -q "1.2" \
  && SINFO=1 || SINFO=0
check "GetServerInformation Nimbus/NimbusOS/1.0/1.2" "$SINFO"

echo "[notif] 2) GetCapabilities ..." | tee -a "$LOG"
CAPS=$(qdbus6 "$DEST" "$OBJ" "$IFACE.GetCapabilities" 2>>"$LOG")
echo "$CAPS" | tee -a "$LOG"
CCOK=0
echo "$CAPS" | grep -q body && echo "$CAPS" | grep -q actions \
  && echo "$CAPS" | grep -q icon-static && echo "$CAPS" | grep -q persistence \
  && echo "$CAPS" | grep -q body-markup && CCOK=1
check "GetCapabilities body/actions/icon-static/persistence/body-markup" "$CCOK"

echo "[notif] 3) banner persistente + captura ..." | tee -a "$LOG"
ID1=$(notify-send -a Nimbus "Reunión" "En 5 minutos" -t 0 -p 2>>"$LOG")
echo "[notif] ID1=$ID1 hcount=$(hcount)" | tee -a "$LOG"
[ "$ID1" -gt 0 ] 2>/dev/null && NID=1 || NID=0
check "Notify devuelve id>0" "$NID"
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notif2-banner.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif2-banner.png OK" | tee -a "$LOG" \
  || echo "[notif] WARN: captura banner fallo" | tee -a "$LOG"

echo "[notif] 4) notificación con acciones + captura ..." | tee -a "$LOG"
# NOTA: -A implica --wait (bloquea hasta acción/cierre) -> en background,
# el id sale por fichero. Sin esto el harness se cuelga (cazado en run1).
ID2F="$TMP_INNER/.id2"
notify-send -a Nimbus "Actualización" "Hay cambios listos" -t 0 -A "open=Abrir" -p >"$ID2F" 2>>"$LOG" &
NSA_PID=$!
sleep 2
ID2=$(cat "$ID2F" 2>/dev/null)
echo "[notif] ID2=$ID2 hcount=$(hcount)" | tee -a "$LOG"
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notif2-actions.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif2-actions.png OK" | tee -a "$LOG" \
  || echo "[notif] WARN: captura acciones fallo" | tee -a "$LOG"

echo "[notif] 5) ActionInvoked por DBus (extensión InvokeAction) ..." | tee -a "$LOG"
# Suscriptor de señales con python3-dbus (AddMatch normal). Ni
# dbus-monitor/BecomeMonitor sin eavesdrop (solo se ve a sí mismo,
# cazado en run3) ni gdbus monitor sin --dest (esta versión lo exige)
# sirven aquí.
SIGLISTEN="$TMP_INNER/.sig-listen.py"
cat >"$SIGLISTEN" <<"PYEOF"
import sys
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
logpath, wait = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 10
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
out = open(logpath, "a")
def closed(i, r):
    out.write("SIG NotificationClosed %s %s\n" % (i, r)); out.flush()
def acted(i, k):
    out.write("SIG ActionInvoked %s %s\n" % (i, k)); out.flush()
bus.add_signal_receiver(closed, "NotificationClosed",
                        "org.freedesktop.Notifications")
bus.add_signal_receiver(acted, "ActionInvoked",
                        "org.freedesktop.Notifications")
loop = GLib.MainLoop()
GLib.timeout_add_seconds(wait, loop.quit)
loop.run()
PYEOF
: > "$OUT_ABS/sig-actions.log" # el listener abre en append; limpia run previo
python3 "$SIGLISTEN" "$OUT_ABS/sig-actions.log" 8 > /dev/null 2>&1 &
MONA_PID=$!
sleep 1
H_BEFORE=$(hcount)
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method "$IFACE.InvokeAction" "$ID2" "open" >>"$LOG" 2>&1
sleep 2
kill $MONA_PID 2>/dev/null || true
grep -a "ActionInvoked" "$OUT_ABS/sig-actions.log" | tee -a "$LOG"
grep -aq "SIG ActionInvoked $ID2 open" "$OUT_ABS/sig-actions.log" && AI=1 || AI=0
check "ActionInvoked($ID2,key=open) emitido" "$AI"
H_AFTER=$(hcount)
echo "[notif] hcount $H_BEFORE -> $H_AFTER (tras acción se descarta)" | tee -a "$LOG"
kill $NSA_PID 2>/dev/null || true # el --wait implícito ya debió salir

echo "[notif] 6) CloseNotification -> NotificationClosed reason 3 ..." | tee -a "$LOG"
: > "$OUT_ABS/sig-close.log" # el listener abre en append; limpia run previo
python3 "$SIGLISTEN" "$OUT_ABS/sig-close.log" 8 > /dev/null 2>&1 &
MONC_PID=$!
sleep 1
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method "$IFACE.CloseNotification" "$ID1" >>"$LOG" 2>&1
sleep 2
kill $MONC_PID 2>/dev/null || true
grep -a "NotificationClosed" "$OUT_ABS/sig-close.log" | tee -a "$LOG"
grep -aq "SIG NotificationClosed $ID1 3" "$OUT_ABS/sig-close.log" && NC=1 || NC=0
check "NotificationClosed($ID1, reason=3)" "$NC"

echo "[notif] 7) replaces_id ..." | tee -a "$LOG"
ID3=$(notify-send -a Nimbus "Título v1" "cuerpo" -t 0 -p 2>>"$LOG")
ID3B=$(notify-send -a Nimbus -r "$ID3" "Título v2" "cuerpo" -t 0 -p 2>>"$LOG")
echo "[notif] ID3=$ID3 ID3B=$ID3B" | tee -a "$LOG"
[ "$ID3" = "$ID3B" ] && RP=1 || RP=0
check "replaces_id conserva el id" "$RP"
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method "$IFACE.CloseNotification" "$ID3" >>"$LOG" 2>&1

echo "[notif] 8) DND: Inhibited=true -> sin banner pero con historial ..." | tee -a "$LOG"
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method org.freedesktop.DBus.Properties.Set "$IFACE" Inhibited "<true>" >>"$LOG" 2>&1
H0=$(hcount)
ID4=$(notify-send -a Nimbus "Silenciosa" "No debe verse banner" -t 0 -p 2>>"$LOG")
sleep 2
H1=$(hcount)
echo "[notif] hcount $H0 -> $H1 (ID4=$ID4)" | tee -a "$LOG"
[ "$H1" = "$((H0+1))" ] && DNDH=1 || DNDH=0
check "DND guarda historial (hcount $H0->$H1)" "$DNDH"
spectacle -b -n -o "$OUT_ABS/f3-notif2-dnd.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif2-dnd.png OK (verificar: SIN banner)" | tee -a "$LOG" \
  || echo "[notif] WARN: captura dnd fallo" | tee -a "$LOG"
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method org.freedesktop.DBus.Properties.Set "$IFACE" Inhibited "<false>" >>"$LOG" 2>&1
gdbus call --session --dest "$DEST" --object-path "$OBJ" \
  --method "$IFACE.CloseNotification" "$ID4" >>"$LOG" 2>&1

echo "[notif] 9) timeout 2000ms (antes/después) ..." | tee -a "$LOG"
T0=$(date +%s.%N)
HB0=$(hcount)
ID5=$(notify-send -a Nimbus "Efímera" "Caduca en 2s" -t 2000 -p 2>>"$LOG")
sleep 1
HB=$(hcount)
spectacle -b -n -o "$OUT_ABS/f3-notif2-timeout-before.png" >>"$LOG" 2>&1 || true
sleep 4
HA=$(hcount)
T1=$(date +%s.%N)
echo "[notif] T0=$T0 T1=$T1 ID5=$ID5 hcount base=$HB0 antes=$HB después=$HA" | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-notif2-timeout-after.png" >>"$LOG" 2>&1 || true
[ "$HB" = "$((HB0+1))" ] && [ "$HA" = "$HB0" ] && TO=1 || TO=0
check "timeout: visible antes ($HB) y ausente después ($HA)" "$TO"

echo "[notif] 10) conflicto: segunda barra con nombre tomado ..." | tee -a "$LOG"
"$BAR_BIN" --no-notifications >>"$LOG" 2>&1 &
BAR2_PID=$!
sleep 4
# Segunda barra SIN notificaciones no compite; la prueba real: otra con bus.
kill $BAR2_PID 2>/dev/null || true
"$BAR_BIN" >>"$LOG" 2>&1 &
BAR3_PID=$!
sleep 4
if kill -0 $BAR3_PID 2>/dev/null; then ALIVE=1; else ALIVE=0; fi
check "2ª barra con nombre tomado sigue VIVA" "$ALIVE"
grep -aq "ya registrado" "$LOG" && CONF=1 || CONF=0
check "2ª barra loguea el conflicto (ya registrado)" "$CONF"
kill $BAR3_PID 2>/dev/null || true
sleep 1
kill -0 $BAR_PID 2>/dev/null && STILL=1 || STILL=0
check "1ª barra (dueña) sigue viva tras el conflicto" "$STILL"

echo "[notif] 11) 0 errores QML ..." | tee -a "$LOG"
QMLERR=$(grep -aiE "TypeError|ReferenceError|RangeError|SyntaxError|is not a function|Cannot read propert|Unable to assign|file://.*qml.*rror" "$LOG" | grep -av "kwin_wayland" | wc -l)
echo "[notif] QMLERR=$QMLERR" | tee -a "$LOG"
[ "$QMLERR" = "0" ] && QE=1 || QE=0
check "0 errores QML" "$QE"

echo "[notif] resumen: PASS=$PASS FAIL=$FAIL" | tee -a "$LOG"
ls -la "$OUT_ABS"/f3-notif2*.png >>"$LOG" 2>&1
echo "$KWIN_PID $BAR_PID" > "$PIDFILE"
echo "[notif] FIN (FAIL=$FAIL)." | tee -a "$LOG"
exit $FAIL
' >>"$LOG" 2>&1
RC=$?
echo "[notif] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
