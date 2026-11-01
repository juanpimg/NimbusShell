# nimbus-missioncontrol — overlay Mission Control/Spaces (F7 R-MC-CUSTOM).

Qt6 Quick (C++/QML, sin KF obligatorio). Rejilla estilo macOS: fila de
Spaces + grupos por app con tamaños + App Exposé. Datos vía KWin
scripting/DBus; miniaturas ScreenShot2 si el pipe devuelve imagen, si no
fallback icono+título.

## Uso

```sh
cmake -B build -S apps/nimbus-missioncontrol && cmake --build build
./build/nimbus-missioncontrol --demo            # datos falsos (4 Spaces, 6 ventanas)
./build/nimbus-missioncontrol --shot /tmp/mc.png # captura propia tras pintar
./build/nimbus-missioncontrol --reduce-motion    # fade 150ms (sin slide/zoom)
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.toggle
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.requestThumbs
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.thumbLog
```

## Atajo (Meta+W) vía KWin script

`kwin/nimbus-mc.js` es un one-shot: llama por DBus a `/MC toggle`.
Cargarlo una vez deja el atajo libre para bindear Meta+W en
`kglobalshortcutsrc` (componente `nimbus-mc`); el stock Overview
(`Meta+W`/`F3` en kwin) debe desactivarse para no duplicar overlays
(Ruling R-MC-STOCK: Nimbus MC reemplaza a Overview como overlay por
defecto; Overview sigue disponible vía efecto si se quiere).

Meta+Ctrl+←/→ stock de KWin (cambiar de escritorio) sigue funcionando:
MC no bindea nada con Ctrl y reacciona al cambio vía pushState.

## Rulings

- **R-SPACES:** MC garantiza 4 Spaces al arrancar (`ensureSpaces(4)`,
  nombres `Escritorio 1..4` para los creados vía
  `VirtualDesktopManager.createDesktop(pos, nombre)`); no renombra ni
  borra los existentes. `+` crea `Escritorio N` real. Plasma 6: los
  escritorios son globales, no por monitor (divergencia 1:1 conocida).
- **R-MC-DISPLAY:** overlay solo en pantalla primaria; MC-por-display
  pendiente (F7-T10). Sin segundo overlay layer-shell sin Ruling.
- **R-MC-ANIM:** entrada slide/zoom 450ms (§2.5: MC/Spaces 400-500ms);
  reduce-motion = fade 150ms sin escala ni desplazamiento
  (`--reduce-motion` o `/MC setReduceMotion`).
- **R-MC-THUMB:** ScreenShot2 (`CaptureWorkspace`/`CaptureWindow` con
  pipe, handle = `internalId` del scripting) si devuelve PNG; si no,
  fallback icono+título con el error exacto en `thumbLog`.

## Atajos del overlay (sin Ctrl)

`Esc` cerrar · `Enter` activar · `←/→` selección · `Tab` App Exposé ·
`F11` Show Desktop (passthrough a `org.kde.KWin showDesktop`).

## Gaps conocidos (ver evidence F7-T01/T04/T05/T06/T07)

- Drag entre Spaces: DropArea → `moveWindowToDesktop` real + 4/5 casos
  E2E por DBus; DND con preview en vivo pendiente.
- Thumbs: `CaptureWindow` depende del handle aceptado por KWin (ver
  `thumbLog` en nested); `CaptureWorkspace` como thumb del Space activo.
- 60fps: medido con `fpsProbe` (cuenta `frameSwapped` 1.2s durante la
  intro); en nested prima llvmpipe, valor honesto en evidencia.
