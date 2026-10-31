#!/bin/bash
# lib/plasma.sh — perfil plasma: paquetes y dotfiles base.
# Usa REPO_ROOT del instalador (con defecto para uso directo/shellcheck).

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PLASMA_LIST="${PLASMA_LIST:-$REPO_ROOT/packages/plasma.list}"
PLASMA_DOTFILES="${PLASMA_DOTFILES:-$REPO_ROOT/dotfiles}"

report_commented() { # líneas comentadas de la lista: informan, no exigen
    local pend clean
    while IFS= read -r pend; do
        clean="$(printf '%s\n' "$pend" | sed 's/^#\+ *//')"
        nimbus_info "    INFO: en lista pero comentado, no exigible: $clean"
    done < <(grep -E '^#[A-Za-z0-9]' "$PLASMA_LIST" || true)
}

plasma_install_packages() {
    echo "-- paquetes plasma (pacman)..."
    # shellcheck disable=SC2046
    sudo pacman -S --needed --noconfirm $(read_list "$PLASMA_LIST") \
        || { echo "ERROR: fallo pacman plasma. Revisa tu conexión (o ejecuta sudo pacman -Sy) o estos paquetes:" >&2;
             local p
             while IFS= read -r p; do
                 pacman -Si "$p" >/dev/null 2>&1 || echo "  - $p (no resoluble: typo, repo ausente o DB sin sincronizar)" >&2;
             done < <(read_list "$PLASMA_LIST"); return 1; }
    report_commented
}

plasma_deploy_dotfiles() { # $1=dir de backup
    local backup_dir="$1"
    echo "-- dotfiles plasma -> \$HOME..."
    copy_dotfiles "$PLASMA_DOTFILES" "$HOME" "$backup_dir" || return 1
}

plasma_check() {
    echo "-- paquetes plasma:"
    local installed p
    installed="$(pacman -Qq 2>/dev/null || true)"
    while IFS= read -r p; do
        if printf '%s\n' "$installed" | grep -Fxq "$p"; then nimbus_ok "$p";
        else nimbus_fail "paquete ausente: $p"; fi
    done < <(read_list "$PLASMA_LIST")
    report_commented
    echo "-- dotfiles plasma ($HOME):"
    check_dotfiles "$PLASMA_DOTFILES" "$HOME"
    echo "-- comandos de sesión:"
    for c in plasmashell kwin_wayland krunner; do
        if command -v "$c" >/dev/null 2>&1; then nimbus_ok "$c";
        else nimbus_fail "comando ausente: $c (instala el perfil plasma y re-ejecuta)"; fi
    done
}
