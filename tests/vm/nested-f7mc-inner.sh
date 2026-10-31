#!/usr/bin/env bash
# Interior del bus anidado F7 (hereda F7BASE/F7LOG/F7OUT/F7MCBIN).
set -u
export HOME="$F7BASE/home"; mkdir -p "$HOME/.config"
export XDG_RUNTIME_DIR="$F7BASE/rt"
export XDG_CONFIG_HOME="$F7BASE/c" XDG_DATA_HOME="$F7BASE/d"
export XDG_CACHE_HOME="$F7BASE/ch" XDG_STATE_HOME="$F7BASE/s"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=nimbus-f7mc
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="$F7LOG"; OUT="$F7OUT"; MCBIN="$F7MCBIN"
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for i in $(seq 1 40); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
sleep 2
plasmashell >>"$LOG" 2>&1 &
sleep 3
qdbus6 org.kde.KWin /VirtualDesktopManager \
  org.kde.KWin.VirtualDesktopManager.createDesktop 1 "Desktop 2" >>"$LOG" 2>&1 || true
kate >>"$LOG" 2>&1 &
konsole >>"$LOG" 2>&1 &
dolphin >>"$LOG" 2>&1 &
sleep 6
echo "[f7] ventanas abiertas" | tee -a "$LOG"
"$MCBIN" --shot "$OUT/f7-mc-grab.png" >>"$LOG" 2>&1 &
MCPID=$!
sleep 9
if kill -0 $MCPID 2>/dev/null; then echo "[f7] mc VIVO pid=$MCPID" | tee -a "$LOG"; else echo "[f7] mc MUERTO" | tee -a "$LOG"; fi
echo "[f7] windowCount=$(qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] desktopCount=$(qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.desktopCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] openLatencyMs=$(qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.openLatencyMs 2>>"$LOG")" | tee -a "$LOG"
T0=$(date +%s%N)
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.toggle >>"$LOG" 2>&1; TR=$?
T1=$(date +%s%N)
echo "[f7] toggle1_rc=$TR toggle_ms=$(( (T1-T0)/1000000 ))" | tee -a "$LOG"
sleep 1
T0=$(date +%s%N)
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.toggle >>"$LOG" 2>&1; TR=$?
T1=$(date +%s%N)
echo "[f7] toggle2_rc=$TR toggle_ms=$(( (T1-T0)/1000000 ))" | tee -a "$LOG"
sleep 2
echo "[f7] activateFirst=$(qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.activateFirst 2>>"$LOG")" | tee -a "$LOG"
sleep 2
spectacle -b -n -o "$OUT/f7-mc-spectacle.png" >>"$LOG" 2>&1 \
  && echo "[f7] spectacle OK" | tee -a "$LOG" || echo "[f7] WARN spectacle fallo" | tee -a "$LOG"
cp -f "$OUT/f7-mc-grab.png" "$OUT/f7-mc.png"
ls -la "$OUT"/f7-mc*.png >>"$LOG" 2>&1 || true
kill $MCPID 2>/dev/null || true
sleep 1
