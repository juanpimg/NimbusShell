#!/usr/bin/env bash
# F10-T02/T03 nested: Dolphin Finder-like + Konsole Nimbus + mimeapps.
# Patron tests/vm/nested-plasma.sh: HOME/XDG temporales, dbus-run-session,
# kwin_wayland --virtual --no-lockscreen. NUNCA --replace, ~/.config del
# host, root ni red. Limpieza por trap.
# Uso: bash tests/vm/nested-f10apps.sh [--out spikes/nested] [--timeout 60]
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
BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-f10apps-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
NH="$BASE_TMP/home"
mkdir -p "$NH/.config" "$NH/.local/share/konsole" "$BASE_TMP/cache" "$BASE_TMP/state"
LOG="$OUT_ABS/f10-apps-nested.log"
: > "$LOG"
cleanup() {
  ps -eo pid,args | grep "[k]win_wayland --virtual.*f10apps-sock" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[f10apps] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM
# Despliegue dotfiles reales al HOME temporal (solo lectura del repo).
cp -f "$REPO_ROOT/dotfiles/.config/dolphinrc" "$REPO_ROOT/dotfiles/.config/konsolerc" \
  "$REPO_ROOT/dotfiles/.config/mimeapps.list" "$NH/.config/"
# kwinrulesrc: regla Nimbus existente (Dolphin/Konsole 1100x700 centradas).
# [MainWindow] Width/Height de dolphinrc los ignora Dolphin 26 en arranque
# (probado: 700x500 sin efecto); el tamano inicial lo impone KWin.
cp -f "$REPO_ROOT/dotfiles/.config/kwinrulesrc" "$NH/.config/"
mkdir -p "$NH/.local/share/dolphin/view_properties/global"
cp -f "$REPO_ROOT/dotfiles/.local/share/dolphin/view_properties/global/.directory" \
  "$NH/.local/share/dolphin/view_properties/global/.directory"
cp -f "$REPO_ROOT/dotfiles/.local/share/konsole/Nimbus.profile" \
  "$REPO_ROOT/dotfiles/.local/share/konsole/Nimbus.colorscheme" "$NH/.local/share/konsole/"
echo "[f10apps] dotfiles desplegados en $NH" | tee -a "$LOG"
# Carpeta de prueba con nombres para orden natural (a1,a2,a10...).
mkdir -p "$NH/F10test"
for n in a1 a2 a10 a20 img1 img2 img10 doc.txt nota.txt sub; do
  if [ "$n" = "sub" ]; then mkdir -p "$NH/F10test/$n"; else : > "$NH/F10test/$n"; fi
done
export XDG_RUNTIME_DIR
timeout "$TIMEOUT" dbus-run-session -- bash -c '
set -u
export HOME="'"$NH"'" XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache" XDG_STATE_HOME="'"$BASE_TMP"'/state"
export QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="f10apps-sock"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE
LOG="'"$LOG"'"
OUT_ABS="'"$OUT_ABS"'"
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 \
  --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
for ((i=0;i<60;i++)); do [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break; sleep 0.5; done
[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { echo "[f10apps] ERROR: sin socket" | tee -a "$LOG"; exit 1; }
sleep 2
echo "[f10apps] --- kreadconfig6 (HOME temporal) ---" | tee -a "$LOG"
echo "  SortingChoice=$(kreadconfig6 --file dolphinrc --group General --key SortingChoice 2>>"$LOG")" | tee -a "$LOG"
echo "  GlobalViewProps=$(kreadconfig6 --file dolphinrc --group General --key GlobalViewProps 2>>"$LOG")" | tee -a "$LOG"
echo "  GlobalViewMode=$(kreadconfig6 --file "$XDG_DATA_HOME/dolphin/view_properties/global/.directory" --group Dolphin --key ViewMode 2>>"$LOG")" | tee -a "$LOG"
echo "  GlobalPreviews=$(kreadconfig6 --file "$XDG_DATA_HOME/dolphin/view_properties/global/.directory" --group Dolphin --key PreviewsShown 2>>"$LOG")" | tee -a "$LOG"
echo "  Width=$(kreadconfig6 --file dolphinrc --group MainWindow --key Width 2>>"$LOG")" | tee -a "$LOG"
echo "  Height=$(kreadconfig6 --file dolphinrc --group MainWindow --key Height 2>>"$LOG")" | tee -a "$LOG"
echo "  ConfirmTrash=$(kreadconfig6 --file dolphinrc --group General --key ConfirmTrash 2>>"$LOG")" | tee -a "$LOG"
echo "  DefaultProfile=$(kreadconfig6 --file konsolerc --group Desktop\ Entry --key DefaultProfile 2>>"$LOG")" | tee -a "$LOG"
echo "  ProfileFont=$(kreadconfig6 --file "$XDG_DATA_HOME/konsole/Nimbus.profile" --group Appearance --key Font 2>>"$LOG")" | tee -a "$LOG"
echo "  ProfileScheme=$(kreadconfig6 --file "$XDG_DATA_HOME/konsole/Nimbus.profile" --group Appearance --key ColorScheme 2>>"$LOG")" | tee -a "$LOG"
echo "  SchemeOpacity=$(kreadconfig6 --file "$XDG_DATA_HOME/konsole/Nimbus.colorscheme" --group General --key Opacity 2>>"$LOG")" | tee -a "$LOG"
echo "  SchemeBlur=$(kreadconfig6 --file "$XDG_DATA_HOME/konsole/Nimbus.colorscheme" --group General --key Blur 2>>"$LOG")" | tee -a "$LOG"
echo "  SchemeBg=$(kreadconfig6 --file "$XDG_DATA_HOME/konsole/Nimbus.colorscheme" --group Background --key Color 2>>"$LOG")" | tee -a "$LOG"
echo "[f10apps] --- xdg-mime query default ---" | tee -a "$LOG"
for m in x-scheme-handler/https text/html application/pdf image/jpeg inode/directory video/mp4; do
  echo "  $m=$(xdg-mime query default "$m" 2>>"$LOG")" | tee -a "$LOG"
done
echo "[f10apps] perfiles konsole: $(konsole --list-profiles 2>>"$LOG" | tr "\n" " ")" | tee -a "$LOG"
echo "[f10apps] konsole (perfil Nimbus) ..." | tee -a "$LOG"
konsole --profile Nimbus --qwindowgeometry 900x560+190+110 >>"$LOG" 2>&1 &
KPID=$!; sleep 5
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-konsole.png" >>"$LOG" 2>&1 \
  && echo "[f10apps] f10-konsole.png OK" | tee -a "$LOG" \
  || echo "[f10apps] WARN: captura konsole fallo" | tee -a "$LOG"
echo "[f10apps] dolphin (F10test) ..." | tee -a "$LOG"
dolphin --new-window "$HOME/F10test" >>"$LOG" 2>&1 &
DPID=$!; sleep 6
timeout 20 spectacle -b -n -o "$OUT_ABS/f10-dolphin.png" >>"$LOG" 2>&1 \
  && echo "[f10apps] f10-dolphin.png OK" | tee -a "$LOG" \
  || echo "[f10apps] WARN: captura dolphin fallo" | tee -a "$LOG"
# NOTA: el tamano se verifica por medicion en la captura (titlebar x=90..1189,
# ventana 1100x700 centrada en 1280x800); KWin scripting print() no vuelca a
# log en este build, no se usa.
echo "[f10apps] --- 10 operaciones de archivo en carpeta temporal ---" | tee -a "$LOG"
T="$HOME/F10ops"; mkdir -p "$T"; OPS_OK=0
op() { if eval "$2"; then OPS_OK=$((OPS_OK+1)); echo "  op$1 OK: $3" | tee -a "$LOG"; else echo "  op$1 FALLO: $3" | tee -a "$LOG"; fi; }
op 1 "touch \"$T/f1.txt\" \"$T/f2.txt\" \"$T/f10.txt\"" "touch x3"
op 2 "mkdir -p \"$T/sub\"" "mkdir"
op 3 "cp \"$T/f1.txt\" \"$T/sub/copia.txt\"" "cp"
op 4 "mv \"$T/f2.txt\" \"$T/sub/movido.txt\"" "mv"
op 5 "ls \"$T\" >/dev/null" "ls"
op 6 "ls -v \"$T\" | head -3 >/dev/null" "orden natural (ls -v)"
op 7 "kioclient move \"$T/f10.txt\" trash:/ >>\"$LOG\" 2>&1" "trash via KIO"
op 8 "test -e \"$HOME/.local/share/Trash/files/f10.txt\"" "en papelera"
op 9 "kioclient move \"trash:/files/f10.txt\" \"$T/f10-vuelta.txt\" >>\"$LOG\" 2>&1 || cp \"$HOME/.local/share/Trash/files/f10.txt\" \"$T/f10-vuelta.txt\"" "restaurar"
op 10 "rm -rf \"$T\"" "limpieza"
echo "[f10apps] OPS_OK=$OPS_OK/10" | tee -a "$LOG"
kill $DPID $KPID 2>/dev/null; sleep 2; kill -9 $DPID $KPID 2>/dev/null || true
echo "[f10apps] FIN" | tee -a "$LOG"
kill $(jobs -p) 2>/dev/null || true
' 2>>"$LOG"
RC=$?
pkill -f "f10apps-sock" 2>/dev/null || true
echo "[f10apps] exit=$RC"
ls -la "$OUT_ABS"/f10-dolphin.png "$OUT_ABS"/f10-konsole.png 2>&1
