#!/bin/bash
# lib/themes.sh — fundación visual: fondo y marca del sistema.
# Despliegue real e idempotente (necesita sudo, solo en modo instalación);
# verificación real por cmp (solo lectura).

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
THEME_WALLPAPER_SRC="${THEME_WALLPAPER_SRC:-$REPO_ROOT/assets/sequoia-light.jpg}"
THEME_WALLPAPER_DST="${THEME_WALLPAPER_DST:-/usr/share/backgrounds/nimbus/sequoia-light.jpg}"
THEME_LOGO_SRC="${THEME_LOGO_SRC:-$REPO_ROOT/assets/nimbus-logo.svg}"
THEME_LOGO_DST="${THEME_LOGO_DST:-/usr/share/nimbus/branding/nimbus-logo.svg}"
# F10-T05 — tema de sonido propio (solo .oga; los .wav son masters en repo).
SOUNDS_SRC="${SOUNDS_SRC:-$REPO_ROOT/packages/themes/sounds-nimbus}"
SOUNDS_DST="${SOUNDS_DST:-${XDG_DATA_HOME:-$HOME/.local/share}/sounds/Nimbus}"

themes_deploy() {
    echo "-- fondo de pantalla y marca Nimbus..."
    if [ -f "$THEME_WALLPAPER_DST" ] && cmp -s "$THEME_WALLPAPER_SRC" "$THEME_WALLPAPER_DST"; then
        echo "    fondo ya presente"
    else
        sudo install -Dm644 "$THEME_WALLPAPER_SRC" "$THEME_WALLPAPER_DST" \
            || echo "    AVISO: no se pudo instalar el fondo (el tema usará fallback hasta F2-T04)." >&2
    fi
    if [ -f "$THEME_LOGO_DST" ] && cmp -s "$THEME_LOGO_SRC" "$THEME_LOGO_DST"; then
        echo "    marca ya presente"
    else
        sudo install -Dm644 "$THEME_LOGO_SRC" "$THEME_LOGO_DST" \
            || echo "    AVISO: no se pudo instalar la marca (la barra usará modo genérico)." >&2
    fi
    # F10-T05 — sonidos Nimbus a nivel usuario (sin sudo): plasma los
    # resuelve vía libcanberra ($XDG_DATA_HOME/sounds/<Theme>/stereo/*.oga).
    echo "-- sonidos Nimbus -> $SOUNDS_DST..."
    if [ ! -d "$SOUNDS_SRC/stereo" ] || [ ! -f "$SOUNDS_SRC/index.theme" ]; then
        echo "    AVISO: falta $SOUNDS_SRC (repo incompleto; sonidos omitidos)." >&2
    else
        mkdir -p "$SOUNDS_DST/stereo" \
            || echo "    AVISO: no se pudo crear $SOUNDS_DST (revisa permisos/disco)." >&2
        if [ -d "$SOUNDS_DST/stereo" ]; then
            cp -af "$SOUNDS_SRC/index.theme" "$SOUNDS_DST/index.theme"
            cp -af "$SOUNDS_SRC"/stereo/*.oga "$SOUNDS_DST/stereo/"
            echo "    sonidos instalados ($(ls "$SOUNDS_DST/stereo"/*.oga | wc -l) .oga)"
        fi
    fi
}

themes_check() {
    echo "-- fondo y marca:"
    if [ -f "$THEME_WALLPAPER_DST" ] && cmp -s "$THEME_WALLPAPER_SRC" "$THEME_WALLPAPER_DST"; then
        nimbus_ok "$THEME_WALLPAPER_DST"
    else nimbus_fail "$THEME_WALLPAPER_DST ausente o distinto (paso de temas en la instalación)"; fi
    if [ -f "$THEME_LOGO_DST" ] && cmp -s "$THEME_LOGO_SRC" "$THEME_LOGO_DST"; then
        nimbus_ok "$THEME_LOGO_DST"
    else nimbus_fail "$THEME_LOGO_DST ausente o distinto (paso de temas en la instalación)"; fi
    if [ -f "$SOUNDS_DST/index.theme" ] && cmp -s "$SOUNDS_SRC/index.theme" "$SOUNDS_DST/index.theme"; then
        nimbus_ok "$SOUNDS_DST (tema de sonido Nimbus)"
    else nimbus_fail "$SOUNDS_DST ausente o distinto (paso de sonidos en la instalación)"; fi
}
