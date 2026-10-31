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
need "$CALAMARES/settings.conf" "settings Calamares"
need "$CALAMARES/branding.desc" "branding Calamares"
need "$CALAMARES/groups-nimbus.json" "grupos netinstall"
need "$CALAMARES/modules/shellprocess-nimbus.conf" "módulo shellprocess-nimbus"
need "$REPO_ROOT/dotfiles/.config/plasma/kdeglobals" "dotfiles plasma"
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
need "$REPO_ROOT/apps/nimbus-spotlight/CMakeLists.txt" "fuente nimbus-spotlight"
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

# 1. Calamares -> airootfs/etc/calamares/ (settings, modules, branding, groups; README no).
mkdir -p "$OUT/airootfs/etc/calamares/modules"
cp -a "$CALAMARES/settings.conf" "$CALAMARES/branding.desc" "$CALAMARES/groups-nimbus.json" "$OUT/airootfs/etc/calamares/" || exit 1
cp -a "$CALAMARES"/modules/*.conf "$OUT/airootfs/etc/calamares/modules/" || exit 1
echo "OK: calamares estagiado ($(ls "$OUT/airootfs/etc/calamares/modules" | wc -l) módulos)"

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
for s in nimbus-theme nimbus-privacy nimbus-flatpak-perms apply-theme; do
  cp -a "$REPO_ROOT/scripts/$s" "$OUT/airootfs/usr/local/bin/$s" || exit 1
  chmod 755 "$OUT/airootfs/usr/local/bin/$s" || exit 1
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
echo "OK: temas y KWin scripts estagiados"

# 5. Apps: cmake+ninja con DESTDIR=staging a /usr/local.
if [ "$SKIP_APPS" -eq 1 ]; then
  echo "SKIP: compilación de apps omitida (--skip-apps); el live no traerá nimbus-bar/apps/spotlight"
else
  for app in "packages/shell/nimbus-bar" "apps/nimbus-apps" "apps/nimbus-spotlight"; do
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

# 6. Verificación del staging antes de mkarchiso.
for f in \
  "$OUT/airootfs/usr/local/bin/nimbus-installed-setup" \
  "$OUT/airootfs/etc/calamares/settings.conf" \
  "$OUT/airootfs/etc/calamares/groups-nimbus.json" \
  "$OUT/airootfs/etc/skel/.config/plasma/kdeglobals" \
  "$OUT/airootfs/usr/local/bin/nimbus-theme" \
  "$OUT/airootfs/usr/share/sddm/themes/nimbus/Main.qml" \
  "$OUT/airootfs/usr/share/nimbus/klassy/nimbus-tahoe.klpw" \
  "$OUT/airootfs/usr/share/kwin/scripts/nimbus-spotlight/metadata.json" \
  ; do
  [ -f "$f" ] || { echo "ERROR: falta en staging: $f" >&2; exit 1; }
done
if [ "$SKIP_APPS" -eq 0 ]; then
  for b in nimbus-bar nimbus-apps nimbus-spotlight; do
    [ -x "$OUT/airootfs/usr/local/bin/$b" ] || { echo "ERROR: falta binario $b en staging" >&2; exit 1; }
  done
fi
bash -n "$OUT/airootfs/usr/local/bin/nimbus-installed-setup" || { echo "ERROR: nimbus-installed-setup no pasa bash -n" >&2; exit 1; }
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
mkarchiso -v -w "$WORK" -o "$ISO_OUT" "$OUT" || { echo "ERROR: mkarchiso falló" >&2; exit 1; }
sha256sum "$ISO_OUT"/*.iso | tee "$ISO_OUT/SHA256SUMS"
echo "== ISO lista en $ISO_OUT =="
