# apps/nimbus-apps (`org.nimbus.Apps`)

Explorador de aplicaciones estilo Tahoe (R-APPSVIEW, F6-T04): ventana centrada
1000x700, Cmd+1, categorías fijas + Suggestions, vistas Icons/List.
Sin carpetas/páginas/reorden (Tahoe eliminó Launchpad).

- **Build:** `cmake -S . -B build && cmake --build build` (Qt6 Quick/Qml/DBus).
- **Uso:** `nimbus-apps --demo` (abre), `--view list`, `--toggle` (DBus).
- **Atajo:** script KWin `packages/kwin/scripts/nimbus-apps-toggle/` (Meta+1).
- **Tests:** `python3 tests/apps/test_desktop_parse.py`, `qmllint qml/AppsWindow.qml`.
