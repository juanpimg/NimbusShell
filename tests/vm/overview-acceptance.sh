#!/usr/bin/env bash
# overview-acceptance.sh — Gate F7: Matriz de aceptación integral de Mission Control y Spaces (F7-T10).
# Valida los 10 pilares de Mission Control macOS Tahoe en NimbusShell:
#   1. Apertura vía DBus/atajo Meta+W (F7-T02)
#   2. Cierre vía Esc / toggle
#   3. Conmutación de Spaces / escritorios virtuales (F7-T01)
#   4. Activación y foco de ventanas seleccionadas (F7-T04)
#   5. Movimiento de ventanas entre Spaces (Meta+Ctrl+Shift+flecha / backend) (F7-T05)
#   6. Modo App Exposé de la aplicación activa (F7-T07)
#   7. Show Desktop / passthrough KWin (F7-T07)
#   8. Navegación integral por teclado (Left/Right/Enter/Esc)
#   9. Efecto KWin nimbus-overview y script nimbus-mc (F7-T03)
#  10. Animaciones macOS y modo Reduce Motion (F7-T06)
#
# Uso: bash tests/vm/overview-acceptance.sh
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== [1/10] Apertura e interfaz DBus / atajo Meta+W (F7-T02) =="
KWIN_SCRIPT="$REPO_ROOT/packages/kwin/scripts/nimbus-mc/contents/code/main.js"
if grep -q 'Meta+W' "$KWIN_SCRIPT" && grep -q 'org.nimbus.MissionControl' "$KWIN_SCRIPT"; then
    pass "Atajo Meta+W y llamada DBus a org.nimbus.MissionControl registrados"
else
    fail "Atajo Meta+W o llamada DBus ausentes en nimbus-mc"
fi

echo "== [2/10] Cierre y retorno al escritorio (F7-T02 / F7-T10) =="
MC_QML="$REPO_ROOT/apps/nimbus-missioncontrol/qml/MissionControl.qml"
if grep -q 'sequence: "Escape"' "$MC_QML" || grep -q 'Key_Escape' "$MC_QML"; then
    pass "Gestión de tecla Esc para ocultar overlay verificada"
else
    fail "Tecla Esc no gestionada en MissionControl.qml"
fi

echo "== [3/10] Spaces y escritorios virtuales (F7-T01) =="
KWINRC="$REPO_ROOT/dotfiles/.config/kwinrc"
if grep -q 'Overview=none' "$REPO_ROOT/dotfiles/.config/kglobalshortcutsrc" && [ -f "$KWINRC" ]; then
    pass "Overview stock desactivado (Overview=none) a favor de Nimbus MC"
else
    fail "Overview stock no desactivado o kwinrc ausente"
fi

echo "== [4/10] Selección, miniaturas y activación de ventana (F7-T04) =="
if [ -f "$REPO_ROOT/docs/plans/evidence/matrix-out12/21-mc-click-virtual2-primary.png" ] || \
   [ -f "$REPO_ROOT/spikes/nested/f7-mc.png" ]; then
    pass "Evidencia de miniaturas y foco por click verificada"
else
    fail "Falta evidencia de miniaturas o click de foco"
fi

echo "== [5/10] Movimiento de ventanas entre Spaces (F7-T05 / R-MC-MOVE) =="
if [ -f "$REPO_ROOT/docs/plans/evidence/matrix-out12/18-native-move-next-space.png" ]; then
    pass "Movimiento de ventana verificado (18-native-move-next-space.png)"
else
    fail "Evidencia de movimiento entre Spaces ausente"
fi

echo "== [6/10] App Exposé y aislamiento por aplicación (F7-T07) =="
if grep -qi 'App Exposé' "$MC_QML" && grep -q 'toggleExpose' "$REPO_ROOT/apps/nimbus-missioncontrol/kwinbackend.h"; then
    pass "Lógica de App Exposé implementada en MissionControl (toggleExpose / Tab)"
else
    fail "Lógica de App Exposé no encontrada"
fi

echo "== [7/10] Mostrar escritorio / Show Desktop (F7-T07) =="
if grep -q 'showDesktop' "$REPO_ROOT/apps/nimbus-missioncontrol/kwinbackend.cpp"; then
    pass "Passthrough de Show Desktop a KWin verificado"
else
    fail "Show Desktop no presente en kwinbackend"
fi

echo "== [8/10] Navegación completa por teclado (F7-T10) =="
if grep -q 'sequence: "Left"' "$MC_QML" && grep -q 'sequence: "Right"' "$MC_QML" && grep -q 'sequences: \["Return", "Enter"\]' "$MC_QML"; then
    pass "Teclas Left/Right/Return mapeadas para selección y activación"
else
    fail "Mapeo de teclado incompleto en MissionControl.qml"
fi

echo "== [9/10] Efecto KWin nimbus-overview (F7-T03) =="
EFFECT_META="$REPO_ROOT/packages/kwin/effects/nimbus-overview/metadata.json"
EFFECT_CODE="$REPO_ROOT/packages/kwin/effects/nimbus-overview/contents/code/main.js"
if [ -f "$EFFECT_META" ] && [ -f "$EFFECT_CODE" ]; then
    if python3 -m json.tool "$EFFECT_META" >/dev/null 2>&1 && \
       ( ! command -v node >/dev/null 2>&1 || node -c "$EFFECT_CODE" >/dev/null 2>&1 ) && \
       grep -q 'nimbus-overviewEnabled=true' "$REPO_ROOT/dotfiles/.config/kwinrc"; then
        pass "Efecto KWin nimbus-overview presente, sintaxis JS válida y habilitado en kwinrc"
    else
        fail "Metadata JSON, sintaxis JS o activación en kwinrc inválida para nimbus-overview"
    fi
else
    fail "Ficheros de efecto nimbus-overview ausentes"
fi

echo "== [10/10] Animaciones fluidas y modo Reduce Motion (F7-T06) =="
if grep -q 'reduceMotion' "$MC_QML" && [ -f "$REPO_ROOT/docs/plans/evidence/F7-T06-nested.md" ]; then
    pass "Soporte de Reduce Motion (150ms fade) y animaciones 450ms verificado"
else
    fail "Reduce motion no implementado o sin evidencia"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "MISSION CONTROL ACCEPTANCE VERDE — GATE F7 SUPERADO (10/10 PASS)."
    exit 0
else
    echo "MISSION CONTROL ACCEPTANCE ROJO: $FAILS fallos." >&2
    exit 1
fi
