#!/usr/bin/env bash
# tests/install/test_deploy_home.sh — camino de despliegue del instalador
# (perfil plasma) en un HOME aislado, sin root, sin red y sin tocar el HOME real.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d /tmp/opencode/nimbus-deploy-home-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

export REPO_ROOT
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_BIN_HOME="$HOME/.local/bin"
export NIMBUS_NO_LIVE=1
export APPS_BIN_DIR="$XDG_BIN_HOME"
export APPS_DESKTOP_DIR="$XDG_DATA_HOME/applications"
export THEME_WALLPAPER_DST="$TMP/system-sequoia.jpg"
export THEME_LOGO_DST="$TMP/system-logo.svg"
export SOUNDS_DST="$XDG_DATA_HOME/sounds/Nimbus"
export THEME_RES_DST="$XDG_DATA_HOME/nimbus/themes/nimbus-tahoe"
export APPS_BUILD_DIR="$TMP/build"
export APPS_BUILD_FILTER="nimbus-about"
export NIMBUS_SKIP_KDE_CACHE=1
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
cp "$REPO_ROOT/assets/sequoia-light.jpg" "$THEME_WALLPAPER_DST"
cp "$REPO_ROOT/assets/nimbus-logo.svg" "$THEME_LOGO_DST"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/plasma.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/themes.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/kwin.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/dock.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/apps.sh"

echo "== despliegue: dotfiles =="
if plasma_deploy_dotfiles "$TMP/backup" >/tmp/opencode/test-deploy-dotfiles.log 2>&1; then
    ok "plasma_deploy_dotfiles"
else
    bad "plasma_deploy_dotfiles"; cat /tmp/opencode/test-deploy-dotfiles.log
fi

echo "== despliegue: tema, KWin, dock y apps =="
for fn in themes_deploy kwin_deploy dock_deploy apps_deploy components_deploy; do
    if "$fn" >"/tmp/opencode/test-deploy-$fn.log" 2>&1; then ok "$fn"; else
        bad "$fn"; cat "/tmp/opencode/test-deploy-$fn.log"
    fi
done
[ -x "$APPS_BIN_DIR/nimbus-about" ] && ok "GUI compilada (nimbus-about)" || bad "GUI no compilada"

echo "== verificación: dotfiles 1:1 tras aplicar tema =="
CHECK_FAIL=0
if check_dotfiles "$REPO_ROOT/dotfiles" "$HOME" >/tmp/opencode/test-deploy-dotfiles-check.log 2>&1 && \
   [ "$CHECK_FAIL" = "0" ]; then
    ok "check_dotfiles sin drift tras el tema"
else
    bad "check_dotfiles con drift tras el tema"; cat /tmp/opencode/test-deploy-dotfiles-check.log
fi

echo "== verificación sin drift (themes/kwin/dock/apps) =="
CHECK_FAIL=0
for fn in themes_check kwin_check dock_check apps_check; do
    if out="$("$fn" 2>&1)" && [ "$CHECK_FAIL" = "0" ]; then
        ok "$fn"
    else
        bad "$fn"; printf '%s\n' "$out"
    fi
    CHECK_FAIL=0
done

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
