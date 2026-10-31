#!/bin/bash
# lib/apps.sh — apps Nimbus (welcome, migrate, hw, backup, F9).
# Hoy (F1): sin componentes desplegables. Checks reales del árbol del repo
# + mensajes accionables.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

apps_deploy() {
    nimbus_info "-- apps: sin componentes desplegables aún (wizard y migradores F9)"
}

apps_check() {
    echo "-- apps:"
    local app missing
    missing=0
    for app in nimbus-welcome nimbus-migrate nimbus-hw backup; do
        if [ -d "$REPO_ROOT/apps/$app" ]; then nimbus_ok "apps/$app presente en el repo";
        else nimbus_fail "apps/$app ausente en el repo (repo incompleto)"; missing=1; fi
    done
    [ "$missing" = "0" ] || return 0
    nimbus_info "  [PENDIENTE] binarios de apps: wizard y migradores llegan en F9 (no exigible)"
}
