#!/usr/bin/env bash
# F3-T09 nested: banners Plasma estilo macOS. Plantilla tests/vm/nested-plasma.sh:
# NUNCA root/instalar/~/.config real; HOME+XDG temporales; cleanup por trap.
# Fases: banner básico -> acciones -> DND (Inhibit/UnInhibit) + 0 errores QML.
# Uso: bash tests/vm/nested-notif.sh [--out spikes/nested] [--timeout 60]
set -u
OUT_DIR="spikes/nested"
TIMEOUT=60
STOCK=""
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --stock) STOCK="yes" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/nested-notif.log"
: > "$LOG"
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-notif-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data" XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
# Despliega dotfiles plasma (incluye plasmanotifyrc F3-T09) + tema nimbus:
DEPLOYED=0
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
mkdir -p "$XDG_DATA_HOME/plasma/desktoptheme"
if [ -z "$STOCK" ]; then
  cp -r "$REPO_ROOT/packages/themes/nimbus-notifications/desktoptheme/nimbus-notifications" \
    "$XDG_DATA_HOME/plasma/desktoptheme/"
  XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file plasmarc \
    --group Theme --key name nimbus-notifications
  echo "[notif] tema=nimbus-notifications" | tee -a "$LOG"
else
  echo "[notif] tema=stock (control breeze-dark)" | tee -a "$LOG"
fi
# Holder de inhibición DND: la inhibición FDO muere con el proceso que la
# pide; este holder persiste durante la fase 3 (fichero, no heredoc: el
# subshell interno va entrecomillado simple).
cat > "$OUT_ABS/f3-inhibit-holder.py" <<'PYEOF'
import dbus
import time
bus = dbus.SessionBus()
obj = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
iface = dbus.Interface(obj, "org.freedesktop.Notifications")
cookie = iface.Inhibit("Nimbus", "test F3-T09", dbus.Dictionary({}, signature="sv"))
print(cookie, flush=True)
while True:
    time.sleep(3600)
PYEOF
echo "[notif] holder escrito" | tee -a "$LOG"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="nimbus-notif"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
cleanup() {  local p
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-notif" \
    | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[notif] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
echo "[notif] home-temporal=$NESTED_HOME ($DEPLOYED ficheros plasma)" | tee -a "$LOG"
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
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[notif] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 8
echo "[notif] espera org.freedesktop.Notifications (máx 90s)..." | tee -a "$LOG"
READY=""
for ((i=0; i<90; i++)); do
  if ! kill -0 $PLASMA_PID 2>/dev/null; then echo "[notif] ERROR: plasmashell murió" | tee -a "$LOG"; break; fi
  HAS=$(timeout 5 dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
    string:org.freedesktop.Notifications 2>/dev/null | awk "/boolean/{print \$2}")
  if [ "$HAS" = "true" ]; then READY="yes"; break; fi
  sleep 1
done
echo "[notif] notif-ready=$READY plasmashell-vivo=$(kill -0 $PLASMA_PID 2>/dev/null && echo si || echo no)" | tee -a "$LOG"
echo "[notif] plasmanotifyrc efectivo:" | tee -a "$LOG"
kreadconfig6 --file plasmanotifyrc --group Notifications --key PopupPosition 2>>"$LOG" | tee -a "$LOG"
kreadconfig6 --file plasmanotifyrc --group Notifications --key PopupTimeout 2>>"$LOG" | tee -a "$LOG"
# --- Fase 1: banner básico ---
timeout 30 notify-send -a Nimbus "Reunión" "En 5 minutos" >>"$LOG" 2>&1
echo "[notif] notify básico rc=$?" | tee -a "$LOG"
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notif.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif.png OK" | tee -a "$LOG" \
  || echo "[notif] WARN: captura f3-notif fallo" | tee -a "$LOG"
sleep 5
# --- Fase 2: acciones ---
timeout 14 notify-send -a Nimbus -A "open=Abrir" "Archivo" "Pulsa Abrir" >>"$LOG" 2>&1 &
sleep 2.5
spectacle -b -n -o "$OUT_ABS/f3-notif-actions.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif-actions.png OK" | tee -a "$LOG" \
  || echo "[notif] WARN: captura actions fallo" | tee -a "$LOG"
sleep 6
# --- Fase 3: DND por DBus (holder persistente: la inhibición expira
# con el proceso que la registra) ---
python3 "$OUT_ABS/f3-inhibit-holder.py" > "$OUT_ABS/f3-cookie.txt" 2>>"$LOG" &
HOLDER_PID=$!
sleep 2
COOKIE=$(cat "$OUT_ABS/f3-cookie.txt" 2>/dev/null)
echo "[notif] Inhibit cookie=$COOKIE holder=$HOLDER_PID" | tee -a "$LOG"
busctl --user get-property org.freedesktop.Notifications \
  /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited 2>>"$LOG" | tee -a "$LOG"
timeout 30 notify-send -a Nimbus "Silenciada" "No debe verse banner" >>"$LOG" 2>&1
sleep 2
spectacle -b -n -o "$OUT_ABS/f3-notif-dnd.png" >>"$LOG" 2>&1 \
  && echo "[notif] f3-notif-dnd.png OK (esperado: sin banner)" | tee -a "$LOG" \
  || echo "[notif] WARN: captura dnd fallo" | tee -a "$LOG"
kill $HOLDER_PID 2>/dev/null || true
sleep 1
busctl --user get-property org.freedesktop.Notifications \
  /org/freedesktop/Notifications org.freedesktop.Notifications Inhibited 2>>"$LOG" | tee -a "$LOG"
QMLERR=$(grep -ciE "qqml.*error|qml.*error|failed.*\.qml" "$LOG" || true)
echo "[notif] QMLERR=$QMLERR" | tee -a "$LOG"
echo "[notif] FIN" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[notif] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
