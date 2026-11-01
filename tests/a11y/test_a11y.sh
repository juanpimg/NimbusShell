#!/usr/bin/env bash
# F11-T04 — Tests de accesibilidad (sin VM, sin root, sin red).
# Cada feature: --apply/--check/--revert en un HOME temporal virgen,
# claves verificadas con kreadconfig6. Nunca toca el host.
#
# Uso: bash tests/a11y/test_a11y.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
A11Y="$REPO_ROOT/scripts/nimbus-a11y"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  ok: $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FALLO: $1"; }

if [ "$(id -u)" = "0" ]; then echo "ERROR: estos tests no corren como root." >&2; exit 1; fi
command -v kreadconfig6 >/dev/null 2>&1 || { echo "ERROR: falta kreadconfig6." >&2; exit 1; }
command -v kwriteconfig6 >/dev/null 2>&1 || { echo "ERROR: falta kwriteconfig6." >&2; exit 1; }

BASE_TMP="$(mktemp -d /tmp/opencode/nimbus-a11y-test-XXXXXX)"
chmod 700 "$BASE_TMP"
cleanup() { rm -rf "$BASE_TMP" || echo "WARN: no se pudo borrar $BASE_TMP" >&2; }
trap cleanup EXIT INT TERM

cfg() { # <home> <args kreadconfig6...>
  local h="$1"; shift
  XDG_CONFIG_HOME="$h/.config" kreadconfig6 "$@" 2>/dev/null
}

expect_key() { # <home> <file> <group> <key> <valor> <desc>
  local got
  got="$(cfg "$1" --file "$2" --group "$3" --key "$4")"
  if [ "$got" = "$5" ]; then ok "$6"; else bad "$6 (esperado [$5], obtenido [$got])"; fi
}

echo "-- lint: bash -n + shellcheck cero warnings"
bash -n "$A11Y" && ok "bash -n nimbus-a11y" || bad "bash -n nimbus-a11y"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$A11Y" && ok "shellcheck nimbus-a11y" || bad "shellcheck nimbus-a11y"
else
  bad "shellcheck ausente (no verificable)"
fi

echo "-- --list ofrece los 8 features"
for f in orca zoom contrast stickykeys bouncekeys slowkeys reduce-motion reduce-transparency; do
  "$A11Y" --list | grep -Fxq "$f" && ok "list contiene $f" || bad "list contiene $f"
done

echo "-- --check es solo lectura (no crea nada)"
H0="$BASE_TMP/home-readonly"; mkdir -p "$H0/.config"
"$A11Y" --check --home "$H0" >/dev/null || bad "--check sale 0 en HOME virgen"
[ -z "$(ls -A "$H0/.config")" ] && ok "--check no escribe en HOME" || bad "--check no escribe en HOME"

echo "-- feature desconocido falla con mensaje"
if "$A11Y" --apply inventado --home "$H0" 2>"$BASE_TMP/err.txt"; then
  bad "--apply inventado debe fallar"
else
  grep -q "desconocido" "$BASE_TMP/err.txt" && ok "--apply inventado falla accionable" || bad "--apply inventado falla accionable"
fi

# Tabla feature -> fichero/grupo/clave/valor esperado tras --apply.
while IFS='|' read -r feat file group key val; do
  [ -n "$feat" ] || continue
  H="$BASE_TMP/home-$feat"; mkdir -p "$H/.config"
  echo "-- $feat"
  "$A11Y" --apply "$feat" --home "$H" >/dev/null 2>"$BASE_TMP/$feat.log" || {
    bad "--apply $feat sale 0"; continue
  }
  ok "--apply $feat sale 0"
  [ "$(cfg "$H" --file "$file" --group "$group" --key "$key")" = "$val" ] &&
    ok "$feat: $file [$group] $key=$val" ||
    bad "$feat: $file [$group] $key=$val"
  "$A11Y" --check --home "$H" | grep -Fq "$feat=on" &&
    ok "$feat: --check lo ve on" || bad "$feat: --check lo ve on"
  # Idempotencia: segundo apply deja el mismo valor.
  "$A11Y" --apply "$feat" --home "$H" >/dev/null 2>&1 &&
    [ "$(cfg "$H" --file "$file" --group "$group" --key "$key")" = "$val" ] &&
    ok "$feat: re-apply idempotente" || bad "$feat: re-apply idempotente"
  # Revert: dos reverts (por el doble apply) devuelven al estado virgen.
  "$A11Y" --revert --home "$H" >/dev/null 2>&1
  "$A11Y" --revert --home "$H" >/dev/null 2>&1
  "$A11Y" --check --home "$H" | grep -Fq "$feat=off" &&
    ok "$feat: --revert lo deja off" || bad "$feat: --revert lo deja off"
