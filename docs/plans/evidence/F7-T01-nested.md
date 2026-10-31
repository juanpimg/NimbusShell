# F7-T01 nested — Mission Control base: overlay, Spaces y ventanas

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Plasma 6.8 / KWin (nested
`kwin_wayland --virtual --no-lockscreen`, bus D-Bus privado, HOME/XDG
temporales; host intacto, sin root, sin instalar). Harness:
`tests/vm/nested-f7mc.sh` (+ `nested-f7mc-inner.sh`).

## 1. Arquitectura

`apps/nimbus-missioncontrol/` (Qt6 Quick C++/QML, **sin KF obligatorio**,
solo `Qt6 Gui/Qml/Quick/DBus` + `LayerShellQt`):

- `main.cpp`: overlay fullscreen en pantalla primaria, layer-shell
  `Overlay` sin zona exclusiva, teclado exclusivo solo si visible;
  servicio `org.nimbus.MissionControl /MC`
  (`toggle/show/hide/refresh/pushState/pushWindows/windowCount/
  desktopCount/openLatencyMs/activateFirst`); flags `--demo` y
  `--shot <png>` (grabWindow tras pintar, evidencia primaria).
- `kwinbackend.{h,cpp}`: modelo QML (`desktops`, `windows`,
  `currentDesktop`, `currentApp`, `exposeActiveAppOnly`,
  `hasThumbnails`, `openLatencyMs`, `lastError`) + acciones
  (`activateWindow`, `moveWindowToDesktop`, `setCurrentDesktopById/ByIndex`,
  `toggleExpose`, `activateFirst` de test).
- `qml/MissionControl.qml`: fila de Spaces + parrilla del Space activo +
  App Exposé (`Tab` filtra por `currentApp`); cierra Esc (Shortcut) / clic
  fuera; Enter activa; ←/→ mueve selección; drag de miniatura a Space
  (DropArea → `moveWindowToDesktop`); tokens dark §2.1
  (`#FFFFFF/#EBEBF5/#0A84FF/#2C2C2E/#38383A`, r-sm 8 / r-md 10-12).
- `kwin/nimbus-mc.js`, `.desktop`, `README.md`, `CMakeLists.txt`.
- `qmllint` = 0 errores; build CMake OK.

## 2. DBus KWin (verificado en host, solo lectura)

- `/VirtualDesktopManager`: `count`, `current`, `createDesktop`,
  `removeDesktop` existen; **`desktops` es `a(iss)` y leerla por QDBus
  aborta el proceso** (`type struct … not a basic type`, crash
  reproducido en nested). Solución: QDBus solo tipos básicos
  (`count:uint`, `current:QString`, `setCurrentDesktop(int)`); ids/nombres
  reales llegan por scripting.
- Ventanas/escritorios vía KWin scripting: helper one-shot
  (`/Scripting loadScript+start`, unload a 1.2s) vuelca
  `workspace.desktops` + `workspace.windowList()` (solo `normalWindow`,
  excluye sin-caption y el propio overlay) a JSON y lo devuelve con
  `callDBus(… 'pushState' …)`. Activar/mover/escritorio actual, mismo
  mecanismo + `setCurrentDesktop(int)`.
- ScreenShot2 real: servicio `org.kde.KWin.ScreenShot2`,
  path `/org/kde/KWin/ScreenShot2`,
  `CaptureWindow/CaptureWorkspace(opciones, pipe)` — exige
  portal/pipewire (no implementado en T01/T02). `hasThumbnails=false`
  honesto + fallback icono+título.

## 3. Captura y medidas (nested, kate+konsole+dolphin reales)

- `spikes/nested/f7-mc.png` (= `f7-mc-grab.png`, grabWindow del overlay):
  fila Spaces (`Escritorio 1·3 ventanas` + `Desktop 2` creado por DBus)
  + 3 tiles reales (Konsole/Dolphin/Kate con caption+app) + fallback
  icono+título + footer `3 ventanas · 2 Spaces`.
- `spikes/nested/f7-mc-spectacle.png`: overlay sobre sesión anidada viva
  (Konsole/Dolphin reales + panel plasmashell detrás). Nota: spectacle va
  por portal y captura el host si este está bloqueado; evidencia primaria
  = grab (`f7mc-nested.log` completo).
- `open_ms=79` (serie 78/98/107/79) < 300ms (A7) ✓; `windowCount=3`,
  `desktopCount=2`; `activateFirst=…Konsole` (ruta activación E2E OK);
  **0 errores QML** (única línea `nimbus-mc` = info `open_ms`).
- Click: `MouseArea` en tile → `activateWindow` + hide (código; click
  posicional E2E pendiente, ver gaps). Teclado: Shortcuts
  Esc/Enter/←/→/Tab (qmllint OK; inyección de teclas E2E pendiente).

## 4. Gaps (→ F7-T07..T10)

1. Drag entre Spaces implementado (DropArea) pero sin test E2E de
   coordenadas (exige pointer lab con medición en captura actual).
2. Multi-monitor: overlay solo en primaria; MC-por-display pendiente.
3. Thumbnails reales (pipewire) → F7-T09; `+` crear Space = no-op
   documentado.
4. App Exposé y atajos verificados en código/qmllint, sin E2E de teclado.
