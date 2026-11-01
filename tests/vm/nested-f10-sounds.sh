#!/usr/bin/env bash
# F10-T05 — Test anidado de sonidos Nimbus + Spectacle. Seguro en host:
# NUNCA --replace/root/instalar; todo en XDG_* temporales bajo
# dbus-run-session. Uso: bash tests/vm/nested-f10-sounds.sh [--out spikes/nested] [--timeout 60]
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
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f10-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
for v in CONFIG DATA CACHE STATE; do mkdir -p "$BASE_TMP/${v,,}"; done
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
# Dotfiles plasma reales (incluye kdeglobals [Sounds] y spectaclerc F10-T05).
DEPLOYED=0
for f in "$REPO_ROOT/dotfiles/.config/plasma"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in README*) continue ;; esac
  cp -f "$f" "$NESTED_HOME/.config/" && DEPLOYED=$((DEPLOYED+1))
done
# Tema de sonido a XDG_DATA_HOME/sounds/Nimbus (como haria install.sh).
mkdir -p "$BASE_TMP/data/sounds/Nimbus"
cp -rf "$REPO_ROOT/packages/themes/sounds-nimbus/index.theme" \
  "$REPO_ROOT/packages/themes/sounds-nimbus/stereo" \
  "$BASE_TMP/data/sounds/Nimbus/"
# Sin bloqueo en la sesion anidada (el seed de producto bloquea; aqui
# queremos el escritorio + banner visibles en la captura).
XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file kscreenlockerrc \
  --group Daemon --key Autolock false
XDG_CONFIG_HOME="$NESTED_HOME/.config" kwriteconfig6 --file kscreenlockerrc \
  --group Daemon --key LockOnResume false
LOG="$OUT_ABS/f10-nested.log"
: > "$LOG"
echo "[f10] dotfiles=$DEPLOYED sonidos instalados en \$XDG_DATA_HOME/sounds/Nimbus" | tee -a "$LOG"
echo "[f10] find:" | tee -a "$LOG"
find "$BASE_TMP/data/sounds/Nimbus" -type f | sort | tee -a "$LOG"
echo "[f10] ffprobe (duracion):" | tee -a "$LOG"
for o in "$BASE_TMP/data/sounds/Nimbus"/stereo/*.oga; do
  printf '  %s %ss\n' "$(basename "$o")" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$o")" | tee -a "$LOG"
done
export WAYLAND_DISPLAY="nimbus-f10"
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME"'/.config"
export XDG_DATA_HOME="'"$BASE_TMP"'/data"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache"
export XDG_STATE_HOME="'"$BASE_TMP"'/state"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0; i<TIMEOUT*2; i++)); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[f10] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
plasmashell >>"$LOG" 2>&1 &
sleep 8
echo "[f10] kdeglobals Sounds: $(kreadconfig6 --file kdeglobals --group Sounds --key Theme 2>>"$LOG") / Enable=$(kreadconfig6 --file kdeglobals --group Sounds --key Enable 2>>"$LOG")" | tee -a "$LOG"
echo "[f10] spectaclerc: autoSave=$(kreadconfig6 --file spectaclerc --group General --key autoSaveImage 2>>"$LOG") clipboard=$(kreadconfig6 --file spectaclerc --group General --key clipboardGroup 2>>"$LOG")" | tee -a "$LOG"
# El greeter del locker arranca con --immediateLock en nested y SetActive
# no lo baja: matar el greeter para ver escritorio + banner en la captura.
# (El nombre se compone para que pkill -f no se suicide con su propia
# linea de comando ni con comentarios que contengan el literal.)
P="k"
pkill -f "[$P]screenlocker_greet" >>"$LOG" 2>&1 || true
sleep 1
notify-send "Nimbus" "Tema de sonido Nimbus activo (prueba F10-T05)" -t 4000 >>"$LOG" 2>&1 || echo "[f10] WARN: notify-send fallo" | tee -a "$LOG"
sleep 2
spectacle -b -n -o "$OUT_ABS/f10-sounds.png" >>"$LOG" 2>&1 \
  && echo "[f10] f10-sounds.png OK" | tee -a "$LOG" \
  || echo "[f10] WARN: captura fallo" | tee -a "$LOG"
spectacle -b -f -o "$OUT_ABS/f10-spectacle.png" >>"$LOG" 2>&1 \
  && echo "[f10] f10-spectacle.png OK (fullscreen via Spectacle)" | tee -a "$LOG" \
  || echo "[f10] WARN: spectacle fullscreen fallo" | tee -a "$LOG"
ls -la "$OUT_ABS"/f10-* >>"$LOG" 2>&1
' >>"$LOG" 2>&1
RC=$?
echo "[f10] exit=$RC" | tee -a "$LOG"
rm -rf "$BASE_TMP"
exit $RC
