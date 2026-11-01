#!/usr/bin/env bash
# F8-T02/T04/T05 — Tests de páginas reales del KCM (sin VM, sin root).
# Ejercita save_probe (load/save/defaults C++ reales), un HOME temporal
# POR ESCENARIO, y verifica los canales con kreadconfig6/grep.
# NUNCA toca el host.
#
# Uso: bash tests/kcm/test-pages.sh [--probe /tmp/nimbus-probe-build/save_probe]
set -u

PROBE="/tmp/nimbus-probe-build/save_probe"
for ((i=1; i<=$#; i++)); do
  case "${!i}" in
    --probe) j=$((i+1)); PROBE="${!j}" ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); echo "  ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FALLO: $1 (esperado [$2], obtenido [$3])"; }
check_eq() { # <desc> <esperado> <obtenido>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi
}

if [ ! -x "$PROBE" ]; then
  echo "ERROR: falta $PROBE (compila tests/kcm/probe en /tmp primero)" >&2
  exit 1
fi

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-pages-XXXXXX)"
chmod 700 "$BASE_TMP"
RUNTIME_DIR="$BASE_TMP/runtime"; mkdir -p "$RUNTIME_DIR"; chmod 700 "$RUNTIME_DIR"
cleanup() { rm -rf "$BASE_TMP" || echo "WARN: no se pudo borrar $BASE_TMP" >&2; }
trap cleanup EXIT INT TERM

# Un escenario = un HOME virgen (si no, defaults pisaría lo anterior).
# FAKE_BIN (exportado): dir con fakes que precede al PATH interno.
# FAKE_PATH_OVERRIDE (exportado): sustituye el PATH interno por completo
# (para simular herramientas ausentes). El resto de FAKE_* se propaga.
run_scenario() { # <nombre> <scenario-arg>
  local name="$1" arg="$2"
  local nh="$BASE_TMP/home-$name"
  mkdir -p "$nh/.config" "$nh/.local/share" "$BASE_TMP/cache-$name" "$BASE_TMP/sys-$name"
  dbus-run-session -- bash -c '
set -u
export HOME="'"$nh"'" XDG_CONFIG_HOME="'"$nh"'/.config" XDG_DATA_HOME="'"$nh"'/.local/share"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache-'"$name"'" XDG_CONFIG_DIRS="'"$BASE_TMP"'/sys-'"$name"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'"
export FAKE_LOG="'"$BASE_TMP"'/fake-'"$name"'" FAKE_BT_DIR="'"$REPO_ROOT"'/tests/kcm/fakes/bt-state"
export FAKE_BT_FAIL="${FAKE_BT_FAIL:-}" FAKE_PKEXEC_RC="${FAKE_PKEXEC_RC:-0}" FAKE_LP_RC="${FAKE_LP_RC:-0}"
export FAKE_BIN="'"${FAKE_BIN:-}"'" FAKE_PATH_OVERRIDE="'"${FAKE_PATH_OVERRIDE:-}"'"
mkdir -p "$FAKE_LOG"
if [ -n "$FAKE_PATH_OVERRIDE" ]; then
  export PATH="$FAKE_PATH_OVERRIDE"
else
  export PATH="'"$REPO_ROOT"'/scripts${FAKE_BIN:+:$FAKE_BIN}:$PATH"
fi
"'"$PROBE"'" "'"$arg"'" >"'"$BASE_TMP"'/'"$name"'.dump" 2>/dev/null
' >/dev/null 2>&1
}

dump_get() { # <nombre> <clave>
  grep "^$2=" "$BASE_TMP/$1.dump" 2>/dev/null | cut -d= -f2-
}

cfg() { # <home> <resto de args de kreadconfig6>
  local home="$1"; shift
  XDG_CONFIG_HOME="$home/.config" kreadconfig6 "$@" 2>/dev/null
}

echo "[pages] escenarios en $BASE_TMP"

