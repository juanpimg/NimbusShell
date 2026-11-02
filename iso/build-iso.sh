#!/usr/bin/env bash
# build-iso.sh — estagia el perfil NimbusOS y construye la ISO netinstall.
# Flujo: copia iso/profile a staging temporal, superpone calamares/dotfiles/
# scripts/temas/apps, verifica nimbus-installed-setup y llama a mkarchiso.
# Solo autoría + staging en este host; el build real con root se hace en VM.
# Uso: iso/build-iso.sh [--check] [--stage-only] [--out DIR] [--skip-apps] [--help]
#   --check       solo lectura (sin sudo, sin red, sin escribir); exit 0 si OK.
#   --stage-only  estagia en DIR y verifica el árbol; no llama a mkarchiso.
#   --out DIR     destino del staging (defecto: /tmp/nimbus-stage) o de la ISO.
#   --work DIR    directorio de trabajo de mkarchiso (defecto: /tmp/nimbus-work).
#   --skip-apps   no compila nimbus-bar/apps/spotlight (documentar el SKIP).
# Idempotente: re-ejecutar limpia y regenera el staging sin duplicar.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$REPO_ROOT/iso/profile"
CALAMARES="$REPO_ROOT/iso/calamares"
OUT="/tmp/nimbus-stage"
WORK="/tmp/nimbus-work"
CHECK=0
STAGE_ONLY=0
SKIP_APPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --stage-only) STAGE_ONLY=1; shift ;;
    --skip-apps) SKIP_APPS=1; shift ;;
    --work=*) WORK="${1#--work=}"; [ -n "$WORK" ] || { echo "ERROR: --work requiere DIR" >&2; exit 1; }; shift ;;
    --work) [ $# -ge 2 ] || { echo "ERROR: --work requiere un directorio" >&2; exit 1; }; WORK="$2"; shift 2 ;;
    --out=*) OUT="${1#--out=}"; [ -n "$OUT" ] || { echo "ERROR: --out requiere DIR" >&2; exit 1; }; shift ;;
    --out) [ $# -ge 2 ] || { echo "ERROR: --out requiere un directorio (usa --out DIR)" >&2; exit 1; }; OUT="$2"; shift 2 ;;
    -h|--help)
      echo "Uso: $0 [--check] [--stage-only] [--out DIR] [--skip-apps]"
      echo "  --check: solo lectura. --stage-only: solo estagia en DIR (defecto /tmp/nimbus-stage)."
      echo "  --work DIR: directorio de trabajo de mkarchiso (defecto /tmp/nimbus-work)."
      exit 0 ;;
    *) echo "ERROR: flag desconocido: $1 (ver --help)" >&2; exit 1 ;;
  esac
done

fail=0
need() { # need <fichero> <descripción>
  if [ -e "$1" ]; then
    echo "OK: $2 ($1)"
  else
    echo "ERROR: falta $2 ($1)" >&2; fail=1
  fi
}

