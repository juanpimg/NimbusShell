#!/usr/bin/env bash
# test_qml_suite.sh — ejecuta tests unitarios QML con qmltestrunner (offscreen).
# Sin root, sin red, entorno offscreen.
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QMLTESTRUNNER="/usr/lib/qt6/bin/qmltestrunner"
[ -x "$QMLTESTRUNNER" ] || QMLTESTRUNNER="$(command -v qmltestrunner 2>/dev/null || true)"

if [ -z "$QMLTESTRUNNER" ]; then
    echo "  [SKIP] qmltestrunner no encontrado"
    exit 0
fi

FAILS=0
pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

for test_file in "$REPO_ROOT"/tests/qml/tst_*.qml; do
    [ -f "$test_file" ] || continue
    name="$(basename "$test_file")"
    out_tmp="$(mktemp)"
    if QT_QPA_PLATFORM=offscreen "$QMLTESTRUNNER" \
        -import "$REPO_ROOT/packages/shell/nimbus-bar/qml" \
        -input "$test_file" >"$out_tmp" 2>&1; then
        passed="$(grep -m1 -E '[0-9]+ passed' "$out_tmp" | awk '{print $2}')"
        pass "$name ($passed tests passed)"
    else
        echo "=== Salida $name ===" >&2
        cat "$out_tmp" >&2
        fail "$name falló"
    fi
    rm -f "$out_tmp"
done

if [ "$FAILS" -eq 0 ]; then
    echo "QML SUITE VERDE."
    exit 0
else
    echo "QML SUITE ROJA ($FAILS fallos)." >&2
    exit 1
fi
