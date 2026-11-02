#!/usr/bin/env bash
# test_installed_acceptance.sh — tests del arnés F2-T08 sin VM.
#
# Aísla el harness con HOME/XDG temporales, una raíz de sistema falsa y
# fakes en PATH (qdbus6, pgrep, spectacle, systemctl, pacman, kreadconfig6,
# ydotool, hostname, id). No toca ~/.config real ni usa root.
#
# Uso: bash tests/acceptance/test_installed_acceptance.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/tests/vm/installed-acceptance.sh"
REPORT="$REPO_ROOT/tests/vm/installed-acceptance-report.sh"

[ -f "$SCRIPT" ] || { echo "ERROR: falta $SCRIPT" >&2; exit 1; }
[ -f "$REPORT" ] || { echo "ERROR: falta $REPORT" >&2; exit 1; }

TMP_BASE="${TMPDIR:-/tmp/opencode}"
[ -d "$TMP_BASE" ] || TMP_BASE="${TMPDIR:-/tmp}"
TMP="$(mktemp -d "$TMP_BASE/nimbus-accept-test-XXXXXX")" \
  || { echo "ERROR: no se pudo crear temporal" >&2; exit 1; }
KEEP=0
for arg in "$@"; do
  [ "$arg" = "--keep" ] && KEEP=1
done
BIN="$TMP/bin"
mkdir -p "$BIN"
SCENARIO_STATE="$TMP/state-init"
mkdir -p "$SCENARIO_STATE"

cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    printf 'TMP: %s\n' "$TMP"
  else
    rm -rf "$TMP" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

PASS_TESTS=0
FAIL_TESTS=0
ok() { printf 'ok - %s\n' "$1"; PASS_TESTS=$((PASS_TESTS + 1)); }
bad() { printf 'not ok - %s\n' "$1"; FAIL_TESTS=$((FAIL_TESTS + 1)); }

assert_rc() { # $1=desc $2=esperado $3=real
  if [ "$2" -eq "$3" ]; then
    ok "$1"
  else
    bad "$1 (rc esperado $2, real $3)"
  fi
}

assert_contains() { # $1=fichero $2=texto $3=desc
  if grep -qF -- "$2" "$1" 2>/dev/null; then
    ok "$3"
  else
    bad "$3 (falta '$2' en $1)"
  fi
}

# ---------------------------------------------------------------------------
# Fakes
# ---------------------------------------------------------------------------
cat >"$BIN/qdbus6" <<'EOF'
#!/usr/bin/env bash
set -u
state="${FAKE_STATE:?}"
if [ "${1:-}" = "org.kde.plasmashell" ]; then
  printf '%s\n' "${FAKE_PANEL_STATE:-false:1}"
  exit 0
fi
if [ "${1:-}" = "org.freedesktop.Notifications" ]; then
  printf 'Nimbus\nNimbusOS\n1.0\n1.2\n'
  exit 0
fi
svc="${1:-}"
if [ -n "${FAKE_ACT_FAIL:-}" ] && [ "$svc" = "${FAKE_ACT_FAIL}" ]; then
  printf 'activación simulada fallida\n' >&2
  exit 1
fi
case "$svc" in
  org.nimbus.*) : >"$state/active-$svc"; exit 0 ;;
  *) exit 1 ;;
esac
EOF

cat >"$BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
set -u
state="${FAKE_STATE:?}"
pattern=""
for arg in "$@"; do
  case "$arg" in
    -*) : ;;
    *) pattern="$arg" ;;
  esac
done
case "$pattern" in
  *plasmashell*) printf '4000\n'; exit 0 ;;
  *nimbus-bar*) printf '4100\n'; exit 0 ;;
  *nimbus-spotlight*)
    if [ -f "$state/active-org.nimbus.Spotlight" ]; then printf '4101\n'; exit 0; fi ;;
  *nimbus-apps*)
    if [ -f "$state/active-org.nimbus.Apps" ]; then printf '4102\n'; exit 0; fi ;;
  *nimbus-missioncontrol*)
    if [ -f "$state/active-org.nimbus.MissionControl" ]; then printf '4103\n'; exit 0; fi ;;
  *ydotoold*)
    if [ -f "$state/ydotoold" ]; then printf '4200\n'; exit 0; fi ;;
