#!/usr/bin/env bash
# tests/calamares/test_calamares_config.sh — Validador F9-T01:
# Calamares pulido: comprueba settings.conf, branding.desc, módulos conf,
# scripts referenciados, permisos ejecutables y slideshow QML.
# Sin root, sin red, modo solo-lectura.
set -u

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAL_DIR="$REPO_ROOT/iso/calamares"

echo "== calamares: validación de estructura y ficheros =="

[ -d "$CAL_DIR" ] && ok "Directorio iso/calamares presente" || bad "Falta iso/calamares"
[ -f "$CAL_DIR/settings.conf" ] && ok "settings.conf presente" || bad "Falta settings.conf"
[ -f "$CAL_DIR/branding/nimbus/branding.desc" ] && ok "branding.desc presente" || bad "Falta branding.desc"

# Comprobar sintaxis YAML básica en todos los .conf
python3 -c "
import yaml, glob, sys
for path in glob.glob('$CAL_DIR/modules/*.conf') + ['$CAL_DIR/settings.conf', '$CAL_DIR/branding/nimbus/branding.desc']:
    with open(path, 'r', encoding='utf-8') as fh:
        try:
            yaml.safe_load(fh)
        except Exception as e:
            print(f'Error parseando {path}: {e}', file=sys.stderr)
            sys.exit(1)
print('YAML_OK')
" >/dev/null 2>&1 && ok "Sintaxis YAML válida en todos los módulos y branding" || bad "Error de sintaxis YAML en Calamares"

# Comprobar que todos los scripts referenciados en shellprocess existen y son ejecutables
for script in nimbus-assets.sh nimbus-efi-fallback.sh nimbus-kernel.sh nimbus-pacstrap-patch.sh; do
  p="$CAL_DIR/scripts/$script"
  if [ -x "$p" ]; then
    ok "Script Calamares ejecutable: $script"
  else
    bad "Script Calamares ausente o sin +x: $script"
  fi
  bash -n "$p" && ok "bash -n $script" || bad "bash -n falló en $script"
done

# Comprobar que users.conf tiene 'input' para ydotool
grep -qE '^\s*-\s*input\s*$' "$CAL_DIR/modules/users.conf" \
  && ok "users.conf incluye grupo 'input' para ydotool" \
  || bad "users.conf no incluye grupo 'input'"

# Comprobar slideshow QML
if command -v qmllint >/dev/null 2>&1; then
  qmllint "$CAL_DIR/branding/nimbus/slideshow/slideshow.qml" >/dev/null 2>&1 \
    && ok "qmllint slideshow.qml válido" \
    || bad "qmllint falló en slideshow.qml"
fi

# Comprobar branding.desc
grep -q "productName: NimbusOS" "$CAL_DIR/branding/nimbus/branding.desc" \
  && ok "branding.desc productName=NimbusOS" \
  || bad "branding.desc sin productName NimbusOS"

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
