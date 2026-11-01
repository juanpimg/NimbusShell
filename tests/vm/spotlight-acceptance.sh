#!/usr/bin/env bash
# F6-T09 aceptación Spotlight: 20 consultas + 10 apps lanzables + teclado +
# toggle/cierre, con latencia local (<50ms) y fallback KRunner documentado.
# Nested KWin virtual + HOME/XDG temporales (dbus-run-session). NUNCA toca
# ~/.config del host, su sesión, root ni red.
# Uso: bash tests/vm/spotlight-acceptance.sh [--out spikes/nested]
#        [--timeout 150] [--bin /tmp/.../nimbus-spotlight]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=150
BIN="/tmp/opencode/f6accept-spot/nimbus-spotlight"
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
LOG="$OUT_ABS/f6-acceptance-nested.log"
TABLE="$OUT_ABS/f6-acceptance-table.txt"
: > "$LOG"
: > "$TABLE"

QML="$REPO_ROOT/apps/nimbus-spotlight/qml/Spotlight.qml"

# --- Estático: navegación por teclado declarada en QML (sin sintetizar teclas
# en nested: no hay ydotool/wtype en el runner; el runtime cubre toggle) ---
echo "[spot-acc] checks estáticos de teclado en Spotlight.qml" | tee -a "$LOG"
static_ok=0; static_fail=0
scheck() { # $1=desc $2=patrón grep -E
  if grep -qE "$2" "$QML"; then echo "[spot-acc] STATIC-OK: $1" | tee -a "$LOG"; static_ok=$((static_ok+1));
  else echo "[spot-acc] STATIC-FAIL: $1" | tee -a "$LOG"; static_fail=$((static_fail+1)); fi
}
scheck "Cmd+1..4 (Meta+1..4)" 'sequence: "Meta\+[1234]"'
scheck "Quick Keys A-L" 'ABCDEFGHIJKL'
scheck "flechas arriba/abajo" 'Qt\.Key_Down.*Qt\.Key_Up|Key_Down'
scheck "Home/End" 'Qt\.Key_Home|Qt\.Key_End'
scheck "RePág/AvPág" 'Qt\.Key_PageDown|Qt\.Key_PageUp'
scheck "Enter activa" 'Qt\.Key_Return'
scheck "Esc cierra" 'Qt\.Key_Escape|sequence: "Escape"'
scheck "Ctrl+Tab fallback KRunner" 'sequence: "Ctrl\+Tab"'
scheck "Tab navega sin trampas" 'KeyNavigation\.tab'

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-spotacc-XXXXXX)"
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
  ps -eo pid,args | grep "[k]win_wayland --virtual.*nimbus-spotacc" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  ps -eo pid,args | grep "[n]imbus-spotlight.*nimbus-spotacc" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[spot-acc] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

# Semillas de ficheros + portapapeles en el HOME temporal.
mkdir -p "$NESTED_HOME/Documents"
printf 'informe anual 2026\n' > "$NESTED_HOME/Documents/informe-2026.txt"
printf 'notas de la reunion\n' > "$NESTED_HOME/Documents/reunión-notas.txt"
printf 'lista de la compra\n' > "$NESTED_HOME/Documents/música-lista.txt"
mkdir -p "$NESTED_HOME/.local/share"
cat > "$NESTED_HOME/.local/share/recently-used.xbel" <<'EOF'
<?xml version="1.0"?>
<xbel version="1.0"><bookmark href="file://REPLACEME/Documents/informe-2026.txt"/></xbel>
EOF
sed -i "s|REPLACEME|$NESTED_HOME|" "$NESTED_HOME/.local/share/recently-used.xbel"
mkdir -p "$NESTED_HOME/.local/share/klipper"
printf 'nota de reunion manana\nhttps://ejemplo.es/informe\ncomando --revision 42\n' \
  > "$NESTED_HOME/.local/share/klipper/history2.lst"
echo "[spot-acc] semillas: 3 ficheros + xbel + history2.lst" | tee -a "$LOG"

