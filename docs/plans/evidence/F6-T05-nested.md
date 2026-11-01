# F6-T05 — Vistas y categorías de Apps · evidencia nested

## Cambios (Suggestions ya existía; faltaban persistencia state y capturas)
- `appmodel.cpp`: frecuencia en `~/.local/state/nimbus-apps/usage.ini`
  (`GenericStateLocation`; antes `AppDataLocation`). No lee xbel.
- `main.cpp`: flags `--category <cat>` y `--shot <png>` (captura propia
  tras pintar y sale; para test nested determinista).
- `AppsWindow.qml`: el sidebar refleja la categoría inicial del modelo.
- Fixtures: 8 `.desktop` nuevos (una app por categoría fija).
- `tests/apps/test_categories.py`: 10 categorías C++==QML, mapeo
  (System→Utilidades, 9 casos), orden alfabético, Suggestions por uso,
  ruta state, sin xbel → RESULT OK.

## Vistas verificadas (nested ligero: HOME/XDG temporales, offscreen)
- `spikes/nested/f6-apps-categories.png`: **Suggestions activa**
  (resaltada) con 3 apps por uso desc (Kate 9, Game 5, Writer 1), "3 apps".
- `spikes/nested/f6-apps-sort.png`: **Todas**, 10 apps en orden alfabético
  (Ajustes…Writer), "10 apps". Iconos = fallback letra (sin tema en nested).
- 10 categorías fijas: Todas, Suggestions, Productividad, Desarrollo,
  Gráficos, Juegos, Multimedia, Utilidades, Internet, Ajustes.
- Vistas Icons/List conmutables (`listMode`), buscador incremental,
  teclado flechas/Enter/Esc (código ya existente, sin cambios).
- Errores QML: **0** (`f6-apps-qmlerr.txt` vacío, rc=0 en ambas capturas).

## Tests
- `tests/apps/test_desktop_parse.py` → RESULT OK (11 checks, dedup incluido).
- `tests/apps/test_categories.py` → RESULT OK (21 checks).
- `qmllint AppsWindow.qml` → limpio. Build CMake `nimbus-apps` → OK.

## Límites
- Sin modo oscuro auto (`dark` manual); sin animación de apertura.
- Atajo Meta+1 vía script KWin (no verificado aquí; DBus toggle de F6-T04).
- Suggestions sin historial muestra las 8 primeras alfabéticas.