esac
exit 1
EOF

cat >"$BIN/kreadconfig6" <<'EOF'
#!/usr/bin/env bash
set -u
file="" group="" key=""
while [ $# -gt 0 ]; do
  case "$1" in
    --file) file="${2:-}"; shift 2 ;;
    --group) group="${2:-}"; shift 2 ;;
    --key) key="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
case "$file" in
  /*) path="$file" ;;
  *) path="${XDG_CONFIG_HOME:-$HOME/.config}/$file" ;;
esac
[ -f "$path" ] || exit 0
awk -v s="[$group]" -v k="$key" '
  /^\[/ { insec = ($0 == s); next }
  insec && index($0, k "=") == 1 {
    sub(/^[^=]*=/, "");
    sub(/\r$/, "");
    print;
    exit
  }
' "$path"
EOF

cat >"$BIN/spectacle" <<'EOF'
#!/usr/bin/env bash
set -u
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$out" ] || exit 2
n=0
[ -f "$FAKE_STATE/spectacle-count" ] && n="$(cat "$FAKE_STATE/spectacle-count")"
n=$((n + 1))
printf 'fake-png-%s\n' "$n" >"$out"
printf '%s\n' "$n" >"$FAKE_STATE/spectacle-count"
: >"$FAKE_STATE/spectacle-called"
exit 0
EOF

cat >"$BIN/ydotool" <<'EOF'
#!/usr/bin/env bash
set -u
[ "${FAKE_YDOTOOL_FAIL:-0}" = "1" ] && exit 1
printf '%s\n' "$*" >>"$FAKE_STATE/ydotool-calls"
exit 0
EOF

cat >"$BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "is-enabled" ] && [ "${2:-}" = "sddm" ]; then
  printf '%s\n' "${FAKE_SDDM:-enabled}"
  exit 0
fi
exit 0
EOF

cat >"$BIN/pacman" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "-Q" ]; then
  case "${2:-}" in
    klassy-nimbus)
      [ "${FAKE_MISSING_KLASSY:-0}" = "1" ] && exit 1
      printf 'klassy-nimbus 6.7.3-1\n'; exit 0 ;;
    krema)
      [ "${FAKE_MISSING_KREMA:-0}" = "1" ] && exit 1
      printf 'krema 0.12.0-1\n'; exit 0 ;;
  esac
fi
exit 1
EOF

cat >"$BIN/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'nimbusos\n'
EOF

cat >"$BIN/id" <<'EOF'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  -un) printf 'nimbus\n' ;;
  -u) printf '1000\n' ;;
  -nG) printf 'nimbus input\n' ;;
  -gn) printf 'nimbus\n' ;;
  *) printf 'nimbus\n' ;;
esac
EOF

chmod +x "$BIN"/*

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
make_home() { # $1=HOME temporal
  local home="$1"
  mkdir -p "$home/.config/plasma-workspace/env" \
           "$home/.config/autostart" \
           "$home/.config/klassy"
  printf '#!/bin/sh\nexit 0\n' >"$home/.config/plasma-workspace/env/nimbus-bar.sh"
  chmod 755 "$home/.config/plasma-workspace/env/nimbus-bar.sh"
  printf '[Desktop Entry]\nType=Application\n' >"$home/.config/autostart/krema.desktop"
  printf '[Desktop Entry]\nType=Application\n' >"$home/.config/autostart/nimbus-hide-panel.desktop"
  printf '[Desktop Entry]\nType=Application\n' >"$home/.config/autostart/nimbus-theme-init.desktop"
  {
    printf '[Plugins]\n'
    for s in nimbus-spotlight nimbus-apps-toggle nimbus-tabs nimbus-mc nimbus-zoom; do
      printf '%sEnabled=true\n' "$s"
    done
  } >"$home/.config/kwinrc"
  {
    printf '[General]\nColorScheme=NimbusTahoe\n'
    printf '[Colors:Window]\nDecorationFocus=10,132,255\n'
  } >"$home/.config/kdeglobals"
  printf '[ButtonBehaviour]\nShowCloseIconNormallyActive=false\n' \
    >"$home/.config/klassy/klassyrc"
  printf '[General]\nPosition=bottom\n' >"$home/.config/kremarc"
}

make_rootfs() { # $1=raíz falsa
  local root="$1"
  mkdir -p "$root/usr/share/dbus-1/services" \
           "$root/usr/lib/qt6/plugins/plasma/kcms/systemsettings" \
           "$root/usr/share/applications"
  for svc in org.nimbus.Spotlight org.nimbus.Apps org.nimbus.MissionControl; do
    printf '[D-BUS Service]\nName=%s\n' "$svc" \
      >"$root/usr/share/dbus-1/services/$svc.service"
  done
  : >"$root/usr/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_nimbus.so"
  printf '[Desktop Entry]\nType=Application\nName=Nimbus\n' \
    >"$root/usr/share/applications/kcm_nimbus.desktop"
}

new_state() { # $1=nombre
  SCENARIO_STATE="$TMP/state-$1"
  mkdir -p "$SCENARIO_STATE"
}

run_harness() { # $1=bin $2=home $3=rootfs $4=out [args...]
  local bin="$1" home="$2" rootfs="$3" out="$4"
  shift 4
  env -i \
    PATH="$bin:/usr/bin:/bin" \
    HOME="$home" \
    TMPDIR="$TMP" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_SESSION_TYPE=wayland \
    WAYLAND_DISPLAY=wayland-0 \
    XDG_CURRENT_DESKTOP=KDE \
    FAKE_STATE="$SCENARIO_STATE" \
    FAKE_SDDM="${FAKE_SDDM:-enabled}" \
    FAKE_MISSING_KLASSY="${FAKE_MISSING_KLASSY:-0}" \
    FAKE_MISSING_KREMA="${FAKE_MISSING_KREMA:-0}" \
    FAKE_ACT_FAIL="${FAKE_ACT_FAIL:-}" \
    FAKE_YDOTOOL_FAIL="${FAKE_YDOTOOL_FAIL:-0}" \
    bash "$SCRIPT" --root "$rootfs" --out "$out" \
      --expect-user nimbus --expect-host nimbusos "$@"
}

json_check() { # $1=json $2=desc $3=script python (stdin)
  if python3 - "$1" <<PY
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
status = {c["id"]: c["status"] for c in data["checks"]}
$3
PY
  then
    ok "$2"
  else
    bad "$2 (JSON no cumple)"
  fi
}

# ---------------------------------------------------------------------------
# Caso 1: PASS completo (atajos SKIP por no pedirlos)
# ---------------------------------------------------------------------------
new_state pass
make_home "$TMP/home-pass"
make_rootfs "$TMP/rootfs"
run_harness "$BIN" "$TMP/home-pass" "$TMP/rootfs" "$TMP/out-pass" \
  >"$TMP/pass.log" 2>&1
RC=$?
assert_rc "PASS: exit 0" 0 "$RC"
[ -f "$TMP/out-pass/acceptance.json" ] && ok "PASS: acceptance.json creado" \
  || bad "PASS: acceptance.json creado"
[ -f "$TMP/out-pass/acceptance.md" ] && ok "PASS: acceptance.md creado" \
  || bad "PASS: acceptance.md creado"

json_check "$TMP/out-pass/acceptance.json" "PASS: JSON válido y veredicto" \
'assert data["verdict"] == "PASS"
assert data["summary"]["FAIL"] == 0
assert data["summary"]["SKIP"] == 1
assert status["shortcuts.real"] == "SKIP"
assert status["panel.stock"] == "PASS"
assert status["bar.process"] == "PASS"
assert status["notifications.server"] == "PASS"
assert status["dbus.spotlight"] == "PASS"
assert status["dbus.apps"] == "PASS"
assert status["dbus.missioncontrol"] == "PASS"
assert status["theme.scheme"] == "PASS"
assert status["theme.accent"] == "PASS"
assert status["kcm.nimbus"] == "PASS"'

assert_contains "$TMP/out-pass/acceptance.md" "VEREDICTO: PASS" \
  "PASS: markdown con veredicto"

if bash "$REPORT" --json "$TMP/out-pass/acceptance.json" \
  >"$TMP/report.txt" 2>&1; then
  ok "report: exit 0 con JSON PASS"
else
  bad "report: exit 0 con JSON PASS"
fi
assert_contains "$TMP/report.txt" "panel.stock" "report: pinta tabla"
assert_contains "$TMP/report.txt" "VEREDICTO: PASS" "report: resumen"

# ---------------------------------------------------------------------------
# Caso 2: FAIL (paquete Krema ausente) -> exit 1
# ---------------------------------------------------------------------------
new_state fail
make_home "$TMP/home-fail"
FAKE_MISSING_KREMA=1 run_harness "$BIN" "$TMP/home-fail" "$TMP/rootfs" \
  "$TMP/out-fail" >"$TMP/fail.log" 2>&1
RC=$?
assert_rc "FAIL: exit 1" 1 "$RC"
json_check "$TMP/out-fail/acceptance.json" "FAIL: paquete y veredicto" \
'assert data["verdict"] == "FAIL"
assert data["summary"]["FAIL"] >= 1
assert status["packages.krema"] == "FAIL"'
if bash "$REPORT" --json "$TMP/out-fail/acceptance.json" \
  >"$TMP/report-fail.txt" 2>&1; then
  bad "report: exit 1 con JSON FAIL"
else
  ok "report: exit 1 con JSON FAIL"
fi

# ---------------------------------------------------------------------------
# Caso 3: --with-shortcuts sin ydotool -> SKIP y CERO spectacle
# ---------------------------------------------------------------------------
BIN_NOY="$TMP/bin-noy"
mkdir -p "$BIN_NOY"
for f in "$BIN"/*; do
  b="$(basename "$f")"
  [ "$b" = "ydotool" ] && continue
  cp "$f" "$BIN_NOY/$b"
done
new_state noy
make_home "$TMP/home-noy"
run_harness "$BIN_NOY" "$TMP/home-noy" "$TMP/rootfs" "$TMP/out-noy" \
  --with-shortcuts >"$TMP/noy.log" 2>&1
RC=$?
assert_rc "sin ydotool: exit 1 por ydotool.binary" 1 "$RC"
json_check "$TMP/out-noy/acceptance.json" "sin ydotool: shortcut SKIP" \
'assert status["shortcuts.real"] == "SKIP"
assert status["ydotool.binary"] == "FAIL"
assert "ydotool" in [c["detail"] for c in data["checks"] if c["id"] == "shortcuts.real"][0]'
if [ ! -e "$SCENARIO_STATE/spectacle-called" ]; then
  ok "sin ydotool: spectacle NO se ejecutó"
else
  bad "sin ydotool: spectacle NO se ejecutó"
fi

# ---------------------------------------------------------------------------
# Caso 4: --with-shortcuts con ydotool -> capturas y PASS
# ---------------------------------------------------------------------------
new_state shortcuts
touch "$SCENARIO_STATE/ydotoold"
make_home "$TMP/home-sc"
run_harness "$BIN" "$TMP/home-sc" "$TMP/rootfs" "$TMP/out-sc" \
  --with-shortcuts >"$TMP/sc.log" 2>&1
RC=$?
assert_rc "shortcuts: exit 0" 0 "$RC"
json_check "$TMP/out-sc/acceptance.json" "shortcuts: PASS y artefactos" \
'assert status["shortcuts.real"] == "PASS"
check = [c for c in data["checks"] if c["id"] == "shortcuts.real"][0]
assert len(check["artifacts"]) == 4
for path in check["artifacts"]:
    assert path.endswith(".png")'
[ -e "$SCENARIO_STATE/spectacle-called" ] && ok "shortcuts: spectacle ejecutado" \
  || bad "shortcuts: spectacle ejecutado"
[ -s "$SCENARIO_STATE/ydotool-calls" ] && ok "shortcuts: ydotool envió teclas" \
  || bad "shortcuts: ydotool envió teclas"

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS_TESTS" "$FAIL_TESTS"
[ "$FAIL_TESTS" -eq 0 ] || exit 1
exit 0
