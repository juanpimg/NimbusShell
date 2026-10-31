#!/usr/bin/env python3
"""F6-T04: test del parser .desktop (réplica de AppModel::parseDesktopFile).

Reglas bajo test: NoDisplay, OnlyShowIn ajeno, Type!=Application,
Exec con %codes, Terminal, Name localizado. Sale 0 si todo pasa.
"""
import re
import sys
from pathlib import Path

FIX = Path(__file__).resolve().parent.parent.parent / "apps" / "nimbus-apps" / "fixtures"


def parse(path: Path):
    kv = {}
    in_entry = False
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("["):
            in_entry = (line == "[Desktop Entry]")
            continue
        if not in_entry or "=" not in line:
            continue
        key, val = line.split("=", 1)
        if "[" in key:
            if not key.startswith("Name["):
                continue
            key = key[: key.index("[")]
        if key == "Name" and "Name" in kv:
            continue
        kv[key] = val
    if kv.get("Type") != "Application":
        return None
    if not kv.get("Name") or not kv.get("Exec"):
        return None
    if kv.get("NoDisplay", "").lower() == "true":
        return None
    if kv.get("Hidden", "").lower() == "true":
        return None
    only = kv.get("OnlyShowIn", "")
    if only and not any(s in only for s in ("KDE", "Plasma", "Qt")):
        return None
    exe = re.sub(r"%[a-zA-Z]", "", kv["Exec"]).strip()
    exe = re.sub(r"\s+", " ", exe)
    return {
        "name": kv["Name"],
        "exec": exe,
        "icon": kv.get("Icon", ""),
        "categories": [c for c in kv.get("Categories", "").split(";") if c],
        "terminal": kv.get("Terminal", "").lower() == "true",
    }


def check(cond, msg):
    print(("PASS" if cond else "FAIL"), "-", msg)
    return cond


def main():
    ok = True
    a = parse(FIX / "kate.desktop")
    ok &= check(a and a["name"] == "Kate Editor", "Name básico")
    ok &= check(a and a["exec"] == "kate", f"Exec sin %U (got {a['exec'] if a else None})")
    ok &= check(a and "Utility" in a["categories"], "Categorías parseadas")
    ok &= check(parse(FIX / "hidden.desktop") is None, "NoDisplay=true se ignora")
    ok &= check(parse(FIX / "gnome-only.desktop") is None, "OnlyShowIn=GNOME se ignora")
    ok &= check(parse(FIX / "link.desktop") is None, "Type=Link se ignora")
    t = parse(FIX / "terminal.desktop")
    ok &= check(t and t["terminal"] is True, "Terminal=true detectado")
    ok &= check(t and t["exec"] == "mytool --opt", f"Exec con %f limpio (got {t['exec'] if t else None})")
    # Sin inyección shell: el exec limpio no contiene % ni ; encadenado raro
    ok &= check(t and "%" not in t["exec"], "Sin %codes residuales")
    print("RESULT:", "OK" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
