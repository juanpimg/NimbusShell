#!/usr/bin/env bash
# test_autostart.sh (F3-T03): arranque determinista de nimbus-bar + auto-hide.
# Sin host: fakes qdbus6/pgrep/systemctl en PATH, HOME temporal, sin root/red.
# Cubre: start idempotente (sin instancia / con instancia), single-instance
# por org.nimbus.Bar (fake qdbus6 que simula nombre tomado), hide-panel llama
# a evaluateScript con `hiding = "autohide"` y exit 0 sin panel, unidad con
# Type=dbus/BusName/orden Plasma, y permisos en installed-setup.
# Salta (exit 0) lo que necesite herramienta ausente; falla ante regresión.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AIROOTFS="$REPO_ROOT/iso/profile/airootfs"
START="$AIROOTFS/usr/local/bin/nimbus-bar-start"
HIDE="$AIROOTFS/usr/local/bin/nimbus-hide-panel"
UNIT="$AIROOTFS/etc/skel/.config/systemd/user/nimbus-bar.service"
SETUP="$AIROOTFS/usr/local/bin/nimbus-installed-setup"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }
need() { command -v "$1" >/dev/null 2>&1 || { skip "falta $1 ($2)"; return 1; }; }

# --- 0. shellcheck (cero warnings) ---
echo "== autostart: shellcheck =="
if need shellcheck "lint de scripts"; then
  if shellcheck -S warning "$START" "$HIDE" "$SETUP" \
      "$AIROOTFS/etc/skel/.config/plasma-workspace/env/nimbus-bar.sh" \
      "$REPO_ROOT/iso/build-iso.sh" "$0" \
      && shellcheck -S warning -e SC2034 "$REPO_ROOT/iso/profile/profiledef.sh"; then
    # profiledef.sh lo sourcea mkarchiso (vars de perfil: SC2034 excluido).
    pass "shellcheck cero warnings"
  else
    fail "shellcheck"
  fi
fi

# --- 1. nimbus-bar-start con fakes: sin instancia -> lanza; con instancia -> 0 ---
echo "== autostart: nimbus-bar-start idempotente =="
T="$(mktemp -d)"; FAKEBIN="$(mktemp -d)"
printf '#!/bin/bash\necho "FAKE-BAR $@" >>"$FAKE_CALLS"; exit 0\n' >"$FAKEBIN/nimbus-bar"
chmod 755 "$FAKEBIN/nimbus-bar"
export FAKE_CALLS="$T/calls"
: >"$FAKE_CALLS"
# pgrep falso en PATH (más robusto que exportar la función: el hijo hereda
# funciones exportadas y rompería la resolución por PATH).
FAKEDIR="$(mktemp -d)"
cat >"$FAKEDIR/pgrep" <<'EOF'
#!/bin/bash
# fake pgrep: PGREP_MODE=1 -> simula instancia viva (rc 0); 0 -> nada (rc 1).
[ "${PGREP_MODE:-0}" = "1" ] && exit 0
exit 1
EOF
chmod 755 "$FAKEDIR/pgrep"
run_start() { # run_start <home> [extra env...]
  HOME="$1" XDG_STATE_HOME="$1/.local/state" NIMBUS_BAR_BIN="$FAKEBIN/nimbus-bar" \
    WAYLAND_DISPLAY="" PATH="$FAKEDIR:$PATH" "$START"
}
run_start "$T" || fail "start sin instancia (rc)"
grep -q FAKE-BAR "$FAKE_CALLS" && pass "start sin instancia lanza nimbus-bar" \
  || fail "start sin instancia lanza nimbus-bar"
grep -q . "$T/.local/state/nimbus/bar.log" && pass "start escribe bar.log" \
  || fail "start escribe bar.log"
: >"$FAKE_CALLS"
PGREP_MODE=1 run_start "$T" \
  || fail "start con instancia (rc debe ser 0)"
[ -s "$FAKE_CALLS" ] && fail "start con instancia no debe lanzar" \
  || pass "start con instancia sale 0 sin lanzar"
unset PGREP_MODE
grep -q "ya hay una instancia" "$T/.local/state/nimbus/bar.log" \
  && pass "start con instancia lo loguea" || fail "start con instancia lo loguea"
