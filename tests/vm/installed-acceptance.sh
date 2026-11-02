#!/usr/bin/env bash
# installed-acceptance.sh — arnés de aceptación del sistema instalado NimbusOS.
#
# Se ejecuta DENTRO de la VM instalada, en la sesión gráfica del usuario
# (Plasma Wayland). No necesita root para las comprobaciones; `sudo` se usa
# SOLO si se pasa --mount-share (montar el 9p del host en /mnt/hostshare).
#
# No asume layout de teclado: los atajos, si se piden, se inyectan con
# ydotool por keycodes Linux (KEY_*), nunca por caracteres.
#
# Salida: $OUT/acceptance.json + $OUT/acceptance.md, y resumen por consola.
# Exit 1 si hay algún FAIL. Los SKIP no fallan.
#
# Uso:
#   bash installed-acceptance.sh [--out DIR] [--with-shortcuts]
#        [--mount-share] [--share-tag TAG]
#        [--expect-user nimbus] [--expect-host nimbusos]
#        [--root DIR]   # tests: raíz alternativa para ficheros de sistema
#
# Evidencia F2-T08: docs/plans/evidence/F2-T08-acceptance-harness.md
set -u

OUT=""
WITH_SHORTCUTS=0
MOUNT_SHARE=0
SHARE_TAG="hostshare"
EXPECT_USER="${NIMBUS_EXPECT_USER:-nimbus}"
EXPECT_HOST="${NIMBUS_EXPECT_HOST:-nimbusos}"
SYSROOT=""
RESULTS_FILE=""

usage() {
  cat <<'EOF'
Uso: installed-acceptance.sh [opciones]

  --out DIR          destino de acceptance.json/md
                     (defecto: /mnt/hostshare/e2e o $HOME/aceptacion)
  --mount-share      monta el 9p del host en /mnt/hostshare con sudo
  --share-tag TAG    tag del 9p (defecto: hostshare)
  --with-shortcuts   prueba atajos reales con ydotool + capturas spectacle
  --expect-user U    usuario esperado (defecto: nimbus; "-" = cualquiera no root)
  --expect-host H    hostname esperado (defecto: nimbusos; "-" = cualquiera)
  --root DIR         raíz alternativa para ficheros del sistema (tests)
  -h, --help         esta ayuda

Comprobaciones: sesión Wayland/Plasma, SDDM, usuario/hostname/home, skel,
paquetes Klassy/Krema, scripts KWin nimbus-*, tema/acento, panel stock y
barra, servidor de notificaciones, activación DBus de Spotlight/Apps/MC,
KCM y ydotool/grupo input. Sin tocar ~/.config: solo lectura.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[accept] %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --out)
      [ $# -ge 2 ] || die "--out necesita un directorio"
      OUT="$2"; shift 2 ;;
    --with-shortcuts) WITH_SHORTCUTS=1; shift ;;
    --mount-share) MOUNT_SHARE=1; shift ;;
    --share-tag)
      [ $# -ge 2 ] || die "--share-tag necesita un tag"
      SHARE_TAG="$2"; shift 2 ;;
    --expect-user)
      [ $# -ge 2 ] || die "--expect-user necesita un valor"
      EXPECT_USER="$2"; shift 2 ;;
    --expect-host)
      [ $# -ge 2 ] || die "--expect-host necesita un valor"
      EXPECT_HOST="$2"; shift 2 ;;
    --root)
      [ $# -ge 2 ] || die "--root necesita un directorio"
      SYSROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "flag desconocido: $1 (ver --help)" ;;
  esac
done

command -v python3 >/dev/null 2>&1 || die "falta python3 (lo usa el resumen JSON)"

syspath() { printf '%s%s' "$SYSROOT" "$1"; }

if [ "$MOUNT_SHARE" -eq 1 ]; then
  command -v sudo >/dev/null 2>&1 || die "--mount-share exige sudo instalado"
  command -v mountpoint >/dev/null 2>&1 || die "--mount-share exige mountpoint (util-linux)"
  sudo mkdir -p /mnt/hostshare || die "no se pudo crear /mnt/hostshare"
  if mountpoint -q /mnt/hostshare; then
    log "/mnt/hostshare ya está montado"
  else
    log "montando 9p '$SHARE_TAG' en /mnt/hostshare (sudo)"
    sudo mount -t 9p -o trans=virtio,version=9p2000.L,msize=104857600 \
      "$SHARE_TAG" /mnt/hostshare \
      || die "sudo mount 9p '$SHARE_TAG' falló (¿virtio-9p y tag correctos?)"
  fi
fi

if [ -z "$OUT" ]; then
  if [ -d /mnt/hostshare ] && [ -w /mnt/hostshare ]; then
    OUT="/mnt/hostshare/e2e"
  else
    OUT="$HOME/aceptacion"
  fi
fi
mkdir -p "$OUT" 2>/dev/null || die "no se puede crear OUT: $OUT"
[ -w "$OUT" ] || die "OUT no es escribible: $OUT"

RESULTS_FILE="$(mktemp "${TMPDIR:-/tmp}/nimbus-accept-XXXXXX")" \
  || die "no se pudo crear temporal de resultados"
cleanup() { rm -f "$RESULTS_FILE" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

PASS_N=0
FAIL_N=0
SKIP_N=0

add_check() { # $1=estado $2=id $3=detalle [$4=artefactos coma-separados]
  local st="$1" id="$2" detail="${3:-}" arts="${4:-}"
  detail="$(printf '%s' "$detail" | tr '\t\n' '  ')"
  printf '%s\t%s\t%s\t%s\n' "$st" "$id" "$detail" "$arts" >>"$RESULTS_FILE"
  if [ -t 1 ]; then
    case "$st" in
      PASS) printf '\033[32mPASS\033[0m %-26s %s\n' "$id" "$detail" ;;
      FAIL) printf '\033[31mFAIL\033[0m %-26s %s\n' "$id" "$detail" ;;
      *)    printf '\033[33mSKIP\033[0m %-26s %s\n' "$id" "$detail" ;;
    esac
  else
    printf '%-4s %-26s %s\n' "$st" "$id" "$detail"
  fi
  case "$st" in
    PASS) PASS_N=$((PASS_N + 1)) ;;
    FAIL) FAIL_N=$((FAIL_N + 1)) ;;
    SKIP) SKIP_N=$((SKIP_N + 1)) ;;
  esac
}

