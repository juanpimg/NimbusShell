#!/usr/bin/env bash
# Nested F6-T06 (portapapeles + emoji): nimbus-spotlight real offscreen con
# HOME/XDG temporales. Nunca toca ~/.config del host ni su sesión.
# Uso: bash tests/vm/nested-f6clip.sh [--out spikes/nested] [--timeout 60]
#        [--bin apps/nimbus-spotlight/build/nimbus-spotlight]
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="spikes/nested"
TIMEOUT=60
BIN="apps/nimbus-spotlight/build/nimbus-spotlight"
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
LOG="$OUT_ABS/f6-clip-nested.log"
: > "$LOG"

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-clip-XXXXXX)"
chmod 700 "$BASE_TMP"
NESTED_HOME="$BASE_TMP/home"; mkdir -p "$NESTED_HOME/.config"
export XDG_RUNTIME_DIR="$BASE_TMP/runtime"
export XDG_CONFIG_HOME="$NESTED_HOME/.config"
export XDG_DATA_HOME="$BASE_TMP/data"
export XDG_CACHE_HOME="$BASE_TMP/cache"
export XDG_STATE_HOME="$BASE_TMP/state"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"

cleanup() {
  # shellcheck disable=SC2009
  ps -eo pid,args | grep "[n]imbus-spotlight.*nimbus-clip" | awk "{print \$1}" | xargs -r kill 2>/dev/null || true
  rm -rf "$BASE_TMP" || echo "[clip] WARN: no se pudo borrar $BASE_TMP" >&2
}
trap cleanup EXIT INT TERM

echo "[clip] home=$NESTED_HOME log=$LOG" | tee -a "$LOG"

# Semilla del fallback history2.lst (sin klipper en nested): 3 entradas.
mkdir -p "$NESTED_HOME/.local/share/klipper"
printf 'nota de reunion manana\nhttps://ejemplo.es/informe\ncomando --revision 42\n' \
  > "$NESTED_HOME/.local/share/klipper/history2.lst"
echo "[clip] semilla history2.lst: 3 entradas" | tee -a "$LOG"

# Servidores de portapapeles en sesión AISLADA (dbus-run-session: el nested
# no toca el bus del host; klipper ausente → se ejercita history2.lst).
if dbus-run-session -- qdbus6 org.kde.klipper /klipper org.kde.klipper.klipper.getClipboardHistoryMenu >>"$LOG" 2>&1; then
  echo "[clip] klipper presente en nested" | tee -a "$LOG"
else
  echo "[clip] GAP: sin klipper en nested (fallback history2.lst)" | tee -a "$LOG"
fi
command -v wl-paste >>"$LOG" 2>&1 \
  && echo "[clip] wl-paste presente" | tee -a "$LOG" \
  || echo "[clip] GAP: sin wl-paste (pegado del sistema no verificable aquí)" | tee -a "$LOG"

run_shot() { # $1=clipview $2=query $3=png
  local name="shot-$1"
  dbus-run-session -- bash -c '
    HOME="'"$NESTED_HOME"'" XDG_RUNTIME_DIR="'"$XDG_RUNTIME_DIR"'" \
    XDG_CONFIG_HOME="'"$XDG_CONFIG_HOME"'" XDG_DATA_HOME="'"$XDG_DATA_HOME"'" \
    XDG_CACHE_HOME="'"$XDG_CACHE_HOME"'" XDG_STATE_HOME="'"$XDG_STATE_HOME"'" \
    QT_QPA_PLATFORM=offscreen timeout "'"$TIMEOUT"'" "'"$BIN_ABS"'" \
      --tab clipboard --clipview "'"$1"'" --query "'"$2"'" --shot "'"$OUT_ABS/$3"'"' \
    >>"$LOG" 2>&1 &
  local pid=$!
  # --shot vuelca a los 6s; se mata a los 12s (timeout lo respalda).
  sleep 12
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  [ -s "$OUT_ABS/$3" ] \
    && echo "[clip] $3 OK ($(stat -c%s "$OUT_ABS/$3") bytes)" | tee -a "$LOG" \
    || echo "[clip] ERROR: $3 vacío/ausente" | tee -a "$LOG"
  echo "[clip] $name rc=$?" | tee -a "$LOG"
}

run_shot history "" "f6-clipboard.png"
run_shot emoji "pizza" "f6-emoji.png"

echo "[clip] latencias clipboard/emoji:" | tee -a "$LOG"
grep -h "spotlight-local-latency\|spotlight-latency" "$LOG" | tail -6 | tee -a "$LOG" || true
grep -hiE "qml.*error|file not found|module.*not installed" "$LOG" > "$OUT_ABS/f6-clip-qmlerr.txt" || true
if [ -s "$OUT_ABS/f6-clip-qmlerr.txt" ]; then cat "$OUT_ABS/f6-clip-qmlerr.txt" | tee -a "$LOG";
else echo "[clip] 0 errores QML" | tee -a "$LOG"; fi
# Copiar al portapapeles se verifica en unit test (copyRoundTrip, Qt offscreen);
# aquí no hay servidor Wayland: gap documentado arriba.
echo "[clip] fin. Log: $LOG"