HOME="$T" XDG_STATE_HOME="$T/.local/state" NIMBUS_BAR_BIN=/noexiste/nimbus-bar \
  WAYLAND_DISPLAY="" PATH="$FAKEDIR:$PATH" "$START" >/dev/null 2>&1 \
  && fail "start sin binario debe fallar" || pass "start sin binario rc != 0"

# --- 1b. nimbus-bar-start espera al socket Wayland (bug `Failed to create
# wl_display` del env script) y respeta org.nimbus.Bar vía qdbus ---
echo "== autostart: socket Wayland + org.nimbus.Bar =="
SOCKDIR="$(mktemp -d)"
cat >"$SOCKDIR/qdbus6" <<'EOF'
#!/bin/bash
# fake qdbus6 para nimbus-bar-start: QDBUS_BAR_TAKEN=1 -> org.nimbus.Bar con
# dueño (rc 0); si no, sin dueño (rc 1, como sin bus / nombre libre).
[ "$1" = "org.nimbus.Bar" ] && [ "${QDBUS_BAR_TAKEN:-0}" = "1" ] && exit 0
exit 1
EOF
chmod 755 "$SOCKDIR/qdbus6"
run_start_env() { # vars en el entorno del llamante; se exportan al hijo
  export HOME XDG_STATE_HOME NIMBUS_BAR_BIN XDG_RUNTIME_DIR WAYLAND_DISPLAY \
    NIMBUS_BAR_SOCKET_TRIES QDBUS_BAR_TAKEN
  PATH="$SOCKDIR:$FAKEDIR:$PATH" "$START"
}
# Socket presente: arranca de inmediato y lo loguea.
R1="$(mktemp -d)"
python3 -c "import socket; s=socket.socket(socket.AF_UNIX); s.bind('$R1/wayland-0')" \
  || fail "no se pudo crear socket falso (python3)"
: >"$FAKE_CALLS"
HOME="$R1" XDG_STATE_HOME="$R1/.local/state" NIMBUS_BAR_BIN="$FAKEBIN/nimbus-bar" \
  XDG_RUNTIME_DIR="$R1" WAYLAND_DISPLAY="wayland-0" run_start_env \
  || fail "start con socket (rc)"
grep -q FAKE-BAR "$FAKE_CALLS" && pass "start con socket lanza" \
  || fail "start con socket lanza"
grep -q "socket $R1/wayland-0 listo" "$R1/.local/state/nimbus/bar.log" \
  && pass "start con socket lo loguea" || fail "start con socket lo loguea"
# Socket ausente: espera (rápida: 2 intentos) y avisa, pero igual lanza.
R2="$(mktemp -d)"
: >"$FAKE_CALLS"
HOME="$R2" XDG_STATE_HOME="$R2/.local/state" NIMBUS_BAR_BIN="$FAKEBIN/nimbus-bar" \
  XDG_RUNTIME_DIR="$R2" WAYLAND_DISPLAY="wayland-0" NIMBUS_BAR_SOCKET_TRIES=2 \
  run_start_env || fail "start sin socket (rc debe ser 0)"
grep -q FAKE-BAR "$FAKE_CALLS" && pass "start sin socket lanza tras esperar" \
  || fail "start sin socket lanza tras esperar"
grep -q "sin socket $R2/wayland-0" "$R2/.local/state/nimbus/bar.log" \
  && pass "start sin socket avisa en el log" || fail "start sin socket avisa"
# org.nimbus.Bar tomado (servicio + autostart coincidiendo): exit 0 sin lanzar.
R3="$(mktemp -d)"
: >"$FAKE_CALLS"
HOME="$R3" XDG_STATE_HOME="$R3/.local/state" NIMBUS_BAR_BIN="$FAKEBIN/nimbus-bar" \
  WAYLAND_DISPLAY="" QDBUS_BAR_TAKEN=1 run_start_env \
  || fail "start con org.nimbus.Bar tomado (rc debe ser 0)"
[ -s "$FAKE_CALLS" ] && fail "start con org.nimbus.Bar tomado no debe lanzar" \
  || pass "start con org.nimbus.Bar tomado sale 0 sin lanzar"
