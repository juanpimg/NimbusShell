#!/usr/bin/env bash
# tests/apps/test_apps_deploy.sh — apps de script desplegadas 1:1 en ~/.local/bin.
# Sin root, HOME temporal, no toca el HOME real.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_HOME="$(mktemp -d /tmp/opencode/nimbus-apps-test-XXXXXX)"
trap 'rm -rf "$TMP_HOME"' EXIT INT TERM

export REPO_ROOT
export HOME="$TMP_HOME"
export APPS_BIN_DIR="$TMP_HOME/.local/bin"
export APPS_DESKTOP_DIR="$TMP_HOME/.local/share/applications"
export XDG_DATA_HOME="$TMP_HOME/.local/share"
export NIMBUS_NO_LIVE=1

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/apps.sh"

echo "== apps: despliegue de scripts =="
if apps_deploy >/tmp/opencode/test-apps-deploy.log 2>&1; then ok "apps_deploy"; else
  bad "apps_deploy falló"; cat /tmp/opencode/test-apps-deploy.log
fi

while IFS= read -r rel; do
  dst="$APPS_BIN_DIR/$(basename "$rel")"
  if [ -x "$dst" ] && cmp -s "$REPO_ROOT/$rel" "$dst"; then
    ok "$(basename "$rel") 1:1 y ejecutable"
  else
    bad "$(basename "$rel") ausente o distinto en $dst"
  fi
done < <(apps_shell_scripts)

while IFS= read -r rel; do
  dst="$APPS_BIN_DIR/$(basename "$rel")"
  if [ -x "$dst" ] && cmp -s "$REPO_ROOT/$rel" "$dst"; then
    ok "$(basename "$rel") 1:1 y ejecutable"
  else
    bad "$(basename "$rel") ausente o distinto en $dst"
  fi
done < <(apps_user_tools)

res="$XDG_DATA_HOME/nimbus"
[ -d "$res/bar/presets" ] && ok "recursos de barra" || bad "faltan presets de barra"
[ -f "$res/bar/pins.txt" ] && ok "pines de barra" || bad "faltan pines de barra"
[ -f "$res/dock/kremarc-nimbus" ] && ok "preset de dock" || bad "falta preset de dock"

if [ -f "$APPS_DESKTOP_DIR/org.nimbus.bugreport.desktop" ] && \
   cmp -s "$REPO_ROOT/apps/nimbus-bug-report/org.nimbus.bugreport.desktop" \
          "$APPS_DESKTOP_DIR/org.nimbus.bugreport.desktop"; then
  ok "org.nimbus.bugreport.desktop"
else
  bad "org.nimbus.bugreport.desktop ausente o distinto"
fi

echo "== apps: idempotencia =="
before="$(find "$APPS_BIN_DIR" -type f | wc -l)"
before_res="$(find "$XDG_DATA_HOME/nimbus" -type f | wc -l)"
if apps_deploy >/tmp/opencode/test-apps-deploy-2.log 2>&1; then ok "segunda ejecución"; else
  bad "segunda ejecución falló"
fi
after="$(find "$APPS_BIN_DIR" -type f | wc -l)"
after_res="$(find "$XDG_DATA_HOME/nimbus" -type f | wc -l)"
[ "$before" = "$after" ] && ok "no duplica binarios ($after ficheros)" || bad "duplicó binarios: $before -> $after"
[ "$before_res" = "$after_res" ] && ok "no duplica recursos ($after_res ficheros)" || bad "duplicó recursos: $before_res -> $after_res"

echo "== apps: --check coherente =="
CHECK_FAIL=0
if apps_check >/tmp/opencode/test-apps-check.log 2>&1; then
  if [ "$CHECK_FAIL" = "0" ]; then ok "apps_check sin drift"; else bad "apps_check marcó drift"; cat /tmp/opencode/test-apps-check.log; fi
else
  bad "apps_check devolvió error"; cat /tmp/opencode/test-apps-check.log
fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
