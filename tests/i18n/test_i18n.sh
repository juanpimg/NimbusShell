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

echo "== i18n: export html válido, >=20 filas, 0 Ctrl nuevos, idempotente =="
if "$ROOT/scripts/nimbus-i18n" --export html >/tmp/opencode/i18n-export.txt 2>&1; then
    pass "nimbus-i18n --export html ($(cat /tmp/opencode/i18n-export.txt))"
else fail "nimbus-i18n --export html ($(cat /tmp/opencode/i18n-export.txt))"; fi
if python3 - "$ROOT" <<'PYEOF'; then
import re, sys
from html.parser import HTMLParser
from pathlib import Path
ROOT = Path(sys.argv[1])
html = (ROOT / "docs" / "user-guide" / "shortcuts.html").read_text(encoding="utf-8")
class T(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self.cur, self.cell, self.in_td = [], None, "", False
    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.cur = []
        elif tag in ("td", "th") and self.cur is not None:
            self.in_td, self.cell = True, ""
    def handle_data(self, d):
        if self.in_td:
            self.cell += d
    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cur is not None:
            self.cur.append(self.cell)
            self.in_td = False
        elif tag == "tr" and self.cur is not None:
            self.rows.append(self.cur)
            self.cur = None
p = T()
p.feed(html)  # HTML válido si parsea sin excepción
body = [r for r in p.rows if len(r) == 3 and "macOS" not in r[0]]
assert len(body) >= 20, f"tabla con {len(body)} filas (<20)"
src = (ROOT / "dotfiles" / ".config" / "plasma" / "kglobalshortcutsrc").read_text(encoding="utf-8")
have = set(re.findall(r"[A-Za-z]+\+Ctrl\+[A-Za-z]+|Ctrl\+[A-Za-z]+", src))
for r in body:
    for b in re.findall(r"Meta\+Ctrl\+[A-Za-z]+|(?<!\+)Ctrl\+[A-Za-z]+", r[1]):
        assert b in have, f"Ctrl nuevo en HTML: {b}"
print(f"HTML válido: {len(body)} filas, 0 Ctrl nuevos")
PYEOF
    pass "HTML válido, tabla >=20, 0 Ctrl nuevos"
else fail "HTML válido, tabla >=20, 0 Ctrl nuevos"; fi
md5a="$(md5sum "$ROOT/docs/user-guide/shortcuts.html" | cut -d' ' -f1)"
"$ROOT/scripts/nimbus-i18n" --export html >/dev/null 2>&1
md5b="$(md5sum "$ROOT/docs/user-guide/shortcuts.html" | cut -d' ' -f1)"
if [ "$md5a" = "$md5b" ]; then pass "--export html idempotente ($md5a)";
else fail "--export html no idempotente ($md5a vs $md5b)"; fi

echo "== i18n: export pdf (genera o aviso exit 0) =="
if "$ROOT/scripts/nimbus-i18n" --export pdf >/tmp/opencode/i18n-pdf.txt 2>&1; then
    if [ -f "$ROOT/docs/user-guide/shortcuts.pdf" ]; then
        pass "shortcuts.pdf generado ($(cat /tmp/opencode/i18n-pdf.txt))"
    elif grep -q "pacman -S" /tmp/opencode/i18n-pdf.txt; then
        pass "sin motor PDF: aviso accionable y exit 0 (documentado)"
    else fail "sin PDF ni aviso accionable ($(cat /tmp/opencode/i18n-pdf.txt))"; fi
else fail "nimbus-i18n --export pdf rc!=0 ($(cat /tmp/opencode/i18n-pdf.txt))"; fi

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
        # shortcuts.pdf es artefacto bajo demanda (--export pdf genera o
        # avisa con exit 0 si no hay motor; lo cubre el paso "export pdf").
        if t.endswith("shortcuts.pdf") and not (d.parent / t).exists():
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
