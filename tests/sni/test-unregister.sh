#!/usr/bin/env bash
# Test unregister F3-T07-fix: mini-watcher + fake A (--quit-after) + fake B
# + probe del StatusNotifierModel REAL. Sin kwin/plasmashell (rápido,
# sin locker): verifica que al morir A la barra (modelo) quita el icono
# y sigue viva (exit 0 + UNREGISTER_OK). Seguro: bus privado
# (dbus-run-session), sin root, sin tocar ~/.config ni la sesión real.
# Uso: bash tests/sni/test-unregister.sh [--fake /tmp/fake-sni]
set -u
FAKE_BIN="/tmp/fake-sni"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --fake) j=$((i+1)); FAKE_BIN="${!j}" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROBE_BIN="/tmp/sni-probe-model"
if [ ! -x "$PROBE_BIN" ]; then
  echo "[unreg] compila probe-model..."
  cmake -S "$REPO_ROOT/tests/sni" -B /tmp/sni-build >/dev/null 2>&1 \
    && cmake --build /tmp/sni-build --target model-probe 2>&1 | tail -1
  cp /tmp/sni-build/model-probe "$PROBE_BIN"
fi
export QT_QPA_PLATFORM=offscreen
dbus-run-session -- bash -c '
set -u
REPO="'"$REPO_ROOT"'"
FAKE="'"$FAKE_BIN"'"
PROBE="'"$PROBE_BIN"'"
export QT_QPA_PLATFORM=offscreen
trap '"'"'kill $(jobs -p) 2>/dev/null || true'"'"' EXIT
python3 "$REPO/tests/sni/mini-watcher.py" &
sleep 1
"$PROBE" &
PROBE_PID=$!
sleep 1
"$FAKE" --service org.nimbus.FakeSniA --title "Nimbus A" --letter A --quit-after 6 &
"$FAKE" --service org.nimbus.FakeSniB --title "Nimbus B" --letter B &
wait $PROBE_PID
RC=$?
echo "[unreg] probe exit=$RC"
exit $RC
'
RC=$?
if [ $RC -eq 0 ]; then echo "[unreg] UNREGISTER_OK"; else echo "[unreg] UNREGISTER_FAIL rc=$RC"; fi
exit $RC