echo "== Apariencia =="
run_scenario appearance appearance
H="$BASE_TMP/home-appearance"
check_eq "kdeglobals ColorScheme light" "BreezeLight" "$(cfg "$H" --file kdeglobals --group General --key ColorScheme)"
check_eq "kdeglobals LookAndFeel light" "org.kde.breeze.desktop" "$(cfg "$H" --file kdeglobals --group KDE --key LookAndFeelPackage)"
check_eq "nimbusrc Wallpaper" "/tmp/nimbus-wall.jpg" "$(cfg "$H" --file nimbusrc --group Appearance --key Wallpaper)"
check_eq "kremarc IconSize" "64" "$(cfg "$H" --file kremarc --group General --key IconSize)"
check_eq "kremarc MaxZoomFactor" "1.2" "$(cfg "$H" --file kremarc --group General --key MaxZoomFactor)"
check_eq "kremarc VisibilityMode autohide" "1" "$(cfg "$H" --file kremarc --group General --key VisibilityMode)"
check_eq "dump animationSpeed pedido" "2" "$(dump_get appearance animationSpeed)"
check_eq "dump darkMode off" "false" "$(dump_get appearance darkMode)"
check_eq "dump accent" "#FF9500" "$(dump_get appearance accentColor)"

echo "== Accesibilidad =="
run_scenario a11y a11y
H="$BASE_TMP/home-a11y"
check_eq "kwinrc zoomEnabled" "true" "$(cfg "$H" --file kwinrc --group Plugins --key zoomEnabled)"
check_eq "kwinrc invertEnabled" "true" "$(cfg "$H" --file kwinrc --group Plugins --key invertEnabled)"
check_eq "kwinrc blurEnabled off" "false" "$(cfg "$H" --file kwinrc --group Plugins --key blurEnabled)"
check_eq "kwinrc AnimationSpeed reduce-motion" "0" "$(cfg "$H" --file kwinrc --group Compositing --key AnimationSpeed)"
check_eq "kcminputrc RepeatDelay" "300" "$(cfg "$H" --file kcminputrc --group Keyboard --key RepeatDelay)"
check_eq "kcminputrc RepeatRate" "30" "$(cfg "$H" --file kcminputrc --group Keyboard --key RepeatRate)"
check_eq "kaccessrc ScreenReader Enabled" "true" "$(cfg "$H" --file kaccessrc --group ScreenReader --key Enabled)"
echo "  nota: gsettings/dconf no persiste en sandbox (ver evidencia); el canal fichero kaccessrc sí."

echo "== Atajos (nimbus-keys real) =="
run_scenario shortcuts-ctrl shortcuts-ctrl
CTRL_CLOSE="$(cfg "$BASE_TMP/home-shortcuts-ctrl" --file kglobalshortcutsrc --group kwin --key Window\ Close)"
case "$CTRL_CLOSE" in *Ctrl*) ok "modo ctrl escribe ($CTRL_CLOSE)";; *) bad "modo ctrl" "…Ctrl…" "$CTRL_CLOSE";; esac
run_scenario shortcuts-meta shortcuts-meta
META_CLOSE="$(cfg "$BASE_TMP/home-shortcuts-meta" --file kglobalshortcutsrc --group kwin --key Window\ Close)"
case "$META_CLOSE" in *Meta*) ok "modo meta escribe ($META_CLOSE)";; *) bad "modo meta" "…Meta…" "$META_CLOSE";; esac

echo "== Defaults (Reset canónico) =="
run_scenario defaults defaults
check_eq "defaults darkMode" "true" "$(dump_get defaults darkMode)"
check_eq "defaults accent" "#0A84FF" "$(dump_get defaults accentColor)"
check_eq "defaults dock" "48" "$(dump_get defaults dockIconSize)"
check_eq "defaults anim" "3" "$(dump_get defaults animationSpeed)"
check_eq "defaults cmdMode meta" "true" "$(dump_get defaults cmdMode)"
check_eq "defaults zoom off" "false" "$(dump_get defaults zoomEnabled)"

