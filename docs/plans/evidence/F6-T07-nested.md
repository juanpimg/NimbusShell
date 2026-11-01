# F6-T07 — Teclado y accesibilidad Spotlight/Apps · evidencia nested

## Atajos (todos sin ratón; también en cabeceras QML y READMEs)
- Spotlight: Tab/Shift+Tab = Campo→[Vistas]→Resultados→Acciones→Pestañas→Campo
  (cerrado, `KeyNavigation`); ↑↓, Home/End, RePág/AvPág ±10; Enter/Espacio
  activan; Esc cierra; Cmd+1..4 pestañas (globales); A–L elige resultado N
  (solo con foco en lista); **Ctrl+Tab = KRunner** (antes Tab: Ruling abajo).
- Apps: Tab/Shift+Tab = Buscador→Vista→Categorías→Rejilla/Lista→Buscador;
  flechas (rejilla con columnas reales), Home/End, ±10; Enter lanza;
  Esc oculta (fix: antes `Qt.quit()` mataba el proceso); Espacio en botones.
- Foco visible: anillo blanco 2px (Spotlight, tokens `focusCol/focusW`) y
  accent→label 2px (Apps, `focusW`; ≥3:1 non-text en ambos temas).
- A11y: `Accessible.name` (10+/7+), `role` (List/ListItem/Grid/Button/ComboBox/
  Grouping/EditableText), `description`, `announce` de selección/pestaña/
  vista/categoría. Hit targets: filas 44, botones 36, pills/pestañas 32,
  cats 36, lista 40, buscadores 32. Texto interactivo ≥12px.
- Contraste medido: blanco/#2C2C2E 13.94, #EBEBF5/#2C2C2E 11.77,
  blanco/#0A84FF 3.65. Ruling: selección transient mantiene accent Tahoe
  (3.65 <4.5, +posición/●/announce, no solo color); pestaña footer pasa a
  blanco (13.94); botones bold 13px sobre accent (documentado, no silencioso).

## Ruling Tab→KRunner
F6-T02 usaba Tab como fallback KRunner; eso atrapa el foco (Tab nunca sale
del campo) y viola a11y. Desde F6-T07 Tab navega y el fallback es Ctrl+Tab
+ botón "Buscar en KRunner (Ctrl+Tab)". Sin cambios en Portapapeles
(sin fallback: datos locales) ni en Cmd+1..4/Quick Keys.

## Tests
- `tests/spotlight/test_a11y.py`: OK (35 checks: ciclo, teclas, foco, a11y,
  targets, contraste + node + qmllint).
- `tests/spotlight/test_focus.js` (node, misma `focuslogic.js` que importa
  `tst_focus.qml`): 17 aserciones OK.
- `tests/apps/test_a11y.py`: OK (30 checks + qmllint).
- `tst_focus.qml`: artefacto QML/JS listo; **qmltestrunner SKIP en este host**
  (sale 1 en silencio hasta con un TestCase trivial; preexistente, también
  afecta a `tst_calendar.qml`): la lógica se ejecuta en node + réplica.
- `qmllint` limpio en ambos QML; builds CMake OK (spotlight+`tst_index`,
  apps); `tst_index` 21 passed; `test_categories.py` OK (sin regresión).

## Nested (`tests/vm/nested-f6a11y.sh`; dbus-run-session, HOME/XDG temp)
- `spikes/nested/f6-a11y-focus.png` (1280x800): "kate"→Kate primera, anillo
  blanco en el campo (PIL: 2593 px blancos en banda superior), Quick Keys
  A–L, Abrir/Copiar/Revelar, KRunner Ctrl+Tab, footer nuevo, latencia 1 ms.
- `spikes/nested/f6-a11y-apps.png` (1000x700): anillo en buscador, 73 apps.
- `f6-a11y-qmlerr.txt` vacío: **0 errores QML**. Log `f6-a11y-nested.log`.
- **Orca: NO** (no instalado en el host; sin `f6-a11y-orca.png`). Preparado:
  roles/nombres/descripciones + `announce` cableados; el harness arranca
  Orca y captura si existe (`command -v orca`).

## Límites
- Sin inyección real de teclas en nested (harness sin soporte): el camino de
  cada tecla es el mismo `Keys.onPressed`/`Shortcut` verificado por lógica +
  estático; foco real visible en captura (el campo arranca enfocado).
- qmltestrunner roto en el host (preexistente); revalidar `tst_focus.qml` en
  VM/host con Qt sano: `QT_QPA_PLATFORM=offscreen qmltestrunner -input
  tests/spotlight tst_focus`.
- Contraste botones blancos sobre accent 3.65 (<4.5): aceptado como transient
  con redundancia; si el auditor lo exige, oscurecer a #0066CC (5.57).
