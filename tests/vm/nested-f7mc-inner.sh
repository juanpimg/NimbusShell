#!/usr/bin/env bash
# Interior del bus anidado F7 R-MC-CUSTOM (hereda F7BASE/F7LOG/F7OUT/F7MCBIN).
set -u
export HOME="$F7BASE/home"; mkdir -p "$HOME/.config"
export XDG_RUNTIME_DIR="$F7BASE/rt"
export XDG_CONFIG_HOME="$F7BASE/c" XDG_DATA_HOME="$F7BASE/d"
export XDG_CACHE_HOME="$F7BASE/ch" XDG_STATE_HOME="$F7BASE/s"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY=nimbus-f7mc
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
# 10 ventanas (F7-T04): 3 kate + 3 konsole + 2 dolphin + kwrite + kcalc.
kate >>"$LOG" 2>&1 &
kate >>"$LOG" 2>&1 &
kate >>"$LOG" 2>&1 &
konsole >>"$LOG" 2>&1 &
konsole >>"$LOG" 2>&1 &
konsole >>"$LOG" 2>&1 &
dolphin >>"$LOG" 2>&1 &
dolphin >>"$LOG" 2>&1 &
kwrite >>"$LOG" 2>&1 &
kcalc >>"$LOG" 2>&1 &
sleep 10
echo "[f7] 10 ventanas pedidas" | tee -a "$LOG"
# MC arranca con 1 Space: ensureSpaces(4) debe crear Escritorio 1..4.
"$MCBIN" --shot "$OUT/f7-mc-grab.png" >>"$LOG" 2>&1 &
MCPID=$!
sleep 10
if kill -0 $MCPID 2>/dev/null; then echo "[f7] mc VIVO pid=$MCPID" | tee -a "$LOG"; else echo "[f7] mc MUERTO" | tee -a "$LOG"; fi
echo "[f7] windowCount=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] desktopCount=$($MC.desktopCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] openLatencyMs=$($MC.openLatencyMs 2>>"$LOG")" | tee -a "$LOG"
$MC.grabShot "$OUT/f7-mc-spaces.png" >>"$LOG" 2>&1
echo "[f7] spaces_rc=$? shot=$([ -f "$OUT/f7-mc-spaces.png" ] && echo OK || echo FALTA)" | tee -a "$LOG"
# F7-T07: App Exposé ON + F7-T04: thumbs reales.
$MC.toggleExpose >>"$LOG" 2>&1
$MC.requestThumbs >>"$LOG" 2>&1
sleep 30
echo "[f7] thumbLog:" | tee -a "$LOG"
$MC.thumbLog 2>>"$LOG" | tee -a "$LOG"
$MC.grabShot "$OUT/f7-mc-thumbs.png" >>"$LOG" 2>&1
echo "[f7] thumbs_rc=$? shot=$([ -f "$OUT/f7-mc-thumbs.png" ] && echo OK || echo FALTA)" | tee -a "$LOG"
# F7-T05 drag: 5 casos (mover a 4, volver a 1, mismo space, índice inválido, UI DropArea=código).
echo "[f7] total_antes=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] drag1=$($MC.moveFirstTo 4 2>>"$LOG")" | tee -a "$LOG"
sleep 4
$MC.refresh >>"$LOG" 2>&1
sleep 4
echo "[f7] total_tras1=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] drag2=$($MC.moveFirstTo 1 2>>"$LOG")" | tee -a "$LOG"
sleep 4
$MC.refresh >>"$LOG" 2>&1
sleep 4
echo "[f7] total_tras2=$($MC.windowCount 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] drag_same=$($MC.moveFirstTo 1 2>>"$LOG")" | tee -a "$LOG"
echo "[f7] drag_invalid=$($MC.moveFirstTo 99 2>>"$LOG") rc=$?" | tee -a "$LOG"
# F7-T07: Show Desktop ida y vuelta (verifica prop KWin).
$MC.showDesktop true >>"$LOG" 2>&1; sleep 1
echo "[f7] showingDesktop=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.showingDesktop 2>>"$LOG")" | tee -a "$LOG"
$MC.showDesktop false >>"$LOG" 2>&1; sleep 1
echo "[f7] showingDesktop=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.showingDesktop 2>>"$LOG")" | tee -a "$LOG"
# F7-T01: Meta+Ctrl+flechas stock siguen (best-effort vía kglobalaccel).
qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Switch One Desktop to the Left" >>"$LOG" 2>&1
echo "[f7] meta_ctrl_left_rc=$? currentDesktop=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.currentDesktop 2>>"$LOG")" | tee -a "$LOG"
# F7-T06: fps durante la intro + reduce-motion.
$MC.replayIntro >>"$LOG" 2>&1
echo "[f7] fps_intro=$($MC.fpsProbe 2>>"$LOG")" | tee -a "$LOG"
$MC.setReduceMotion true >>"$LOG" 2>&1
sleep 1
$MC.grabShot "$OUT/f7-mc-rm.png" >>"$LOG" 2>&1
echo "[f7] rm_rc=$? shot=$([ -f "$OUT/f7-mc-rm.png" ] && echo OK || echo FALTA)" | tee -a "$LOG"
$MC.setReduceMotion false >>"$LOG" 2>&1
# F7-T10: matriz de aceptación (misma ruta que UI/atajos vía selftestKey).
echo "[f7t10] st0=$($MC.uiState 2>>"$LOG")" | tee -a "$LOG"
$MC.show >>"$LOG" 2>&1; sleep 1
echo "[f7t10] 1-abrir=$($MC.isVisible 2>>"$LOG")" | tee -a "$LOG"
echo "[f7t10] key-Esc=$($MC.selftestKey Escape 2>>"$LOG") vis=$($MC.isVisible 2>>"$LOG")" | tee -a "$LOG"
$MC.show >>"$LOG" 2>&1; sleep 1
$MC.setCurrentDesktopByIndex 2 >>"$LOG" 2>&1; sleep 1
echo "[f7t10] 3-switch=currentDesktop=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.currentDesktop 2>>"$LOG")" | tee -a "$LOG"
$MC.setCurrentDesktopByIndex 1 >>"$LOG" 2>&1; sleep 1
echo "[f7t10] 4-activar=$($MC.activateFirst 2>>"$LOG")" | tee -a "$LOG"
echo "[f7t10] 6-expose=$($MC.selftestKey Tab 2>>"$LOG") st=$($MC.uiState 2>>"$LOG")" | tee -a "$LOG"
echo "[f7t10] key-Left=$($MC.selftestKey Left 2>>"$LOG") st=$($MC.uiState 2>>"$LOG")" | tee -a "$LOG"
echo "[f7t10] key-Right=$($MC.selftestKey Right 2>>"$LOG") st=$($MC.uiState 2>>"$LOG")" | tee -a "$LOG"
echo "[f7t10] key-Enter=$($MC.selftestKey Enter 2>>"$LOG") vis=$($MC.isVisible 2>>"$LOG")" | tee -a "$LOG"
$MC.show >>"$LOG" 2>&1; sleep 1
echo "[f7t10] 10-rm=$($MC.uiState 2>>"$LOG")" | tee -a "$LOG"
cp -f "$OUT/f7-mc-grab.png" "$OUT/f7-mc.png"
ls -la "$OUT"/f7-mc*.png >>"$LOG" 2>&1 || true
kill $MCPID 2>/dev/null || true
sleep 1
