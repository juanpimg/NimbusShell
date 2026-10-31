#!/bin/bash
# lib/dock.sh — Dock layer-shell (Krema base/fork/theme, F5).
# Hoy (F1): sin componentes desplegables. Checks reales de lo que existe
# (árbol del repo + base layer-shell-qt del sistema) + mensajes accionables.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

dock_deploy() {
    nimbus_info "-- dock: sin componentes desplegables aún (evaluación/fork Krema F5-T01)"
}

dock_check() {
    echo "-- dock:"
    if [ -d "$REPO_ROOT/packages/dock" ]; then nimbus_ok "packages/dock presente en el repo";
    else nimbus_fail "packages/dock ausente en el repo (repo incompleto)"; fi
    if pacman -Qq layer-shell-qt >/dev/null 2>&1; then nimbus_ok "base layer-shell-qt instalada";
    else nimbus_fail "layer-shell-qt ausente (la instala el paso de paquetes plasma)"; fi
    nimbus_info "  [PENDIENTE] Dock Nimbus: evaluación/fork Krema en F5-T01 (no exigible)"
}
