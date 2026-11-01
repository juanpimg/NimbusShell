#!/usr/bin/env bash
# test_autostart.sh (F3-T03): arranque determinista de nimbus-bar + auto-hide.
# Sin host: fakes qdbus6/pgrep/systemctl en PATH, HOME temporal, sin root/red.
# Cubre: start idempotente (sin instancia / con instancia), single-instance
# por org.nimbus.Bar (fake qdbus6 que simula nombre tomado), hide-panel llama
# a evaluateScript con `visibilityMode = 1` y exit 0 sin panel, unidad con
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
run_start() { # run_start <home>
  HOME="$1" XDG_STATE_HOME="$1/.local/state" NIMBUS_BAR_BIN="$FAKEBIN/nimbus-bar" \
    PATH="$FAKEDIR:$PATH" "$START"
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
  PATH="$FAKEDIR:$PATH" "$START" >/dev/null 2>&1 \
  && fail "start sin binario debe fallar" || pass "start sin binario rc != 0"

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
          "'"$B"'/build/nimbus-bar" --no-notifications >"'"$H2"'/first.log" 2>&1 & p=$!
          sleep 3
          if kill -0 $p 2>/dev/null; then echo ALIVE; else echo DEAD; fi
          timeout 12 "'"$B"'/build/nimbus-bar" --no-notifications >"'"$H2"'/second.log" 2>&1
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
      *'panels().length'*) echo 1 ;;
      *'visibilityMode = 1'*) exit 0 ;;
      *evaluateScript*) exit 0 ;;
      *) exit 0 ;;
    esac
    ;;
esac
EOF
chmod 755 "$H3/qdbus6"
run_hide() { # run_hide <home> <mode>
  HOME="$1" XDG_STATE_HOME="$1/.local/state" QDBUS_MODE="$2" \
    QDBUS_CALLS="$1/calls" NIMBUS_HIDE_PANEL_DELAY=0.01 \
    NIMBUS_HIDE_PANEL_ATTEMPTS=3 PATH="$H3:$FAKEDIR:$PATH" "$HIDE"
  echo "RC=$?"
}
: >"$T/calls"
out="$(run_hide "$T" ok)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel ok rc 0" || fail "hide-panel ok rc ($out)"
grep -q 'visibilityMode = 1' "$T/calls" \
  && pass "hide-panel llama evaluateScript con visibilityMode = 1" \
  || fail "hide-panel llama evaluateScript ($(cat "$T/calls"))"
out="$(run_hide "$T" nopanel)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel sin panel rc 0" || fail "hide-panel sin panel ($out)"
grep -q "sin paneles" "$T/.local/state/nimbus/hide-panel.log" \
  && pass "hide-panel sin panel lo loguea" || fail "hide-panel sin panel lo loguea"
out="$(run_hide "$T" down)"
[ "${out##*RC=}" = "0" ] && pass "hide-panel sin bus rc 0" || fail "hide-panel sin bus ($out)"

# --- 4. unidad systemd de usuario ---
echo "== autostart: nimbus-bar.service =="
for key in 'Type=dbus' 'BusName=org.freedesktop.Notifications' \
           'PartOf=plasma-workspace.target' 'After=plasma-kwin_wayland.service' \
           'Before=plasma-plasmashell.service' 'WantedBy=plasma-workspace.target' \
           'ExecStart=/usr/local/bin/nimbus-bar-start'; do
  grep -qF "$key" "$UNIT" && pass "unidad: $key" || fail "unidad: falta $key"
done
[ -f "$AIROOTFS/etc/skel/.config/autostart/nimbus-bar.desktop" ] \
  && pass "fallback autostart nimbus-bar.desktop" || fail "falta nimbus-bar.desktop"
grep -q 'nimbus-bar-start' "$AIROOTFS/etc/skel/.config/autostart/nimbus-bar.desktop" \
  && pass "autostart usa nimbus-bar-start" || fail "autostart Exec"
grep -q 'nimbus-bar-start' "$AIROOTFS/etc/skel/.config/plasma-workspace/env/nimbus-bar.sh" \
  && pass "env script delega en nimbus-bar-start" || fail "env script"

# --- 5. installed-setup: habilita servicio + 755 arranque ---
echo "== autostart: nimbus-installed-setup =="
grep -q 'nimbus-bar.service' "$SETUP" && pass "setup menciona nimbus-bar.service" \
  || fail "setup: nimbus-bar.service"
grep -q 'default.target.wants/nimbus-bar.service' "$SETUP" \
  && pass "setup enlaza default.target.wants" || fail "setup: wants"
grep -q 'nimbus-bar.sh' "$SETUP" && pass "setup asegura 755 arranque" \
  || fail "setup: 755 arranque"
grep -q 'Current=nimbus\|SDDM_THEME' "$SETUP" \
  && pass "setup SDDM/tema intacto" || fail "setup SDDM tocado?"

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
