#!/usr/bin/env bash
# tests/install/test_build_components.sh — build real y --check en prefijo aislado.
# Compila nimbus-about (solo Qt6) para no exigir KF6 en cualquier host de CI.
set -u

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d /tmp/opencode/nimbus-build-components-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT INT TERM

if ! command -v cmake >/dev/null 2>&1; then
    echo "SKIP: cmake no disponible"
    exit 0
fi

echo "== build-components: help y check vacío =="
"$REPO_ROOT/scripts/build-components" --help >/dev/null && ok "--help" || bad "--help"
if "$REPO_ROOT/scripts/build-components" --check --prefix "$TMP/prefix" --filter nimbus-about >/dev/null 2>&1; then
    bad "--check vacío debería fallar"
else
    ok "--check vacío detecta ausencia"
fi

echo "== build-components: build real de nimbus-about =="
if "$REPO_ROOT/scripts/build-components" --prefix "$TMP/prefix" --build-dir "$TMP/build" \
    --filter nimbus-about >"$TMP/build.log" 2>&1; then
    ok "build+install nimbus-about"
else
    bad "build nimbus-about"; tail -20 "$TMP/build.log"
fi
[ -x "$TMP/prefix/bin/nimbus-about" ] && ok "binario instalado" || bad "falta binario"
[ -f "$TMP/prefix/share/applications/org.nimbus.about.desktop" ] && ok "desktop instalado" || bad "falta desktop"
[ -f "$TMP/prefix/share/icons/hicolor/scalable/apps/nimbus-about.svg" ] && ok "icono instalado" || bad "falta icono"

echo "== build-components: --check verde =="
if out="$("$REPO_ROOT/scripts/build-components" --check --prefix "$TMP/prefix" --filter nimbus-about 2>&1)"; then
    ok "--check verde"
else
    bad "--check falló"; echo "$out"
fi
grep -q 'BUILD_COMPONENTS_CHECK_OK' <<<"$out" && ok "marcador OK" || bad "sin marcador OK"

echo "== build-components: KCM en prefijo aislado =="
if "$REPO_ROOT/scripts/build-components" --prefix "$TMP/prefix" --build-dir "$TMP/build" \
    --filter kcm_nimbus >"$TMP/build-kcm.log" 2>&1; then
    ok "build+install kcm_nimbus"
else
    bad "build kcm_nimbus"; tail -20 "$TMP/build-kcm.log"
fi
KCM_PLUGIN="$TMP/prefix/lib/qt6/plugins/plasma/kcms/systemsettings/kcm_nimbus.so"
[ -f "$KCM_PLUGIN" ] && ok "plugin KCM instalado" || bad "falta plugin KCM"
[ -f "$TMP/prefix/share/applications/kcm_nimbus.desktop" ] && ok "desktop KCM" || bad "falta desktop KCM"
[ -f "$TMP/prefix/share/kpackage/kcms/kcm_nimbus/metadata.json" ] && ok "metadata KCM" || bad "falta metadata KCM"
if out="$("$REPO_ROOT/scripts/build-components" --check --prefix "$TMP/prefix" --filter kcm_nimbus 2>&1)"; then
    ok "--check KCM verde"
else
    bad "--check KCM falló"; echo "$out"
fi

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
