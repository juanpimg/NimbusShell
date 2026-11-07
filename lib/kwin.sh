#!/bin/bash
# lib/kwin.sh — decoración, efectos y reglas KWin.
# Despliega scripts (nimbus-spotlight, nimbus-apps-toggle, nimbus-zoom, nimbus-tabs, nimbus-mc)
# y efectos (nimbus-overview) en el entorno del usuario.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

kwin_deploy() {
    nimbus_info "-- kwin: desplegando scripts y efectos KWin Nimbus"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
    local scripts_dir="$data_dir/kwin/scripts"
    local effects_dir="$data_dir/kwin/effects"
    mkdir -p "$scripts_dir" "$effects_dir"
    for s in "$REPO_ROOT/packages/kwin/scripts"/*; do
        [ -d "$s" ] || continue
        cp -a "$s" "$scripts_dir/"
    done
    for e in "$REPO_ROOT/packages/kwin/effects"/*; do
        [ -d "$e" ] || continue
        cp -a "$e" "$effects_dir/"
    done
    nimbus_ok "scripts y efectos KWin desplegados en $data_dir/kwin"
}

kwin_check() {
    echo "-- kwin:"
    if [ -d "$REPO_ROOT/packages/kwin" ]; then
        nimbus_ok "packages/kwin presente en el repo"
    else
        nimbus_fail "packages/kwin ausente en el repo (repo incompleto)"
    fi
    if [ -d "$REPO_ROOT/packages/kwin/effects/nimbus-overview" ]; then
        nimbus_ok "efecto nimbus-overview presente"
    else
        nimbus_fail "efecto nimbus-overview ausente"
    fi
    if [ -f "$HOME/.config/kwinrc" ]; then
        nimbus_ok "kwinrc presente"
    else
        nimbus_info "  [PENDIENTE] kwinrc: defaults Nimbus llegan en F2-T03 (no exigible)"
    fi
}
