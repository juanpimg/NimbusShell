#!/bin/bash
# NimbusShell — convierte cualquier Arch instalado en el escritorio NimbusOS.
# Uso: ./install.sh [--check] [--help]
#   sin args : instala (pide sudo una vez al inicio, con keep-alive).
#   --check  : solo informa (no instala, no escribe, no pide sudo); exit 1 si
#              falta algo o hay drift en dotfiles.
# Idempotente y re-ejecutable: --needed, backups con timestamp, guards.
# NUNCA ejecutar como root (los paquetes AUR no pueden compilarse como root).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFICIAL_LIST="$SCRIPT_DIR/packages.nimbus.conf"
AUR_LIST="$SCRIPT_DIR/packages.nimbus-aur.txt"
DOTFILES="$SCRIPT_DIR/dotfiles"
WALLPAPER_SRC="$SCRIPT_DIR/assets/sequoia-light.jpg"
WALLPAPER_DST="/usr/share/backgrounds/nimbus/sequoia-light.jpg"
BRANDING_SRC="$SCRIPT_DIR/assets/nimbus-logo.svg"
BRANDING_DST="/usr/share/nimbus/branding/nimbus-logo.svg"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

CHECK=0
for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        -h|--help)
            echo "Uso: ./install.sh [--check]"
            echo "  Sin args instala NimbusShell. --check solo informa (exit 1 si hay drift)."
            exit 0 ;;
        *) echo "ERROR: argumento desconocido: $arg (ver --help)" >&2; exit 2 ;;
    esac
done

FAIL=0
fail()  { echo "  [FALTA] $1" >&2; FAIL=1; }
ok()    { echo "  [OK] $1"; }
info()  { echo "$1"; }

read_list() { # $1=fichero -> stdout: paquetes (sin comentarios ni vacias)
    # Corta comentarios inline (#...), quita CR (edits CRLF), recorta
    # espacios y elimina vacias. Un paquete por linea, sin espacios internos.
    sed 's/#.*//; s/\r//g; s/^[[:space:]]*//; s/[[:space:]]*$//' "$1" | grep -v '^[[:space:]]*$'
}

# --- 0. Precondiciones (ambos modos) ------------------------------------------
if [ "$(id -u)" = "0" ]; then
    echo "ERROR: no ejecutar como root. Entra como tu usuario (con sudo) y reintenta." >&2
    exit 2
fi
if ! command -v pacman >/dev/null 2>&1; then
    echo "ERROR: sin pacman: esto no parece Arch Linux (NimbusShell solo cubre Arch y derivados)." >&2
    exit 2
fi
for f in "$OFFICIAL_LIST" "$AUR_LIST"; do
    [ -f "$f" ] || { echo "ERROR: falta $f (repo incompleto)" >&2; exit 2; }
done
[ -d "$DOTFILES" ] || { echo "ERROR: falta $DOTFILES" >&2; exit 2; }

