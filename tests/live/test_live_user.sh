#!/usr/bin/env bash
# test_live_user.sh (F2-T07/R-LIVE-USER): usuario gráfico del live + SDDM.
# Sin root, sin red: valida ficheros, unidad, sudoers live y autostart.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="$REPO_ROOT/iso/profile/airootfs"
FAILS=0
pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
skip() { echo "  [SKIP] $1"; }

echo "== live: ficheros =="
for f in \
  "$PROFILE/usr/local/bin/nimbus-live-user" \
  "$PROFILE/usr/local/bin/nimbus-live-installer" \
  "$PROFILE/etc/systemd/system/nimbus-live-user.service" \
  "$PROFILE/etc/sudoers.d/10-nimbus-live" \
  "$PROFILE/etc/xdg/autostart/nimbus-installer.desktop"; do
  [ -f "$f" ] && pass "existe ${f#"$PROFILE"/}" || fail "falta ${f#"$PROFILE"/}"
done

echo "== live: scripts =="
if bash -n "$PROFILE/usr/local/bin/nimbus-live-user" \
            "$PROFILE/usr/local/bin/nimbus-live-installer"; then
  pass "bash -n"
else
  fail "bash -n"
fi
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning \
      "$PROFILE/usr/local/bin/nimbus-live-user" \
      "$PROFILE/usr/local/bin/nimbus-live-installer"; then
    pass "shellcheck cero warnings"
  else
    fail "shellcheck"
  fi
else
  skip "shellcheck ausente"
fi
grep -q 'useradd -m -G wheel,input' "$PROFILE/usr/local/bin/nimbus-live-user" \
  && pass "crea usuario en wheel+input" || fail "useradd sin wheel+input"
grep -q 'chpasswd' "$PROFILE/usr/local/bin/nimbus-live-user" \
  && pass "fija contraseña live" || fail "sin chpasswd"
grep -q 'sudo env' "$PROFILE/usr/local/bin/nimbus-live-installer" \
  && pass "instalador live usa sudo env" || fail "instalador live sin sudo env"

echo "== live: systemd + SDDM =="
grep -q 'Before=display-manager.service' \
  "$PROFILE/etc/systemd/system/nimbus-live-user.service" \
  && pass "live-user corre antes del greeter" || fail "sin Before=display-manager"
grep -q 'WantedBy=multi-user.target' \
  "$PROFILE/etc/systemd/system/nimbus-live-user.service" \
  && pass "live-user en multi-user.target" || fail "sin WantedBy"
[ -L "$PROFILE/etc/systemd/system/multi-user.target.wants/nimbus-live-user.service" ] \
  && pass "live-user enabled" || fail "live-user no enabled"
[ -L "$PROFILE/etc/systemd/system/display-manager.service" ] \
  && [ "$(readlink "$PROFILE/etc/systemd/system/display-manager.service")" = "/usr/lib/systemd/system/sddm.service" ] \
  && pass "display-manager -> sddm" || fail "display-manager no apunta a sddm"

echo "== live: sudoers y autostart =="
grep -qx 'nimbus ALL=(ALL) NOPASSWD: ALL' \
  "$PROFILE/etc/sudoers.d/10-nimbus-live" \
  && pass "sudoers live NOPASSWD" || fail "sudoers live incorrecto"
grep -q '^Exec=/usr/local/bin/nimbus-live-installer' \
  "$PROFILE/etc/xdg/autostart/nimbus-installer.desktop" \
  && pass "autostart Calamares live" || fail "autostart live incorrecto"

echo "== live: integración en build/CI =="
grep -q 'nimbus-live-user' "$REPO_ROOT/iso/build-iso.sh" \
  && pass "build-iso exige live-user" || fail "build-iso no valida live-user"
grep -q 'nimbus-live-user' "$REPO_ROOT/iso/profile/profiledef.sh" \
  && pass "profiledef fija permisos live" || fail "profiledef sin permisos live"
grep -q 'ydotoold.service' "$REPO_ROOT/tests/bar/test_autostart.sh" \
  && pass "ydotoold cubierto por test_autostart" || fail "ydotoold sin test"

echo
if [ "$FAILS" -eq 0 ]; then echo "LIVE USER VERDE."; exit 0; fi
echo "LIVE USER ROJO: $FAILS fallo(s)." >&2
exit 1
