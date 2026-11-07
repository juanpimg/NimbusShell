#!/bin/bash
# lib/dock.sh — Dock layer-shell (Krema base/fork/theme, F5).
# Hoy (F1): sin componentes desplegables. Checks reales de lo que existe
# (árbol del repo + base layer-shell-qt del sistema) + mensajes accionables.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

dock_deploy() {
    nimbus_info "-- dock: configurando Krema con preset Nimbus (kremarc)"
    local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    mkdir -p "$cfg_dir"
    if [ -f "$REPO_ROOT/packages/dock/kremarc-nimbus" ]; then
        if [ ! -f "$cfg_dir/kremarc" ]; then
            cp "$REPO_ROOT/packages/dock/kremarc-nimbus" "$cfg_dir/kremarc"
            nimbus_ok "kremarc inicializado con preset Nimbus"
        else
            nimbus_info "kremarc ya existe; respetando configuración del usuario"
        fi
    fi
    local apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$apps_dir"
    for l in "$REPO_ROOT/packages/dock/launchers"/*.desktop; do
        [ -f "$l" ] || continue
        cp "$l" "$apps_dir/"
    done
}

dock_check() {
    echo "-- dock:"
    if [ -d "$REPO_ROOT/packages/dock" ]; then
        nimbus_ok "packages/dock presente en el repo"
    else
        nimbus_fail "packages/dock ausente en el repo (repo incompleto)"
    fi
    if [ -f "$REPO_ROOT/packages/dock/kremarc-nimbus" ]; then
        nimbus_ok "preset kremarc-nimbus presente"
    else
        nimbus_fail "kremarc-nimbus ausente"
    fi
    if pacman -Qq layer-shell-qt >/dev/null 2>&1; then
        nimbus_ok "base layer-shell-qt instalada"
    else
        nimbus_fail "layer-shell-qt ausente (la instala el paso de paquetes plasma)"
    fi
}
