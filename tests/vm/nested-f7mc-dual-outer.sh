#!/usr/bin/env bash
# Exterior dual: kwin virtual grande + 2ª sesión D-Bus para el kwin interno.
set -u
export HOME="$F7BASE/home-outer"; mkdir -p "$HOME/.config"
export XDG_RUNTIME_DIR="$F7BASE/rt"
export XDG_CONFIG_HOME="$F7BASE/c" XDG_DATA_HOME="$F7BASE/d"
export XDG_CACHE_HOME="$F7BASE/ch" XDG_STATE_HOME="$F7BASE/s"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=nimbus-dual-outer
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="$F7LOG"
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
kwin_wayland --virtual --no-lockscreen --width 2600 --height 900 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for i in $(seq 1 40); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
sleep 2
echo "[f7dual] outer listo" | tee -a "$LOG"
# Sesión D-Bus propia para el kwin interno (mismo runtime: comparte sockets).
dbus-run-session -- bash "$F7REPO/tests/vm/nested-f7mc-dual-inner.sh" >>"$LOG" 2>&1
echo "[f7dual] inner rc=$?" | tee -a "$LOG"
