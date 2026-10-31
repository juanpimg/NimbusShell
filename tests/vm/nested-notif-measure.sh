#!/usr/bin/env bash
# F3-T09 medición: timeout 5s, agrupación (2 misma app), acciones+historial
# vía scripting Plasma. Plantilla nested-notif.sh: sin root/instalar,
# HOME+XDG temporales, cleanup por trap. Sin inyección de entrada en nested
# (no wtype/ydotool, no root): el clic físico queda como gap documentado.
# Uso: bash tests/vm/nested-notif-measure.sh [--out spikes/nested] [--timeout 60]
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
LOG="$OUT_ABS/nested-notif-measure.log"
: > "$LOG"
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-notifm-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data" XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
DEPLOYED=0
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
mkdir -p "$XDG_DATA_HOME/plasma/desktoptheme"
cp -r "$REPO_ROOT/packages/themes/nimbus-notifications/desktoptheme/nimbus-notifications" \
  "$XDG_DATA_HOME/plasma/desktoptheme/"
XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file plasmarc \
  --group Theme --key name nimbus-notifications
# Llamador Notify con hints exactos de notify-send (urgency+sender-pid;
# ver spikes/nested/f3-wire.dump). Fichero, no inline: el subshell interno
# va entrecomillado simple y python exige comillas simples.
cat > "$OUT_ABS/f3-notify-actions.py" <<'PYEOF'
import dbus
import os
import sys
import time
expire = dbus.Int32(int(sys.argv[1])) if len(sys.argv) > 1 else dbus.Int32(30000)
hold = float(sys.argv[2]) if len(sys.argv) > 2 else 0
bus = dbus.SessionBus()
obj = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
iface = dbus.Interface(obj, "org.freedesktop.Notifications")
print(iface.Notify("Nimbus", dbus.UInt32(0), "", "Acción", "Pulsa Abrir",
                   ["open", "Abrir"],
                   {"urgency": dbus.Byte(1), "sender-pid": dbus.Int64(os.getpid())},
                   expire))
sys.stdout.flush()
if hold:
    time.sleep(hold)
PYEOF
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="nimbus-notifm"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
cleanup() {
  local p
  sleep 2
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-notifm" \
    | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[measure] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
echo "[measure] home-temporal=$NESTED_HOME ($DEPLOYED ficheros)" | tee -a "$LOG"
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
WAYLAND_DISPLAY="'"$WAYLAND_DISPLAY"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[measure] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 8
READY=""
for ((i=0; i<90; i++)); do
  kill -0 $PLASMA_PID 2>/dev/null || { echo "[measure] ERROR: plasmashell murió" | tee -a "$LOG"; break; }
  HAS=$(timeout 5 dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
    string:org.freedesktop.Notifications 2>/dev/null | awk "/boolean/{print \$2}")
  if [ "$HAS" = "true" ]; then READY="yes"; break; fi
  sleep 1
done
echo "[measure] notif-ready=$READY" | tee -a "$LOG"
[ "$READY" = "yes" ] || exit 1
# --- M1: timeout 5s (PopupTimeout=5000): visible a +2s, ausente a +7s ---
T0=$(date +%s.%N)
timeout 30 notify-send -a Nimbus "Medición" "timeout 5s" >>"$LOG" 2>&1
echo "[measure] T0=$T0 send-rc=$?" | tee -a "$LOG"
sleep 2
T1=$(date +%s.%N)
spectacle -b -n -o "$OUT_ABS/f3-timeout-before.png" >>"$LOG" 2>&1
echo "[measure] T1=$T1 (+2s, banner esperado visible)" | tee -a "$LOG"
sleep 5
T2=$(date +%s.%N)
spectacle -b -n -o "$OUT_ABS/f3-timeout-after.png" >>"$LOG" 2>&1
echo "[measure] T2=$T2 (+7s, banner esperado ausente)" | tee -a "$LOG"
# --- M2: agrupación, 2 notifs misma app (pila de popups) ---
timeout 30 notify-send -a Nimbus "Grupo A1" "primera" >>"$LOG" 2>&1
sleep 0.5
timeout 30 notify-send -a Nimbus "Grupo A2" "segunda" >>"$LOG" 2>&1
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-group.png" >>"$LOG" 2>&1 \
  && echo "[measure] f3-group.png OK (pila A1+A2 esperada)" | tee -a "$LOG" \
  || echo "[measure] WARN: captura grupo fallo" | tee -a "$LOG"
# --- M3: acciones. A/B: (a) expire -1 efímero; (b) expire 30000 con
# emisor vivo. Aísla expire vs liveness (el botón solo apareció con
# notify-send --wait). La pila M2 ya expiró (sleep 7 previo). ---
sleep 7
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.GetCapabilities 2>>"$LOG" | tee -a "$LOG"
NIDA=$(timeout 15 python3 "$OUT_ABS/f3-notify-actions.py" -1 0 2>>"$LOG")
echo "[measure] Notify-A expire-1 id=$NIDA" | tee -a "$LOG"
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notify-a.png" >>"$LOG" 2>&1 \
  && echo "[measure] f3-notify-a.png OK" | tee -a "$LOG" \
  || echo "[measure] WARN: captura A fallo" | tee -a "$LOG"
timeout 40 python3 "$OUT_ABS/f3-notify-actions.py" 30000 30 > "$OUT_ABS/f3-nidb.txt" 2>>"$LOG" &
sleep 2
NIDB=$(cat "$OUT_ABS/f3-nidb.txt" 2>/dev/null)
echo "[measure] Notify-B expire-30000 hold id=$NIDB" | tee -a "$LOG"
spectacle -b -n -o "$OUT_ABS/f3-notify-b.png" >>"$LOG" 2>&1 \
  && echo "[measure] f3-notify-b.png OK" | tee -a "$LOG" \
  || echo "[measure] WARN: captura B fallo" | tee -a "$LOG"
NID="$NIDA"
# El banner de acciones (expire 30s) deja banner con botón visible.
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notify-id.png" >>"$LOG" 2>&1 \
  && echo "[measure] f3-notify-id.png OK (banner id=$NID con botón)" | tee -a "$LOG" \
  || echo "[measure] WARN: captura notify-id fallo" | tee -a "$LOG"
QMLERR=$(grep -ciE "qqml.*error|qml.*error|failed.*\.qml" "$LOG" || true)
echo "[measure] QMLERR=$QMLERR" | tee -a "$LOG"
echo "[measure] FIN" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[measure] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
