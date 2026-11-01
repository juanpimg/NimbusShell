#!/usr/bin/env bash
# Tests F9-T05: migrador Windows/Mac con HOME temporal (nunca ~/.config real).
set -u
MIG="apps/nimbus-migrate/nimbus-migrate-desktop"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "ok: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FALLO: $1"; }

check_fixture() { # $1 nombre $2 fixture $3 marca equivalencias $4 importado que rollback debe borrar
    local NAME="$1" FIX="$2" WANT="$3" GONE="$4" H BEFORE N GEN
    H="$(mktemp -d /tmp/opencode/f9t05-XXXXXX)"
    echo "intruso" > "$H/intruso.txt"

    # 1. dry-run no escribe nada
    BEFORE="$(find "$H" -type f | sort)"
    "$MIG" --source "$FIX" --home "$H" --dry-run > /tmp/opencode/f9t05-"$NAME"-dry.txt || bad "$NAME: dry-run exit!=0"
    [ "$(find "$H" -type f | sort)" = "$BEFORE" ] && ok "$NAME: dry-run no escribe" || bad "$NAME: dry-run escribió"
    grep -q "tipos migrables: [3-9]" /tmp/opencode/f9t05-"$NAME"-dry.txt && ok "$NAME: dry-run 3+ tipos" || bad "$NAME: dry-run <3 tipos"

    # 2. apply importa 3+ tipos
    "$MIG" --source "$FIX" --home "$H" --apply > /tmp/opencode/f9t05-"$NAME"-apply.txt || bad "$NAME: apply exit!=0"
    N=0
    [ -f "$H/Documents/nota.txt" ] && N=$((N+1))
    grep -q "https://" "$H/.local/share/nimbus-migrate/bookmarks.html" 2>/dev/null && N=$((N+1))
    ls "$H"/Pictures/fondo-importado.* > /dev/null 2>&1 && N=$((N+1))
    grep -q "$WANT" "$H/.local/share/nimbus-migrate/equivalencias.txt" 2>/dev/null && N=$((N+1))
    grep -q "BreezeDark" "$H/.config/kdeglobals" 2>/dev/null && N=$((N+1))
    [ "$N" -ge 3 ] && ok "$NAME: apply importa $N tipos (>=3)" || bad "$NAME: apply solo $N tipos"
    grep -q "NO migrable" /tmp/opencode/f9t05-"$NAME"-apply.txt && ok "$NAME: informe no-migrable" || bad "$NAME: falta informe"
    ls -d "$H/.config"/nimbusshell-backup-* > /dev/null 2>&1 && ok "$NAME: backup creado" || bad "$NAME: sin backup"
    [ ! -e "$H/Documents/app-setup.exe" ] && [ ! -e "$H/Downloads/musica.dmg" ] && ok "$NAME: ejecutables excluidos" || bad "$NAME: copió ejecutables"

    # 3. no sobrescribe: fichero previo intacto + idempotente
    echo "MIO" > "$H/Documents/nota.txt"
    GEN="$(md5sum "$H/.local/share/nimbus-migrate/bookmarks.html" "$H/.local/share/nimbus-migrate/equivalencias.txt" "$H/.config/kdeglobals" | md5sum)"
    "$MIG" --source "$FIX" --home "$H" --apply > /dev/null || bad "$NAME: re-apply exit!=0"
    [ "$(cat "$H/Documents/nota.txt")" = "MIO" ] && ok "$NAME: no sobrescribe" || bad "$NAME: sobrescribió"
    [ "$(md5sum "$H/.local/share/nimbus-migrate/bookmarks.html" "$H/.local/share/nimbus-migrate/equivalencias.txt" "$H/.config/kdeglobals" | md5sum)" = "$GEN" ] && ok "$NAME: idempotente" || bad "$NAME: re-apply cambió generados"

    # 4. rollback restaura (kdeglobals previo marcado)
    echo "PREVIO" > "$H/.config/kdeglobals"
    echo "mio-previo" > "$H/Documents/previo-mio.txt"  # nunca importado: debe sobrevivir
    "$MIG" --source "$FIX" --home "$H" --apply > /dev/null || bad "$NAME: apply2 exit!=0"
    "$MIG" --source "$FIX" --home "$H" --rollback --apply | grep -q ROLLBACK_OK && ok "$NAME: rollback ok" || bad "$NAME: rollback falló"
    [ "$(cat "$H/.config/kdeglobals")" = "PREVIO" ] && ok "$NAME: rollback restaura" || bad "$NAME: rollback no restaura"
    [ ! -e "$H/$GONE" ] && ok "$NAME: rollback borra importados" || bad "$NAME: rollback dejó $GONE"
    [ "$(cat "$H/Documents/previo-mio.txt")" = "mio-previo" ] && ok "$NAME: rollback respeta no-importados" || bad "$NAME: rollback borró de más"

    # 5. no toca ficheros ajenos + --json
    [ "$(cat "$H/intruso.txt")" = "intruso" ] && ok "$NAME: ajenos intactos" || bad "$NAME: tocó ajenos"
    "$MIG" --source "$FIX" --home "$H" --dry-run --json | grep -q '"migrated_types"' && ok "$NAME: --json" || bad "$NAME: --json roto"
    rm -rf "$H"
}

check_fixture "win" "tests/migrate/fixtures/win-home" "LibreOffice Writer" "Documents/informe.docx"
check_fixture "mac" "tests/migrate/fixtures/mac-home" "Thunderbird" "Documents/presupuesto.numbers"
echo "== $PASS ok, $FAIL fallos =="
[ "$FAIL" -eq 0 ]
