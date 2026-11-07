#!/usr/bin/env bash
# tests/welcome/test_welcome.sh — Suite F9-T02/T04: Asistente nimbus-welcome y selección de apps.
# Sin root, sin red, HOME temporal.
set -u

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "== welcome: desktop file y qmllint =="
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$REPO_ROOT/apps/nimbus-welcome/org.nimbus.welcome.desktop" \
    && ok "org.nimbus.welcome.desktop válido" || bad "desktop welcome inválido"
fi

if command -v qmllint >/dev/null 2>&1; then
  qmllint "$REPO_ROOT/apps/nimbus-welcome/qml/Welcome.qml" >/dev/null 2>&1 \
    && ok "qmllint apps/nimbus-welcome/qml/Welcome.qml" || bad "qmllint falló en Welcome.qml"
fi

echo "== welcome: compilacion y ejecucion de tst_welcome =="
BUILD_DIR="$(mktemp -d /tmp/opencode/build-welcome-test-XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '$BUILD_DIR'" EXIT INT TERM

if cmake -B "$BUILD_DIR" -S "$REPO_ROOT/apps/nimbus-welcome" >/dev/null 2>&1 && cmake --build "$BUILD_DIR" >/dev/null 2>&1; then
  ok "Compilación de nimbus-welcome y tst_welcome correcta"
  if ctest --test-dir "$BUILD_DIR" --output-on-failure >/dev/null 2>&1; then
    ok "Suite tst_welcome completada con éxito (pasos, límites, layout, wifi, apps e instalación reactiva)"
  else
    bad "Suite tst_welcome falló"
  fi
else
  bad "Fallo compilando nimbus-welcome"
fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
