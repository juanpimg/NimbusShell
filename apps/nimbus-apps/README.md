# apps/nimbus-apps (`org.nimbus.Apps`)

Explorador de aplicaciones estilo Tahoe (R-APPSVIEW, F6-T04): ventana centrada
1000x700, Cmd+1, categorías fijas + Suggestions, vistas Icons/List.
Sin carpetas/páginas/reorden (Tahoe eliminó Launchpad).

- **Build:** `cmake -S . -B build && cmake --build build` (Qt6 Quick/Qml/DBus).
- **Uso:** `nimbus-apps --demo` (abre), `--view list`, `--toggle` (DBus).
- **Atajo:** script KWin `packages/kwin/scripts/nimbus-apps-toggle/` (Meta+1).
- **Tests:** `python3 tests/apps/test_desktop_parse.py`, `qmllint qml/AppsWindow.qml`.

## Teclado y accesibilidad (F6-T07, todo sin ratón)

| Atajo | Acción |
|---|---|
| Tab / Shift+Tab | Buscador → Vista → Categorías → Rejilla/Lista → Buscador (sin trampas) |
| ← → ↑ ↓ | Mueve la selección (rejilla: columnas reales; lista: ±1) |
| Home / End · RePág / AvPág | Primera / última app · ±10 |
| Enter | Lanza la app / entra en la rejilla desde categorías |
| Esc | Oculta la ventana (no cierra el proceso) |
| Espacio | Activa el botón enfocado |

Foco visible (anillo accent 2px), nombres/roles/descripciones y `announce`
de vista/categoría/selección (Orca/AT-SPI). Contraste y medidas en
`docs/plans/evidence/F6-T07-nested.md`. Tests: `python3
tests/apps/test_a11y.py` (estático + `qmllint`; sin test QML vivo: la vista
exige AppModel C++).
