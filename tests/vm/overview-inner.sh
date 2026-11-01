#!/usr/bin/env bash
# Interior perf: kwin virtual + plasmashell + 20 ventanas + MC + medidas.
set -u
export HOME="$F7BASE/home"; mkdir -p "$HOME/.config"
export XDG_RUNTIME_DIR="$F7BASE/rt"
export XDG_CONFIG_HOME="$F7BASE/c" XDG_DATA_HOME="$F7BASE/d"
export XDG_CACHE_HOME="$F7BASE/ch" XDG_STATE_HOME="$F7BASE/s"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=nimbus-perf
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="$F7LOG"; OUT="$F7OUT"; MCBIN="$F7MCBIN"
MC="qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl"
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for i in $(seq 1 40); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
sleep 2
plasmashell >>"$LOG" 2>&1 &
sleep 3
# 20 ventanas garantizadas (6 kate + 6 konsole + 4 dolphin + 2 kwrite + 2 kcalc).
for i in 1 2 3 4 5 6; do kate >>"$LOG" 2>&1 & konsole >>"$LOG" 2>&1 & done
for i in 1 2 3 4; do dolphin >>"$LOG" 2>&1 & done
kwrite >>"$LOG" 2>&1 & kwrite >>"$LOG" 2>&1 &
kcalc >>"$LOG" 2>&1 & kcalc >>"$LOG" 2>&1 &
sleep 14
echo "[f7perf] 20 ventanas pedidas" | tee -a "$LOG"
"$MCBIN" --shot "$OUT/f7-mc-perf-grab.png" >>"$LOG" 2>&1 &
MCPID=$!
sleep 12
if kill -0 $MCPID 2>/dev/null; then echo "[f7perf] mc VIVO pid=$MCPID" | tee -a "$LOG"; else echo "[f7perf] mc MUERTO (crash)" | tee -a "$LOG"; fi
echo "[f7perf] windowCount=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7perf] desktopCount=$($MC.desktopCount 2>>"$LOG")" | tee -a "$LOG"
for n in 1 2 3; do
  T0=$(date +%s%N)
  $MC.toggle >>"$LOG" 2>&1; TR=$?
  T1=$(date +%s%N)
  echo "[f7perf] toggle${n}_rc=$TR toggle_ms=$(( (T1-T0)/1000000 ))" | tee -a "$LOG"
  sleep 1
done
$MC.show >>"$LOG" 2>&1
sleep 1
$MC.replayIntro >>"$LOG" 2>&1
echo "[f7perf] fps_20win=$($MC.fpsProbe 2>>"$LOG")" | tee -a "$LOG"
$MC.grabShot "$OUT/f7-mc-perf.png" >>"$LOG" 2>&1
echo "[f7perf] perf_rc=$? shot=$([ -f "$OUT/f7-mc-perf.png" ] && echo OK || echo FALTA)" | tee -a "$LOG"
if kill -0 $MCPID 2>/dev/null; then echo "[f7perf] mc SIGUE-VIVO (0 crash)" | tee -a "$LOG"; else echo "[f7perf] mc MURIO" | tee -a "$LOG"; fi
kill $MCPID 2>/dev/null || true
sleep 1