ini_get() { # $1=fichero $2=sección $3=clave
  local file="$1" sec="$2" key="$3"
  [ -f "$file" ] || return 0
  awk -v s="[$sec]" -v k="$key" '
    /^\[/ { insec = ($0 == s); next }
    insec && index($0, k "=") == 1 {
      sub(/^[^=]*=/, "");
      sub(/\r$/, "");
      print;
      exit
    }
  ' "$file" 2>/dev/null
}

cfg_get() { # $1=fichero relativo (kdeglobals/kwinrc) $2=grupo $3=clave
  local file="$1" group="$2" key="$3" path
  if command -v kreadconfig6 >/dev/null 2>&1; then
    kreadconfig6 --file "$file" --group "$group" --key "$key" 2>/dev/null | head -n 1
    return 0
  fi
  case "$file" in
    /*) path="$file" ;;
    *)  path="${XDG_CONFIG_HOME:-$HOME/.config}/$file" ;;
  esac
  ini_get "$path" "$group" "$key"
}

find_first() { # primer fichero no vacío de la lista
  local f
  for f in "$@"; do
    if [ -s "$f" ]; then printf '%s' "$f"; return 0; fi
  done
  return 1
}

find_pid() { # $1=patrón pgrep -f; imprime PIDs (puede ser vacío)
  local pat="$1"
  pgrep -f "$pat" 2>/dev/null || true
}

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" | awk '{print $1}'
  else
    cksum "$file" | awk '{print $1 "-" $2}'
  fi
}

# ---------------------------------------------------------------------------
# Sesión
# ---------------------------------------------------------------------------
SESSION_TYPE="${XDG_SESSION_TYPE:-}"
WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}"
DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
SESSION_WAYLAND=0
SESSION_PLASMA=0

if [ "$SESSION_TYPE" = "wayland" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  SESSION_WAYLAND=1
  add_check PASS "session.wayland" \
    "type=${SESSION_TYPE:-?} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-?}"
else
  add_check FAIL "session.wayland" \
    "no es Wayland (XDG_SESSION_TYPE=${SESSION_TYPE:-vacío}, WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-vacío})"
fi

PLASMA_PID="$(find_pid 'plasmashell' | head -n 1)"
if printf '%s' "$DESKTOP" | grep -qiE 'kde|plasma' || [ -n "$PLASMA_PID" ]; then
  SESSION_PLASMA=1
  add_check PASS "session.plasma" \
    "XDG_CURRENT_DESKTOP=${DESKTOP:-?} plasmashell_pid=${PLASMA_PID:-?}"
else
  add_check FAIL "session.plasma" \
    "no se detecta Plasma (XDG_CURRENT_DESKTOP=${DESKTOP:-vacío}, sin plasmashell)"
fi

# ---------------------------------------------------------------------------
# Usuario / host / home
# ---------------------------------------------------------------------------
ACTUAL_USER="$(id -un 2>/dev/null || true)"
ACTUAL_UID="$(id -u 2>/dev/null || true)"
HOST_NAME="$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || true)"

if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_UID" = "0" ]; then
  add_check FAIL "user.identity" "usuario='$ACTUAL_USER' uid='$ACTUAL_UID' (no root)"
elif [ "$EXPECT_USER" != "-" ] && [ "$ACTUAL_USER" != "$EXPECT_USER" ]; then
  add_check FAIL "user.identity" \
    "usuario='$ACTUAL_USER' (esperado '$EXPECT_USER'), uid=$ACTUAL_UID, HOME=$HOME"
elif [ ! -d "$HOME" ]; then
  add_check FAIL "user.identity" "HOME no existe: $HOME"
elif [ ! -w "$HOME" ]; then
  add_check FAIL "user.identity" "HOME no escribible: $HOME"
else
  add_check PASS "user.identity" "usuario=$ACTUAL_USER uid=$ACTUAL_UID HOME=$HOME"
fi

if [ -z "$HOST_NAME" ]; then
  add_check FAIL "host.hostname" "hostname vacío"
elif [ "$EXPECT_HOST" != "-" ] && [ "$HOST_NAME" != "$EXPECT_HOST" ]; then
  add_check FAIL "host.hostname" "hostname='$HOST_NAME' (esperado '$EXPECT_HOST')"
else
  add_check PASS "host.hostname" "hostname=$HOST_NAME"
fi

# ---------------------------------------------------------------------------
# SDDM
# ---------------------------------------------------------------------------
if ! command -v systemctl >/dev/null 2>&1; then
  add_check FAIL "sddm.enabled" "sin systemctl; no se puede comprobar sddm"
else
  SDDM_STATE="$(systemctl is-enabled sddm 2>/dev/null || true)"
  case "$SDDM_STATE" in
    enabled|enabled-runtime|alias)
      add_check PASS "sddm.enabled" "systemctl is-enabled sddm = $SDDM_STATE" ;;
    *)
      add_check FAIL "sddm.enabled" \
        "systemctl is-enabled sddm = '${SDDM_STATE:-vacío}' (esperado enabled)" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Skel en el home
# ---------------------------------------------------------------------------
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CANON_DIR="$HOME/.config/plasma"

ENV_SCRIPT="$CONFIG_DIR/plasma-workspace/env/nimbus-bar.sh"
[ -f "$ENV_SCRIPT" ] || ENV_SCRIPT="$HOME/.config/plasma-workspace/env/nimbus-bar.sh"
if [ ! -f "$ENV_SCRIPT" ]; then
  add_check FAIL "skel.plasma-env" "falta .config/plasma-workspace/env/nimbus-bar.sh"
elif [ ! -x "$ENV_SCRIPT" ]; then
  add_check FAIL "skel.plasma-env" "$ENV_SCRIPT existe pero no es ejecutable"
else
  add_check PASS "skel.plasma-env" "$ENV_SCRIPT (ejecutable)"
fi

AUTOSTART_MISSING=""
for f in krema.desktop nimbus-hide-panel.desktop nimbus-theme-init.desktop; do
  [ -s "$CONFIG_DIR/autostart/$f" ] || AUTOSTART_MISSING="$AUTOSTART_MISSING $f"
done
if [ -n "$AUTOSTART_MISSING" ]; then
  add_check FAIL "skel.autostart" "faltan .config/autostart/$AUTOSTART_MISSING"
else
  add_check PASS "skel.autostart" \
    "krema, hide-panel y theme-init presentes en $CONFIG_DIR/autostart"
fi

KWINRC_PATH="$(find_first "$CONFIG_DIR/kwinrc" "$CANON_DIR/kwinrc" || true)"
if [ -z "$KWINRC_PATH" ]; then
  add_check FAIL "skel.kwinrc" "falta kwinrc (ni $CONFIG_DIR/kwinrc ni $CANON_DIR/kwinrc)"
elif [ "$KWINRC_PATH" = "$CONFIG_DIR/kwinrc" ]; then
  add_check PASS "skel.kwinrc" "$KWINRC_PATH"
else
  add_check PASS "skel.kwinrc" \
    "$KWINRC_PATH (solo skel: KWin lee $CONFIG_DIR/kwinrc; ver kwin.scripts)"
fi

KDEGLOBALS_PATH="$(find_first "$CONFIG_DIR/kdeglobals" "$CANON_DIR/kdeglobals" || true)"
if [ -z "$KDEGLOBALS_PATH" ]; then
  add_check FAIL "skel.kdeglobals" \
    "falta kdeglobals (ni $CONFIG_DIR/kdeglobals ni $CANON_DIR/kdeglobals)"
elif [ "$KDEGLOBALS_PATH" = "$CONFIG_DIR/kdeglobals" ]; then
  add_check PASS "skel.kdeglobals" "$KDEGLOBALS_PATH"
else
  add_check PASS "skel.kdeglobals" \
    "$KDEGLOBALS_PATH (solo skel: la sesión lee $CONFIG_DIR/kdeglobals)"
fi

KLASSYRC_PATH="$(find_first "$CONFIG_DIR/klassy/klassyrc" "$HOME/.config/klassy/klassyrc" || true)"
if [ -z "$KLASSYRC_PATH" ]; then
  add_check FAIL "skel.klassyrc" "falta .config/klassy/klassyrc"
else
  add_check PASS "skel.klassyrc" "$KLASSYRC_PATH"
fi

KREMARC_PATH="$(find_first "$CONFIG_DIR/kremarc" "$CONFIG_DIR/krema/kremarc" || true)"
if [ -z "$KREMARC_PATH" ]; then
  add_check FAIL "skel.kremarc" "falta .config/kremarc (preset del Dock)"
else
  add_check PASS "skel.kremarc" "$KREMARC_PATH"
fi

# ---------------------------------------------------------------------------
# Paquetes
# ---------------------------------------------------------------------------
if ! command -v pacman >/dev/null 2>&1; then
  add_check FAIL "packages.klassy-nimbus" "sin pacman"
  add_check FAIL "packages.krema" "sin pacman"
else
  if PKG_OUT="$(pacman -Q klassy-nimbus 2>/dev/null)"; then
    add_check PASS "packages.klassy-nimbus" "$PKG_OUT"
  else
    add_check FAIL "packages.klassy-nimbus" "pacman -Q klassy-nimbus falló (no instalado)"
  fi
  if PKG_OUT="$(pacman -Q krema 2>/dev/null)"; then
    add_check PASS "packages.krema" "$PKG_OUT"
  else
    add_check FAIL "packages.krema" "pacman -Q krema falló (no instalado)"
  fi
fi

# ---------------------------------------------------------------------------
# Scripts KWin (config efectiva: ~/.config/kwinrc)
# ---------------------------------------------------------------------------
KWIN_SCRIPTS="nimbus-spotlight nimbus-apps-toggle nimbus-tabs nimbus-mc nimbus-zoom"
if [ ! -s "$CONFIG_DIR/kwinrc" ]; then
  CANON_KWINRC="$CANON_DIR/kwinrc"
  if [ -s "$CANON_KWINRC" ]; then
    add_check FAIL "kwin.scripts" \
      "sin $CONFIG_DIR/kwinrc; nimbus-*Enabled solo en $CANON_KWINRC (KWin no lo lee)"
  else
    add_check FAIL "kwin.scripts" "sin $CONFIG_DIR/kwinrc"
  fi
else
  KWIN_BAD=""
  KWIN_OK=""
  for s in $KWIN_SCRIPTS; do
    val="$(cfg_get kwinrc Plugins "${s}Enabled")"
    if [ "$val" = "true" ] || [ "$val" = "1" ]; then
      KWIN_OK="$KWIN_OK $s"
    else
      KWIN_BAD="$KWIN_BAD ${s}=${val:-vacío}"
    fi
  done
  if [ -n "$KWIN_BAD" ]; then
    add_check FAIL "kwin.scripts" "no activos:$KWIN_BAD"
  else
    add_check PASS "kwin.scripts" "activos:$KWIN_OK"
  fi
fi

# ---------------------------------------------------------------------------
# Tema / acento (config efectiva: ~/.config/kdeglobals)
# ---------------------------------------------------------------------------
if [ ! -s "$CONFIG_DIR/kdeglobals" ]; then
  if [ -s "$CANON_DIR/kdeglobals" ]; then
    add_check FAIL "theme.scheme" \
      "sin $CONFIG_DIR/kdeglobals; solo $CANON_DIR/kdeglobals (no efectivo)"
  else
    add_check FAIL "theme.scheme" "sin $CONFIG_DIR/kdeglobals"
  fi
  add_check FAIL "theme.accent" "sin $CONFIG_DIR/kdeglobals"
else
  SCHEME="$(cfg_get kdeglobals General ColorScheme)"
  ACCENT="$(cfg_get kdeglobals 'Colors:Window' DecorationFocus)"
  case "$SCHEME" in
    NimbusTahoe|NimbusTahoeLight)
      add_check PASS "theme.scheme" "ColorScheme=$SCHEME" ;;
    *)
      add_check FAIL "theme.scheme" \
        "ColorScheme='${SCHEME:-vacío}' (esperado NimbusTahoe/NimbusTahoeLight)" ;;
  esac
  if printf '%s' "$ACCENT" | grep -qE '^#[0-9A-Fa-f]{6}$|^[0-9]{1,3}(,[0-9]{1,3}){2}$'; then
    add_check PASS "theme.accent" "Colors:Window/DecorationFocus=$ACCENT"
  else
    add_check FAIL "theme.accent" \
      "Colors:Window/DecorationFocus='${ACCENT:-vacío}' (esperado RGB o #RRGGBB)"
  fi
fi

# ---------------------------------------------------------------------------
# Panel stock (en vivo) + barra Nimbus
# ---------------------------------------------------------------------------
PANEL_JS='var r=[]; panels().forEach(function(p){r.push(p.visible+":"+p.visibilityMode);}); r.join(",");'
if ! command -v qdbus6 >/dev/null 2>&1; then
  add_check FAIL "panel.stock" "sin qdbus6; no se puede consultar plasmashell"
else
  PANEL_RAW="$(qdbus6 org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript "$PANEL_JS" 2>&1)"
  PANEL_RC=$?
  if [ "$PANEL_RC" -ne 0 ]; then
    add_check FAIL "panel.stock" "evaluateScript rc=$PANEL_RC: $(printf '%s' "$PANEL_RAW" | head -n 1)"
  else
    PANEL_CLEAN="$(printf '%s' "$PANEL_RAW" | tr -d '"' | tail -n 1)"
    PANEL_COUNT=0
    PANEL_BAD=""
    PANEL_GOOD=1
    if [ -n "$PANEL_CLEAN" ]; then
      IFS=',' read -r -a PANEL_ITEMS <<< "$PANEL_CLEAN"
      for item in "${PANEL_ITEMS[@]}"; do
        item="$(printf '%s' "$item" | tr -d ' ')"
        [ -n "$item" ] || continue
        case "$item" in
          *:*) ;;
          *) PANEL_GOOD=0; PANEL_BAD="$PANEL_BAD formato=$item"; continue ;;
        esac
        vis="${item%%:*}"
        mode="${item##*:}"
        PANEL_COUNT=$((PANEL_COUNT + 1))
        if [ "$vis" != "false" ] && [ "$vis" != "0" ]; then
          PANEL_GOOD=0
          PANEL_BAD="$PANEL_BAD visible=$vis"
        fi
        if [ "$mode" != "1" ]; then
          PANEL_GOOD=0
          PANEL_BAD="$PANEL_BAD visibilityMode=$mode"
        fi
      done
    fi
    if [ "$PANEL_COUNT" -eq 0 ]; then
      add_check FAIL "panel.stock" "plasmashell no devolvió paneles ('$PANEL_CLEAN')"
    elif [ "$PANEL_GOOD" -eq 1 ]; then
      add_check PASS "panel.stock" "paneles=$PANEL_COUNT visible=false visibilityMode=1"
    else
      add_check FAIL "panel.stock" \
        "paneles=$PANEL_COUNT; esperado visible=false/visibilityMode=1;$PANEL_BAD"
    fi
  fi
fi

BAR_PIDS="$(find_pid '/usr/local/bin/nimbus-bar')"
if [ -z "$BAR_PIDS" ]; then
  BAR_PIDS="$(pgrep -x nimbus-bar 2>/dev/null || true)"
fi
if [ -n "$BAR_PIDS" ]; then
  add_check PASS "bar.process" "nimbus-bar vivo (pid $(printf '%s' "$BAR_PIDS" | tr '\n' ',' | sed 's/,$//'))"
else
  add_check FAIL "bar.process" "no hay proceso nimbus-bar"
fi

# ---------------------------------------------------------------------------
# Servidor de notificaciones FDO
# ---------------------------------------------------------------------------
if ! command -v qdbus6 >/dev/null 2>&1; then
  add_check FAIL "notifications.server" "sin qdbus6"
else
  NOTIF_INFO="$(qdbus6 org.freedesktop.Notifications \
    /org/freedesktop/Notifications \
    org.freedesktop.Notifications.GetServerInformation 2>&1)"
  NOTIF_RC=$?
  if [ "$NOTIF_RC" -ne 0 ] || [ -z "$NOTIF_INFO" ]; then
    add_check FAIL "notifications.server" \
      "GetServerInformation rc=$NOTIF_RC: $(printf '%s' "$NOTIF_INFO" | head -n 1)"
  elif printf '%s' "$NOTIF_INFO" | grep -qiE 'plasmashell|^Plasma$|^KDE$'; then
    add_check FAIL "notifications.server" \
      "responde plasmashell/KDE, no Nimbus: $(printf '%s' "$NOTIF_INFO" | tr '\n' '/')"
  elif printf '%s' "$NOTIF_INFO" | grep -qi 'nimbus'; then
    add_check PASS "notifications.server" \
      "Nimbus: $(printf '%s' "$NOTIF_INFO" | tr '\n' '/')"
  else
    add_check FAIL "notifications.server" \
      "servidor inesperado: $(printf '%s' "$NOTIF_INFO" | tr '\n' '/')"
  fi
fi

# ---------------------------------------------------------------------------
# Activación DBus de los daemons Nimbus
# ---------------------------------------------------------------------------
check_activation() { # $1=id $2=servicio $3=ruta $4=interfaz $5=método $6=patrón $7=etiqueta
  local cid="$1" service="$2" path="$3" iface="$4" method="$5"
  local pattern="$6" label="$7" svc_file user_svc pids pid still out rc newpids

  svc_file="$(syspath "/usr/share/dbus-1/services/${service}.service")"
  user_svc="$HOME/.local/share/dbus-1/services/${service}.service"
  if [ ! -f "$svc_file" ] && [ ! -f "$user_svc" ]; then
    add_check FAIL "$cid" "$label: sin service file ${service}.service"
    return 0
  fi
  if ! command -v qdbus6 >/dev/null 2>&1; then
    add_check FAIL "$cid" "$label: sin qdbus6"
    return 0
  fi

  pids="$(find_pid "$pattern")"
  if [ -n "$pids" ]; then
    for pid in $pids; do kill "$pid" 2>/dev/null || true; done
    sleep 1
    still="$(find_pid "$pattern")"
    if [ -n "$still" ]; then
      add_check FAIL "$cid" "$label: daemon sigue vivo tras kill (pid $(printf '%s' "$still" | tr '\n' ','))"
      return 0
    fi
  fi

  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 10 qdbus6 "$service" "$path" "${iface}.${method}" 2>&1)"
    rc=$?
  else
    out="$(qdbus6 "$service" "$path" "${iface}.${method}" 2>&1)"
    rc=$?
  fi

  newpids=""
  for _ in 1 2 3 4 5; do
    newpids="$(find_pid "$pattern")"
    [ -n "$newpids" ] && break
    sleep 0.5
  done
  if [ "$rc" -eq 0 ] && [ -n "$newpids" ]; then
    add_check PASS "$cid" \
      "$label: activado por DBus (pid $(printf '%s' "$newpids" | tr '\n' ',' | sed 's/,$//'))"
  else
    add_check FAIL "$cid" \
      "$label: rc=$rc pids='$(printf '%s' "$newpids" | tr '\n' ',')' salida=$(printf '%s' "$out" | head -n 1)"
  fi
}

check_activation "dbus.spotlight" "org.nimbus.Spotlight" "/Spotlight" \
  "org.nimbus.Spotlight" "toggle" "/usr/local/bin/nimbus-spotlight" "Spotlight"
check_activation "dbus.apps" "org.nimbus.Apps" "/Apps" \
  "org.nimbus.Apps" "toggle" "/usr/local/bin/nimbus-apps" "Apps"
check_activation "dbus.missioncontrol" "org.nimbus.MissionControl" "/MC" \
  "org.nimbus.MissionControl" "toggle" "/usr/local/bin/nimbus-missioncontrol" "Mission Control"

# ---------------------------------------------------------------------------
# KCM Nimbus
# ---------------------------------------------------------------------------
KCM_SO="$(syspath '/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_nimbus.so')"
KCM_DESKTOP="$(syspath '/usr/share/applications/kcm_nimbus.desktop')"
KCM_PKG="$(syspath '/usr/share/kpackage/kcms/kcm_nimbus/metadata.json')"
KCM_MISSING=""
[ -f "$KCM_SO" ] || KCM_MISSING="$KCM_MISSING kcm_nimbus.so"
[ -f "$KCM_DESKTOP" ] || KCM_MISSING="$KCM_MISSING kcm_nimbus.desktop"
if [ -n "$KCM_MISSING" ]; then
  add_check FAIL "kcm.nimbus" "faltan:$KCM_MISSING"
else
  if [ -f "$KCM_PKG" ]; then
    add_check PASS "kcm.nimbus" "plugin + desktop + kpackage presentes"
  else
    add_check PASS "kcm.nimbus" "plugin + desktop presentes (sin metadata de kpackage)"
  fi
fi

# ---------------------------------------------------------------------------
# ydotool / grupo input
# ---------------------------------------------------------------------------
if command -v ydotool >/dev/null 2>&1; then
  add_check PASS "ydotool.binary" "$(command -v ydotool)"
else
  add_check FAIL "ydotool.binary" \
    "falta ydotool (F6-T06: Pegar copia sin autopegar)"
fi

GROUPS_USER="$(id -nG 2>/dev/null || true)"
if printf '%s\n' "$GROUPS_USER" | tr ' ' '\n' | grep -qx 'input'; then
  add_check PASS "ydotool.input-group" "grupos=$GROUPS_USER"
else
  add_check FAIL "ydotool.input-group" \
    "usuario no está en input (grupos='${GROUPS_USER:-vacío}'); ydotool no podrá abrir uinput"
fi

# ---------------------------------------------------------------------------
# Atajos reales (opt-in): ydotool por keycodes + capturas spectacle
# ---------------------------------------------------------------------------
if [ "$WITH_SHORTCUTS" -eq 0 ]; then
  add_check SKIP "shortcuts.real" \
    "no solicitado; usar --with-shortcuts (ydotool + spectacle, sin layout)"
else
  SHORTCUT_MISSING=""
  command -v ydotool >/dev/null 2>&1 || SHORTCUT_MISSING="$SHORTCUT_MISSING ydotool"
  command -v spectacle >/dev/null 2>&1 || SHORTCUT_MISSING="$SHORTCUT_MISSING spectacle"
  if [ -z "$SHORTCUT_MISSING" ] && ! pgrep -x ydotoold >/dev/null 2>&1; then
    SHORTCUT_MISSING="$SHORTCUT_MISSING ydotoold-inactivo"
  fi
  if [ -n "$SHORTCUT_MISSING" ]; then
    add_check SKIP "shortcuts.real" \
      "SKIP: falta$SHORTCUT_MISSING; no se envía ninguna tecla ni captura"
  else
    capture() { # $1=destino
      local path="$1"
      rm -f "$path"
      if ! spectacle -b -n -f -o "$path" >/dev/null 2>&1; then
        return 1
      fi
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        [ -s "$path" ] && return 0
        sleep 0.5
      done
      return 1
    }
    BEFORE="$OUT/shortcuts-before.png"
    if ! capture "$BEFORE"; then
      add_check FAIL "shortcuts.real" "spectacle no produjo captura base ($BEFORE)"
    else
      BEFORE_HASH="$(hash_file "$BEFORE")"
      ARTIFACTS="$BEFORE"
      SHORTCUT_BAD=""
      SHORTCUT_CHANGED=0
      SHORTCUT_KEYS=(
        "spotlight|125:1 57:1 57:0 125:0|Meta+Espacio"
        "mc|125:1 17:1 17:0 125:0|Meta+W"
        "apps|125:1 2:1 2:0 125:0|Meta+1"
      )
      for spec in "${SHORTCUT_KEYS[@]}"; do
        IFS='|' read -r sid keyseq label <<< "$spec"
        read -r -a key_arr <<< "$keyseq"
        if ! ydotool key "${key_arr[@]}" >/dev/null 2>&1; then
          SHORTCUT_BAD="$SHORTCUT_BAD ${label}:ydotool-falló"
          continue
        fi
        sleep 1
        SHOT="$OUT/shortcut-${sid}.png"
        if ! capture "$SHOT"; then
          SHORTCUT_BAD="$SHORTCUT_BAD ${label}:sin-captura"
          continue
        fi
        ARTIFACTS="$ARTIFACTS,$SHOT"
        SHOT_HASH="$(hash_file "$SHOT")"
        if [ "$SHOT_HASH" != "$BEFORE_HASH" ]; then
          SHORTCUT_CHANGED=$((SHORTCUT_CHANGED + 1))
        else
          SHORTCUT_BAD="$SHORTCUT_BAD ${label}:captura-igual"
        fi
        ydotool key 1:1 1:0 >/dev/null 2>&1 || true
        sleep 0.5
      done
      if [ -n "$SHORTCUT_BAD" ]; then
        add_check FAIL "shortcuts.real" \
          "fallos:$SHORTCUT_BAD (capturas para revisión humana)" "$ARTIFACTS"
      elif [ "$SHORTCUT_CHANGED" -eq 0 ]; then
        add_check FAIL "shortcuts.real" \
          "ninguna captura cambió; atajos no produjeron efecto visible" "$ARTIFACTS"
      else
        add_check PASS "shortcuts.real" \
          "3 atajos por keycode; $SHORTCUT_CHANGED capturas cambiaron (revisar artefactos)" \
          "$ARTIFACTS"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------------
# JSON + Markdown
# ---------------------------------------------------------------------------
JSON="$OUT/acceptance.json"
MD="$OUT/acceptance.md"
python3 - "$RESULTS_FILE" "$JSON" "$MD" "$HOST_NAME" "$ACTUAL_USER" \
  "$SESSION_TYPE" "$DESKTOP" "$OUT" "$SESSION_WAYLAND" "$SESSION_PLASMA" <<'PY'
import datetime
import json
import sys

(results_path, json_path, md_path, host, user, session_type, desktop, out,
 wayland, plasma) = sys.argv[1:11]

rows = []
with open(results_path, encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        while len(parts) < 4:
            parts.append("")
        status, cid, detail, arts = parts[0], parts[1], parts[2], parts[3]
        artifacts = [a for a in arts.split(",") if a]
        rows.append({
            "id": cid,
            "status": status,
            "detail": detail,
            "artifacts": artifacts,
        })

summary = {"PASS": 0, "FAIL": 0, "SKIP": 0}
for row in rows:
    summary[row["status"]] = summary.get(row["status"], 0) + 1

data = {
    "schema": 1,
    "generated_at": datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "hostname": host,
    "user": user,
    "session": {
        "type": session_type,
        "desktop": desktop,
        "wayland": wayland == "1",
        "plasma": plasma == "1",
    },
    "out": out,
    "checks": rows,
    "summary": summary,
    "verdict": "FAIL" if summary.get("FAIL", 0) else "PASS",
}

with open(json_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")

def esc(value):
    return value.replace("|", "\\|").replace("\n", " ")

with open(md_path, "w", encoding="utf-8") as fh:
    fh.write("# Aceptación del sistema instalado NimbusOS\n\n")
    fh.write(f"- Fecha: {data['generated_at']}\n")
    fh.write(f"- Host: {host}\n")
    fh.write(f"- Usuario: {user}\n")
    fh.write(f"- Sesión: {session_type or '?'} / {desktop or '?'} "
             f"(wayland={data['session']['wayland']}, "
             f"plasma={data['session']['plasma']})\n")
    fh.write(f"- Salida: {out}\n\n")
    fh.write("| Estado | Check | Detalle |\n")
    fh.write("| --- | --- | --- |\n")
    for row in rows:
        fh.write(f"| {row['status']} | {esc(row['id'])} | "
                 f"{esc(row['detail'])} |\n")
    fh.write("\n")
    fh.write(f"**Resumen:** {summary.get('PASS', 0)} PASS / "
             f"{summary.get('FAIL', 0)} FAIL / "
             f"{summary.get('SKIP', 0)} SKIP — "
             f"**VEREDICTO: {data['verdict']}**\n")

sys.exit(1 if summary.get("FAIL", 0) else 0)
PY
PY_RC=$?

printf '\n[accept] %d PASS / %d FAIL / %d SKIP\n' "$PASS_N" "$FAIL_N" "$SKIP_N"
printf '[accept] JSON: %s\n[accept] MD:   %s\n' "$JSON" "$MD"
if [ "$PY_RC" -ne 0 ] || [ "$FAIL_N" -ne 0 ]; then
  printf '[accept] VEREDICTO: FAIL\n'
  exit 1
fi
printf '[accept] VEREDICTO: PASS\n'
exit 0