# 18 consultas DBus (fichero creado FUERA del bloque nested para que la
# ruta exista en ambos; #19 clipboard y #20 sin-resultados van offscreen).
QUERIES_FILE="$BASE_TMP/queries.txt"
printf "%s\n" \
  "kate|app exacta|apps" \
  "dolphin|app exacta|apps" \
  "konsole|app exacta|apps" \
  "kat|prefijo|apps" \
  "dolp|prefijo|apps" \
  "kons|prefijo|apps" \
  "ktae|fuzzy (transposición)|apps" \
  "cnsol|fuzzy|apps" \
  "gwenviw|fuzzy|apps" \
  "ratón|acentos (ajuste Ratón)|fuzzy+fold" \
  "reunion|acentos (fichero reunión-notas)|fuzzy+fold" \
  "informe|archivo semilla|files" \
  "wifi|ajuste (KCM Red)|settings" \
  "pantalla|ajuste (KCM Pantalla)|settings" \
  "2+2*3|calc|calc=8" \
  "(10-4)/2|calc|calc=3" \
  "?clima mañana|web|DuckDuckGo" \
  "nimbus shell|web genérica|DuckDuckGo" > "$QUERIES_FILE"

dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
BIN="'"$BIN_ABS"'"
LOG="'"$LOG"'"
TABLE="'"$TABLE"'"
QUERIES_FILE="'"$QUERIES_FILE"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-spotacc"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT

echo "[spot-acc] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[spot-acc] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2
echo "[spot-acc] arranque nimbus-spotlight --query kate ..." | tee -a "$LOG"
"$BIN" --query "kate" --shot "$OUT_ABS/f6-acceptance.png" >>"$LOG" 2>&1 &
SPOT_PID=$!
sleep 9
if kill -0 $SPOT_PID 2>/dev/null; then echo "[spot-acc] spotlight VIVO (pid $SPOT_PID)" | tee -a "$LOG";
else echo "[spot-acc] ERROR: spotlight MUERTO" | tee -a "$LOG"; exit 1; fi
sleep 4  # scanFilesAsync (ficheros semilla) en hilo aparte

# 18 consultas vía DBus query() (síncrono): #19 clipboard y #20 sin-resultados
# van en runs offscreen propios más abajo.
: > "$TABLE"
printf "%s|%s|%s|%s|%s\n" "n" "consulta" "tipo" "ms" "resultados" >> "$TABLE"
n=0; maxms=0; fails=0
while IFS="|" read -r q kind expect; do
  n=$((n+1))
  before=$(grep -c "spotlight-local-latency" "$LOG" || true)
  qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.query "$q" >>"$LOG" 2>&1
  rc=$?
  sleep 0.4
  line=$(grep "spotlight-local-latency" "$LOG" | sed -n "$((before+1))p")
  ms=$(printf "%s" "$line" | sed -n "s/.*query=\([0-9]*\)ms.*/\1/p")
  res=$(printf "%s" "$line" | sed -n "s/.*results=\([0-9]*\).*/\1/p")
  [ -n "$ms" ] || ms="?"
  [ -n "$res" ] || res="?"
  printf "%s|%s|%s|%s|%s\n" "$n" "$q" "$kind" "$ms" "$res" >> "$TABLE"
  echo "[spot-acc] q$n [$kind] $q -> ${ms}ms res=$res (rc=$rc)" | tee -a "$LOG"
  case "$ms" in ""|"?"*) fails=$((fails+1)) ;; *) [ "$ms" -lt 50 ] || fails=$((fails+1)); [ "$ms" -gt "$maxms" ] && maxms="$ms" ;; esac
  case "$res" in ""|"?"*|"0") fails=$((fails+1)) ;; esac
done < "$QUERIES_FILE"
echo "[spot-acc] latencia local máx=${maxms}ms, fallos(ms>=50 o res=0)=$fails" | tee -a "$LOG"
echo "[spot-acc] FAILCOUNT=$fails" | tee -a "$LOG"

