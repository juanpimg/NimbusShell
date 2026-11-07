#!/usr/bin/env bash
# test_security.sh — F2-T09: validación de seguridad base del sistema
# Cubre:
#   1. Telemetría KDE desactivada (PlasmaUserFeedback con FeedbackLevel=0 en dotfiles y skel)
#   2. scripts/nimbus-privacy: dry-run (--check), aplicación en HOME temporal y purga de UserFeedback.*
#   3. scripts/nimbus-flatpak-perms: política de aislamiento y dry-run
#   4. firewalld habilitado en services.conf y nimbus-installed-setup
#   5. Particionado LUKS2 documentado en partition.conf
#   6. Chequeo estático de tests/vm/security-check.sh
set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }

echo "== security: telemetría KDE desactivada =="
FB_CANON="$REPO_ROOT/dotfiles/.config/PlasmaUserFeedback"
FB_PLASMA="$REPO_ROOT/dotfiles/.config/plasma/PlasmaUserFeedback"

if [ -f "$FB_CANON" ] && [ -f "$FB_PLASMA" ]; then
    if cmp -s "$FB_CANON" "$FB_PLASMA"; then
        pass "PlasmaUserFeedback canónico == plasma (cmp)"
    else
        fail "PlasmaUserFeedback canónico y plasma divergen"
    fi
else
    fail "falta PlasmaUserFeedback en dotfiles"
fi

if grep -q '^FeedbackLevel=0' "$FB_CANON" 2>/dev/null; then
    pass "dotfiles/.config/PlasmaUserFeedback FeedbackLevel=0"
else
    fail "dotfiles/.config/PlasmaUserFeedback no tiene FeedbackLevel=0"
fi

SETUP="$REPO_ROOT/iso/profile/airootfs/usr/local/bin/nimbus-installed-setup"
if grep -q 'FeedbackLevel=0' "$SETUP" 2>/dev/null; then
    pass "nimbus-installed-setup configura FeedbackLevel=0 en /etc/xdg"
else
    fail "nimbus-installed-setup no fija FeedbackLevel=0"
fi

echo "== security: firewall y servicios =="
SERVICES_CONF="$REPO_ROOT/iso/calamares/modules/services.conf"
if [ -f "$SERVICES_CONF" ] && grep -q 'firewalld' "$SERVICES_CONF"; then
    pass "calamares/services.conf habilita firewalld"
else
    fail "calamares/services.conf no incluye firewalld"
fi

if grep -q 'firewalld' "$SETUP"; then
    pass "nimbus-installed-setup habilita firewalld"
else
    fail "nimbus-installed-setup no habilita firewalld"
fi

echo "== security: particionado LUKS2 =="
PARTITION_CONF="$REPO_ROOT/iso/calamares/modules/partition.conf"
if [ -f "$PARTITION_CONF" ] && grep -qi 'LUKS' "$PARTITION_CONF"; then
    pass "calamares/partition.conf documenta soporte LUKS2"
else
    fail "falta referencia a LUKS en partition.conf"
fi

echo "== security: nimbus-privacy en HOME temporal =="
PRIVACY_SCRIPT="$REPO_ROOT/scripts/nimbus-privacy"
if [ -x "$PRIVACY_SCRIPT" ]; then
    # Test --check (dry-run)
    if "$PRIVACY_SCRIPT" --check >/dev/null 2>&1; then
        pass "nimbus-privacy --check exit 0"
    else
        fail "nimbus-privacy --check falló"
    fi

    # Test aplicación en HOME temporal con purga de ficheros simulados
    TMP_SEC="$(mktemp -d /tmp/opencode/sec-test-XXXXXX)"
    cleanup() { rm -rf "$TMP_SEC"; }
    trap cleanup EXIT

    mkdir -p "$TMP_SEC/home/.config" "$TMP_SEC/home/.local/state"
    touch "$TMP_SEC/home/.local/state/UserFeedback.testapp1"
    touch "$TMP_SEC/home/.local/state/UserFeedback.testapp2"

    if HOME="$TMP_SEC/home" XDG_CONFIG_HOME="$TMP_SEC/home/.config" XDG_STATE_HOME="$TMP_SEC/home/.local/state" \
       "$PRIVACY_SCRIPT" >/dev/null 2>&1; then
        pass "nimbus-privacy aplicación real exit 0"
    else
        fail "nimbus-privacy aplicación real falló"
    fi

    # Verificar que los datos de telemetría fueron purgados
    REMAINING="$(find "$TMP_SEC/home/.local/state" -maxdepth 1 -name 'UserFeedback.*' | wc -l)"
    if [ "$REMAINING" -eq 0 ]; then
        pass "UserFeedback.* purgados con éxito (0 restos)"
    else
        fail "quedan $REMAINING ficheros UserFeedback.* sin purgar"
    fi

    # Idempotencia
    if HOME="$TMP_SEC/home" XDG_CONFIG_HOME="$TMP_SEC/home/.config" XDG_STATE_HOME="$TMP_SEC/home/.local/state" \
       "$PRIVACY_SCRIPT" >/dev/null 2>&1; then
        pass "nimbus-privacy re-ejecución idempotente exit 0"
    else
        fail "nimbus-privacy re-ejecución falló"
    fi
else
    fail "scripts/nimbus-privacy ausente o no ejecutable"
fi

echo "== security: nimbus-flatpak-perms =="
FLATPAK_SCRIPT="$REPO_ROOT/scripts/nimbus-flatpak-perms"
if [ -x "$FLATPAK_SCRIPT" ]; then
    if "$FLATPAK_SCRIPT" --check >/dev/null 2>&1; then
        pass "nimbus-flatpak-perms --check exit 0"
    else
        fail "nimbus-flatpak-perms --check falló"
    fi
else
    fail "scripts/nimbus-flatpak-perms ausente o no ejecutable"
fi

echo "== security: arnés VM security-check.sh =="
SEC_VM="$REPO_ROOT/tests/vm/security-check.sh"
if [ -f "$SEC_VM" ]; then
    if bash -n "$SEC_VM" && shellcheck -S warning "$SEC_VM"; then
        pass "security-check.sh válido y sin warnings de shellcheck"
    else
        fail "security-check.sh tiene errores de sintaxis o shellcheck"
    fi
else
    fail "tests/vm/security-check.sh ausente"
fi

echo
if [ "$FAILS" -eq 0 ]; then
    echo "SECURITY VERDE (todos los checks pasan)."
    exit 0
else
    echo "SECURITY ROJO ($FAILS fallos)." >&2
    exit 1
fi
