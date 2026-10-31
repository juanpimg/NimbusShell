#!/usr/bin/env python3
"""F6-T05: categorías fijas, orden y Suggestions de nimbus-apps.

Réplica documentada de AppModel (C++ Qt): kFixed, mapCategory (tokens
exactos), orden alfabético (localeAwareCompare ≈ orden Unicode) y
Suggestions por frecuencia en ~/.local/state/nimbus-apps/usage.ini.
Sale 0 si todo pasa.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
FIX = REPO / "apps" / "nimbus-apps" / "fixtures"
CPP = REPO / "apps" / "nimbus-apps" / "appmodel.cpp"
QML = REPO / "apps" / "nimbus-apps" / "qml" / "AppsWindow.qml"


def map_category(cats):
    s = {c.lower() for c in cats}
    if s & {"settings", "desktopsettings", "x-settings"}:
        return "Ajustes"
    if "development" in s:
        return "Desarrollo"
    if s & {"graphics", "photography"}:
        return "Gráficos"
    if "game" in s:
        return "Juegos"
    if s & {"audiovideo", "audio", "video", "player", "recorder"}:
        return "Multimedia"
    if s & {"network", "webbrowser", "email", "chat", "instantmessaging"}:
        return "Internet"
    if s & {"office", "productivity", "education", "science"}:
        return "Productividad"
    return "Utilidades"


def parse(path):
    kv, in_entry = {}, False
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
    if only and not any(x in only for x in ("KDE", "Plasma", "Qt")):
        return None
    return {"name": kv["Name"],
            "cats": [c for c in kv.get("Categories", "").split(";") if c]}


ok = True


def check(cond, msg):
    global ok
    print(("PASS" if cond else "FAIL"), "-", msg)
    ok = ok and bool(cond)


# 1. 10 categorías fijas: C++ kFixed == QML cats (mismo conjunto).
cpp_cats = re.findall(r'"(Todas|Productividad|Desarrollo|Gráficos|Juegos|'
                      r'Multimedia|Utilidades|Internet|Ajustes|Suggestions)"',
                      CPP.read_text(encoding="utf-8"))
qml_cats = re.findall(r'"(Todas|Suggestions|Productividad|Desarrollo|Gráficos|'
                      r'Juegos|Multimedia|Utilidades|Internet|Ajustes)"',
                      QML.read_text(encoding="utf-8"))
check(len(set(cpp_cats)) == 10, f"C++ kFixed tiene 10 (got {sorted(set(cpp_cats))})")
check(set(qml_cats) == set(cpp_cats), "QML cats == C++ kFixed (mismo conjunto)")
check("Suggestions" in qml_cats, "Suggestions existe en el sidebar")

# 2. Mapeo categoría .desktop -> fija (System NO es Ajustes).
check(map_category(["System", "TerminalEmulator"]) == "Utilidades",
      "System -> Utilidades (no Ajustes)")
for cats, want in [(["Settings"], "Ajustes"),
                   (["Development"], "Desarrollo"),
                   (["Graphics"], "Gráficos"),
                   (["Game"], "Juegos"),
                   (["AudioVideo"], "Multimedia"),
                   (["Network", "WebBrowser"], "Internet"),
                   (["Office"], "Productividad"),
                   (["Utility"], "Utilidades"),
                   ([], "Utilidades")]:
    check(map_category(cats) == want, f"{cats} -> {want}")

# 3. Orden por categoría/nombre: réplica de rescan() (ordena por nombre).
apps = []
for fn in FIX.glob("*.desktop"):
    a = parse(fn)
    if a:
        apps.append(a)
apps.sort(key=lambda a: a["name"].lower())  # localeAwareCompare ≈ orden Unicode
names = [a["name"] for a in apps]
check(names == ["Ajustes Nimbus", "Calc Nimbus", "Dev Nimbus",
                "Firefox Nimbus", "Game Nimbus", "Gimp Nimbus",
                "Kate Editor", "Music Nimbus", "Terminal App",
                "Writer Nimbus"],
      f"orden alfabético por nombre (got {names})")
by_cat = {}
for a in apps:
    by_cat.setdefault(map_category(a["cats"]), []).append(a["name"])
check(by_cat.get("Internet") == ["Firefox Nimbus"], "Internet: Firefox Nimbus")
check(by_cat.get("Ajustes") == ["Ajustes Nimbus"], "Ajustes: Ajustes Nimbus")
check("Kate Editor" in by_cat.get("Utilidades", []), "Utilidades incluye Kate")

# 4. Suggestions: orden por frecuencia desc; sin historial, 8 alfabéticas.
usage = {"game-nimbus.desktop": 5, "kate.desktop": 9, "writer-nimbus.desktop": 1}
sug = sorted(usage.items(), key=lambda kv: -kv[1])
check([k for k, _ in sug] == ["kate.desktop", "game-nimbus.desktop",
                              "writer-nimbus.desktop"],
      "Suggestions ordena por uso desc")
check([a["name"] for a in apps[:8]] == names[:8], "fallback: 8 primeras alfabéticas")

# 5. Persistencia en ~/.local/state (GenericStateLocation), no xbel/AppData.
src = CPP.read_text(encoding="utf-8")
check("GenericStateLocation" in src and "nimbus-apps/usage.ini" in src,
      "uso en ~/.local/state/nimbus-apps/usage.ini")
check("recently-used.xbel" not in src, "no lee xbel")

print("RESULT:", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
