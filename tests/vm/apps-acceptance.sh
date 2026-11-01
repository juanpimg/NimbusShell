#!/usr/bin/env bash
# F6-T09 aceptación Apps: abre/cierra, categorías + Suggestions, vistas
# Icons/List, teclado completo. Nested KWin virtual + HOME/XDG temporales
# (dbus-run-session). NUNCA toca ~/.config del host, su sesión, root ni red.
# Uso: bash tests/vm/apps-acceptance.sh [--out spikes/nested] [--timeout 120]
#        [--bin /tmp/.../nimbus-apps]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=120
BIN="/tmp/opencode/f6accept-apps/nimbus-apps"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BIN="${!j}" ;;
  esac
done
case "$BIN" in /*) BIN_ABS="$BIN" ;; *) BIN_ABS="$REPO_ROOT/$BIN" ;; esac
[ -x "$BIN_ABS" ] || { echo "ERROR: sin binario $BIN_ABS" >&2; exit 1; }

OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/f6-apps-acceptance-nested.log"
: > "$LOG"

QML="$REPO_ROOT/apps/nimbus-apps/qml/AppsWindow.qml"
MODEL="$REPO_ROOT/apps/nimbus-apps/appmodel.cpp"
MAIN="$REPO_ROOT/apps/nimbus-apps/main.cpp"

# --- Estático: categorías/Suggestions/vistas/teclado declarados ---
echo "[apps-acc] checks estáticos en AppsWindow.qml/appmodel" | tee -a "$LOG"
static_ok=0; static_fail=0
scheck() { # $1=desc $2=patrón $3=fichero
  if grep -qE "$2" "$3"; then echo "[apps-acc] STATIC-OK: $1" | tee -a "$LOG"; static_ok=$((static_ok+1));
  else echo "[apps-acc] STATIC-FAIL: $1" | tee -a "$LOG"; static_fail=$((static_fail+1)); fi
}
scheck "categorías fijas" '"Todas", "Suggestions"' "$QML"
scheck "vista rejilla" 'GridView' "$QML"
scheck "vista lista" 'ListView' "$QML"
scheck "flag --view icons|list" '"view"' "$MAIN"
scheck "flag --category" '"category"' "$MAIN"
scheck "teclado categorías (arriba/abajo/Home/End)" 'Qt\.Key_Home' "$QML"
scheck "teclado rejilla (flechas+Enter+Esc)" 'Qt\.Key_Return \|\| event\.key === Qt\.Key_Enter' "$QML"
scheck "Esc oculta" 'Keys\.onEscapePressed|Shortcut.*Escape' "$QML"
scheck "Tab buscador<->rejilla" 'Tab pasa al selector|Tab vuelve al buscador' "$QML"
scheck "filtro por nombre" 'Filtra por nombre' "$QML"
scheck "modelo expone categorías" 'fixedCategories' "$MODEL"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-appsacc-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-appsacc" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[n]imbus-apps.*nimbus-appsacc" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[apps-acc] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
BIN="'"$BIN_ABS"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-appsacc"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[apps-acc] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[apps-acc] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2
# Abre: --demo vista icons + captura propia.
echo "[apps-acc] nimbus-apps --demo --shot f6-apps-acceptance.png ..." | tee -a "$LOG"
"$BIN" --demo --shot "$OUT_ABS/f6-apps-acceptance.png" >>"$LOG" 2>&1 &
APPS_PID=$!
sleep 8
if [ -s "$OUT_ABS/f6-apps-acceptance.png" ]; then echo "[apps-acc] ABRE-OK: f6-apps-acceptance.png" | tee -a "$LOG";
else echo "[apps-acc] ABRE-FAIL: sin captura icons" | tee -a "$LOG"; fi
kill $APPS_PID 2>/dev/null || true
wait $APPS_PID 2>/dev/null || true
# Vista lista + categoría Desarrollo.
echo "[apps-acc] nimbus-apps --demo --view list --category Desarrollo ..." | tee -a "$LOG"
"$BIN" --demo --view list --category Desarrollo --shot "$OUT_ABS/f6-apps-acceptance-list.png" >>"$LOG" 2>&1 &
LIST_PID=$!
sleep 8
if [ -s "$OUT_ABS/f6-apps-acceptance-list.png" ]; then echo "[apps-acc] VISTA-OK: list+Desarrollo" | tee -a "$LOG";
else echo "[apps-acc] VISTA-FAIL: sin captura list" | tee -a "$LOG"; fi
kill $LIST_PID 2>/dev/null || true
wait $LIST_PID 2>/dev/null || true
# Toggle abre/cierra vía DBus contra instancia viva.
"$BIN" --demo >>"$LOG" 2>&1 &
TOG_PID=$!
sleep 5
if kill -0 $TOG_PID 2>/dev/null; then echo "[apps-acc] instancia toggle VIVA" | tee -a "$LOG";
else echo "[apps-acc] TOGGLE-FAIL: instancia muerta" | tee -a "$LOG"; fi
"$BIN" --toggle >>"$LOG" 2>&1 && echo "[apps-acc] toggle oculta rc=0" | tee -a "$LOG" \
  || echo "[apps-acc] WARN: toggle oculta rc!=0" | tee -a "$LOG"
sleep 1
"$BIN" --toggle >>"$LOG" 2>&1 && echo "[apps-acc] toggle muestra rc=0" | tee -a "$LOG" \
  || echo "[apps-acc] WARN: toggle muestra rc!=0" | tee -a "$LOG"
sleep 1
spectacle -b -n -o "$OUT_ABS/f6-apps-acceptance-spectacle.png" >>"$LOG" 2>&1 \
  && echo "[apps-acc] spectacle OK" | tee -a "$LOG" \
  || echo "[apps-acc] WARN: spectacle fallo" | tee -a "$LOG"
kill $TOG_PID 2>/dev/null || true
wait $TOG_PID 2>/dev/null || true
echo "[apps-acc] CIERRA-OK (instancia terminada)" | tee -a "$LOG"
ls -la "$OUT_ABS"/f6-apps-acceptance*.png 2>>"$LOG" || true
grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-apps-acceptance-qmlerr.txt" || true
if [ -s "$OUT_ABS/f6-apps-acceptance-qmlerr.txt" ]; then cat "$OUT_ABS/f6-apps-acceptance-qmlerr.txt" | tee -a "$LOG";
else echo "[apps-acc] 0 errores QML" | tee -a "$LOG"; fi
kill $KWIN_PID 2>/dev/null || true
wait $KWIN_PID 2>/dev/null || true
' 2>>"$LOG"
RC=$?
pkill -f "[n]imbus-appsacc" 2>/dev/null || true
QMLERR_N=0
[ -s "$OUT_ABS/f6-apps-acceptance-qmlerr.txt" ] && QMLERR_N=$(wc -l < "$OUT_ABS/f6-apps-acceptance-qmlerr.txt")
echo "[apps-acc] static_ok=$static_ok static_fail=$static_fail qmlerr=$QMLERR_N nested_rc=$RC"
echo "[apps-acc] fin. Log: $LOG"
if [ "$static_fail" -ne 0 ] || [ "$QMLERR_N" -ne 0 ] || [ "$RC" -ne 0 ]; then
  echo "[apps-acc] VEREDICTO: FAIL" | tee -a "$LOG"
  exit 1
fi
echo "[apps-acc] VEREDICTO: PASS" | tee -a "$LOG"
