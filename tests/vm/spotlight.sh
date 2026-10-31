#!/usr/bin/env bash
# F6-T08 benchmark Spotlight: latencia toggle DBus (org.nimbus.Spotlight.toggle)
# y query local con 10k archivos sintéticos (índice ya construido y en frío),
# objetivo <50ms; RSS (/proc/<pid>/status VmRSS), CPU% en reposo y durante
# query (2-3 s); arranque en frío (spawn→primer frame) y RAM. Sin freeze:
# cada sonda DBus va con timeout. HOME/XDG temporales, cleanup por trap.
# No toca la sesión ni ~/.config del host.
# Uso: bash tests/vm/spotlight.sh [--out spikes/nested] [--timeout 150]
#        [--bin <nimbus-spotlight>] [--tst <tst_index>]
#        [--query kate] [--files 10000] [--rounds 10]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=150
QUERY="kate"
BIN="apps/nimbus-spotlight/build/nimbus-spotlight"
TST=""
NFILES=10000
ROUNDS=10
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --out) j=$((i+1)); OUT_DIR="${!j}" ;;
    --timeout) j=$((i+1)); TIMEOUT="${!j}" ;;
    --bin) j=$((i+1)); BIN="${!j}" ;;
    --tst) j=$((i+1)); TST="${!j}" ;;
    --query) j=$((i+1)); QUERY="${!j}" ;;
    --files) j=$((i+1)); NFILES="${!j}" ;;
    --rounds) j=$((i+1)); ROUNDS="${!j}" ;;
  esac