echo "== build-iso --check de fuentes =="
need "$PROFILE/profiledef.sh" "profiledef.sh"
need "$PROFILE/packages.x86_64" "packages.x86_64"
need "$PROFILE/pacman.conf" "pacman.conf"
need "$PROFILE/airootfs/usr/local/bin/nimbus-installed-setup" "nimbus-installed-setup"
need "$PROFILE/airootfs/usr/local/bin/nimbus-bar-start" "nimbus-bar-start"
need "$PROFILE/airootfs/usr/local/bin/nimbus-hide-panel" "nimbus-hide-panel"
need "$PROFILE/airootfs/etc/skel/.config/systemd/user/nimbus-bar.service" "unidad nimbus-bar"
need "$PROFILE/airootfs/etc/skel/.config/autostart/nimbus-bar.desktop" "autostart nimbus-bar"
need "$CALAMARES/settings.conf" "settings Calamares"
need "$CALAMARES/branding/nimbus/branding.desc" "branding Calamares"
need "$CALAMARES/groups-nimbus.json" "grupos netinstall"
need "$CALAMARES/modules/shellprocess-nimbus.conf" "módulo shellprocess-nimbus"
need "$REPO_ROOT/dotfiles/.config/plasma/kdeglobals" "dotfiles plasma"
need "$REPO_ROOT/dotfiles/.config/kdeglobals" "dotfiles kdeglobals efectivo (KDE lee ~/.config/kdeglobals)"
need "$REPO_ROOT/dotfiles/.config/kwinrc" "dotfiles kwinrc efectivo (KWin lee ~/.config/kwinrc)"
need "$REPO_ROOT/dotfiles/.config/autostart/nimbus-hide-panel.desktop" "autostart panel Nimbus"
need "$REPO_ROOT/scripts/nimbus-theme" "script nimbus-theme"
need "$REPO_ROOT/scripts/nimbus-privacy" "script nimbus-privacy"
need "$REPO_ROOT/scripts/nimbus-flatpak-perms" "script nimbus-flatpak-perms"
need "$REPO_ROOT/scripts/apply-theme" "script apply-theme"
need "$REPO_ROOT/packages/themes/nimbus-tahoe/kdeglobals" "tema nimbus-tahoe"
need "$REPO_ROOT/packages/themes/nimbus-tokens/tokens.json" "tokens Nimbus"
need "$REPO_ROOT/packages/themes/klassy-preset/nimbus-tahoe.klpw" "preset klassy"
need "$REPO_ROOT/packages/themes/sddm-nimbus/Main.qml" "tema sddm-nimbus"
need "$REPO_ROOT/packages/kwin/scripts/nimbus-spotlight/metadata.json" "KWin script spotlight"
need "$REPO_ROOT/packages/kwin/decoration/nimbus-decoration/klassy-hover-plus.patch" "parche klassy-hover-plus"
need "$REPO_ROOT/packages/shell/nimbus-bar/CMakeLists.txt" "fuente nimbus-bar"
need "$REPO_ROOT/apps/nimbus-apps/CMakeLists.txt" "fuente nimbus-apps"
need "$REPO_ROOT/apps/nimbus-about/CMakeLists.txt" "fuente nimbus-about"
need "$REPO_ROOT/apps/nimbus-clock/CMakeLists.txt" "fuente nimbus-clock"
need "$REPO_ROOT/apps/nimbus-help/CMakeLists.txt" "fuente nimbus-help"
need "$REPO_ROOT/apps/nimbus-spotlight/CMakeLists.txt" "fuente nimbus-spotlight"
need "$REPO_ROOT/packages/kcm/kcm_nimbus/CMakeLists.txt" "fuente KCM Nimbus (F8)"
# Coherencia: shellprocess debe invocar lo estagiado.
if grep -q '/usr/local/bin/nimbus-installed-setup' "$CALAMARES/modules/shellprocess-nimbus.conf" 2>/dev/null; then
  echo "OK: shellprocess invoca /usr/local/bin/nimbus-installed-setup"
else
  echo "ERROR: shellprocess-nimbus.conf no invoca nimbus-installed-setup" >&2; fail=1
fi
if [ "$fail" -ne 0 ]; then echo "ERROR: --check falló (ver faltas arriba)" >&2; exit 1; fi
echo "== --check OK =="
[ "$CHECK" -eq 1 ] && exit 0

echo "== staging en $OUT =="
rm -rf "$OUT"
mkdir -p "$OUT" || { echo "ERROR: no se puede crear $OUT" >&2; exit 1; }
cp -a "$PROFILE/." "$OUT/" || { echo "ERROR: no se pudo copiar el perfil a $OUT" >&2; exit 1; }

