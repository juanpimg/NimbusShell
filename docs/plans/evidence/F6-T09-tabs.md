# F6-T09 — Cmd+2..4 a vistas Spotlight (evidencia nested)

## DBus (`apps/nimbus-spotlight/main.cpp`)
- `Toggle` ahora guarda `QQuickWindow*` + slots `showTab(tab)` / `toggleTab(tab)`
  (`apps|files|actions|clipboard`; inválida → warning sin romper); ambos reutilizan
  la ventana única (sin doble instancia), llaman `setTab` QML, `setVisible(true)` +
  `requestActivate()` + `focusSearch()`. `toggle()` también reenfoca al mostrar.
- QML (`Spotlight.qml`): solo se añade `focusSearch()` (foco al campo); `setTab`
  intacto. `qmllint` 0 avisos.

## KWin (`packages/kwin/scripts/nimbus-tabs/`)
- `registerShortcut` Meta+2→`toggleTab("files")`, Meta+3→`actions`, Meta+4→
  `clipboard`; Meta+1 sigue en `nimbus-apps-toggle` (no duplicado). Sin Ctrl (R-CTRL).
- `node --check` OK; carga del script en KWin no verificada en nested (mismo límite
  que F6-T04: el harness no instala scripts; DBus sí verificado).

## kglobalshortcutsrc
- Sin cambios: `activate task manager entry 2..4=none` ya reservaba (F6-T04).
  Ruling: Meta+2..4 viven en el KWin Script `nimbus-tabs`, no en kglobalshortcutsrc.

## Nested (kwin virtual 1280x800, HOME temporal, bin `--demo`, log `f6-tabs-nested.log`)
- `toggleTab files|actions|clipboard` → `spotlight-tab=<tab>` en log (3/3 TAB_OK),
  mismo pid vivo tras las 3 (ALIVE_OK), `showTab bogus` → warning + sigue vivo.
- Capturas: `f6-tab-files.png` (● Archivos ⌘2), `f6-tab-actions.png` (● Acciones ⌘3),
  `f6-tab-clipboard.png` (● Portapapeles ⌘4 + pills Historial|Emoji); campo con
  anillo de foco en las 3. Errores QML: 0 (`f6-tabs-qmlerr.txt` vacío).

## Límites
- Cierre Esc no pulsado con tecla real (Shortcut preexistente F6-T07); verificado el
  ocultado por segundo `toggleTab` misma pestaña. 2 warnings QML preexistentes
  (`Accessible` en root `ApplicationWindow`, F6-T07) sin cambio. KWin Script sin
  instalar en nested (ver arriba); atajos QML Meta+2..4 internos ya existían.
