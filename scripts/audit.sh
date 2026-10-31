#!/bin/bash
# F0-T01 — Inventario y baseline reproducible del repo NimbusShell.
# Solo lectura (+ su propia salida por stdout). Sin sudo, sin red, sin
# escritura en el repo. Idempotente: re-ejecutar produce el mismo informe
# (salvo métricas volátiles del host: git status, RAM libre).
# Uso: scripts/audit.sh [DIR_REPO]
set -u

REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NIMBUSOS="/home/jp/Escritorio/Proyectos/NimbusOS"

say() { printf '%s\n' "$1"; }
sec() { printf '\n== %s ==\n' "$1"; }

sec "F0-T01 audit — repo: $REPO"

sec "1. LOC por tipo"
if command -v cloc >/dev/null 2>&1; then
    say "-- cloc disponible:"
    cloc --quiet --csv --report-file=/dev/stdout \
        --include-ext=qml,sh,lua,js,md,conf --include-lang=QML,Bourne\ Shell,Lua,JavaScript,Markdown \
        "$REPO/dotfiles" "$REPO/install.sh" "$REPO/README.md" 2>/dev/null || cloc "$REPO/dotfiles" "$REPO/install.sh" 2>/dev/null || true
else
    say "-- cloc ausente: fallback find+wc (ficheros y lineas por extension)"
    for ext in qml sh lua js md conf json; do
        n="$(find "$REPO" -path "$REPO/.git" -prune -o -type f -name "*.$ext" -print 2>/dev/null | wc -l)"
        loc="$(find "$REPO" -path "$REPO/.git" -prune -o -type f -name "*.$ext" -print0 2>/dev/null | xargs -0 cat 2>/dev/null | wc -l)"
        printf '%-6s ficheros=%-5s lineas=%s\n' "$ext" "$n" "$loc"
    done
    total_f="$(find "$REPO" -path "$REPO/.git" -prune -o -type f -print 2>/dev/null | wc -l)"
    say "total ficheros (sin .git): $total_f"
fi

sec "2. Dotfiles por directorio"
if [ -d "$REPO/dotfiles" ]; then
    total="$(find "$REPO/dotfiles" \( -type f -o -type l \) 2>/dev/null | wc -l)"
    say "total dotfiles (f+l): $total"
    while IFS= read -r d; do
        rel="${d#$REPO/dotfiles/}"
        c="$(find "$d" \( -type f -o -type l \) 2>/dev/null | wc -l)"
        printf '%-45s %s\n' "$rel" "$c"
    done < <(find "$REPO/dotfiles" -mindepth 1 -type d 2>/dev/null | sort)
else
    say "AVISO: sin dotfiles en $REPO"
fi

sec "3. Rulings R1-R21 (README.md)"
if [ -f "$REPO/README.md" ]; then
    for i in $(seq 1 21); do
        line="$(grep -m1 -o "R${i} *[:—–-].*" "$REPO/README.md" 2>/dev/null | cut -c1-160 || true)"
        if [ -n "${line:-}" ]; then
            printf 'R%-3s %s\n' "${i}" "$line"
        else
            printf 'R%-3s (no encontrada con grep R%s)\n' "${i}" "${i}"
        fi
    done
else
    say "AVISO: sin README.md"
fi

sec "4a. install.sh (resumen)"
if [ -f "$REPO/install.sh" ]; then
    say "lineas: $(wc -l < "$REPO/install.sh")"
    say "funciones:"
    grep -nE '^[a-z_][a-z0-9_]*\(\)' "$REPO/install.sh" 2>/dev/null || say "  (ninguna)"
    say "checks (--check): $(grep -c 'fail "' "$REPO/install.sh" 2>/dev/null || true) puntos fail/ok"
    say "pasos instalacion [N/8]: $(grep -o '\[[0-9]/8\]' "$REPO/install.sh" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
    say "bash -n: $(bash -n "$REPO/install.sh" 2>&1 && echo OK || echo FALLO)"
else
    say "AVISO: sin install.sh"
fi

sec "4b. Listas de paquetes"
for f in "$REPO"/packages.nimbus*.txt "$REPO"/packages.nimbus.conf; do
    [ -f "$f" ] || continue
    n="$(sed 's/#.*//; s/\r//g' "$f" | grep -vE '^\s*$' | wc -l)"
    aur_hint=""
    case "$f" in *aur*) aur_hint=" (AUR via paru)";; *) aur_hint=" (oficiales pacman)";; esac
    say "$(basename "$f"): $n paquetes$aur_hint"
done

sec "5. NimbusOS (referencia, solo lectura)"
if [ -d "$NIMBUSOS" ]; then
    say "ruta: $NIMBUSOS"
    say "base: $(grep -m1 -i -o 'basad[ao] en [A-Za-z]*' "$NIMBUSOS/README.md" 2>/dev/null || echo 'CachyOS (ver README)')"

    say "perfil ISO: $(ls "$NIMBUSOS" | tr '\n' ' ')"
    if [ -f "$NIMBUSOS/iso.manifest" ]; then
        say "iso.manifest presente ($(wc -l < "$NIMBUSOS/iso.manifest") lineas)"
    else
        say "iso.manifest ausente"
    fi
    if [ -f "$NIMBUSOS/packages.nimbus.x86_64.append" ]; then
        n="$(sed 's/#.*//' "$NIMBUSOS/packages.nimbus.x86_64.append" | grep -vE '^\s*$' | wc -l)"
        say "packages.nimbus.x86_64.append: $n paquetes"
    fi
    if [ -d "$NIMBUSOS/nimbus-overlay/etc/skel" ]; then
        nskel="$(find "$NIMBUSOS/nimbus-overlay/etc/skel" \( -type f -o -type l \) 2>/dev/null | wc -l)"
        say "skel (etc/skel): $nskel ficheros"
    fi
    if [ -d "$NIMBUSOS/nimbus-overlay/etc/calamares" ]; then
        ncal="$(find "$NIMBUSOS/nimbus-overlay/etc/calamares" -type f 2>/dev/null | wc -l)"
        say "calamares overlay: $ncal ficheros"
    else
        say "calamares overlay: ausente"
    fi
    ntot="$(find "$NIMBUSOS/nimbus-overlay" -type f 2>/dev/null | wc -l)"
    say "nimbus-overlay total: $ntot ficheros"
else
    say "AVISO: NimbusOS no accesible en $NIMBUSOS"
fi

sec "6. Metricas del host"
say "git log: $(git -C "$REPO" log -1 --format='%h %ad %s' --date=short 2>/dev/null || echo 'sin git')"
say "git status: $(git -C "$REPO" status --short 2>/dev/null | head -5 | tr '\n' ';' || echo '?')"
say "rama: $(git -C "$REPO" branch --show-current 2>/dev/null || echo '?')"
say "kernel: $(uname -r 2>/dev/null || echo '?')"
if command -v free >/dev/null 2>&1; then
    free -h 2>/dev/null | head -2 || true
fi
say "nproc: $(nproc 2>/dev/null || echo '?')"

sec "FIN F0-T01 audit (exit 0)"
