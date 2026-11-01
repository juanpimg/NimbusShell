#!/usr/bin/env bash
# Interior dual: kwin windowed (2 salidas) sobre el outer + apps + MC.
set -u
export HOME="$F7BASE/home-inner"; mkdir -p "$HOME/.config"
export XDG_RUNTIME_DIR="$F7BASE/rt"
export XDG_CONFIG_HOME="$F7BASE/c" XDG_DATA_HOME="$F7BASE/d"
export XDG_CACHE_HOME="$F7BASE/ch" XDG_STATE_HOME="$F7BASE/s"
export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="$F7LOG"; OUT="$F7OUT"; MCBIN="$F7MCBIN"
MC="qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl"
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
# El kwin interno abre sus 2 salidas como ventanas del compositor exterior.
WAYLAND_DISPLAY=nimbus-dual-outer \
kwin_wayland --no-lockscreen --output-count 2 --width 1280 --height 800 \
  --socket nimbus-dual-inner --xwayland >>"$LOG" 2>&1 &
for i in $(seq 1 60); do [ -e "$XDG_RUNTIME_DIR/nimbus-dual-inner" ] && break; sleep 0.5; done
if [ ! -e "$XDG_RUNTIME_DIR/nimbus-dual-inner" ]; then
  echo "[f7dual] FALLO: sin socket inner (gap documentado)" | tee -a "$LOG"
  exit 1
fi
export WAYLAND_DISPLAY=nimbus-dual-inner
sleep 3
plasmashell >>"$LOG" 2>&1 &
sleep 3
kate >>"$LOG" 2>&1 &
konsole >>"$LOG" 2>&1 &
dolphin >>"$LOG" 2>&1 &
sleep 8
echo "[f7dual] apps pedidas" | tee -a "$LOG"
"$MCBIN" --shot "$OUT/f7-mc-dual-grab.png" >>"$LOG" 2>&1 &
MCPID=$!
sleep 12
if kill -0 $MCPID 2>/dev/null; then echo "[f7dual] mc VIVO pid=$MCPID" | tee -a "$LOG"; else echo "[f7dual] mc MUERTO" | tee -a "$LOG"; fi
echo "[f7dual] screenInfo=$($MC.screenInfo 2>>"$LOG")" | tee -a "$LOG"
echo "[f7dual] windowCount=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7dual] desktopCount=$($MC.desktopCount 2>>"$LOG")" | tee -a "$LOG"
$MC.grabShot "$OUT/f7-mc-dual.png" >>"$LOG" 2>&1
echo "[f7dual] dual_rc=$? shot=$([ -f "$OUT/f7-mc-dual.png" ] && echo OK || echo FALTA)" | tee -a "$LOG"
kill $MCPID 2>/dev/null || true
sleep 1
