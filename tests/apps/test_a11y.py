#!/usr/bin/env python3
"""F6-T07: teclado y accesibilidad de nimbus-apps (sin ratón).

Verifica en apps/nimbus-apps/qml/AppsWindow.qml: ciclo Tab/Shift+Tab
cerrado (buscador→vista→categorías→rejilla/lista→buscador), flechas con
columnas reales, Home/End/RePág/AvPág, Enter lanza, Esc oculta (sin
Qt.quit), anillo de foco visible, nombres/roles/descripciones, announce,
hit targets y qmllint. QML活力 test no viable (la vista exige AppModel
C++; se cubre con estático + qmllint + ciclo Tab en focuslogic.js).
Sale 0 si todo pasa.
"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
QML = REPO / "apps" / "nimbus-apps" / "qml" / "AppsWindow.qml"

ok = True


def check(cond, msg):
    global ok
    print(("PASS" if cond else "FAIL"), "-", msg)
    ok = ok and bool(cond)


src = QML.read_text(encoding="utf-8")

# 1. Ciclo Tab/Shift+Tab cerrado y sin trampas.
check(src.count("KeyNavigation.tab:") >= 5, "KeyNavigation.tab en tramo (buscador/vista/cats/rejilla/lista)")
check(src.count("KeyNavigation.backtab:") >= 5, "KeyNavigation.backtab simétrico")
check("KeyNavigation.tab: search" in src, "el ciclo se cierra: vistas→buscador")
check("appModel.listMode ? list : grid" in src, "Tab respeta la vista activa (icons/list)")

# 2. Teclas: flechas, Home/End, páginas, Enter, Esc.
for key in ("Key_Right", "Key_Left", "Key_Down", "Key_Up", "Key_Home",
            "Key_End", "Key_PageDown", "Key_PageUp", "Key_Return",
            "Key_Enter", "Key_Escape"):
    check(key in src, f"tecla {key} gestionada")
check('sequence: "Escape"' in src and 'sequence: "Return"' in src,
      "Esc oculta + Enter lanza (globales)")
code = "\n".join(l for l in src.splitlines() if not l.strip().startswith("//"))
check("Qt.quit()" not in code, "Esc NO mata el proceso (era Qt.quit, ahora hide)")
check("grid.cellWidth" in src, "flechas de rejilla con columnas reales")

# 3. Foco visible (anillo accent 2px, distinto con/sin foco).
check("property int focusW" in src, "token focusW")
check("activeFocus ? root.labelCol : root.accentCol" in src,
      "el anillo cambia con foco de teclado (rejilla/lista)")
check("catList.activeFocus" in src, "las categorías distinguen foco de teclado")

# 4. Accesibilidad: nombres, roles, descripciones, announce.
check(src.count("Accessible.name:") >= 7, "nombres accesibles (>=7)")
check(src.count("Accessible.role:") >= 5, "roles accesibles (>=5: grid, lista, items)")
check("Accessible.description:" in src, "descripciones accesibles")
check("Accessible.announce(root" in src, "announce() a lectores")
check("announceSel()" in src, "la selección se anuncia")
check("Vista lista" in src and "Vista iconos" in src, "el cambio de vista se anuncia")

# 5. Hit targets y texto.
check("height: 36" in src, "filas de categorías 36px")
check("height: 40" in src, "filas de lista 40px")
check("implicitHeight: 32" in src, "buscador 32px")

# 6. qmllint limpio.
r = subprocess.run(["qmllint", str(QML)], capture_output=True, text=True)
check(r.returncode == 0, f"qmllint limpio ({(r.stderr or '').strip()[:200]})")

print("RESULT:", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
