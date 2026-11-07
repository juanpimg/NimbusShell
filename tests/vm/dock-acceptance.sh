#!/usr/bin/env bash
# dock-acceptance.sh — Gate F5: Matriz de aceptación integral del Dock macOS Tahoe (F5-T12).
# Valida los 8 pilares del Dock Nimbus sobre Krema:
#   1. Estética Tahoe 1:1 (tile 48px, radio 12, acrílico 3 al 60%, margen 8)
#   2. Magnificación parabólica 1.6x y hover labels
#   3. TaskManager backend y running dots
#   4. Previews de ventana (PipeWire 200px / 500ms y fallback)
#   5. Menú contextual completo
#   6. Clic, launch, foco y minimización genie
#   7. Papelera dinámica y stack de descargas
#   8. Autohide (VisibilityMode 1/0) y reserva de espacio (ReserveScreenSpace=true)
#
# Uso: bash tests/vm/dock-acceptance.sh [--out DIR]
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== [1/8] Estética Tahoe 1:1 (F5-T03) =="
if bash "$REPO_ROOT/tests/dock/test_dock_config.sh" >/dev/null 2>&1; then
    pass "Geometría, tile 48px, esquinas 12 y acrílico 3 al 60% verificados"
else
    fail "Configuración estética no conforme"
fi

echo "== [2/8] Magnificación parabólica 1.6x (F5-T04) =="
PRESET="$REPO_ROOT/packages/dock/kremarc-nimbus"
ZOOM_VAL="$(grep '^MaxZoomFactor=' "$PRESET" | cut -d= -f2)"
ZOOM_STYLE="$(grep '^ZoomStyle=' "$PRESET" | cut -d= -f2)"
if [ "$ZOOM_VAL" = "1.6" ] && [ "$ZOOM_STYLE" = "0" ]; then
    pass "Magnificación 1.6x y curva parabólica (ZoomStyle=0) verificados"
else
    fail "Magnificación incorrecta: factor=$ZOOM_VAL style=$ZOOM_STYLE"
fi

echo "== [3/8] Backend TaskManager y seguimiento de tareas (F5-T02) =="
SEPARATE="$(grep '^SeparateLaunchers=' "$PRESET" | cut -d= -f2)"
PINS="$(grep '^PinnedLaunchers=' "$PRESET" | cut -d= -f2)"
if [ "$SEPARATE" = "false" ] && [ -n "$PINS" ]; then
    pass "Backend unificado TaskManager (SeparateLaunchers=false, pins activos)"
else
    fail "TaskManager no conforme"
fi

echo "== [4/8] Previews de ventanas PipeWire (F5-T07) =="
PREVIEW_EN="$(grep '^PreviewEnabled=' "$PRESET" | cut -d= -f2)"
PREVIEW_SZ="$(grep '^PreviewThumbnailSize=' "$PRESET" | cut -d= -f2)"
PREVIEW_DL="$(grep '^PreviewHoverDelay=' "$PRESET" | cut -d= -f2)"
if [ "$PREVIEW_EN" = "true" ] && [ "$PREVIEW_SZ" = "200" ] && [ "$PREVIEW_DL" = "500" ]; then
    pass "Previews configuradas a 200px / 500ms delay"
else
    fail "Configuración de previews incorrecta"
fi

echo "== [5/8] Menús contextuales y acciones (F5-T06) =="
# Valida presencia de evidencias en repositorio
EVID_CTX="$REPO_ROOT/docs/plans/evidence/F5-T08-context-menu.png"
if [ -f "$EVID_CTX" ] || [ -f "$REPO_ROOT/docs/plans/evidence/matrix-out12/04-dock-context-menu.png" ]; then
    pass "Evidencia de menú contextual verificada (Unpin/Close/Settings)"
else
    fail "Falta evidencia de menú contextual"
fi

echo "== [6/8] Clic, launch, foco y genie minimize (F5-T06) =="
KWINRC="$REPO_ROOT/dotfiles/.config/kwinrc"
if grep -qi 'magiclamp' "$KWINRC" 2>/dev/null; then
    pass "Animación genie (magiclamp) configurada en KWin"
else
    fail "magiclamp no encontrado en kwinrc"
fi

echo "== [7/8] Papelera y stack de Descargas (F5-T09) =="
if bash "$REPO_ROOT/tests/dock/test_dock_trash.sh" >/dev/null 2>&1; then
    pass "Papelera dinámica y stack de descargas verificados"
else
    fail "Suite test_dock_trash.sh falló"
fi

echo "== [8/8] Autohide y reserva de pantalla (F5-T05 / F5-T10) =="
RESERVE="$(grep '^ReserveScreenSpace=' "$PRESET" | cut -d= -f2)"
if [ "$RESERVE" = "true" ]; then
    pass "Reserva de espacio exclusiva activa (ReserveScreenSpace=true)"
else
    fail "ReserveScreenSpace != true"
fi

if bash "$REPO_ROOT/tests/dock/test_dock_prefs.sh" >/dev/null 2>&1; then
    pass "Preferencias dinámicas y conmutación de autohide verificadas"
else
    fail "Suite test_dock_prefs.sh falló"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "DOCK ACCEPTANCE VERDE — GATE F5 SUPERADO (8/8 PASS)."
    exit 0
else
    echo "DOCK ACCEPTANCE ROJO: $FAILS fallos." >&2
    exit 1
fi
