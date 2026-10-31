#!/usr/bin/env bash
# F3-T09 sonda wire: vuelca mensajes Notify de notify-send vs gdbus para
# aislar por qué el botón de acción solo aparece con notify-send.
# Plantilla nested: sin root/instalar, HOME+XDG temporales, cleanup.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ABS="$REPO_ROOT/spikes/nested"
LOG="$OUT_ABS/nested-notif-wire.log"
: > "$LOG"
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-wire-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data" XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/"
done
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="nimbus-wire"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
cleanup() {
  local p
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-wire" \
    | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  sleep 2
  rm -rf "$BASE_TMP" || echo "[wire] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
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
for ((i=0; i<120; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
plasmashell >>"$LOG" 2>&1 &
PLASMA_PID=$!
sleep 8
for ((i=0; i<90; i++)); do
  kill -0 $PLASMA_PID 2>/dev/null || break
  HAS=$(timeout 5 dbus-send --session --print-reply --dest=org.freedesktop.DBus \
    /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
    string:org.freedesktop.Notifications 2>/dev/null | awk "/boolean/{print \$2}")
  if [ "$HAS" = "true" ]; then break; fi
  sleep 1
done
dbus-monitor --monitor "type='"'"'method_call'"'"',interface='"'"'org.freedesktop.Notifications'"'"',member='"'"'Notify'"'"'" > "$OUT_ABS/f3-wire.dump" 2>>"$LOG" &
MON_PID=$!
sleep 1
echo "=== notify-send ===" >> "$OUT_ABS/f3-wire.dump"
timeout 10 notify-send -a Nimbus -A "open=Abrir" "Wire1" "via notify-send" >>"$LOG" 2>&1 &
sleep 2
echo "=== gdbus ===" >> "$OUT_ABS/f3-wire.dump"
timeout 10 gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "Nimbus" 0 "" "Wire2" "via gdbus" "[\"open\", \"Abrir\"]" "{}" 30000 >>"$LOG" 2>&1
sleep 2
kill $MON_PID 2>/dev/null || true
echo "[wire] FIN" | tee -a "$LOG"
' >>"$LOG" 2>&1
RC=$?
echo "[wire] dbus-run-session exit=$RC" | tee -a "$LOG"
exit $RC
