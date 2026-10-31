# F6-T04 — Apps Tahoe (evidencia nested)

## Implementación
- `apps/nimbus-apps/`: Qt6 Quick app propia (`org.nimbus.Apps`).
  - `appmodel.h/.cpp`: escanea `~/.local/share/applications` + `XDG_DATA_DIRS`
    (+ `QStandardPaths::ApplicationsLocation` respaldo), parsea `.desktop`
    (Name/Exec/Icon/Categories/NoDisplay/OnlyShowIn/Hidden/Type/Terminal),
    deduplica por id (gana user-local), orden alfabético; `cleanExec` quita
    `%codes`; lanzamiento con `QProcess::startDetached` sin shell.
  - `NimbusIconProvider` (`QQuickImageProvider`, `image://nimbusicons/`):
    `QIcon::fromTheme` (ruta absoluta o tema) + fallback letra sobre pastilla.
  - `qml/AppsWindow.qml`: 1000x700 frameless always-on-top centrada, tokens
    contrato §2 (bg `#F2F2F7`/`#1C1C1E`, accent `#007AFF`/`#0A84FF`, t12/t13,
    radio 16, spacing 20/12), buscador incremental, 10 categorías fijas
    (Todas, Suggestions + 8), toggle Iconos/Lista, teclado (flechas/Enter/Esc).
  - `main.cpp`: `--demo` abre, `--view list`, `--toggle` vía DBus
    `org.nimbus.Apps /Apps toggle()/show()/hide()`; arranca oculta.
- `packages/kwin/scripts/nimbus-apps-toggle/`: KWin Script `registerShortcut`
  Meta+1 → `callDBus toggle`. Vía elegida: KWin Script (aplica en vivo sin
  re-login, sin tocar ficheros de atajos, Ctrl intacto — R-CTRL).
- `apps/nimbus-apps/org.nimbus.Apps.desktop`, `fixtures/` (5 .desktop).

## Correcciones durante nested
1. `engine.load(qrc:/qml/...)` fallaba silencioso (exit 1) con `qt_add_qml_module`;
   fix: `loadFromModule("Nimbus.Apps", "AppsWindow")`.
2. Mapeo categorías por substring (`System`→Ajustes para Alacritty/Dolphin);
   fix: tokens exactos (`System`→Utilidades). Verificado en captura lista.

## Tests
- `tests/apps/test_desktop_parse.py`: 9 checks (Name, Exec `%U`/`%f`,
  NoDisplay, OnlyShowIn=GNOME, Type=Link, Terminal, sin `%` residual) → `RESULT: OK`.
- `qmllint AppsWindow.qml` → 0 avisos.
- Build CMake Qt6.12 → OK.

## Nested (HOME/XDG temporales, kwin virtual 1280x800, cleanup por trap)
- `spikes/nested/f6-apps.png`: grid 73 apps + iconos tema reales + sidebar.
- `spikes/nested/f6-apps-list.png`: vista lista con columna categoría.
- Latencia apertura (spawn→registro DBus, poll 50ms): **287 ms** (<300 ms, A6/A7).
- Errores QML: **0** (`QML_ERRORS=0`, log `f6-apps-nested.log`).

## Límites
- Sin modo oscuro auto (prop `dark` manual); frecuencia Suggestions en
  `AppDataLocation` (no lee `recently-used.xbel`, formato distinto).
- Atajo Meta+1 registrado al instalar el script KWin (no verificado en
  nested: el harness no instala scripts; DBus toggle sí verificado).
- Sin assets Apple: iconos del tema del sistema + fallback propio.
- Ventana estática sin animación de apertura; fps real se mide en F6-T08/A5.

## Fix reviewer (dedup user-local)
- `rescan()` iteraba `dataDirs()` en orden inverso con skip-if-seen: ganaba
  `/usr/share` sobre `~/.local/share`. Corregido a orden de prioridad
  (user-local primero, skip-if-seen, `append`).
- Test: fixtures `dedup-system/` + `dedup-user/` con mismo id `dup.desktop`;
  2 checks nuevos (gana user; el primero en prioridad gana) → 11/11 PASS.
