#!/bin/bash
# lib/kwin.sh — decoración, efectos y reglas KWin.
# Hoy (F1): sin componentes desplegables (preset Klassy F3-T02, reglas
# F4-T07). Checks reales de lo que existe + mensajes accionables.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

kwin_deploy() {
    nimbus_info "-- kwin: sin componentes desplegables aún (preset Klassy F3-T02, reglas F4-T07)"
}

kwin_check() {
    echo "-- kwin:"
    if [ -d "$REPO_ROOT/packages/kwin" ]; then nimbus_ok "packages/kwin presente en el repo";
    else nimbus_fail "packages/kwin ausente en el repo (repo incompleto)"; fi
    if [ -f "$HOME/.config/kwinrc" ]; then nimbus_ok "kwinrc presente";
    else nimbus_info "  [PENDIENTE] kwinrc: defaults Nimbus llegan en F2-T03 (no exigible)"; fi
}