echo "== Red (solo lectura; sin tocar radios del host) =="
run_scenario network network
check_eq "wifiAvailable" "true" "$(dump_get network wifiAvailable)"
check_eq "wifiEnabled" "true" "$(dump_get network wifiEnabled)"
WCOUNT="$(dump_get network wifiCount)"
case "$WCOUNT" in ''|*[!0-9]*) bad "wifiCount numérico" ">=1" "$WCOUNT";; *)
  if [ "$WCOUNT" -ge 1 ]; then ok "wifiCount=$WCOUNT redes"; else bad "wifiCount" ">=1" "$WCOUNT"; fi;; esac
check_eq "bluetoothAvailable" "true" "$(dump_get network bluetoothAvailable)"
check_eq "printingAvailable (sin CUPS aquí)" "false" "$(dump_get network printingAvailable)"

echo "== Sistema (lecturas + energía reversible) =="
run_scenario system system
UCOUNT="$(dump_get system userCount)"
case "$UCOUNT" in ''|*[!0-9]*) bad "userCount numérico" ">=1" "$UCOUNT";; *)
  if [ "$UCOUNT" -ge 1 ]; then ok "userCount=$UCOUNT"; else bad "userCount" ">=1" "$UCOUNT"; fi;; esac
check_eq "currentUser" "$USER" "$(dump_get system currentUser)"
[ -n "$(dump_get system hostName)" ] && ok "hostName: $(dump_get system hostName)" || bad "hostName" "no vacío" ""
[ -n "$(dump_get system timeZone)" ] && ok "timeZone: $(dump_get system timeZone)" || bad "timeZone" "no vacío" ""
[ -n "$(dump_get system systemLocale)" ] && ok "systemLocale: $(dump_get system systemLocale)" || bad "systemLocale" "no vacío" ""
EPROFS="$(dump_get system energyProfiles)"
case "$EPROFS" in *balanced*) ok "energyProfiles: $EPROFS";; *) bad "energyProfiles" "…balanced…" "$EPROFS";; esac
[ -n "$(dump_get system energyRoundtrip)" ] && ok "energyRoundtrip: $(dump_get system energyRoundtrip) (restaurado)" || bad "energyRoundtrip" "no vacío" ""

echo "== Updates (checkupdates real) =="
run_scenario updates updates
check_eq "updatesAvailable" "true" "$(dump_get updates updatesAvailable)"
UC="$(dump_get updates updatesCount)"; SHOWN="$(dump_get updates updatesShown)"
case "$UC" in ''|*[!0-9]*) bad "updatesCount numérico" ">=0" "$UC";; *)
  if [ "$UC" -ge 0 ] && [ "$SHOWN" -le 15 ]; then ok "updatesCount=$UC shown=$SHOWN";
  else bad "updatesCount/shown" ">=0/<=15" "$UC/$SHOWN"; fi;; esac

echo "== Programación diaria (ficheros en HOME temporal) =="
run_scenario schedule schedule-on
SCH="$BASE_TMP/home-schedule"
if [ -f "$SCH/.config/systemd/user/nimbus-updates-check.timer" ] && [ -f "$SCH/.config/systemd/user/nimbus-updates-check.service" ]; then
  ok "timer+service escritos en HOME temporal"
else
  bad "timer+service" "existen" "faltan"
fi
run_scenario schedule schedule-off
check_eq "dailyCheck leído tras guardar" "true" "$(dump_get schedule dailyCheckLoaded)"
if [ ! -e "$SCH/.config/systemd/user/nimbus-updates-check.timer" ]; then
  ok "timer borrado al desactivar"
else
  bad "timer borrado" "ausente" "existe"
fi

