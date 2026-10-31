# F3-T03 nested — barra superior custom layer-shell 24pt (R-TOPBAR-LAYER)

Fecha: 2026-10-31. Harness `tests/vm/nested-bar.sh` (réplica de
`tests/vm/nested-plasma.sh`: KWin virtual 1280x800 propio, HOME/XDG
temporales, sin `--replace`, sin root). Sesión: plasmashell (fondo) +
kate (cliente normal) + `nimbus-bar` (`/tmp/nimbus-bar-prefix/bin/nimbus-bar`).

## Resultado: barra ARRIBA, 24 px exactos, sin robo de foco, exclusiveZone activa

- Captura canónica: `spikes/nested/f3-bar-24.png` — franja superior
  full-width con logo "N" propio + "Nimbus", placeholders Wi-Fi/BT/batería
  dibujada, reloj HH:mm (20:54); kate flotante debajo sin solape.
- Medición PIL (diff `f3-bar-24.png` vs `f3-bar-nobar.png`, umbral ΣΔ>36,
  >5 px/fila): filas que difieren = **0–23 exactas → altura 24** (±0,
  umbral ±1). Empieza en y=0 (anclada arriba).
- Placement (sonda KWin scripting vía `callDBus`+`dbus-monitor`,
  `spikes/nested/probe-dbus.log`): kate maximizado por script →
  `geom x=0 y=24 w=1280 h=730` → **exclusiveZone=24 respetada** (h=730 =
  800−24−46 del panel inferior default). Captura:
  `spikes/nested/f3-bar-24-max.png` (kate encaja bajo la barra).
- Foco/teclado: `active=Bienvenido — Kate` ANTES y DESPUÉS de lanzar la
  barra → **no roba foco** (`keyboardInteractivity=None` +
  `activateOnShow=false` en QML y refuerzo C++).

## Build

`cmake -S packages/shell/nimbus-bar -B /tmp/nimbus-bar-build` +
`cmake --build` + `install --prefix /tmp/nimbus-bar-prefix` (Qt6
Gui/Qml/Quick + `LayerShellQt::Interface`). `main.cpp`: `QGuiApplication`,
`LayerShellQt::Shell::useLayerShell()` (disponible con warning
deprecation 6.6, sigue funcional), `QQmlApplicationEngine` → `qrc:/Bar.qml`.
`Bar.qml`: `Window` 24 px + `org.kde.layershell as LayerShellQt`, anclas
Top|Left|Right, `exclusionZone=24`, `layer=LayerTop`,
`keyboardInteractivity=None`, `scope="nimbus-bar"`, sin decoración
(`FramelessWindowHint`). Tokens vía `NimbusTokens.qml` (copia
md5-idéntica a `packages/themes/nimbus-tokens`; fondo glass
`rgba(0,0,0,0.55)` provisional `[INFERIDO]`).

## Hallazgos (trampas, para futuras tareas)

1. `import org.kde.layershell` SIN alias rompe la creación del `Window`
   (`Type cannot be created`: `Window` colisiona con el tipo no-creable
   del módulo). Obliga `import org.kde.layershell as LayerShellQt`.
2. `qt6_add_resources(target fichero.qrc)` no enlazó nada (binario sin
   recurso, fallo silencioso); funciona `CMAKE_AUTORCC=ON` + `.qrc` como
   fuente de `qt_add_executable`.
3. `QQmlApplicationEngine` no imprime errores de `load()` por defecto;
   el binario conecta `warnings` para diagnóstico.
4. `print()` de scripts KWin cargados por D-Bus NO llega al stdout de
   kwin; canal de salida viable: `callDBus` a interface inexistente +
   `dbus-monitor`. API scripting 6.8 verificada: `workspace.windowList()`
   sí existe, `workspace.windows()`/`outputs()` no; ventana: `x/y/width/
   height`, `setMaximize(h,v)`; `clientArea(opt,0,1)` incompatible
   (quiere `Output*`, no int) → placement se prueba maximizando.
5. En plataforma offscreen la barra NO carga (layer-shell exige Wayland);
   esperado, no es bug.

## Limitaciones (no cierran F3-T03; van a F3-T04/T05)

- Extras (Wi-Fi/BT/batería) y reloj son placeholders sin menús/NC/CC.
- Sin blur KWin tras la barra (tinta plana; blur-live pendiente).
- Barra no integrada en ISO ni en autostart de Plasma (binario en
  `/tmp/nimbus-bar-prefix`; sin package/install.sh todavía).