grep -q "org.nimbus.Bar ya registrado" "$R3/.local/state/nimbus/bar.log" \
  && pass "start con org.nimbus.Bar tomado lo loguea" \
  || fail "start con org.nimbus.Bar tomado lo loguea"
rm -rf "$SOCKDIR" "$R1" "$R2" "$R3"

# --- 2. single-instance en main.cpp (org.nimbus.Bar; FDO intacto) ---
echo "== autostart: single-instance C++ =="
if need cmake "build nimbus-bar" ; then
  if [ ! -f /usr/lib/cmake/LayerShellQt/LayerShellQtConfigVersion.cmake ]; then
    skip "sin LayerShellQt (build solo con dev files)"
  else
    B="$(mktemp -d)"
    if ! cmake "$REPO_ROOT/packages/shell/nimbus-bar" -DCMAKE_BUILD_TYPE=Release \
         -B "$B/build" >/dev/null 2>&1; then
      fail "cmake configure"
    elif ! cmake --build "$B/build" -j"$(nproc)" >/dev/null 2>&1; then
      fail "cmake build"
    else
      pass "build nimbus-bar con org.nimbus.Bar"
      if need dbus-run-session "bus de sesión de prueba" && need timeout "timeout"; then
        H2="$(mktemp -d)"
        dbus-run-session -- bash -c '
          set -u
          export QT_QPA_PLATFORM=offscreen HOME="'"$H2"'" XDG_RUNTIME_DIR="'"$H2"'/run"
          mkdir -p "$XDG_RUNTIME_DIR"
          "'"$B"'/build/nimbus-bar" >"'"$H2"'/first.log" 2>&1 & p=$!
          sleep 3
          if kill -0 $p 2>/dev/null; then echo ALIVE; else echo DEAD; fi
          timeout 12 "'"$B"'/build/nimbus-bar" >"'"$H2"'/second.log" 2>&1
          echo "RC2=$?"
          kill $p 2>/dev/null
        ' >"$H2/out.txt" 2>&1 || true
        grep -q ALIVE "$H2/out.txt" && pass "primera instancia viva" \
          || fail "primera instancia viva ($(cat "$H2/out.txt"))"
        grep -q 'RC2=0' "$H2/out.txt" && pass "segunda instancia sale 0" \
          || fail "segunda instancia sale 0 ($(cat "$H2/out.txt"))"
        grep -q 'org.nimbus.Bar ya registrado' "$H2/second.log" \
          && pass "segunda instancia loguea org.nimbus.Bar" \
          || fail "segunda instancia loguea org.nimbus.Bar"
        rm -rf "$H2"
      fi
    fi
    rm -rf "$B"
  fi
fi

# --- 3. nimbus-hide-panel con qdbus6 falso ---
echo "== autostart: nimbus-hide-panel =="
H3="$(mktemp -d)"
cat >"$H3/qdbus6" <<'EOF'
#!/bin/bash
# fake qdbus6: registra llamadas en $QDBUS_CALLS; simula plasmashell según
# QDBUS_MODE: ok (panel) | nopanel (length 0) | down (sin bus, rc 1).
echo "CALL: $*" >>"$QDBUS_CALLS"
case "${QDBUS_MODE:-ok}" in
  down) exit 1 ;;
  nopanel)
    case "$*" in *evaluateScript*) echo 0 ;; *) : ;; esac
    exit 0 ;;
  *) # ok
    case "$*" in
      *'p.hiding = "autohide"'*) echo 1 ;;
      *'p.hiding'*) echo autohide ;;
      *'panels().length'*) echo 1 ;;
      *evaluateScript*) exit 0 ;;
      *) exit 0 ;;
    esac
    ;;
esac
EOF
chmod 755 "$H3/qdbus6"
run_hide() { # run_hide <home> <mode>
  HOME="$1" XDG_CACHE_HOME="$1/.cache" XDG_STATE_HOME="$1/.local/state" QDBUS_MODE="$2" \
    QDBUS_CALLS="$1/calls" NIMBUS_HIDE_PANEL_TIMEOUT=1 \
    PATH="$H3:$FAKEDIR:$PATH" "$HIDE"
  echo "RC=$?"
}
: >"$T/calls"
out="$(run_hide "$T" ok)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel ok rc 0" || fail "hide-panel ok rc ($out)"
grep -q 'p.hiding = "autohide"' "$T/calls" \
  && pass "hide-panel llama evaluateScript con hiding = autohide" \
  || fail "hide-panel llama evaluateScript ($(cat "$T/calls"))"
