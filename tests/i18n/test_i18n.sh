#!/usr/bin/env bash
# test_i18n.sh — F11-T05: TS válidos, cobertura es/en, --check verde,
# chuleta >=20 atajos sin Ctrl nuevos, docs sin enlaces rotos.
# Solo lectura (HOME temporal si alguna herramienta lo exige), sin root.
set -u
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0
pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1" >&2; FAILS=$((FAILS + 1)); }
export HOME="${HOME_TMP:-$(mktemp -d /tmp/opencode/i18n-home-XXXXXX)}"

echo "== i18n: TS válidos y 0 unfinished =="
python3 - "$ROOT" <<'PYEOF' || exit 1
import sys, xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(sys.argv[1])
for lang in ("es", "en"):
    p = ROOT / "i18n" / f"nimbus_{lang}.ts"
    assert p.exists(), f"falta {p}"
    try:
        tree = ET.parse(str(p))
    except ET.ParseError as e:
        print(f"XML inválido en {p.name}: {e}")
        sys.exit(1)
    n = unf = 0
    for m in tree.getroot().iter("message"):
        n += 1
        t = m.find("translation")
        if t is None or (t.text or "") == "" or t.get("type") == "unfinished":
            unf += 1
    assert n > 0, f"{p.name} sin mensajes"
    assert unf == 0, f"{p.name}: {unf} unfinished/vacíos"
    print(f"nimbus_{lang}.ts: {n} mensajes, 0 unfinished")
PYEOF
[ "$?" = "0" ] && pass "TS válidos, 0 unfinished" || fail "TS válidos, 0 unfinished"

echo "== i18n: es/en misma cobertura =="
if python3 - "$ROOT" <<'PYEOF'; then
import sys, xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(sys.argv[1])
def srcs(lang):
    t = ET.parse(str(ROOT / "i18n" / f"nimbus_{lang}.ts"))
    return {m.findtext("source") for m in t.getroot().iter("message")}
es, en = srcs("es"), srcs("en")
assert es == en, f"es/en difieren: solo-es={len(es-en)}, solo-en={len(en-es)}"
print(f"cobertura idéntica: {len(es)} cadenas")
PYEOF
    pass "es/en misma cobertura"
else fail "es/en misma cobertura"; fi

echo "== i18n: nimbus-i18n --check verde =="
if "$ROOT/scripts/nimbus-i18n" --check >/tmp/opencode/i18n-check.txt 2>&1; then
    pass "nimbus-i18n --check ($(cat /tmp/opencode/i18n-check.txt))"
else fail "nimbus-i18n --check ($(cat /tmp/opencode/i18n-check.txt))"; fi

echo "== i18n: chuleta >=20 atajos, 0 Ctrl nuevos =="
rows="$(grep '^|' "$ROOT/docs/user-guide/shortcuts.md" 2>/dev/null | grep -vc '^| *\(macOS\|---\)' || true)"
if [ "${rows:-0}" -ge 20 ]; then pass "chuleta con $rows atajos (>=20)";
else fail "chuleta con ${rows:-0} atajos (<20)"; fi
if python3 - "$ROOT" <<'PYEOF'; then
import re, sys
from pathlib import Path
ROOT = Path(sys.argv[1])
md = (ROOT / "docs" / "user-guide" / "shortcuts.md").read_text(encoding="utf-8")
src = (ROOT / "dotfiles" / ".config" / "plasma" / "kglobalshortcutsrc").read_text(encoding="utf-8")
# Todo binding con Ctrl+ en la chuleta debe existir ya en kglobalshortcutsrc.
have = set(re.findall(r"[A-Za-z]+\+Ctrl\+[A-Za-z]+|Ctrl\+[A-Za-z]+", src))
for line in md.splitlines():
    if not line.startswith("|") or re.match(r"\|\s*(macOS|---)", line):
        continue
    cells = line.split("|")
    if len(cells) < 4:
        continue
    nimbus_cell = cells[2]  # solo la columna Nimbus: la macOS cita Ctrl+n de macOS real
    for b in re.findall(r"Meta\+Ctrl\+[A-Za-z]+|(?<!\+)Ctrl\+[A-Za-z]+", nimbus_cell):
        assert b in have, f"Ctrl nuevo en chuleta: {b}"
print(f"0 Ctrl nuevos ({len(have)} heredados en dotfile)")
PYEOF
    pass "chuleta sin Ctrl nuevos"
else fail "chuleta sin Ctrl nuevos"; fi

echo "== i18n: docs sin enlaces internos rotos =="
if python3 - "$ROOT" <<'PYEOF'; then
import re, sys
from pathlib import Path
ROOT = Path(sys.argv[1])
docs = [ROOT / "docs" / "user-guide" / "README.md",
        ROOT / "docs" / "user-guide" / "shortcuts.md",
        ROOT / "docs" / "i18n.md"]
bad = []
for d in docs:
    assert d.exists(), f"falta {d}"
    for m in re.finditer(r"\]\(([^)\"#]+)\)", d.read_text(encoding="utf-8")):
        t = m.group(1)
        if re.match(r"https?:|mailto:", t):
            continue
        if not (d.parent / t).exists():
            bad.append(f"{d.name}: {t}")
assert not bad, "rotos: " + "; ".join(bad)
print(f"{len(docs)} docs, 0 enlaces rotos")
PYEOF
    pass "docs sin enlaces rotos"
else fail "docs sin enlaces rotos"; fi

echo
if [ "$FAILS" = "0" ]; then echo "I18N VERDE."; exit 0
else echo "I18N ROJO: $FAILS paso(s) en [FAIL]." >&2; exit 1; fi
