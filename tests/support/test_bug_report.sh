#!/usr/bin/env bash
# tests/support/test_bug_report.sh — Tests F9-T10: nimbus-bug-report y nimbus-backup.
# Sin root, sin red, HOME temporal.
set -u

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  [OK] $*"; }
bad() { FAIL=$((FAIL + 1)); echo "  [FALLO] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUG_REPORT="$REPO_ROOT/apps/nimbus-bug-report/nimbus-bug-report"
BACKUP_TOOL="$REPO_ROOT/apps/backup/nimbus-backup"

echo "== soporte y diagnostico: sintaxis y lint =="
bash -n "$BUG_REPORT" && ok "bash -n nimbus-bug-report" || bad "bash -n nimbus-bug-report"
shellcheck -S warning "$BUG_REPORT" && ok "shellcheck nimbus-bug-report" || bad "shellcheck nimbus-bug-report"
desktop-file-validate "$REPO_ROOT/apps/nimbus-bug-report/org.nimbus.bugreport.desktop" \
  && ok "org.nimbus.bugreport.desktop válido" || bad "desktop file inválido"

echo "== soporte y diagnostico: modo dry-run =="
DRY_OUT="$("$BUG_REPORT" --dry-run 2>&1)" || bad "--dry-run exit != 0"
echo "$DRY_OUT" | grep -q "DRY-RUN (solo lectura)" && ok "--dry-run modo solo lectura detectado" || bad "--dry-run sin salida esperada"

echo "== soporte y diagnostico: generacion de informe =="
TEST_TMP="$(mktemp -d /tmp/opencode/test-bugreport-XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '$TEST_TMP'" EXIT INT TERM

TEST_HOME="$TEST_TMP/home"
mkdir -p "$TEST_HOME/.config"
export NIMBUS_TEST_HOME="$TEST_HOME"

# Crear config falsa con secreto para comprobar anonimización
cat > "$TEST_HOME/.config/nimbus-welcome.ini" <<'EOF'
[user]
name=TestUser
password=SuperSecretPassword123
token=SecretTokenXYZ
EOF

REPORT_TAR="$TEST_TMP/report.tar.gz"
"$BUG_REPORT" --out "$REPORT_TAR" >/dev/null 2>&1 || bad "generación de reporte falló"

[ -f "$REPORT_TAR" ] && ok "Tarball generado: $REPORT_TAR" || bad "Tarball ausente"

# Extraer y comprobar ficheros internos
EXTRACT_DIR="$TEST_TMP/extracted"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$REPORT_TAR" -C "$EXTRACT_DIR" || bad "error descomprimiendo tarball"

[ -f "$EXTRACT_DIR/system-info.txt" ] && ok "Contiene system-info.txt" || bad "Falta system-info.txt"
[ -f "$EXTRACT_DIR/hardware-info.txt" ] && ok "Contiene hardware-info.txt" || bad "Falta hardware-info.txt"
[ -f "$EXTRACT_DIR/session-info.txt" ] && ok "Contiene session-info.txt" || bad "Falta session-info.txt"
[ -f "$EXTRACT_DIR/dbus-services.txt" ] && ok "Contiene dbus-services.txt" || bad "Falta dbus-services.txt"
[ -f "$EXTRACT_DIR/journal-errors.txt" ] && ok "Contiene journal-errors.txt" || bad "Falta journal-errors.txt"

# Comprobar anonimización de secretos en configs
if [ -f "$EXTRACT_DIR/configs/nimbus-welcome.ini" ]; then
  if grep -q "SuperSecretPassword123" "$EXTRACT_DIR/configs/nimbus-welcome.ini"; then
    bad "FALLO DE SEGURIDAD: contraseña no anonimizada en config recopilada"
  else
    ok "Anonimización correcta de secretos en configs recopiladas"
  fi
else
  bad "Falta nimbus-welcome.ini en configs de reporte"
fi

echo "== soporte y backup: ciclo save y restore de nimbus-backup =="
# Probar ciclo save / restore con nimbus-backup en HOME temporal
BACKUP_DIR="$TEST_TMP/backups"
mkdir -p "$BACKUP_DIR"
cat > "$TEST_HOME/.config/kwinrc" <<'EOF'
[General]
theme=TestTheme
EOF

"$BACKUP_TOOL" save --dest "$BACKUP_DIR" >/dev/null 2>&1 || bad "nimbus-backup save falló"
BKP_FILE="$(ls -1 "$BACKUP_DIR"/nimbus-backup-*.tar.gz 2>/dev/null | head -1)"
[ -n "$BKP_FILE" ] && [ -f "$BKP_FILE" ] && ok "nimbus-backup save generó tarball" || bad "nimbus-backup no generó tarball"

# Modificar config y probar restore
echo "theme=ChangedTheme" > "$TEST_HOME/.config/kwinrc"
"$BACKUP_TOOL" restore --file "$BKP_FILE" >/dev/null 2>&1 || bad "nimbus-backup restore falló"
grep -q "theme=TestTheme" "$TEST_HOME/.config/kwinrc" && ok "nimbus-backup restore restauró configuración original" || bad "restore no recuperó contenido"

echo "Resultado: $PASS ok, $FAIL fallos"
[ "$FAIL" -eq 0 ]