done <<'EOF'
zoom|kwinrc|Plugins|zoomEnabled|true
contrast|kdeglobals|General|ColorScheme|NimbusHighContrast
stickykeys|kaccessrc|Keyboard|StickyKeys|true
bouncekeys|kaccessrc|Keyboard|BounceKeys|true
slowkeys|kaccessrc|Keyboard|SlowKeys|true
reduce-motion|kwinrc|Compositing|AnimationSpeed|0
reduce-transparency|kwinrc|Plugins|blurEnabled|false
EOF

echo "-- claves extra de cada feature (re-apply en HOME fresco)"
H="$BASE_TMP/home-extra"; mkdir -p "$H/.config"
"$A11Y" --apply reduce-motion --home "$H" >/dev/null 2>&1
expect_key "$H" kwinrc Plugins magiclampEnabled false "reduce-motion apaga Genie (magiclamp)"
expect_key "$H" kwinrc Effect-fade FadeInTime 150 "reduce-motion fade-in 150ms (contrato §2.5)"
"$A11Y" --apply reduce-transparency --home "$H" >/dev/null 2>&1
expect_key "$H" kwinrc Plugins translucencyEnabled false "reduce-transparency apaga translucency"
"$A11Y" --apply bouncekeys --home "$H" >/dev/null 2>&1
expect_key "$H" kaccessrc Keyboard BounceKeysDelay 500 "bouncekeys fija retardo 500ms"
"$A11Y" --apply slowkeys --home "$H" >/dev/null 2>&1
expect_key "$H" kaccessrc Keyboard SlowKeysDelay 500 "slowkeys fija retardo 500ms"
"$A11Y" --apply contrast --home "$H" >/dev/null 2>&1
[ -f "$H/.local/share/color-schemes/NimbusHighContrast.colors" ] &&
  ok "contrast instala el .colors en el HOME" || bad "contrast instala el .colors en el HOME"
"$A11Y" --apply all --home "$H" >/dev/null 2>&1
"$A11Y" --check --home "$H" | grep -c "=on" | grep -Fq "8" &&
  ok "--apply all activa los 8" || bad "--apply all activa los 8"

echo "-- orca sin Orca instalado: avisa y guarda igual"
if command -v orca >/dev/null 2>&1; then
  echo "  salto: Orca sí instalado aquí (el aviso solo aplica sin Orca)"
else
  HO="$BASE_TMP/home-orca"; mkdir -p "$HO/.config"
  "$A11Y" --apply orca --home "$HO" >"$BASE_TMP/orca.log" 2>&1
  grep -q "Orca no está instalado" "$BASE_TMP/orca.log" &&
    ok "orca ausente avisa" || bad "orca ausente avisa"
  expect_key "$HO" kaccessrc ScreenReader Enabled true "orca guarda el espejo kaccessrc igual"
fi

echo "-- kaccessrc canónico: defaults Nimbus"
grep -Fq "StickyKeys=false" "$REPO_ROOT/dotfiles/.config/kaccessrc" &&
  ok "canónico sticky off" || bad "canónico sticky off"
grep -Fq "VisibleBell=true" "$REPO_ROOT/dotfiles/.config/kaccessrc" &&
  ok "canónico aviso visible" || bad "canónico aviso visible"

echo "== $PASS ok, $FAIL fallos"
[ "$FAIL" = "0" ]