if [ "$CHECK" = "1" ]; then
    # ============================ MODO --check ================================
    echo "== NimbusShell --check (solo lectura) =="
    echo "-- pacman:"; command -v pacman >/dev/null && ok "pacman presente" || fail "sin pacman"
    echo "-- paru:"
    if command -v paru >/dev/null 2>&1; then ok "paru presente";
    else fail "paru ausente (el instalador lo pondria desde cachyos o compilado AUR)"; fi

    echo "-- paquetes oficiales:"
    while IFS= read -r p; do
        pacman -Qq "$p" >/dev/null 2>&1 && ok "$p" || fail "paquete oficial ausente: $p"
    done < <(read_list "$OFFICIAL_LIST")

    echo "-- paquetes AUR:"
    while IFS= read -r p; do
        pacman -Qq "$p" >/dev/null 2>&1 && ok "$p" || fail "paquete AUR ausente: $p"
    done < <(read_list "$AUR_LIST")

    echo "-- dotfiles ($HOME):"
    while IFS= read -r src; do
        rel="${src#$DOTFILES/}"
        dst="$HOME/$rel"
        if [ ! -e "$dst" ]; then fail "falta en HOME: $rel";
        elif ! cmp -s "$src" "$dst"; then fail "difiere de HOME: $rel"; fi
    done < <(find "$DOTFILES" -type f | sort)
    [ "$FAIL" = "0" ] && ok "dotfiles 1:1 con el repo"

    echo "-- fondo de pantalla:"
    if [ -f "$WALLPAPER_DST" ] && cmp -s "$WALLPAPER_SRC" "$WALLPAPER_DST"; then ok "$WALLPAPER_DST";
    else fail "$WALLPAPER_DST ausente o distinto"; fi

    echo "-- logo de barra:"
    if [ -f "$BRANDING_DST" ] && cmp -s "$BRANDING_SRC" "$BRANDING_DST"; then ok "$BRANDING_DST";
    else fail "$BRANDING_DST ausente o distinto (barCustomLogoPath de MacBar)"; fi

    echo "-- binarios de sesion:"
    for c in hyprland hyprlock qs kitty swaybg udiskie flatpak brightnessctl; do
        command -v "$c" >/dev/null 2>&1 && ok "$c" || fail "comando ausente: $c"
    done
    [ -x "$HOME/.local/bin/macshell" ] && ok ".local/bin/macshell" \
        || fail ".local/bin/macshell ausente o sin +x (autostart exec-once)"
    [ -x "$HOME/.local/bin/macshell-start" ] && ok ".local/bin/macshell-start" \
        || fail ".local/bin/macshell-start ausente o sin +x"
    [ -x "$HOME/.local/bin/nimbus-minimize-toggle" ] && ok ".local/bin/nimbus-minimize-toggle" \
        || fail ".local/bin/nimbus-minimize-toggle ausente o sin +x"
    [ -x "$HOME/.local/bin/nimbus-screenshot" ] && ok ".local/bin/nimbus-screenshot" \
        || fail ".local/bin/nimbus-screenshot ausente o sin +x (binds SUPER+SHIFT+3/4/5)"

    echo "-- sonidos UI:"
    for s in pop charge shutter glass tink; do
        [ -s "$HOME/.local/share/sounds/macshell/$s.wav" ] && ok "sonido $s" \
            || fail "sonido ausente: $s.wav (paso [6/8] con ffmpeg)"
    done

    echo "-- coherencia QS_ICON_THEME (hyprland.conf + hyprland.lua vs macshell/env):"
    q1="$(grep -h '^env = QS_ICON_THEME' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null | sed 's/.*,//; s/^[[:space:]]*//; s/[[:space:]]*$//' || true)"
    q1lua="$(grep -h 'hl\.env("QS_ICON_THEME"' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null | sed 's/.*"QS_ICON_THEME", *"\([^"]*\)".*/\1/' || true)"
    q2="$(grep -h '^QS_ICON_THEME=' "$HOME/.config/macshell/env" 2>/dev/null | cut -d= -f2 || true)"
    if [ -n "${q1:-}" ] && [ "${q1:-}" = "${q2:-}" ] && { [ -z "${q1lua:-}" ] || [ "${q1lua:-}" = "${q2:-}" ]; }; then ok "QS_ICON_THEME=$q1 en todos";
    else fail "QS_ICON_THEME difiere (conf='$q1' lua='$q1lua' env='$q2')"; fi

    echo "-- config Hyprland (HOME temporal):"
    if command -v hyprland >/dev/null 2>&1 && { [ -f "$HOME/.config/hypr/hyprland.lua" ] || [ -f "$HOME/.config/hypr/hyprland.conf" ]; }; then
        tmpcheck="$(mktemp -d)" || { echo "ERROR: sin temporal (TMPDIR lleno)" >&2; exit 1; }
        ln -s "$HOME/.config" "$tmpcheck/.config"
        if HOME="$tmpcheck" hyprland --verify-config >/dev/null 2>&1; then ok "hyprland --verify-config";
        else fail "hyprland --verify-config falla (o SKIP si pide plugin .so sin cargar: ver README)"; fi
        rm -rf "$tmpcheck"
    else fail "hyprland ausente o sin config en ~/.config/hypr/"; fi

    echo "-- servicios de sistema:"
    if command -v systemctl >/dev/null 2>&1; then
        for u in auto-cpufreq.service thermald.service bluetooth.service; do
            systemctl is-enabled "$u" >/dev/null 2>&1 && ok "$u habilitado" || fail "$u no habilitado"
        done
        if pacman -Qq auto-cpufreq >/dev/null 2>&1 && systemctl is-enabled power-profiles-daemon.service >/dev/null 2>&1; then
            fail "power-profiles-daemon activo (conflicto con auto-cpufreq)"
        else ok "sin conflicto power-profiles-daemon/auto-cpufreq"; fi
    else fail "sin systemctl"; fi

    echo "-- flathub:"
    if command -v flatpak >/dev/null 2>&1 && flatpak remotes 2>/dev/null | grep -q '^flathub'; then ok "flathub presente";
    else fail "flathub ausente (o sin flatpak)"; fi

    if [ "$FAIL" = "0" ]; then echo "CHECK VERDE: nada que hacer."; else echo "CHECK ROJO: hay drift (ver [FALTA] arriba)."; fi
    exit "$FAIL"
fi

# ============================ MODO INSTALACION ===============================
echo "== NimbusShell: instalacion =="
echo "Pide sudo una vez al inicio (pacman/systemctl); el AUR se compila como tu usuario, nunca como root."

sudo -v || { echo "ERROR: sin sudo, abortar." >&2; exit 1; }
( while sleep 240; do sudo -n -v 2>/dev/null || true; done ) &
KA=$!
trap 'kill $KA 2>/dev/null || true' EXIT

# --- 1. Paquetes oficiales ----------------------------------------------------
echo "-- [1/8] paquetes oficiales (pacman)..."
# shellcheck disable=SC2046
sudo pacman -S --needed --noconfirm $(read_list "$OFFICIAL_LIST") \
    || { echo "ERROR: fallo pacman oficial. Revisa tu conexion o estos paquetes:" >&2;
         # shellcheck disable=SC2046
         for p in $(read_list "$OFFICIAL_LIST"); do
             pacman -Si "$p" >/dev/null 2>&1 || echo "  - $p (no resoluble: typo o repo ausente)" >&2;
         done; exit 1; }

# --- 2. paru (helper AUR; cachyos lo trae, en vanilla se compila) ------------
echo "-- [2/8] helper AUR (paru)..."
if ! command -v paru >/dev/null 2>&1; then
    if sudo pacman -Si paru >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm paru || { echo "ERROR: no se pudo instalar paru." >&2; exit 1; }
    else
        echo "    paru no esta en tus repos: compilando desde el AUR como $(whoami)..."
        command -v git >/dev/null 2>&1 || { echo "ERROR: sin git para compilar paru." >&2; exit 1; }
        tmpaur="$(mktemp -d)" || { echo "ERROR: sin temporal para compilar paru (TMPDIR lleno)" >&2; exit 1; }
        git clone --depth 1 https://aur.archlinux.org/paru.git "$tmpaur/paru" \
            || { echo "ERROR: sin red o sin AUR." >&2; rm -rf "$tmpaur"; exit 1; }
        ( cd "$tmpaur/paru" && makepkg -si --noconfirm ) \
            || { echo "ERROR: fallo compilacion paru." >&2; rm -rf "$tmpaur"; exit 1; }
        rm -rf "$tmpaur"
    fi
fi
command -v paru >/dev/null 2>&1 || { echo "ERROR: paru sigue ausente." >&2; exit 1; }
echo "    paru OK"

# --- 3. Paquetes AUR (paru, como usuario) -------------------------------------
echo "-- [3/8] paquetes AUR (paru, como $(whoami))..."
echo "    (paru puede pedirte revisar PKGBUILD o importar claves UNA vez; no se salta a proposito)"
# shellcheck disable=SC2046
paru -S --needed --noconfirm $(read_list "$AUR_LIST") \
    || { echo "ERROR: fallo paru AUR." >&2; exit 1; }

# --- 4. Dotfiles -> $HOME (con backup previo, jamas borrar) -------------------
echo "-- [4/8] dotfiles -> \$HOME..."
BACKUP="$HOME/.config/nimbusshell-backup-$(date +%Y%m%d-%H%M%S)"
n_new=0; n_same=0; n_upd=0
while IFS= read -r src; do
    rel="${src#$DOTFILES/}"
    dst="$HOME/$rel"
    if [ ! -e "$dst" ]; then
        mkdir -p "$(dirname "$dst")" \
            || { echo "ERROR: no se pudo crear $(dirname "$dst") (revisa permisos/disco)" >&2; exit 1; }
        cp -a "$src" "$dst" \
            || { echo "ERROR: no se pudo copiar $rel a tu HOME (revisa permisos/disco)" >&2; exit 1; }
        n_new=$((n_new + 1))
    elif ! cmp -s "$src" "$dst"; then
        mkdir -p "$BACKUP/$(dirname "$rel")" \
            || { echo "ERROR: no se pudo crear el backup en $BACKUP (revisa permisos/disco)" >&2; exit 1; }
        cp -a "$dst" "$BACKUP/$rel" \
            || { echo "ERROR: no se pudo respaldar $rel (revisa permisos/disco)" >&2; exit 1; }
        cp -a "$src" "$dst" \
            || { echo "ERROR: no se pudo actualizar $rel (tu original sigue en $BACKUP/$rel)" >&2; exit 1; }
        n_upd=$((n_upd + 1))
    else
        n_same=$((n_same + 1))
    fi
done < <(find "$DOTFILES" -type f | sort)
echo "    nuevos=$n_new actualizados=$n_upd (backup en $BACKUP) identicos=$n_same"
# Solo quitar el dir si quedo vacio (rmdir, no rm -rf): si otro run creo un
# backup con el mismo timestamp (mismo segundo), su contenido se conserva.
rmdir "$BACKUP" 2>/dev/null || true

# --- 5. Fondo de pantalla + branding del sistema -------------------------------
echo "-- [5/8] fondo de pantalla y branding..."
if [ -f "$WALLPAPER_DST" ] && cmp -s "$WALLPAPER_SRC" "$WALLPAPER_DST"; then
    echo "    fondo ya presente"
else
    sudo install -Dm644 "$WALLPAPER_SRC" "$WALLPAPER_DST" \
        || echo "    AVISO: no se pudo instalar el fondo (swaybg/hyprpaper usaran fallback)." >&2
fi
if [ -f "$BRANDING_DST" ] && cmp -s "$BRANDING_SRC" "$BRANDING_DST"; then
    echo "    logo ya presente"
else
    sudo install -Dm644 "$BRANDING_SRC" "$BRANDING_DST" \
        || echo "    AVISO: no se pudo instalar el logo (la barra usara el modo arch)." >&2
fi

# --- 6. Fuentes + sonidos UI + Nautilus estilo Finder (nivel usuario) ---------
echo "-- [6/8] fuentes, sonidos y ajustes de usuario..."
command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
# Sonidos de MacShell (pw-play): se generan desde sound-theme-freedesktop
# (licencia libre) con ffmpeg, ya en el manifest. Idempotente: no reconvierte.
if command -v ffmpeg >/dev/null 2>&1; then
    SOUNDS="$HOME/.local/share/sounds/macshell"
    FDO="/usr/share/sounds/freedesktop/stereo"
    mkdir -p "$SOUNDS" 2>/dev/null || echo "    AVISO: sin dir de sonidos" >&2
    for m in "pop:audio-volume-change" "charge:power-plug" "shutter:camera-shutter" "glass:dialog-information" "tink:bell"; do
        n="${m%%:*}"; src="$FDO/${m#*:}.oga"
        if [ ! -s "$SOUNDS/$n.wav" ]; then
            ffmpeg -y -v error -i "$src" "$SOUNDS/$n.wav" >/dev/null 2>&1 \
                || echo "    AVISO: sin sonido $n (falta $src)" >&2
        fi
    done
    echo "    sonidos UI listos (pop/charge/shutter/glass/tink)"
else
    echo "    AVISO: sin ffmpeg, salto sonidos UI" >&2
fi
if command -v gsettings >/dev/null 2>&1 \
    && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.nautilus.preferences'; then
    gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view' 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences show-hidden-files false 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences sort-directories-first true 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences default-sort-order 'name' 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences search-filter-time-type 'last_modified' 2>/dev/null || true
    gsettings set org.gnome.nautilus.preferences show-create-link true 2>/dev/null || true
    gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard' 2>/dev/null || true
    gsettings set org.gnome.nautilus.icon-view captions "['size', 'date_modified', 'none']" 2>/dev/null || true
    gsettings set org.gnome.nautilus.window-state sidebar-width 200 2>/dev/null || true
    gsettings set org.gnome.nautilus.window-state side-pane-visible true 2>/dev/null || true
    gsettings set org.gnome.nautilus.window-state maximized false 2>/dev/null || true
    gsettings set org.gnome.nautilus.window-state geometry '880x600' 2>/dev/null || true
    echo "    nautilus estilo Finder aplicado (equivale al dconf db de la ISO, a nivel usuario)"
else
    echo "    nautilus/gsettings no disponible: salto ajustes Finder"
fi

# --- 7. Servicios de sistema + Flathub ----------------------------------------
echo "-- [7/8] servicios y flathub..."
if command -v systemctl >/dev/null 2>&1; then
    if pacman -Qq auto-cpufreq >/dev/null 2>&1 \
        && systemctl list-unit-files 2>/dev/null | grep -q '^power-profiles-daemon'; then
        sudo systemctl mask --now power-profiles-daemon.service >/dev/null 2>&1 || true
        echo "    power-profiles-daemon enmascarado (conflicto con auto-cpufreq)"
    fi
    for u in auto-cpufreq thermald bluetooth; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${u}\\.service[[:space:]]"; then
            sudo systemctl enable "${u}.service" >/dev/null 2>&1 \
                && echo "    $u habilitado" || echo "    AVISO: no se pudo habilitar $u" >&2
        else
            echo "    AVISO: $u sin unit-file (se revisara en [8/8])" >&2
        fi
    done
else
    echo "    AVISO: sin systemctl, salto servicios" >&2
fi
if command -v flatpak >/dev/null 2>&1; then
    sudo flatpak remote-add --if-not-exists flathub "$FLATHUB_URL" >/dev/null 2>&1 \
        || echo "    AVISO: flathub sin red ahora; reintenta: sudo flatpak remote-add --if-not-exists flathub $FLATHUB_URL" >&2
fi

# --- 8. Verificacion ----------------------------------------------------------
echo "-- [8/8] verificacion..."
VFAIL=0
for c in hyprland hyprlock qs kitty swaybg udiskie flatpak brightnessctl paru; do
    command -v "$c" >/dev/null 2>&1 && echo "    [OK] $c" || { echo "    [FALTA] $c" >&2; VFAIL=1; }
done
for b in macshell macshell-start nimbus-minimize-toggle nimbus-screenshot; do
    [ -x "$HOME/.local/bin/$b" ] && echo "    [OK] .local/bin/$b" || { echo "    [FALTA] .local/bin/$b" >&2; VFAIL=1; }
done
for s in pop charge shutter glass tink; do
    [ -s "$HOME/.local/share/sounds/macshell/$s.wav" ] && echo "    [OK] sonido $s" || { echo "    [FALTA] sonido $s.wav" >&2; VFAIL=1; }
done
# Paridad con --check: lo desplegado se re-verifica aqui. Si algo ambiental
# fallo arriba con AVISO (servicios/flathub/fondo), aqui cuenta como FALTA
# igual que en --check (re-ejecutar tras arreglarlo; el install es idempotente).
while IFS= read -r src; do
    rel="${src#$DOTFILES/}"
    cmp -s "$src" "$HOME/$rel" || { echo "    [FALTA] dotfile sin desplegar: $rel" >&2; VFAIL=1; }
done < <(find "$DOTFILES" -type f | sort)
if [ -f "$WALLPAPER_DST" ] && cmp -s "$WALLPAPER_SRC" "$WALLPAPER_DST"; then
    echo "    [OK] fondo"
else echo "    [FALTA] fondo $WALLPAPER_DST ausente o distinto" >&2; VFAIL=1; fi
if [ -f "$BRANDING_DST" ] && cmp -s "$BRANDING_SRC" "$BRANDING_DST"; then
    echo "    [OK] logo"
else echo "    [FALTA] logo $BRANDING_DST ausente o distinto" >&2; VFAIL=1; fi
v1="$(grep -h '^env = QS_ICON_THEME' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null | sed 's/.*,//; s/^[[:space:]]*//; s/[[:space:]]*$//' || true)"
v1lua="$(grep -h 'hl\.env("QS_ICON_THEME"' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null | sed 's/.*"QS_ICON_THEME", *"\([^"]*\)".*/\1/' || true)"
v2="$(grep -h '^QS_ICON_THEME=' "$HOME/.config/macshell/env" 2>/dev/null | cut -d= -f2 || true)"
if [ -n "${v1:-}" ] && [ "${v1:-}" = "${v2:-}" ] && { [ -z "${v1lua:-}" ] || [ "${v1lua:-}" = "${v2:-}" ]; }; then
    echo "    [OK] QS_ICON_THEME=$v1"
else echo "    [FALTA] QS_ICON_THEME (conf='$v1' lua='$v1lua' env='$v2')" >&2; VFAIL=1; fi
if command -v systemctl >/dev/null 2>&1; then
    for u in auto-cpufreq.service thermald.service bluetooth.service; do
        if ! systemctl list-unit-files 2>/dev/null | grep -q "^${u}[[:space:]]"; then
            echo "    [AVISO] $u sin unit-file (paquete ausente o entorno sin systemd)" >&2
        elif systemctl is-enabled "$u" >/dev/null 2>&1; then echo "    [OK] $u"
        else echo "    [FALTA] $u no habilitado" >&2; VFAIL=1; fi
    done
else echo "    [FALTA] sin systemctl" >&2; VFAIL=1; fi
if command -v flatpak >/dev/null 2>&1 && flatpak remotes 2>/dev/null | grep -q '^flathub'; then
    echo "    [OK] flathub"
else echo "    [FALTA] flathub ausente" >&2; VFAIL=1; fi
if command -v hyprland >/dev/null 2>&1; then
    tmpv="$(mktemp -d)" || { echo "    [FALTA] sin temporal para verificar" >&2; VFAIL=1; }
    if [ -n "${tmpv:-}" ]; then
        ln -s "$HOME/.config" "$tmpv/.config"
        if HOME="$tmpv" hyprland --verify-config >/dev/null 2>&1; then
            echo "    [OK] hyprland --verify-config"
        else
            echo "    [AVISO] hyprland --verify-config falla: si el error es solo por plugin .so" \
                "sin cargar (hyprbars), es SKIP conocido, no FAIL (ver README)." >&2
        fi
        rm -rf "$tmpv"
    fi
fi

echo
if [ "$VFAIL" = "0" ]; then
    echo "NIMBUSSHELL OK. Cierra sesion y entra en Hyprland (tu DM o 'Hyprland' en TTY)."
    echo "Si vienes de otro escritorio, tu config anterior esta en ~/.config/nimbusshell-backup-*."
else
    echo "INSTALACION CON FALTOS (ver [FALTA] arriba). Re-ejecuta ./install.sh; si persiste, abre issue." >&2
    exit 1
fi
