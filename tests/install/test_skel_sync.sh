#!/usr/bin/env bash
# tests/install/test_skel_sync.sh — port aditivo dotfiles → skel.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d /tmp/opencode/nimbus-skel-sync-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM
SRC="$TMP/src"
DEST="$TMP/skel"
mkdir -p "$SRC/.config/plasma" "$SRC/.config/kitty" "$DEST/.config/hypr" \
         "$DEST/.local/bin" "$DEST/Desktop" "$DEST/.config/kitty"
printf 'kwinrc\n' > "$SRC/.config/kwinrc"
printf 'page\n' > "$SRC/.config/plasma/main.qml"
printf 'kitty nuevo\n' > "$SRC/.config/kitty/kitty.conf"
printf 'hypr legacy\n' > "$DEST/.config/hypr/hyprland.conf"
printf 'wrapper\n' > "$DEST/.local/bin/macshell-start"
printf 'iso\n' > "$DEST/Desktop/Instalar NimbusOS.desktop"
printf 'kitty viejo\n' > "$DEST/.config/kitty/kitty.conf"

echo "== skel-sync: check inicial (debe fallar) =="
if "$REPO_ROOT/scripts/nimbus-skel-sync" --check --src "$SRC" --dest "$DEST" >/tmp/opencode/test-skel-check1.log 2>&1; then
    bad "check inicial no detectó diferencias"
else
    ok "check inicial detecta diferencias"
fi
grep -q '\[FALTA\] .config/kwinrc' /tmp/opencode/test-skel-check1.log && ok "reporta falta kwinrc" || bad "no reporta falta kwinrc"
grep -q '\[DIFIERE\] .config/kitty/kitty.conf' /tmp/opencode/test-skel-check1.log && ok "reporta kitty distinto" || bad "no reporta kitty"

echo "== skel-sync: apply =="
if out="$("$REPO_ROOT/scripts/nimbus-skel-sync" --apply --src "$SRC" --dest "$DEST" 2>&1)"; then
    ok "apply"
else
    bad "apply falló"; echo "$out"
fi
grep -q 'SKEL_SYNC_APPLIED' <<<"$out" && ok "marcador apply" || bad "sin marcador apply"
grep -q 'kwinrc' "$DEST/.config/kwinrc" && ok "kwinrc copiado" || bad "kwinrc no copiado"
grep -q 'kitty nuevo' "$DEST/.config/kitty/kitty.conf" && ok "kitty actualizado" || bad "kitty no actualizado"
[ -f "$DEST/.config/hypr/hyprland.conf" ] && ok "legacy hypr intacto" || bad "legacy hypr borrado"
[ -f "$DEST/.local/bin/macshell-start" ] && ok "wrapper ISO intacto" || bad "wrapper borrado"
[ -f "$DEST/Desktop/Instalar NimbusOS.desktop" ] && ok "Desktop ISO intacto" || bad "Desktop borrado"

echo "== skel-sync: check final (debe pasar) =="
if out="$("$REPO_ROOT/scripts/nimbus-skel-sync" --check --src "$SRC" --dest "$DEST" 2>&1)"; then
    ok "check final verde"
else
    bad "check final falló"; echo "$out"
fi
grep -q 'SKEL_SYNC_OK' <<<"$out" && ok "marcador OK" || bad "sin marcador OK"

echo "== skel-sync: extra no permitido =="
printf 'x\n' > "$DEST/.config/extra-inesperado"
if "$REPO_ROOT/scripts/nimbus-skel-sync" --check --src "$SRC" --dest "$DEST" >/tmp/opencode/test-skel-extra.log 2>&1; then
    bad "no detectó extra inesperado"
else
    ok "detecta extra inesperado"
fi
rm -f "$DEST/.config/extra-inesperado"

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
