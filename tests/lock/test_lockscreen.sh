#!/usr/bin/env bash
# tests/lock/test_lockscreen.sh — Suite F10-T04: Lockscreen Nimbus (kscreenlocker).
# Sin root, sin red, modo solo lectura.
set -u

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_THEME="$REPO_ROOT/packages/themes/nimbus-lockscreen"

echo "== lockscreen: metadatos y estructura =="
[ -f "$LOCK_THEME/metadata.json" ] && ok "metadata.json presente" || bad "metadata.json ausente"
python3 -c "import json; json.load(open('$LOCK_THEME/metadata.json'))" >/dev/null 2>&1 \
  && ok "metadata.json es JSON válido" || bad "metadata.json no es JSON válido"

grep -q '"Id": "org.nimbus.desktop"' "$LOCK_THEME/metadata.json" \
  && ok "metadata.json Id=org.nimbus.desktop" || bad "metadata.json Id incorrecto"

echo "== lockscreen: qmllint =="
if command -v qmllint >/dev/null 2>&1; then
  for qml in LockScreen.qml NimbusLockClock.qml NimbusLockUi.qml NimbusTokens.qml; do
    qmllint "$LOCK_THEME/contents/lockscreen/$qml" >/dev/null 2>&1 \
      && ok "qmllint $qml" || bad "qmllint falló en $qml"
  done
fi

echo "== lockscreen: verificacion de integracion y atajos =="
# Verificar dotfiles kscreenlockerrc
LOCK_CFG="$REPO_ROOT/dotfiles/.config/plasma/kscreenlockerrc"
[ -f "$LOCK_CFG" ] && ok "kscreenlockerrc presente" || bad "kscreenlockerrc ausente"
grep -qE 'Theme=org\.nimbus\.desktop' "$LOCK_CFG" \
  && ok "kscreenlockerrc Theme=org.nimbus.desktop" || bad "kscreenlockerrc no tiene Theme nimbus"
grep -qE 'Autolock=true' "$LOCK_CFG" \
  && ok "kscreenlockerrc Autolock=true" || bad "kscreenlockerrc sin Autolock=true"

# Verificar atajo Meta+Ctrl+Q en kglobalshortcutsrc (≈ Cmd+Ctrl+Q)
SHORTCUTS_CFG="$REPO_ROOT/dotfiles/.config/plasma/kglobalshortcutsrc"
[ -f "$SHORTCUTS_CFG" ] && ok "kglobalshortcutsrc presente" || bad "kglobalshortcutsrc ausente"
grep -q "Lock Session=Meta+Ctrl+Q" "$SHORTCUTS_CFG" \
  && ok "Atajo de bloqueo configurado: Meta+Ctrl+Q" || bad "Falta atajo Lock Session=Meta+Ctrl+Q"

# Verificar bindings esenciales en LockScreen.qml y NimbusLockUi.qml
LOCK_QML="$LOCK_THEME/contents/lockscreen/LockScreen.qml"
UI_QML="$LOCK_THEME/contents/lockscreen/NimbusLockUi.qml"
grep -q "viewVisible" "$LOCK_QML" && ok "LockScreen.qml gestiona viewVisible" || bad "Falta viewVisible"
grep -q "authenticator" "$LOCK_QML" && ok "LockScreen.qml gestiona authenticator" || bad "Falta authenticator"
grep -q "NimbusLockClock" "$UI_QML" && ok "NimbusLockUi.qml incluye NimbusLockClock" || bad "Falta NimbusLockClock"
grep -q "NimbusLockUi" "$LOCK_QML" && ok "LockScreen.qml incluye NimbusLockUi" || bad "Falta NimbusLockUi"

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
