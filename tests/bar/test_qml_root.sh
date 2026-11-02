#!/usr/bin/env bash
# test_qml_root.sh: `nimbus-bar --qml-root DIR` carga Bar.qml desde disco
# (iteración QML sin rebuild de CMake). Cubre:
#   - build limpio del paquete
#   - DIR/Bar.qml + import "." (NimbusTokens.qml/qmldir) desde una COPIA del
#     directorio real en un tmp (no el árbol fuente): --dump-preset exit 0
#   - forma --qml-root=DIR
#   - sin flag: sigue cargando qrc:/Bar.qml
#   - negativo: DIR inexistente → exit != 0 y mensaje accionable
# Sin sudo, sin red, sin instalar. Salta (exit 0) si falta toolchain/dev files.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BAR_SRC="$REPO_ROOT/packages/shell/nimbus-bar"
FAILS=0
TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }

need() { command -v "$1" >/dev/null 2>&1 || { skip "falta $1 ($2)"; return 1; }; }

echo "== qml-root: build =="
if ! need cmake "build nimbus-bar"; then
  echo "== qml-root: sin toolchain; 0 fallos =="
  exit 0
fi
if [ ! -f /usr/lib/cmake/LayerShellQt/LayerShellQtConfigVersion.cmake ]; then
  skip "sin LayerShellQt (build solo con dev files)"
  exit 0
fi

TMP="$(mktemp -d /tmp/opencode/nimbus-qmlroot-XXXXXX)"
BIN="$TMP/build/nimbus-bar"
if ! cmake "$BAR_SRC" -DCMAKE_BUILD_TYPE=Release -B "$TMP/build" >/dev/null 2>&1; then
  fail "cmake configure"
elif ! cmake --build "$TMP/build" -j"$(nproc)" >/dev/null 2>&1; then
  fail "cmake build"
else
  pass "build nimbus-bar"
fi
[ -x "$BIN" ] || { echo "== qml-root: sin binario; 1 fallo =="; exit 1; }

# Copia REAL del dir QML: import "." debe resolver NimbusTokens del tmp.
cp -a "$BAR_SRC/qml" "$TMP/qml-copia"
[ -f "$TMP/qml-copia/NimbusTokens.qml" ] && [ -f "$TMP/qml-copia/qmldir" ] \
  && pass "copia con NimbusTokens.qml + qmldir" \
  || fail "copia incompleta del dir QML"

run() { # $1..: args; imprime stdout+stderr, propaga exit
  QT_QPA_PLATFORM=offscreen timeout 20 "$BIN" "$@" 2>&1
}

echo "== qml-root: carga desde disco =="
out="$(run --dump-preset)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'preset-dump: name='; then
  pass "sin flag sigue en qrc (--dump-preset)"
else
  fail "sin flag qrc (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"
fi

out="$(run --qml-root "$BAR_SRC/qml" --dump-preset)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'preset-dump: name='; then
  pass "--qml-root $BAR_SRC/qml (--dump-preset)"
else
  fail "--qml-root dir fuente (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"
fi
printf '%s' "$out" | grep -q 'qml-root=' \
  && pass "log qml-root=<dir>" || fail "sin log qml-root"

out="$(run --qml-root="$TMP/qml-copia" --dump-preset)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'preset-dump: name='; then
  pass "--qml-root=DIR (copia: import \".\" resuelve NimbusTokens)"
else
  fail "--qml-root=DIR copia (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"
fi

echo "== qml-root: negativos =="
out="$(run --qml-root "$TMP/no-existe" --dump-preset)"; rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'qml-root'; then
  pass "DIR inexistente → exit != 0 con mensaje ($rc)"
else
  fail "DIR inexistente (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"
fi

out="$(run --qml-root 2>&1)"; rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'requiere un directorio'; then
  pass "--qml-root sin valor → exit != 0 con uso ($rc)"
else
  fail "--qml-root sin valor (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"
fi

echo "== qml-root: resultado =="
if [ "$FAILS" = 0 ]; then
  echo "  [OK] 0 fallos"
  exit 0
fi
echo "  [FAIL] $FAILS fallo(s)" >&2
exit 1
