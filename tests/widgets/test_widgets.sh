#!/usr/bin/env bash
# tests/widgets/test_widgets.sh — Suite F10-T01:
# Widgets de escritorio, ClockApp, AboutApp, Now Playing y Tiempo.
# Sin root, sin red, HOME temporal.
set -u

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "== widgets: lint y desktop files =="
desktop-file-validate "$REPO_ROOT/apps/nimbus-clock/org.nimbus.clock.desktop" \
  && ok "org.nimbus.clock.desktop válido" || bad "desktop clock inválido"

if [ -f "$REPO_ROOT/apps/nimbus-about/org.nimbus.about.desktop" ]; then
  desktop-file-validate "$REPO_ROOT/apps/nimbus-about/org.nimbus.about.desktop" \
    && ok "org.nimbus.about.desktop válido" || bad "desktop about inválido"
fi

if command -v qmllint >/dev/null 2>&1; then
  qmllint "$REPO_ROOT/apps/nimbus-clock/qml/Clock.qml" >/dev/null 2>&1 \
    && ok "qmllint apps/nimbus-clock/qml/Clock.qml" || bad "qmllint falló en Clock.qml"
  qmllint "$REPO_ROOT/packages/shell/nimbus-bar/qml/MediaWidget.qml" >/dev/null 2>&1 \
    && ok "qmllint nimbus-bar MediaWidget.qml" || bad "qmllint falló en MediaWidget.qml"
  qmllint "$REPO_ROOT/packages/shell/nimbus-bar/qml/WeatherWidget.qml" >/dev/null 2>&1 \
    && ok "qmllint nimbus-bar WeatherWidget.qml" || bad "qmllint falló en WeatherWidget.qml"
fi

echo "== widgets: compilacion y ejecucion de pruebas de nimbus-clock =="
BUILD_DIR="$(mktemp -d /tmp/opencode/build-clock-test-XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '$BUILD_DIR'" EXIT INT TERM

if cmake -B "$BUILD_DIR" -S "$REPO_ROOT/apps/nimbus-clock" >/dev/null 2>&1 && cmake --build "$BUILD_DIR" >/dev/null 2>&1; then
  ok "Compilación de nimbus-clock y tst_clock correcta"
  if ctest --test-dir "$BUILD_DIR" --output-on-failure >/dev/null 2>&1; then
    ok "Suite tst_clock completada con éxito (zonas horarias, alarmas, límites)"
  else
    bad "Suite tst_clock falló"
  fi
else
  bad "Fallo compilando nimbus-clock"
fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
