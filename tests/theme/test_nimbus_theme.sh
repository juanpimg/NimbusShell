#!/usr/bin/env bash
# tests/theme/test_nimbus_theme.sh — nimbus-theme claro/oscuro con Aurorae.
# HOME temporal; sin sesión viva (LIVE=0), así no toca el escritorio real.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d /tmp/opencode/nimbus-theme-switch-XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT INT TERM

if ! command -v kwriteconfig6 >/dev/null 2>&1; then
    echo "SKIP: kwriteconfig6 no disponible (sin KDE en este entorno)"
    exit 0
fi

export HOME="$TMP_HOME"
mkdir -p "$HOME/.config"
printf '[General]\nColorScheme=BreezeDark\n' > "$HOME/.config/kdeglobals"
printf '[org.kde.kdecoration2]\nlibrary=org.kde.breeze\n' > "$HOME/.config/kwinrc"

echo "== nimbus-theme: variante dark =="
if "$REPO_ROOT/scripts/nimbus-theme" dark >/tmp/opencode/test-nimbus-theme-dark.log 2>&1; then ok "dark"; else bad "dark falló"; cat /tmp/opencode/test-nimbus-theme-dark.log; fi
grep -q 'ColorScheme=NimbusTahoe$' "$HOME/.config/kdeglobals" && ok "color scheme dark" || bad "color scheme dark"
grep -q 'theme=__aurorae__svg__MacTahoeLiquidKde-Dark' "$HOME/.config/kwinrc" && ok "Aurorae dark" || bad "Aurorae dark"
[ -d "$HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Dark" ] && ok "ficheros Aurorae dark" || bad "faltan ficheros Aurorae dark"
if "$REPO_ROOT/scripts/nimbus-theme" dark --check >/tmp/opencode/test-nimbus-theme-check-dark.log 2>&1; then ok "check dark"; else bad "check dark"; cat /tmp/opencode/test-nimbus-theme-check-dark.log; fi

echo "== nimbus-theme: variante light =="
if "$REPO_ROOT/scripts/nimbus-theme" light >/tmp/opencode/test-nimbus-theme-light.log 2>&1; then ok "light"; else bad "light falló"; cat /tmp/opencode/test-nimbus-theme-light.log; fi
grep -q 'ColorScheme=NimbusTahoeLight$' "$HOME/.config/kdeglobals" && ok "color scheme light" || bad "color scheme light"
grep -q 'theme=__aurorae__svg__MacTahoeLiquidKde-Light' "$HOME/.config/kwinrc" && ok "Aurorae light" || bad "Aurorae light"
[ -d "$HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Light" ] && ok "ficheros Aurorae light" || bad "faltan ficheros Aurorae light"
if "$REPO_ROOT/scripts/nimbus-theme" light --check >/tmp/opencode/test-nimbus-theme-check-light.log 2>&1; then ok "check light"; else bad "check light"; cat /tmp/opencode/test-nimbus-theme-check-light.log; fi

echo "== nimbus-theme: revert =="
if "$REPO_ROOT/scripts/nimbus-theme" --revert >/tmp/opencode/test-nimbus-theme-revert.log 2>&1; then ok "revert"; else bad "revert falló"; cat /tmp/opencode/test-nimbus-theme-revert.log; fi
grep -q 'ColorScheme=BreezeDark' "$HOME/.config/kdeglobals" && ok "kdeglobals restaurado" || bad "kdeglobals no restaurado"
grep -q 'library=org.kde.breeze' "$HOME/.config/kwinrc" && ok "kwinrc restaurado" || bad "kwinrc no restaurado"
[ ! -f "$HOME/.config/nimbus-theme-applied" ] && ok "stamp eliminado" || bad "stamp no eliminado"

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
