#!/usr/bin/env bash
# Test reproducible de compare.sh: genera 3 PNG sinteticos con PIL y verifica
# 0% (igual), 100% (distinto) y error (tamano distinto).
# Uso: test_compare.sh. Exit 0 si todo pasa.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d /tmp/nimbus-diff-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
fails=0

python3 - "$TMP" <<'EOF'
import sys
from PIL import Image
d = sys.argv[1]
Image.new("RGB", (32, 32), (10, 20, 30)).save(f"{d}/a.png")
Image.new("RGB", (32, 32), (10, 20, 30)).save(f"{d}/b.png")
Image.new("RGB", (32, 32), (200, 210, 220)).save(f"{d}/c.png")
Image.new("RGB", (16, 16), (10, 20, 30)).save(f"{d}/d.png")
EOF

check() {  # check <desc> <exit_esperado> <args...>
  local desc="$1" want="$2"; shift 2
  out="$("$HERE/compare.sh" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]]; then echo "OK   $desc (exit $rc): $out";
  else echo "FAIL $desc: esperado exit $want, obtenido $rc: $out"; fails=$((fails+1)); fi
}

check "identicas -> 0%" 0 "$TMP/a.png" "$TMP/b.png"
check "distintas -> supera umbral" 1 "$TMP/a.png" "$TMP/c.png"
check "distintas con umbral 100 -> pasa" 0 "$TMP/a.png" "$TMP/c.png" --threshold 100
check "tamano distinto -> error" 2 "$TMP/a.png" "$TMP/d.png"
check "crop igual -> 0%" 0 "$TMP/a.png" "$TMP/b.png" --crop 0,0,16,16
check "fichero ausente -> error" 2 "$TMP/noexiste.png" "$TMP/b.png"
check "help" 0 --help

if [[ $fails -eq 0 ]]; then echo "TODOS LOS TESTS PASAN"; else echo "$fails FALLOS"; fi
exit "$fails"