echo "== Persistencia (save→load round-trip) =="
run_scenario persist persist
check_eq "persiste darkMode" "false" "$(dump_get persist darkMode)"
check_eq "persiste dock" "72" "$(dump_get persist dockIconSize)"
check_eq "persiste zoom" "true" "$(dump_get persist zoomEnabled)"
check_eq "persiste delay" "250" "$(dump_get persist repeatDelay)"
# nimbus-theme (en PATH) aplica su esquema tras nuestra escritura.
PSCHEME="$(cfg "$BASE_TMP/home-persist" --file kdeglobals --group General --key ColorScheme)"
case "$PSCHEME" in *Light*) ok "persiste kdeglobals ($PSCHEME)";; *) bad "persiste kdeglobals" "…Light…" "$PSCHEME";; esac

echo "== Reset Apariencia =="
run_scenario reset-appearance reset-appearance
check_eq "reset darkMode" "true" "$(dump_get reset-appearance darkMode)"
check_eq "reset accent" "#0A84FF" "$(dump_get reset-appearance accentColor)"
check_eq "reset dock" "48" "$(dump_get reset-appearance dockIconSize)"
RSCHEME="$(cfg "$BASE_TMP/home-reset-appearance" --file kdeglobals --group General --key ColorScheme)"
case "$RSCHEME" in BreezeDark|NimbusTahoe) ok "reset kdeglobals ($RSCHEME)";; *) bad "reset kdeglobals" "BreezeDark|NimbusTahoe" "$RSCHEME";; esac
check_eq "reset kremarc" "48" "$(cfg "$BASE_TMP/home-reset-appearance" --file kremarc --group General --key IconSize)"

echo "== Reset Accesibilidad (+kscreenlockerrc) =="
run_scenario reset-a11y reset-a11y
check_eq "reset zoom" "false" "$(dump_get reset-a11y zoomEnabled)"
check_eq "reset invert" "false" "$(dump_get reset-a11y invertColors)"
check_eq "reset motion" "false" "$(dump_get reset-a11y reduceMotion)"
check_eq "reset delay" "500" "$(dump_get reset-a11y repeatDelay)"
check_eq "reset kwinrc zoom" "false" "$(cfg "$BASE_TMP/home-reset-a11y" --file kwinrc --group Plugins --key zoomEnabled)"
check_eq "reset anim 3" "3" "$(cfg "$BASE_TMP/home-reset-a11y" --file kwinrc --group Compositing --key AnimationSpeed)"
check_eq "reset Autolock" "false" "$(cfg "$BASE_TMP/home-reset-a11y" --file kscreenlockerrc --group Daemon --key Autolock)"
check_eq "reset LockOnResume" "false" "$(cfg "$BASE_TMP/home-reset-a11y" --file kscreenlockerrc --group Daemon --key LockOnResume)"

echo "== Reset Atajos =="
run_scenario reset-shortcuts reset-shortcuts
check_eq "reset cmdMode" "true" "$(dump_get reset-shortcuts cmdMode)"
RSCLOSE="$(cfg "$BASE_TMP/home-reset-shortcuts" --file kglobalshortcutsrc --group kwin --key Window\ Close)"
case "$RSCLOSE" in *Meta*) ok "reset escribe Meta ($RSCLOSE)";; *) bad "reset atajos" "…Meta…" "$RSCLOSE";; esac

echo "== Reset Sistema (energía reversible) =="
run_scenario reset-system reset-system
check_eq "reset energía balanced" "balanced" "$(dump_get reset-system energyAfterReset)"

echo "== Reset Updates =="
run_scenario reset-updates reset-updates
check_eq "reset dailyCheck" "false" "$(dump_get reset-updates dailyCheck)"
if [ ! -e "$BASE_TMP/home-reset-updates/.config/systemd/user/nimbus-updates-check.timer" ]; then
  ok "reset borra timer"
else
  bad "reset timer" "ausente" "existe"
fi

echo "== Reset Red (radios encendidos, sin cambiar estado) =="
run_scenario reset-network reset-network
check_eq "reset wifi on" "true" "$(dump_get reset-network wifiEnabled)"

echo "== Backup nimbusshell-backup-* =="
BK="$(ls -d "$BASE_TMP"/home-persist/.config/nimbusshell-backup-* 2>/dev/null | head -1)"
if [ -n "$BK" ] && [ "$(ls "$BK" 2>/dev/null | wc -l)" -ge 1 ]; then
  ok "backup en HOME temporal: $(basename "$BK") ($(ls "$BK" | wc -l) ficheros)"
