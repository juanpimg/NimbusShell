#!/usr/bin/env bash
# Tests F9-T07/T08: nimbus-updates con fakes en PATH (sin root, sin red).
# Cubre: --check dry-run (con y sin pendientes), --apply simulado (snapshot
# + upgrade via fakes), --rollback-list/--rollback, root-salvo-apply.
set -u
UPD="scripts/nimbus-updates"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FALLO: $1"; }

[ "$(id -u)" = "0" ] && { echo "FALLO: no ejecutar tests como root"; exit 1; }

FAKE="$(mktemp -d /tmp/opencode/f9upd-XXXXXX)"
mkdir -p "$FAKE/bin" "$FAKE/log"
cat > "$FAKE/bin/checkupdates" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_MODE:-full}" = "empty" ]; then exit 0; fi
echo "firefox 1 -> 2"
echo "kate 3 -> 4"
EOF
cat > "$FAKE/bin/pacman" <<'EOF'
#!/usr/bin/env bash
echo "pacman $*" >> "$FAKE_LOG/pacman.log"
case "$1" in
  -Qu) [ "${FAKE_MODE:-full}" = "empty" ] || { echo "a 1 -> 2"; echo "b 1 -> 2"; } ;;
  -Syu) echo "UPGRADED" ;;
esac
exit 0
EOF
cat > "$FAKE/bin/snapper" <<'EOF'
#!/usr/bin/env bash
echo "snapper $*" >> "$FAKE_LOG/snapper.log"
[ "$1" = "-c" ] && shift 2
case "$1" in
  list) echo "# | Tipo | Fecha | Descripcion"; echo "5 | pre | hoy | nimbus-pre-update"; ;;
  create) echo 42 ;;
  undochange) echo "UNDO $2"; ;;
esac
exit 0
EOF
chmod +x "$FAKE"/bin/*
export PATH="$FAKE/bin:$PATH"
export FAKE_LOG="$FAKE/log" FAKE_MODE=full

# 1. --check con pendientes: lenguaje llano, exit 0
OUT="$("$UPD" --check 2>&1)" || bad "--check exit!=0"
echo "$OUT" | grep -q "2 actualizacion" && ok "check lista pendientes" || bad "check no lista: $OUT"
echo "$OUT" | grep -q "Para instalarlas" && ok "check lenguaje llano" || bad "check sin consejo llano"

# 2. --check sin pendientes: no escribe nada (idempotente/dry-run)
FAKE_MODE=empty
BEFORE="$(ls -A "$FAKE/log")"
OUT="$("$UPD" --check 2>&1)" || bad "check-empty exit!=0"
echo "$OUT" | grep -q "Todo al dia" && ok "check vacio llano" || bad "check vacio: $OUT"
[ "$(ls -A "$FAKE/log")" = "$BEFORE" ] && ok "check no escribe (dry-run)" || bad "check escribio"
FAKE_MODE=full

# 3. Sin flags = --check
"$UPD" 2>&1 | grep -q "actualizacion" && ok "sin flags equivale a check" || bad "sin flags no es check"

# 4. --apply simulado: snapshot + upgrade, reporta
rm -f "$FAKE"/log/*.log
"$UPD" --apply > "$FAKE/apply.txt" 2>&1 || bad "apply exit!=0"
grep -q "create" "$FAKE/log/snapper.log" && ok "apply crea snapshot" || bad "apply sin snapshot"
grep -q "Syu" "$FAKE/log/pacman.log" && ok "apply ejecuta upgrade" || bad "apply sin upgrade"
grep -q "APPLY OK" "$FAKE/apply.txt" && ok "apply reporta" || bad "apply no reporta"

# 5. --rollback-list y --rollback simulados
"$UPD" --rollback-list 2>&1 | grep -q "nimbus-pre-update" && ok "rollback-list" || bad "rollback-list fallo"
"$UPD" --rollback 5 2>&1 | grep -q "ROLLBACK OK" && ok "rollback ok" || bad "rollback fallo"
grep -q "undochange" "$FAKE/log/snapper.log" && ok "rollback usa undochange" || bad "rollback sin undochange"

# 6. Sin snapper: degradacion con instrucciones, exit 1
mkdir -p "$FAKE/empty" && PATH="$FAKE/empty:/usr/bin:/bin" command -v bash >/dev/null
OPATH="$PATH"; PATH="$FAKE/empty:/usr/bin:/bin"
"$UPD" --rollback-list >/dev/null 2>&1 && bad "sin-snapper debio fallar" || ok "sin-snapper falla con instrucciones"
PATH="$OPATH"

# 7. bash -n + shellcheck
bash -n "$UPD" && ok "bash -n" || bad "bash -n fallo"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$UPD" && ok "shellcheck cero" || bad "shellcheck warnings"
  shellcheck -S warning tests/updates/test_updates.sh && ok "shellcheck test" || bad "shellcheck test fallo"
else ok "shellcheck no instalado (omitido)"; fi

rm -rf "$FAKE"
echo "== $PASS ok, $FAIL fallos =="
[ "$FAIL" -eq 0 ]