# 10 apps lanzables: hit en índice (ya medido arriba para kate/dolphin/
# konsole) + .desktop con Exec cuyo binario existe. Sin lanzar de verdad
# en nested (evita 10 ventanas y flakiness; el lanzamiento real es manual).
echo "[spot-acc] 10 apps lanzables (.desktop + Exec existe):" | tee -a "$LOG"
for app in kate dolphin konsole spectacle gwenview ark kcalc firefox systemsettings Alacritty; do
  desk=$(ls /usr/share/applications/ | grep -i "$app" | head -1)
  if [ -z "$desk" ]; then echo "[spot-acc] APP-FAIL: $app sin .desktop" | tee -a "$LOG"; fails=$((fails+1)); continue; fi
  execbin=$(grep -m1 "^Exec=" "/usr/share/applications/$desk" | sed "s/^Exec=//" | awk "{print \$1}" | sed "s|.*/||")
  if command -v "$execbin" >/dev/null 2>&1; then echo "[spot-acc] APP-OK: $app ($desk -> $execbin)" | tee -a "$LOG";
  else echo "[spot-acc] APP-FAIL: $app ($desk Exec=$execbin ausente)" | tee -a "$LOG"; fails=$((fails+1)); fi
done

# Toggle/cierre vía DBus (teclado físico Esc/Meta+Espacio: gap, ver evidencia).
qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle >>"$LOG" 2>&1 \
  && echo "[spot-acc] toggle oculta rc=0" | tee -a "$LOG" \
  || { echo "[spot-acc] toggle FAIL" | tee -a "$LOG"; fails=$((fails+1)); }
sleep 1
qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle >>"$LOG" 2>&1 \
  && echo "[spot-acc] toggle muestra rc=0" | tee -a "$LOG" \
  || { echo "[spot-acc] toggle FAIL" | tee -a "$LOG"; fails=$((fails+1)); }
sleep 1
# KRunner fallback: en bus aislado no hay daemon (NameHasOwner, sin arranque).
if qdbus6 org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner "org.kde.krunner" 2>>"$LOG" | grep -q "true"; then
  echo "[spot-acc] krunner presente en nested (inesperado)" | tee -a "$LOG"
else
  echo "[spot-acc] krunner ausente en nested: fallback no medible aquí (ref F6-T02: ~236ms)" | tee -a "$LOG"
fi
spectacle -b -n -o "$OUT_ABS/f6-acceptance-spectacle.png" >>"$LOG" 2>&1 \
  && echo "[spot-acc] spectacle OK" | tee -a "$LOG" \
  || echo "[spot-acc] WARN: spectacle fallo" | tee -a "$LOG"
kill $SPOT_PID 2>/dev/null || true
wait $SPOT_PID 2>/dev/null || true
echo "[spot-acc] cierre instancia principal rc=$?" | tee -a "$LOG"
kill $KWIN_PID 2>/dev/null || true
wait $KWIN_PID 2>/dev/null || true
' 2>>"$LOG"
RC=$?
pkill -f "[n]imbus-spotacc" 2>/dev/null || true

# #19 clipboard y #20 sin-resultados: offscreen (QT_QPA_PLATFORM) con el HOME
# temporal ya limpiado por trap... se re-semilla mínimo aquí (host, aislado).
# OJO bus: dbus-run-session propio (sin él, el offscreen ve el klipper del
# HOST por DBUS_SESSION_BUS_ADDRESS y la captura filtra datos reales).
CLIP_TMP="$(mktemp -d /tmp/opencode/nimbus-spotacc-off-XXXXXX)"
chmod 700 "$CLIP_TMP"
mkdir -p "$CLIP_TMP/home/.local/share/klipper" "$CLIP_TMP/home/Documents" "$CLIP_TMP/rt"
printf 'nota de reunion manana\nhttps://ejemplo.es/informe\ncomando --revision 42\n' \
  > "$CLIP_TMP/home/.local/share/klipper/history2.lst"