# 1. Calamares -> airootfs/usr/share/nimbus/calamares/ (el paquete
# cachyos-calamares instala /etc/calamares; el wrapper lo superpone al
# lanzar el instalador, evitando conflictos de pacstrap).
mkdir -p "$OUT/airootfs/usr/share/nimbus/calamares/modules"
cp -a "$CALAMARES/settings.conf" "$CALAMARES/groups-nimbus.json" "$OUT/airootfs/usr/share/nimbus/calamares/" || exit 1
cp -a "$CALAMARES/branding" "$OUT/airootfs/usr/share/nimbus/calamares/" || exit 1
mkdir -p "$OUT/airootfs/usr/share/nimbus/calamares/scripts"
cp -a "$CALAMARES/scripts/." "$OUT/airootfs/usr/share/nimbus/calamares/scripts/" || exit 1
chmod 755 "$OUT/airootfs/usr/share/nimbus/calamares/scripts/"*.sh "$OUT/airootfs/usr/share/nimbus/calamares/scripts/pacstrap_calamares" 2>/dev/null || true
cp -a "$CALAMARES"/modules/*.conf "$OUT/airootfs/usr/share/nimbus/calamares/modules/" || exit 1
echo "OK: calamares estagiado ($(ls "$OUT/airootfs/usr/share/nimbus/calamares/modules" | wc -l) módulos)"

# 2. dotfiles/ -> airootfs/etc/skel/ (solo .config y .icons; excluye legacy/hyprland).
mkdir -p "$OUT/airootfs/etc/skel"
if [ -d "$REPO_ROOT/dotfiles/.config" ]; then
  cp -a "$REPO_ROOT/dotfiles/.config" "$OUT/airootfs/etc/skel/" || exit 1
fi
if [ -d "$REPO_ROOT/dotfiles/.icons" ]; then
  cp -a "$REPO_ROOT/dotfiles/.icons" "$OUT/airootfs/etc/skel/" || exit 1
fi
# .local no existe en dotfiles (los wrappers viven en scripts/); no se inventa.
rm -rf "$OUT/airootfs/etc/skel/.config/hypr" "$OUT/airootfs/etc/skel/legacy" 2>/dev/null || true
echo "OK: skel estagiado ($(cd "$OUT/airootfs/etc/skel" && find . -type f | wc -l) ficheros)"

# 3. Scripts -> airootfs/usr/local/bin/.
mkdir -p "$OUT/airootfs/usr/local/bin"
for s in nimbus-theme nimbus-privacy nimbus-flatpak-perms apply-theme \
         nimbus-updates nimbus-layout nimbus-a11y nimbus-bar-preset \
         nimbus-keys; do
  cp -a "$REPO_ROOT/scripts/$s" "$OUT/airootfs/usr/local/bin/$s" || exit 1
  chmod 755 "$OUT/airootfs/usr/local/bin/$s" || exit 1
done
for tool in apps/nimbus-hw/nimbus-hw apps/backup/nimbus-backup \
            apps/nimbus-migrate/nimbus-migrate-hyprland apps/nimbus-migrate/nimbus-migrate-desktop; do
  [ -f "$REPO_ROOT/$tool" ] || { echo "ERROR: falta $tool" >&2; exit 1; }
  install -m 0755 "$REPO_ROOT/$tool" "$OUT/airootfs/usr/local/bin/$(basename "$tool")" || exit 1
done
chmod 755 "$OUT/airootfs/usr/local/bin/nimbus-installed-setup" || exit 1
echo "OK: scripts en /usr/local/bin"

# 4. Temas y KWin scripts.
mkdir -p "$OUT/airootfs/usr/share/nimbus/themes" "$OUT/airootfs/usr/share/nimbus/klassy" \
         "$OUT/airootfs/usr/share/sddm/themes" "$OUT/airootfs/usr/share/kwin/scripts"
cp -a "$REPO_ROOT/packages/themes/nimbus-tahoe" "$OUT/airootfs/usr/share/nimbus/themes/" || exit 1
cp -a "$REPO_ROOT/packages/themes/nimbus-tokens" "$OUT/airootfs/usr/share/nimbus/tokens" || exit 1
cp -a "$REPO_ROOT/packages/themes/klassy-preset/nimbus-tahoe.klpw" "$OUT/airootfs/usr/share/nimbus/klassy/" || exit 1
cp -a "$REPO_ROOT/packages/kwin/decoration/nimbus-decoration/klassy-hover-plus.patch" "$OUT/airootfs/usr/share/nimbus/klassy/" || exit 1
cp -a "$REPO_ROOT/packages/themes/sddm-nimbus" "$OUT/airootfs/usr/share/sddm/themes/nimbus" || exit 1
cp -a "$REPO_ROOT/packages/kwin/scripts"/nimbus-spotlight "$OUT/airootfs/usr/share/kwin/scripts/" || exit 1
cp -a "$REPO_ROOT/packages/kwin/scripts"/nimbus-apps-toggle "$OUT/airootfs/usr/share/kwin/scripts/" || exit 1
cp -a "$REPO_ROOT/packages/kwin/scripts"/nimbus-zoom "$OUT/airootfs/usr/share/kwin/scripts/" || exit 1
cp -a "$REPO_ROOT/packages/kwin/scripts"/nimbus-tabs "$OUT/airootfs/usr/share/kwin/scripts/" || exit 1
cp -a "$REPO_ROOT/packages/kwin/scripts"/nimbus-mc "$OUT/airootfs/usr/share/kwin/scripts/" || exit 1
# Activación DBus de las apps residentes (F6/F7): el atajo abre el servicio.
mkdir -p "$OUT/airootfs/usr/share/dbus-1/services"
cp -a "$REPO_ROOT/packages/dbus/." "$OUT/airootfs/usr/share/dbus-1/services/" || exit 1
# Presets/pins de la barra y arte propio (instalados: /usr/share/nimbus).
mkdir -p "$OUT/airootfs/usr/share/nimbus/bar" "$OUT/airootfs/usr/share/nimbus/systemd/user"
cp -a "$REPO_ROOT/dotfiles/.config/systemd/user/." "$OUT/airootfs/usr/share/nimbus/systemd/user/" || exit 1
cp -a "$REPO_ROOT/packages/shell/nimbus-bar/presets" "$OUT/airootfs/usr/share/nimbus/bar/" || exit 1
cp -a "$REPO_ROOT/packages/shell/nimbus-bar/pins.txt" "$OUT/airootfs/usr/share/nimbus/bar/" || exit 1
cp -a "$REPO_ROOT/assets" "$OUT/airootfs/usr/share/nimbus/assets" || exit 1
# Esquemas de color del sistema: el skel referencia NimbusTahoe y debe existir
# en /usr/share/color-schemes para cualquier usuario (no solo el live).
mkdir -p "$OUT/airootfs/usr/share/color-schemes"
cp -a "$REPO_ROOT/packages/themes/nimbus-tahoe/colorschemes/." "$OUT/airootfs/usr/share/color-schemes/" || exit 1
cp -a "$REPO_ROOT/packages/themes/nimbus-tokens/colors/NimbusHighContrast.colors" "$OUT/airootfs/usr/share/color-schemes/" || exit 1
mkdir -p "$OUT/airootfs/usr/share/nimbus/dock"
cp -a "$REPO_ROOT/packages/dock/kremarc-nimbus" "$OUT/airootfs/usr/share/nimbus/dock/" || exit 1
echo "OK: temas y KWin scripts estagiados"
# R-CALAMARES-BOOST: libs 1.91 para cachyos-calamares (repo sirve 1.92).
if [ -f "$REPO_ROOT/iso/compat/boost191.tar.gz" ]; then
  # No pisar /usr/lib (pacstrap instala boost-libs 1.92 y daría conflicto):
  # las libs viven en una ruta privada y el wrapper fija LD_LIBRARY_PATH.
  mkdir -p "$OUT/airootfs/usr/share/nimbus/compat"
  tar -xzf "$REPO_ROOT/iso/compat/boost191.tar.gz" \
      -C "$OUT/airootfs/usr/share/nimbus/compat" || {
    echo "ERROR: no se pudo extraer boost191" >&2; exit 1; }
  [ -f "$OUT/airootfs/usr/share/nimbus/compat/usr/lib/libboost_python314.so.1.91.0" ] || {
    echo "ERROR: falta libboost_python314 1.91 en staging" >&2; exit 1; }
  echo "OK: compat boost191 (Calamares)"
fi
# Klassy precompilado (AUR) para decoración 1:1; instalado por
# nimbus-installed-setup (no depende de AUR en el usuario final).
mkdir -p "$OUT/airootfs/usr/share/nimbus/pkgs"
cp "$REPO_ROOT/iso/compat/klassy-nimbus-"*.pkg.tar.zst "$OUT/airootfs/usr/share/nimbus/pkgs/" \
  || { echo "ERROR: falta paquete klassy-nimbus" >&2; exit 1; }
echo "OK: klassy-nimbus empaquetado"
if ls "$REPO_ROOT/iso/compat/krema-"*.pkg.tar.zst >/dev/null 2>&1; then
  cp "$REPO_ROOT/iso/compat/krema-"*.pkg.tar.zst "$OUT/airootfs/usr/share/nimbus/pkgs/" || exit 1
  echo "OK: krema empaquetado"
else
  echo "AVISO: sin paquete krema (Dock no se instalará)"
fi

# 5. Apps: cmake+ninja con DESTDIR=staging a /usr/local.
if [ "$SKIP_APPS" -eq 1 ]; then
  echo "SKIP: compilación de apps omitida (--skip-apps); el live no traerá nimbus-bar/apps/spotlight"
else
    for app in "packages/shell/nimbus-bar" "apps/nimbus-apps" "apps/nimbus-spotlight" "apps/nimbus-about" "apps/nimbus-clock" "apps/nimbus-help" "apps/nimbus-missioncontrol" "apps/nimbus-welcome"; do
    name="$(basename "$app")"
    builddir="/tmp/nimbus-build-$name"
    rm -rf "$builddir"; mkdir -p "$builddir" || exit 1
    if ! cmake -S "$REPO_ROOT/$app" -B "$builddir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_INSTALL_PREFIX=/usr/local >/tmp/nimbus-cmake-"$name".log 2>&1; then
      echo "ERROR: cmake de $name falló (falta Qt6/KF6/LayerShellQt?). Ver /tmp/nimbus-cmake-$name.log" >&2
      echo "Reintenta con --skip-apps (documenta el SKIP) o instala las deps de build en la VM." >&2
      exit 1
    fi
    if ! cmake --build "$builddir" >>/tmp/nimbus-cmake-"$name".log 2>&1; then
      echo "ERROR: build de $name falló. Ver /tmp/nimbus-cmake-$name.log" >&2; exit 1
    fi
    if ! DESTDIR="$OUT/airootfs" cmake --install "$builddir" >>/tmp/nimbus-cmake-"$name".log 2>&1; then
      echo "ERROR: install de $name falló. Ver /tmp/nimbus-cmake-$name.log" >&2; exit 1
    fi
    echo "OK: $name construido e instalado en staging (/usr/local)"
  done
fi

# 5b. KCM Nimbus (F8): plugin de Sistema, instala en /usr (rutas KDE).
kcm_build="/tmp/nimbus-build-kcm"
rm -rf "$kcm_build"; mkdir -p "$kcm_build" || exit 1
if ! cmake -S "$REPO_ROOT/packages/kcm/kcm_nimbus" -B "$kcm_build" -G Ninja \
     -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/tmp/nimbus-cmake-kcm.log 2>&1; then
  echo "ERROR: cmake del KCM Nimbus falló (¿KF6KCMUtils?). Ver /tmp/nimbus-cmake-kcm.log" >&2
  exit 1
fi
if ! cmake --build "$kcm_build" -j"$(nproc)" >>/tmp/nimbus-cmake-kcm.log 2>&1; then
  echo "ERROR: build del KCM Nimbus falló. Ver /tmp/nimbus-cmake-kcm.log" >&2; exit 1
fi
if ! DESTDIR="$OUT/airootfs" cmake --install "$kcm_build" >>/tmp/nimbus-cmake-kcm.log 2>&1; then
  echo "ERROR: install del KCM Nimbus falló. Ver /tmp/nimbus-cmake-kcm.log" >&2; exit 1
fi
echo "OK: KCM Nimbus construido e instalado (/usr)"

# 6. Verificación del staging antes de mkarchiso.
for f in \
  "$OUT/airootfs/usr/local/bin/nimbus-installed-setup" \
  "$OUT/airootfs/usr/local/bin/nimbus-bar-start" \
  "$OUT/airootfs/etc/skel/.config/systemd/user/nimbus-bar.service" \
  "$OUT/airootfs/etc/skel/.config/autostart/nimbus-bar.desktop" \
  "$OUT/airootfs/usr/share/nimbus/calamares/settings.conf" \
  "$OUT/airootfs/usr/share/nimbus/calamares/groups-nimbus.json" \
  "$OUT/airootfs/usr/share/nimbus/calamares/branding/nimbus/branding.desc" \
  "$OUT/airootfs/etc/skel/.config/plasma/kdeglobals" \
  "$OUT/airootfs/etc/skel/.config/kdeglobals" \
  "$OUT/airootfs/etc/skel/.config/kwinrc" \
  "$OUT/airootfs/etc/skel/.config/autostart/nimbus-hide-panel.desktop" \
  "$OUT/airootfs/usr/local/bin/nimbus-theme" \
  "$OUT/airootfs/usr/share/sddm/themes/nimbus/Main.qml" \
  "$OUT/airootfs/usr/share/nimbus/klassy/nimbus-tahoe.klpw" \
  "$OUT/airootfs/usr/share/nimbus/compat/usr/lib/libboost_python314.so.1.91.0" \
  "$OUT/airootfs/usr/share/nimbus/pkgs/klassy-nimbus-6.7.3-1-x86_64.pkg.tar.zst" \
  "$OUT/airootfs/usr/share/kwin/scripts/nimbus-spotlight/metadata.json" \
  "$OUT/airootfs/usr/share/color-schemes/NimbusTahoe.colors" \
  "$OUT/airootfs/usr/share/nimbus/bar/pins.txt" \
  "$OUT/airootfs/usr/share/nimbus/dock/kremarc-nimbus" \
  "$OUT/airootfs/usr/share/nimbus/bar/presets/default.json" \
  "$OUT/airootfs/usr/share/nimbus/assets/sequoia-dark.jpg" \
  "$OUT/airootfs/usr/local/bin/nimbus-keys" \
  "$OUT/airootfs/usr/share/dbus-1/services/org.nimbus.Spotlight.service" \
  "$OUT/airootfs/usr/share/dbus-1/services/org.nimbus.MissionControl.service" \
  "$OUT/airootfs/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_nimbus.so" \
  "$OUT/airootfs/usr/share/applications/kcm_nimbus.desktop" \
  ; do
  [ -f "$f" ] || { echo "ERROR: falta en staging: $f" >&2; exit 1; }
done
# KWin lee ~/.config/kwinrc: el efectivo debe llegar al skel idéntico al
# canónico plasma/kwinrc (evita el FAIL kwin.scripts de la aceptación).
cmp -s "$OUT/airootfs/etc/skel/.config/kwinrc" "$OUT/airootfs/etc/skel/.config/plasma/kwinrc" \
  || { echo "ERROR: kwinrc efectivo y plasma/kwinrc divergen en staging" >&2; exit 1; }
# KDE lee ~/.config/kdeglobals: debe ser idéntico al canónico plasma.
cmp -s "$OUT/airootfs/etc/skel/.config/kdeglobals" "$OUT/airootfs/etc/skel/.config/plasma/kdeglobals" \
  || { echo "ERROR: kdeglobals efectivo y plasma/kdeglobals divergen en staging" >&2; exit 1; }
grep -q '^Exec=/usr/local/bin/nimbus-hide-panel' \
  "$OUT/airootfs/etc/skel/.config/autostart/nimbus-hide-panel.desktop" \
  || { echo "ERROR: autostart nimbus-hide-panel sin Exec correcto" >&2; exit 1; }
if [ "$SKIP_APPS" -eq 0 ]; then
  for b in nimbus-bar nimbus-apps nimbus-spotlight nimbus-about nimbus-clock nimbus-help nimbus-missioncontrol nimbus-welcome; do
    [ -x "$OUT/airootfs/usr/local/bin/$b" ] || { echo "ERROR: falta binario $b en staging" >&2; exit 1; }
  done
fi
bash -n "$OUT/airootfs/usr/local/bin/nimbus-installed-setup" || { echo "ERROR: nimbus-installed-setup no pasa bash -n" >&2; exit 1; }
# El staging debe llevar el pacstrap con DNS/mirrors (evita copias 9p viejas).
grep -q 'getent ahostsv4' "$OUT/airootfs/usr/share/nimbus/calamares/scripts/pacstrap_calamares" \
  || { echo "ERROR: pacstrap_calamares del staging no tiene el bypass DNS" >&2; exit 1; }
grep -q 'target usa solo Arch' "$OUT/airootfs/usr/share/nimbus/calamares/scripts/pacstrap_calamares" \
  || { echo "ERROR: pacstrap_calamares del staging no tiene mirrors curados" >&2; exit 1; }
echo "== staging OK en $OUT =="
[ "$STAGE_ONLY" -eq 1 ] && exit 0

# 7. Build real: exige root + mkarchiso (solo en VM).
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: el build ISO exige root (usa --stage-only sin root). Reintenta en la VM." >&2; exit 1
fi
command -v mkarchiso >/dev/null 2>&1 || { echo "ERROR: falta mkarchiso (paquete archiso)" >&2; exit 1; }
ISO_OUT="${OUT}/out"
mkdir -p "$ISO_OUT"
mkdir -p "$WORK"
# mkarchiso cachea ${buildmode}.pacman.conf con _run_once; si el perfil cambia
# (p.ej. repos/Architecture) hay que invalidar el sello o reutiliza el viejo.
rm -f "$WORK/iso.pacman.conf" "$WORK/iso._make_pacman_conf" \
      "$WORK/netboot.pacman.conf" "$WORK/netboot._make_pacman_conf"
mkarchiso -v -w "$WORK" -o "$ISO_OUT" "$OUT" || { echo "ERROR: mkarchiso falló" >&2; exit 1; }
sha256sum "$ISO_OUT"/*.iso | tee "$ISO_OUT/SHA256SUMS"
echo "== ISO lista en $ISO_OUT =="
