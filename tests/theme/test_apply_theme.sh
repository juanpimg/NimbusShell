#!/usr/bin/env bash
# test_apply_theme.sh — Test suite para scripts/apply-theme (F2-T04).
# Verifica idempotencia, reversibilidad, variantes light/dark y diff de capturas.
# Sin root, HOME temporal aislado.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d /tmp/nimbus-theme-test-XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT

echo "== [1/6] Test de validación de sintaxis y argumentos =="
bash -n "$REPO_ROOT/scripts/apply-theme"
shellcheck -S warning "$REPO_ROOT/scripts/apply-theme"
"$REPO_ROOT/scripts/apply-theme" --help >/dev/null

echo "== [2/6] Test en HOME temporal: aplicación dark (defecto) =="
mkdir -p "$TMP_HOME/.config"
printf "[General]\nColorScheme=BreezeDark\n" > "$TMP_HOME/.config/kdeglobals"
printf "[org.kde.kdecoration2]\nlibrary=org.kde.breeze\n" > "$TMP_HOME/.config/kwinrc"

HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --variant dark
[ -f "$TMP_HOME/.config/nimbus-theme-applied" ] || { echo "FAIL: falta stamp file"; exit 1; }
[ -f "$TMP_HOME/.config/Kvantum/nimbus.conf" ] || { echo "FAIL: falta Kvantum/nimbus.conf"; exit 1; }
[ -f "$TMP_HOME/.local/share/color-schemes/NimbusTahoe.colors" ] || { echo "FAIL: falta NimbusTahoe.colors"; exit 1; }
[ -f "$TMP_HOME/.local/share/wallpapers/nimbus/contents/images/sequoia-dark.jpg" ] || { echo "FAIL: falta sequoia-dark.jpg"; exit 1; }
[ -d "$TMP_HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Dark" ] || { echo "FAIL: falta decoración Aurorae dark"; exit 1; }
if command -v kwriteconfig6 >/dev/null 2>&1; then
  grep -q 'theme=__aurorae__svg__MacTahoeLiquidKde-Dark' "$TMP_HOME/.config/kwinrc" || { echo "FAIL: kwinrc no usa Aurorae dark"; exit 1; }
  grep -q 'library=org.kde.kwin.aurorae' "$TMP_HOME/.config/kwinrc" || { echo "FAIL: kwinrc no usa la librería Aurorae"; exit 1; }
fi

HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --check --variant dark

echo "== [3/6] Test de idempotencia: re-ejecución sin drift =="
HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --variant dark
HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --check --variant dark

echo "== [4/6] Test de variante light =="
HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --variant light
[ -f "$TMP_HOME/.local/share/color-schemes/NimbusTahoeLight.colors" ] || { echo "FAIL: falta NimbusTahoeLight.colors"; exit 1; }
[ -f "$TMP_HOME/.local/share/wallpapers/nimbus/contents/images/sequoia-light.jpg" ] || { echo "FAIL: falta sequoia-light.jpg"; exit 1; }
[ -d "$TMP_HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Light" ] || { echo "FAIL: falta decoración Aurorae light"; exit 1; }
if command -v kwriteconfig6 >/dev/null 2>&1; then
  grep -q 'theme=__aurorae__svg__MacTahoeLiquidKde-Light' "$TMP_HOME/.config/kwinrc" || { echo "FAIL: kwinrc no usa Aurorae light"; exit 1; }
fi
HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --check --variant light

echo "== [5/6] Test de reversibilidad (--revert) =="
HOME="$TMP_HOME" "$REPO_ROOT/scripts/apply-theme" --revert
[ ! -f "$TMP_HOME/.config/nimbus-theme-applied" ] || { echo "FAIL: stamp file no fue limpiado"; exit 1; }
[ ! -f "$TMP_HOME/.config/Kvantum/nimbus.conf" ] || { echo "FAIL: nimbus.conf no fue limpiado"; exit 1; }
[ ! -d "$TMP_HOME/.local/share/wallpapers/nimbus" ] || { echo "FAIL: wallpapers/nimbus no fue eliminado"; exit 1; }
[ ! -d "$TMP_HOME/.local/share/aurorae/themes/MacTahoeLiquidKde-Dark" ] || { echo "FAIL: decoración Aurorae no fue eliminada"; exit 1; }
grep -q "BreezeDark" "$TMP_HOME/.config/kdeglobals" || { echo "FAIL: kdeglobals no fue restaurado"; exit 1; }
grep -q "org.kde.breeze" "$TMP_HOME/.config/kwinrc" || { echo "FAIL: kwinrc no fue restaurado"; exit 1; }

echo "== [6/6] Verificación diff golden vs captura (compare.sh <= 20%) =="
"$REPO_ROOT/tests/screenshot-diff/compare.sh" \
  "$REPO_ROOT/spikes/nested/f2-theme-base.png" \
  "$REPO_ROOT/spikes/nested/f2-theme.png" \
  --threshold 20

echo "PASS: test_apply_theme.sh completado con éxito."
