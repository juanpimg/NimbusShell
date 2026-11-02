#!/usr/bin/env bash
# installed-acceptance-report.sh — pinta la aceptación del sistema instalado.
#
# Lee acceptance.json (generado dentro de la VM por installed-acceptance.sh)
# y muestra una tabla + resumen. No necesita VM ni conexión: útil en el host
# sobre /mnt/hostshare/e2e/acceptance.json.
#
# Uso:
#   bash tests/vm/installed-acceptance-report.sh [--json RUTA] [--md]
#   bash tests/vm/installed-acceptance-report.sh /mnt/hostshare/e2e/acceptance.json
set -u

JSON=""
MODE="table"
while [ $# -gt 0 ]; do
  case "$1" in
    --json)
      [ $# -ge 2 ] || { echo "ERROR: --json necesita ruta" >&2; exit 1; }
      JSON="$2"; shift 2 ;;
    --md) MODE="md"; shift ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      if [ -z "$JSON" ]; then
        JSON="$1"; shift
      else
        echo "ERROR: argumento extra: $1" >&2; exit 1
      fi ;;
  esac
done

if [ -z "$JSON" ]; then
  for candidate in /mnt/hostshare/e2e/acceptance.json \
                   "$HOME/aceptacion/acceptance.json"; do
    if [ -f "$candidate" ]; then JSON="$candidate"; break; fi
  done
fi
[ -n "$JSON" ] || {
  echo "ERROR: no encuentro acceptance.json; pásalo con --json RUTA" >&2
  exit 1
}
[ -f "$JSON" ] || { echo "ERROR: no existe $JSON" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: falta python3" >&2; exit 1
}

python3 - "$JSON" "$MODE" <<'PY'
import json
import sys

path, mode = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    print(f"ERROR: JSON inválido en {path}: {exc}", file=sys.stderr)
    sys.exit(1)

checks = data.get("checks") or []
summary = data.get("summary") or {}
verdict = data.get("verdict", "?")
generated = data.get("generated_at", "?")
host = data.get("hostname", "?")
user = data.get("user", "?")
session = data.get("session") or {}

if mode == "md":
    print("# Aceptación del sistema instalado\n")
    print(f"- Fecha: {generated}")
    print(f"- Host: {host}")
    print(f"- Usuario: {user}")
    print(f"- Sesión: {session.get('type', '?')} / {session.get('desktop', '?')}")
    print()
    print("| Estado | Check | Detalle |")
    print("| --- | --- | --- |")
    for row in checks:
        detail = str(row.get("detail", "")).replace("|", "\\|")
        print(f"| {row.get('status', '?')} | {row.get('id', '?')} | {detail} |")
    print()
    print(f"**Resumen:** {summary.get('PASS', 0)} PASS / "
          f"{summary.get('FAIL', 0)} FAIL / "
          f"{summary.get('SKIP', 0)} SKIP — **VEREDICTO: {verdict}**")
    sys.exit(0 if verdict == "PASS" else 1)

id_width = max([len("CHECK")] + [len(str(r.get("id", ""))) for r in checks])
print(f"Aceptación sistema instalado — {generated}")
print(f"Host: {host}  Usuario: {user}  "
      f"Sesión: {session.get('type', '?')}/{session.get('desktop', '?')}")
print("-" * (id_width + 58))
print(f"{'ESTADO':<7} {'CHECK':<{id_width}}  DETALLE")
print("-" * (id_width + 58))
for row in checks:
    status = str(row.get("status", "?"))
    cid = str(row.get("id", "?"))
    detail = str(row.get("detail", "")).replace("\n", " ")
    print(f"{status:<7} {cid:<{id_width}}  {detail}")
print("-" * (id_width + 58))
print(f"Resumen: {summary.get('PASS', 0)} PASS / "
      f"{summary.get('FAIL', 0)} FAIL / "
      f"{summary.get('SKIP', 0)} SKIP — VEREDICTO: {verdict}")
sys.exit(0 if verdict == "PASS" else 1)
PY
