#!/usr/bin/env bash
# tests/theme/test_themes_deploy.sh — integración de themes_deploy/themes_check.
# Sin root y sin efecto en la sesión real: HOME y destinos temporales.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d /tmp/opencode/nimbus-themes-deploy-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

export HOME="$TMP/home"
export NIMBUS_NO_LIVE=1
export THEME_WALLPAPER_DST="$TMP/system-sequoia.jpg"
export THEME_LOGO_DST="$TMP/system-logo.svg"
export SOUNDS_DST="$HOME/.local/share/sounds/Nimbus"
export THEME_STAMP="$HOME/.config/nimbus-theme-applied"
mkdir -p "$HOME"
cp "$REPO_ROOT/assets/sequoia-light.jpg" "$THEME_WALLPAPER_DST"
cp "$REPO_ROOT/assets/nimbus-logo.svg" "$THEME_LOGO_DST"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/themes.sh"

echo "== tema: despliegue inicial (dark) =="
if out="$(themes_deploy 2>&1)"; then ok "themes_deploy"; else bad "themes_deploy falló"; echo "$out"; fi
grep -q 'APPLY_OK variant=dark' <<<"$out" && ok "apply-theme dark ejecutado" || bad "apply-theme dark no ejecutado"
[ -f "$THEME_STAMP" ] && ok "stamp presente" || bad "falta stamp"
[ -f "$HOME/.local/share/color-schemes/NimbusTahoe.colors" ] && ok "color scheme dark" || bad "falta color scheme dark"
[ -d "$HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Dark" ] && ok "Aurorae dark" || bad "falta Aurorae dark"
[ -f "$SOUNDS_DST/index.theme" ] && ok "sonidos Nimbus" || bad "faltan sonidos Nimbus"
ls "$SOUNDS_DST"/stereo/*.oga >/dev/null 2>&1 && ok "sonidos .oga" || bad "faltan .oga"

echo "== tema: segunda ejecución respeta la variante =="
if out="$(themes_deploy 2>&1)"; then ok "themes_deploy idempotente"; else bad "themes_deploy idempotente falló"; fi
grep -q 'tema ya aplicado' <<<"$out" && ok "no re-aplica el tema" || bad "re-aplicó el tema"
[ "$(awk 'NR==1 {print $1}' "$THEME_STAMP")" = "dark" ] && ok "variante dark intacta" || bad "variante alterada"

echo "== tema: check verde =="
CHECK_FAIL=0
if themes_check >/tmp/opencode/test-themes-check.log 2>&1 && [ "$CHECK_FAIL" = "0" ]; then
  ok "themes_check sin drift"
else
  bad "themes_check marcó drift"; cat /tmp/opencode/test-themes-check.log
fi

echo "== tema: variante light =="
"$REPO_ROOT/scripts/apply-theme" --variant light >/tmp/opencode/test-themes-light.log 2>&1 \
  && ok "apply-theme light" || bad "apply-theme light falló"
out="$(themes_deploy 2>&1)"
[ "$(awk 'NR==1 {print $1}' "$THEME_STAMP")" = "light" ] && ok "variante light respetada" || bad "themes_deploy pisó light"
CHECK_FAIL=0
if themes_check >/tmp/opencode/test-themes-check-light.log 2>&1 && [ "$CHECK_FAIL" = "0" ]; then
  ok "themes_check light sin drift"
else
  bad "themes_check light marcó drift"; cat /tmp/opencode/test-themes-check-light.log
fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
