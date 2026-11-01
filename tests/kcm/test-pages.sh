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
run_scenario() { # <nombre> <scenario-arg>
  local name="$1" arg="$2"
  local nh="$BASE_TMP/home-$name"
  mkdir -p "$nh/.config" "$nh/.local/share" "$BASE_TMP/cache-$name" "$BASE_TMP/sys-$name"
  dbus-run-session -- bash -c '
set -u
export HOME="'"$nh"'" XDG_CONFIG_HOME="'"$nh"'/.config" XDG_DATA_HOME="'"$nh"'/.local/share"
export XDG_CACHE_HOME="'"$BASE_TMP"'/cache-'"$name"'" XDG_CONFIG_DIRS="'"$BASE_TMP"'/sys-'"$name"'"
export XDG_RUNTIME_DIR="'"$RUNTIME_DIR"'" PATH="'"$REPO_ROOT"'/scripts:$PATH"
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

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
