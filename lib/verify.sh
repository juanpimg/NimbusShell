#!/bin/bash
# lib/verify.sh — verificación por perfil (solo lectura).
# Espera las funciones *_check de cada lib y CHECK_FAIL de lib/common.sh.

verify_profile() { # $1=perfil
    local profile="${1:-plasma}"
    case "$profile" in
        plasma)
            plasma_check
            kwin_check
            themes_check
            dock_check
            apps_check
            ;;
        *) echo "ERROR: perfil desconocido: $profile (plasma|legacy-hypr)" >&2; return 2 ;;
    esac
    if [ "$CHECK_FAIL" = "0" ]; then echo "CHECK VERDE: nada que hacer.";
    else echo "CHECK ROJO: hay drift (ver [FALTA] arriba)."; fi
    return "$CHECK_FAIL"
}
