#!/usr/bin/env bash
# Tests F9-T09: migrador Hyprland→Plasma con HOME temporal (nunca ~/.config real).
set -u
MIG="apps/nimbus-migrate/nimbus-migrate-hyprland"
FIX="tests/migrate/fixtures/hypr-home"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FALLO: $1"; }
newhome() { H="$(mktemp -d /tmp/opencode/f9t09-XXXXXX)"; cp -r "$FIX"/.config "$H"/; echo "$H"; }

# 1. dry-run no escribe nada
H="$(newhome)"; BEFORE="$(find "$H" -type f | sort)"
"$MIG" --home "$H" --dry-run > /dev/null || bad "dry-run exit!=0"
[ "$(find "$H" -type f | sort)" = "$BEFORE" ] && ok "dry-run no escribe" || bad "dry-run escribió"
echo "intruso" > "$H/intruso.txt"

# 2. apply migra 3+ tipos
"$MIG" --home "$H" --apply > /tmp/opencode/f9t09-apply.txt || bad "apply exit!=0"
N=0
grep -q "sequoia" "$H/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null && N=$((N+1))
grep -q "GapsIn=4" "$H/.config/kwinrc" 2>/dev/null && N=$((N+1))
grep -q "Walk Through Windows" "$H/.config/kglobalshortcutsrc" 2>/dev/null && N=$((N+1))
grep -q "BreezeLight" "$H/.config/kdeglobals" 2>/dev/null && N=$((N+1))
[ "$N" -ge 3 ] && ok "apply migra $N tipos (>=3)" || bad "apply solo $N tipos"
grep -q "NO migrable" /tmp/opencode/f9t09-apply.txt && ok "informe no-migrable" || bad "falta informe"
ls -d "$H/.config"/nimbusshell-backup-* > /dev/null 2>&1 && ok "backup creado" || bad "sin backup"

# 3. idempotente: segunda pasada no cambia nada
SUM1="$(md5sum "$H"/.config/kwinrc "$H"/.config/kdeglobals | md5sum)"
"$MIG" --home "$H" --apply > /dev/null || bad "re-apply exit!=0"
[ "$(md5sum "$H"/.config/kwinrc "$H"/.config/kdeglobals | md5sum)" = "$SUM1" ] && ok "idempotente" || bad "re-apply cambió ficheros"

# 4. rollback restaura (kwinrc previo marcado)
echo "PREVIO" > "$H/.config/kwinrc"
"$MIG" --home "$H" --apply > /dev/null || bad "apply2 exit!=0"
"$MIG" --home "$H" --rollback --apply | grep -q ROLLBACK_OK && ok "rollback ok" || bad "rollback falló"
[ "$(cat "$H/.config/kwinrc")" = "PREVIO" ] && ok "rollback restaura" || bad "rollback no restaura"

# 5. no toca ficheros ajenos + --json
[ "$(cat "$H/intruso.txt")" = "intruso" ] && ok "ajenos intactos" || bad "tocó ajenos"
"$MIG" --home "$H" --dry-run --json | grep -q '"migrated_types"' && ok "--json" || bad "--json roto"
rm -rf "$H"
echo "== $PASS ok, $FAIL fallos =="
[ "$FAIL" -eq 0 ]