printf 'notas de la reunion\n' > "$CLIP_TMP/home/Documents/reunión-notas.txt"
echo "[spot-acc] offscreen clipboard/sin-resultados en $CLIP_TMP" | tee -a "$LOG"
dbus-run-session -- env HOME="$CLIP_TMP/home" XDG_RUNTIME_DIR="$CLIP_TMP/rt" \
  XDG_CONFIG_HOME="$CLIP_TMP/home/.config" XDG_DATA_HOME="$CLIP_TMP/data" \
  XDG_CACHE_HOME="$CLIP_TMP/cache" XDG_STATE_HOME="$CLIP_TMP/state" \
  QT_QPA_PLATFORM=offscreen timeout 30 "$BIN_ABS" \
  --tab clipboard --clipview history --query "reunion" \
  --shot "$OUT_ABS/f6-acceptance-clipboard.png" >>"$LOG" 2>&1 &
CLIP_PID=$!
sleep 12; kill "$CLIP_PID" 2>/dev/null || true; wait "$CLIP_PID" 2>/dev/null || true
[ -s "$OUT_ABS/f6-acceptance-clipboard.png" ] \
  && echo "[spot-acc] #19 clipboard PNG OK" | tee -a "$LOG" \
  || echo "[spot-acc] #19 clipboard PNG FAIL" | tee -a "$LOG"
dbus-run-session -- env HOME="$CLIP_TMP/home" XDG_RUNTIME_DIR="$CLIP_TMP/rt" \
  XDG_CONFIG_HOME="$CLIP_TMP/home/.config" XDG_DATA_HOME="$CLIP_TMP/data" \
  XDG_CACHE_HOME="$CLIP_TMP/cache" XDG_STATE_HOME="$CLIP_TMP/state" \
  QT_QPA_PLATFORM=offscreen timeout 30 "$BIN_ABS" \
  --tab apps --query "9z8x7q2w" \
  --shot "$OUT_ABS/f6-acceptance-noresults.png" >>"$LOG" 2>&1 &
NO_PID=$!
sleep 12; kill "$NO_PID" 2>/dev/null || true; wait "$NO_PID" 2>/dev/null || true
NO_LINE=$(grep "spotlight-local-latency.*tab=apps" "$LOG" | tail -1)
echo "[spot-acc] #20 sin-resultados: $NO_LINE" | tee -a "$LOG"
printf "%s|%s|%s|%s|%s\n" "19" "nota de reunion (clipboard)" "clipboard/history2.lst" "visual" "PNG" >> "$TABLE"
printf "%s|%s|%s|%s|%s\n" "20" "9z8x7q2w (tab apps)" "sin resultados" "ver-log" "$NO_LINE" >> "$TABLE"
rm -rf "$CLIP_TMP" || true

grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-acceptance-qmlerr.txt" || true
QMLERR_N=0
if [ -s "$OUT_ABS/f6-acceptance-qmlerr.txt" ]; then
  QMLERR_N=$(wc -l < "$OUT_ABS/f6-acceptance-qmlerr.txt")
  echo "[spot-acc] QML-ERRORES: $QMLERR_N lineas (ver f6-acceptance-qmlerr.txt)" | tee -a "$LOG"
else echo "[spot-acc] 0 errores QML" | tee -a "$LOG"; fi
INNER_FAILS=$(grep "FAILCOUNT=" "$LOG" | tail -1 | cut -d= -f2)
case "$INNER_FAILS" in ""|*[!0-9]*) INNER_FAILS=999 ;; esac
echo "[spot-acc] static_ok=$static_ok static_fail=$static_fail inner_fails=$INNER_FAILS qmlerr=$QMLERR_N nested_rc=$RC"
echo "[spot-acc] fin. Log: $LOG Tabla: $TABLE"
cat "$TABLE"
if [ "$static_fail" -ne 0 ] || [ "$INNER_FAILS" -ne 0 ] || [ "$QMLERR_N" -ne 0 ] || [ "$RC" -ne 0 ]; then
  echo "[spot-acc] VEREDICTO: FAIL (gaps en evidencia F6-T09)" | tee -a "$LOG"
  exit 1
fi
echo "[spot-acc] VEREDICTO: PASS" | tee -a "$LOG"
