#!/bin/bash
# NimbusShell — dispatcher de perfiles (Plasma + legacy Hyprland).
# Uso: ./install.sh [--profile=plasma|legacy-hypr] [--check] [--no-build] [--help]
#   sin args                    : instala el perfil plasma (incluye GUI + KCM).
#   --profile=legacy-hypr       : delega en legacy/hyprland/install.sh (mismos args).
#   --check                     : solo informa (no instala, no escribe, no pide
#                                 sudo, no usa red); exit 1 si falta algo o hay drift.
#   --no-build                  : no compila barra/apps/KCM; deja [PENDIENTE].
# Idempotente y re-ejecutable. NUNCA ejecutar como root.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
LIB_DIR="$REPO_ROOT/lib"
LEGACY_INSTALL="$REPO_ROOT/legacy/hyprland/install.sh"
PLASMA_LIST="$REPO_ROOT/packages/plasma.list"
PLASMA_DOTFILES="$REPO_ROOT/dotfiles"

usage() {
    echo "Uso: ./install.sh [--profile=plasma|legacy-hypr] [--check] [--no-build]"
    echo "  Sin args instala el perfil plasma (incluye GUI + KCM)."
    echo "  --profile=legacy-hypr delega en el instalador legacy congelado."
    echo "  --check solo informa (exit 1 si hay drift); sin sudo, sin red, sin escritura."
    echo "  --no-build omite compilar barra/apps/KCM."
}

PROFILE="plasma"
CHECK=0
NO_BUILD=0
while [ $# -gt 0 ]; do
    case "$1" in
        --profile=*) PROFILE="${1#--profile=}"; shift ;;
        --profile)
            [ $# -ge 2 ] || { echo "ERROR: --profile necesita un valor (plasma|legacy-hypr)" >&2; exit 2; }
            PROFILE="$2"; shift 2 ;;
        --check) CHECK=1; shift ;;
        --no-build) NO_BUILD=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: argumento desconocido: $1 (ver --help)" >&2; exit 2 ;;
    esac
done
case "$PROFILE" in
    plasma|legacy-hypr) ;;
    *) echo "ERROR: --profile debe ser plasma o legacy-hypr (ver --help)" >&2; exit 2 ;;
esac

# --- delegación legacy (antes de cargar libs de plasma) -----------------------
if [ "$PROFILE" = "legacy-hypr" ]; then
    [ -x "$LEGACY_INSTALL" ] || { echo "ERROR: falta $LEGACY_INSTALL (repo incompleto)" >&2; exit 2; }
    if [ "$CHECK" = "1" ]; then
        exec "$LEGACY_INSTALL" --check
    else
        exec "$LEGACY_INSTALL"
    fi
fi

# --- precondiciones del repo (ambos modos, solo lectura) ----------------------
for f in "$LIB_DIR/common.sh" "$LIB_DIR/plasma.sh" "$LIB_DIR/kwin.sh" \
         "$LIB_DIR/themes.sh" "$LIB_DIR/dock.sh" "$LIB_DIR/apps.sh" \
         "$LIB_DIR/verify.sh"; do
    [ -f "$f" ] || { echo "ERROR: falta $f (repo incompleto)" >&2; exit 2; }
done
[ -f "$PLASMA_LIST" ] || { echo "ERROR: falta $PLASMA_LIST (repo incompleto)" >&2; exit 2; }
[ -d "$PLASMA_DOTFILES" ] || { echo "ERROR: falta $PLASMA_DOTFILES (repo incompleto)" >&2; exit 2; }

# shellcheck disable=SC1091
. "$LIB_DIR/common.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/plasma.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/kwin.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/themes.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/dock.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/apps.sh"
# shellcheck disable=SC1091
. "$LIB_DIR/verify.sh"

require_nonroot
require_pacman

if [ "$CHECK" = "1" ]; then
    # ============================ MODO --check ================================
    echo "== NimbusShell --check (perfil plasma, solo lectura) =="
    verify_profile plasma
    exit "$CHECK_FAIL"
fi

# ============================ MODO INSTALACION ===============================
echo "== NimbusShell: instalación (perfil plasma) =="
echo "Pide sudo una vez al inicio (pacman); no hay AUR sin fijar en este perfil."
sudo -v || { echo "ERROR: sin sudo, abortar." >&2; exit 1; }
( while sleep 240; do sudo -n -v 2>/dev/null || true; done ) &
KA=$!
trap 'kill $KA 2>/dev/null || true' EXIT

BACKUP_DIR="$(make_backup_dir)"
plasma_remove_legacy_blockers || exit 1
plasma_install_packages || exit 1
plasma_deploy_dotfiles "$BACKUP_DIR" || exit 1
themes_deploy || exit 1
kwin_deploy
dock_deploy
apps_deploy
[ "$NO_BUILD" = "1" ] && export NIMBUS_SKIP_BUILD=1
components_deploy || exit 1

echo "-- verificación..."
verify_profile plasma
rc="$CHECK_FAIL"
echo
if [ "$rc" = "0" ]; then
    echo "NIMBUSSHELL OK (plasma). Cierra sesión y entra en Plasma (Wayland)."
    echo "Si vienes de otro escritorio, tu config anterior está en ~/.config/nimbusshell-backup-*."
else
    echo "INSTALACIÓN CON FALTOS (ver [FALTA] arriba). Re-ejecuta ./install.sh; si persiste, abre issue." >&2
    exit 1
fi