out="$(run_hide "$T" nopanel)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel sin panel rc 0" || fail "hide-panel sin panel ($out)"
grep -q "sin panel que ocultar" "$T/.cache/nimbus/hide-panel.log" \
  && pass "hide-panel sin panel lo loguea" || fail "hide-panel sin panel lo loguea"
out="$(run_hide "$T" down)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel sin bus rc 0" || fail "hide-panel sin bus ($out)"

# --- 4. unidad systemd de usuario ---
echo "== autostart: nimbus-bar.service =="
for key in 'Type=notify' 'NotifyAccess=all' 'TimeoutStartSec=12' \
           'PartOf=plasma-workspace.target' 'After=plasma-kwin_wayland.service' \
           'Before=plasma-plasmashell.service' 'WantedBy=plasma-workspace.target' \
           'ExecStart=/usr/local/bin/nimbus-bar-start' 'Restart=on-failure'; do
  grep -qF "$key" "$UNIT" && pass "unidad: $key" || fail "unidad: falta $key"
done
if grep -q '^Type=dbus' "$UNIT" || grep -q '^BusName=' "$UNIT"; then
  fail "unidad: sin Type=dbus/BusName (el FDO es no fatal, no estado de unit)"
else
  pass "unidad: sin Type=dbus/BusName"
fi
grep -q 'systemd-notify --ready' "$START" \
  && pass "wrapper: systemd-notify --ready tras adquirir FDO" \
  || fail "wrapper: falta systemd-notify --ready"
grep -q 'org.freedesktop.Notifications' "$START" \
  && pass "wrapper: espera org.freedesktop.Notifications" \
  || fail "wrapper: no espera org.freedesktop.Notifications"
[ -f "$AIROOTFS/etc/skel/.config/autostart/nimbus-bar.desktop" ] \
  && pass "fallback autostart nimbus-bar.desktop" || fail "falta nimbus-bar.desktop"
grep -q 'nimbus-bar-start' "$AIROOTFS/etc/skel/.config/autostart/nimbus-bar.desktop" \
  && pass "autostart usa nimbus-bar-start" || fail "autostart Exec"
if grep -qE 'nimbus-bar-start|nohup|/usr/local/bin/nimbus-bar([[:space:]]|$)' \
    "$AIROOTFS/etc/skel/.config/plasma-workspace/env/nimbus-bar.sh"; then
  fail "env script no debe lanzar procesos (bug wl_display)"
else
  pass "env script sin lanzamiento (solo variables)"
fi

# --- 5. installed-setup: habilita servicio + 755 arranque ---
echo "== autostart: nimbus-installed-setup =="
grep -q 'nimbus-bar.service' "$SETUP" && pass "setup menciona nimbus-bar.service" \
  || fail "setup: nimbus-bar.service"
grep -q 'plasma-workspace.target.wants/nimbus-bar.service' "$SETUP" \
  && pass "setup enlaza plasma-workspace.target.wants" || fail "setup: wants"
if grep -q 'default.target.wants/nimbus-bar.service' "$SETUP"; then
  fail "setup: no debe usar default.target.wants para la barra"
else
  pass "setup: sin default.target.wants para la barra"
fi
grep -q 'nimbus-bar.desktop' "$SETUP" && pass "setup asegura 755 autostart" \
  || fail "setup: 755 autostart"

# --- 6. qmllint de la barra (sin regresión QML) ---
echo "== autostart: qmllint =="
if need qmllint "lint QML"; then
  if qmllint "$REPO_ROOT/packages/shell/nimbus-bar/qml/Bar.qml" >/dev/null 2>&1; then
    pass "qmllint Bar.qml"
  else
    fail "qmllint Bar.qml"
  fi
else
  :
fi

rm -rf "$T" "$FAKEBIN" "$FAKEDIR" "$H3"

echo
if [ "$FAILS" = "0" ]; then echo "AUTOSTART VERDE."; exit 0;
else echo "AUTOSTART ROJO: $FAILS fallo(s)." >&2; exit 1; fi