else
  bad "backup" "dir con ficheros" "ausente"
fi

echo "== Acciones BT/impresión/install/hostname (fakes, 0 cambios reales) =="
export FAKE_BIN="$REPO_ROOT/tests/kcm/fakes"
run_scenario bt-ok bt-ok
check_eq "bt pair" "true" "$(dump_get bt-ok pair)"
check_eq "bt connect" "true" "$(dump_get bt-ok connect)"
check_eq "bt disconnect" "true" "$(dump_get bt-ok disconnect)"
check_eq "bt lista 1 aparato" "1" "$(dump_get bt-ok btDevices)"
[ -s "$BASE_TMP/fake-bt-ok/bluetoothctl.log" ] && ok "fake bluetoothctl invocado" || bad "fake bluetoothctl" "invocado" "sin log"
export FAKE_BT_FAIL="pair"
run_scenario bt-fail bt-fail
check_eq "bt pair falla honesto" "false" "$(dump_get bt-fail pairFail)"
unset FAKE_BT_FAIL
run_scenario print-ok print-ok
check_eq "print test page" "true" "$(dump_get print-ok print)"
[ -s "$BASE_TMP/fake-print-ok/lp.log" ] && ok "fake lp invocado: $(head -1 "$BASE_TMP/fake-print-ok/lp.log")" || bad "fake lp" "invocado" "sin log"
export FAKE_PATH_OVERRIDE="$REPO_ROOT/scripts"
run_scenario print-nocups print-nocups
unset FAKE_PATH_OVERRIDE
check_eq "print sin CUPS falla honesto" "false" "$(dump_get print-nocups printNoCups)"
export FAKE_PATH_OVERRIDE="$REPO_ROOT/tests/kcm/fakes"
run_scenario install-ok install-ok
unset FAKE_PATH_OVERRIDE
check_eq "install termina" "false" "$(dump_get install-ok installing)"
check_eq "install paquete limpio" "" "$(dump_get install-ok installPkg)"
PKLOG="$(cat "$BASE_TMP/fake-install-ok/pkexec.log" 2>/dev/null | head -1)"
case "$PKLOG" in *"pacman -S --noconfirm nimbus-test-pkg"*) ok "pkexec pacman -S nimbus-test-pkg ($PKLOG)";; *) bad "pkexec args" "pacman -S --noconfirm nimbus-test-pkg" "$PKLOG";; esac
case "$(dump_get install-ok installOut)" in *fake-pkexec*) ok "salida visible en UI";; *) bad "installOutput" "…fake-pkexec…" "$(dump_get install-ok installOut)";; esac
run_scenario hostname-locale hostname-locale
check_eq "hostname sin permiso falla" "false" "$(dump_get hostname-locale setHost)"
check_eq "hostname inválido rechazado" "false" "$(dump_get hostname-locale setHostBad)"
check_eq "locale sin permiso falla" "false" "$(dump_get hostname-locale setLoc)"
check_eq "hostname intacto" "true" "$(dump_get hostname-locale hostUnchanged)"
check_eq "locale intacto" "true" "$(dump_get hostname-locale locUnchanged)"
unset FAKE_BIN

echo "== JSON del paquete =="
if python3 -c "import json,sys; json.load(open('$REPO_ROOT/packages/kcm/kcm_nimbus/package-metadata.json')); json.load(open('$REPO_ROOT/packages/kcm/kcm_nimbus/src/metadata.json'))" 2>/dev/null; then
  ok "metadata.json válidos"
else
  bad "metadata.json" "válidos" "parse error"
fi
desktop-file-validate "$REPO_ROOT/packages/kcm/kcm_nimbus/kcm_nimbus.desktop" 2>/dev/null \
  && ok "desktop válido" || bad "desktop" "válido" "fallo validate"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