done
[[ "$QUERY" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: --query solo [A-Za-z0-9._-]" >&2; exit 1; }
[[ "$TIMEOUT" =~ ^[0-9]+$ && "$NFILES" =~ ^[0-9]+$ && "$ROUNDS" =~ ^[0-9]+$ ]] \
  || { echo "ERROR: --timeout/--files/--rounds deben ser enteros" >&2; exit 1; }
[ "$NFILES" -ge 1000 ] || { echo "ERROR: --files mínimo 1000 (contrato 10k)" >&2; exit 1; }
case "$BIN" in /*) BIN_ABS="$BIN" ;; *) BIN_ABS="$REPO_ROOT/$BIN" ;; esac
[ -x "$BIN_ABS" ] || { echo "ERROR: sin binario $BIN_ABS (compila apps/nimbus-spotlight o pasa --bin)" >&2; exit 1; }
if [ -n "$TST" ]; then
  case "$TST" in /*) TST_ABS="$TST" ;; *) TST_ABS="$REPO_ROOT/$TST" ;; esac
  [ -x "$TST_ABS" ] || { echo "ERROR: sin test $TST_ABS" >&2; exit 1; }
fi

OUT_ABS="$REPO_ROOT/$OUT_DIR"
mkdir -p "$OUT_ABS"
LOG="$OUT_ABS/f6-perf.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-perf-XXXXXX)"
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
  sleep 2 # kwin/apaga escribe XDG al salir; evita rm parcial (race)
  rm -rf "$BASE_TMP" || { sleep 2; rm -rf "$BASE_TMP"; } \
    || echo "[perf] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[perf] bin=$BIN_ABS query=$QUERY files=$NFILES rounds=$ROUNDS log=$LOG" | tee -a "$LOG"

# --- 10k sintéticos repartidos en 4 raíces (el worker indexa hasta su tope;
# --- scanRoots limita profundidad y total: se documenta cuántos indexó) ---
PERDIR=$((NFILES / 4))
for d in Documents Downloads Desktop Escritorio; do
  mkdir -p "$NESTED_HOME/$d"
  seq 1 "$PERDIR" | sed "s|^|$NESTED_HOME/$d/doc-informe-|;s|$|-.odt|" | xargs touch
done
echo "kate-notas-sintetico" > "$NESTED_HOME/Documents/kate-notas-sintetico.txt"
echo "[perf] sintéticos: $(find "$NESTED_HOME" -type f | wc -l) ficheros" | tee -a "$LOG"

# --- P0 frío offscreen: tst_index en proceso nuevo (índice recién construido,
# --- sin nested). Frío = primera query tras construir; el binario repite el
# --- mismo camino (NimbusIndex::searchLocal). ---
if [ -n "$TST" ]; then
  echo "[perf] P0 offscreen frío: $TST_ABS" | tee -a "$LOG"
  HOME="$NESTED_HOME" QT_QPA_PLATFORM=offscreen "$TST_ABS" perfFuzzy10k perfSearchLocal \
    > "$OUT_ABS/f6-perf-offscreen.txt" 2>&1 || echo "[perf] WARN: tst_index rc!=0" | tee -a "$LOG"
  grep -hE "perf-fuzzy-10k|perf-searchLocal" "$OUT_ABS/f6-perf-offscreen.txt" | tee -a "$LOG" \
    || echo "[perf] WARN: sin líneas perf en offscreen" | tee -a "$LOG"
else
  echo "[perf] P0 omitida (sin --tst)" | tee -a "$LOG"
fi

# --- P1 nested: arranque frío, toggle, query caliente, RSS/CPU, captura ---
dbus-run-session -- bash -c '
set -u
OUT_ABS="'"$OUT_ABS"'"
TIMEOUT="'"$TIMEOUT"'"
QUERY="'"$QUERY"'"
ROUNDS="'"$ROUNDS"'"
BIN="'"$BIN_ABS"'"
LOG="'"$LOG"'"
export HOME="'"$NESTED_HOME"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export XDG_CONFIG_HOME="'"$NESTED_HOME/.config"'"
export XDG_DATA_HOME="'"$XDG_DATA_HOME"'"
export XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'"
export XDG_STATE_HOME="'"$XDG_STATE_HOME"'"
export QT_QPA_PLATFORM=wayland
export WAYLAND_DISPLAY="nimbus-perf"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
FREEZE=0

now_ns() { date +%s%N; }
rss_kb() { awk "/^VmRSS:/{print \$2}" "/proc/$1/status" 2>/dev/null || echo 0; }
proc_ticks() { sed "s/^.*) //" "/proc/$1/stat" 2>/dev/null | awk "{print \$12+\$13}"; }
cpu_total() { awk "/^cpu /{s=0; for(i=2;i<=NF;i++) s+=\$i; print s}" /proc/stat; }
cpu_pct() { # pid segundos → %CPU (100% = 1 núcleo)
  local pid=$1 secs=$2 a b t1 t2
  kill -0 "$pid" 2>/dev/null || { echo "NA"; return 0; }
  a=$(proc_ticks "$pid"); t1=$(cpu_total)
  sleep "$secs"
  kill -0 "$pid" 2>/dev/null || { echo "NA"; return 0; }
  b=$(proc_ticks "$pid"); t2=$(cpu_total)
  awk -v a="$a" -v b="$b" -v t1="$t1" -v t2="$t2" -v n="$(nproc)" \
    "BEGIN{d=b-a; dt=t2-t1; if(dt<=0){print \"NA\"; exit} printf \"%.1f\", 100*d*n/dt}"
}
stats_ms() { # fichero con ns → "n min/med/max/avg ms"
  sort -n "$1" | awk "{a[NR]=\$1; s+=\$1} END{n=NR; if(n==0){print \"sin muestras\"; exit} \
    m=(n%2?a[(n+1)/2]:(a[n/2]+a[n/2+1])/2); \
    printf \"%d muestras min=%.2f med=%.2f max=%.2f avg=%.2f ms\", \
    n, a[1]/1e6, m/1e6, a[n]/1e6, (s/n)/1e6}"
}
has_owner() {
  timeout 5 qdbus6 org.freedesktop.DBus /org/freedesktop/DBus \
    org.freedesktop.DBus.NameHasOwner "$1" 2>/dev/null
}

echo "[perf] arranque kwin_wayland --virtual ..." | tee -a "$LOG"
kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --socket "$WAYLAND_DISPLAY" --xwayland >>"$LOG" 2>&1 &
KWIN_PID=$!
for ((i=0; i<TIMEOUT*2; i++)); do
  [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
  sleep 0.5
done
if [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
  echo "[perf] ERROR: sin socket compositor" | tee -a "$LOG"
  kill $KWIN_PID 2>/dev/null || true
  exit 1
fi
sleep 2

T_SPAWN=$(now_ns)
"$BIN" --query "$QUERY" >>"$LOG" 2>&1 &
SPOT_PID=$!
READY="no"
for ((i=0; i<150; i++)); do
  kill -0 $SPOT_PID 2>/dev/null || { echo "[perf] ERROR: spotlight murió al arrancar" | tee -a "$LOG"; exit 1; }
  [ "$(has_owner org.nimbus.Spotlight)" = "true" ] && { READY="yes"; break; }
  sleep 0.2
done
T_READY=$(now_ns)
[ "$READY" = "yes" ] || { echo "[perf] ERROR: sin servicio org.nimbus.Spotlight (freeze?)" | tee -a "$LOG"; exit 1; }
COLD_MS=$(awk -v a="$T_SPAWN" -v b="$T_READY" "BEGIN{printf \"%.1f\", (b-a)/1e6}")
echo "[perf] arranque-frío spawn→DBus: ${COLD_MS}ms (primer frame: ventana creada y registrada)" | tee -a "$LOG"
RSS_COLD=$(rss_kb $SPOT_PID)
echo "[perf] RSS arranque: ${RSS_COLD} kB" | tee -a "$LOG"

# Primera query (fría: índice en construcción, worker en curso).
FIRST=""
for ((i=0; i<100; i++)); do
  FIRST=$(grep -h "spotlight-local-latency" "$LOG" | head -1)
  [ -n "$FIRST" ] && break
  sleep 0.2
done
[ -n "$FIRST" ] && echo "[perf] query-fría inicial: $FIRST" | tee -a "$LOG" \
  || echo "[perf] WARN: sin latencia inicial en log" | tee -a "$LOG"
sleep 5 # worker indexa sintéticos

# Query caliente: ROUNDS llamadas DBus cronometradas (round-trip incluye
# searchLocal síncrono) + latencias in-process del log.
: > "$OUT_ABS/f6-perf-query.txt"
for ((k=0; k<ROUNDS; k++)); do
  T0=$(now_ns)
  if timeout 10 qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.query "$QUERY" >>"$LOG" 2>&1; then
    echo $(( $(now_ns) - T0 )) >> "$OUT_ABS/f6-perf-query.txt"
  else
    echo "[perf] ERROR: query DBus colgó (freeze) round=$k" | tee -a "$LOG"; FREEZE=1; break
  fi
done
grep -h "spotlight-local-latency" "$LOG" | tail -n "$ROUNDS" | tee -a "$LOG"
echo "[perf] query-caliente round-trip: $(stats_ms "$OUT_ABS/f6-perf-query.txt")" | tee -a "$LOG"

# Toggle: ROUNDS pares (termina visible) cronometrados.
: > "$OUT_ABS/f6-perf-toggle.txt"
for ((k=0; k<ROUNDS; k++)); do
  T0=$(now_ns)
  if timeout 10 qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle >>"$LOG" 2>&1; then
    echo $(( $(now_ns) - T0 )) >> "$OUT_ABS/f6-perf-toggle.txt"
  else
    echo "[perf] ERROR: toggle DBus colgó (freeze) round=$k" | tee -a "$LOG"; FREEZE=1; break
  fi
done
echo "[perf] toggle round-trip: $(stats_ms "$OUT_ABS/f6-perf-toggle.txt")" | tee -a "$LOG"
kill -0 $SPOT_PID 2>/dev/null || { echo "[perf] ERROR: spotlight murió en medición" | tee -a "$LOG"; exit 1; }

RSS_HOT=$(rss_kb $SPOT_PID)
echo "[perf] RSS post-query: ${RSS_HOT} kB" | tee -a "$LOG"
echo "[perf] CPU reposo (3s): $(cpu_pct $SPOT_PID 3)% (100% = 1 núcleo)" | tee -a "$LOG"
for ((k=0; k<300; k++)); do
  timeout 10 qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.query "$QUERY" >/dev/null 2>&1 || break
done &
BURST_PID=$!
echo "[perf] CPU durante query (2s, ráfaga 300): $(cpu_pct $SPOT_PID 2)% (100% = 1 núcleo)" | tee -a "$LOG"
wait $BURST_PID 2>/dev/null || true
kill -0 $SPOT_PID 2>/dev/null || { echo "[perf] ERROR: spotlight murió en ráfaga" | tee -a "$LOG"; exit 1; }

grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-perf-qmlerr.txt" || true
if [ -s "$OUT_ABS/f6-perf-qmlerr.txt" ]; then
  echo "[perf] ERRORES QML:" | tee -a "$LOG"; cat "$OUT_ABS/f6-perf-qmlerr.txt" | tee -a "$LOG"
else
  echo "[perf] 0 errores QML" | tee -a "$LOG"
fi
spectacle -b -n -o "$OUT_ABS/f6-perf.png" >>"$LOG" 2>&1 \
  && echo "[perf] f6-perf.png OK" | tee -a "$LOG" \
  || echo "[perf] WARN: spectacle falló (captura opcional)" | tee -a "$LOG"
[ "$FREEZE" = "0" ] && echo "[perf] sin freeze (todas las sondas respondieron)" | tee -a "$LOG"
kill $SPOT_PID $KWIN_PID 2>/dev/null || true
' 2>>"$LOG"
RC=$?
echo "[perf] dbus-run-session exit=$RC" | tee -a "$LOG"

# --- Tabla resumen ---
{
  echo "# F6-T08 spotlight — tabla"
  echo "# (med = mediana round-trip DBus; in-process = spotlight-local-latency del log)"
  grep -hE "arranque-frío|RSS|query-fría|query-caliente|toggle round-trip|CPU|errores QML|sin freeze|ERROR|perf-fuzzy|perf-searchLocal" "$LOG" || true
} > "$OUT_ABS/f6-perf-table.txt"
cat "$OUT_ABS/f6-perf-table.txt" | tee -a "$LOG"
exit $RC
