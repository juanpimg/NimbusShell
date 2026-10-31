# nimbus-missioncontrol — overlay Mission Control/Spaces (F7-T01/T02).

Qt6 Quick (C++/QML, sin KF obligatorio). Rejilla estilo macOS: fila de
Spaces + ventanas del Space activo + App Exposé. Datos vía KWin
scripting/DBus; miniaturas reales si ScreenShot2 responde, si no
fallback icono+título.

## Uso

```sh
cmake -B build -S apps/nimbus-missioncontrol && cmake --build build
./build/nimbus-missioncontrol --demo            # datos falsos (2 Spaces, 6 ventanas)
./build/nimbus-missioncontrol --shot /tmp/mc.png # captura propia tras pintar
qdbus6 org.nimbus.MissionControl /MC org.nimbus.MissionControl.toggle
```

## Atajo (Meta+W) vía KWin script

`kwin/nimbus-mc.js` es un one-shot: llama por DBus a `/MC toggle`.
Cargarlo una vez deja el atajo libre para bindear Meta+W en
`kglobalshortcutsrc` (componente `nimbus-mc`); el stock Overview
(`Meta+W`/`F3` en kwin) debe desactivarse para no duplicar overlays
(Ruling R-MC-STOCK: Nimbus MC reemplaza a Overview como overlay por
defecto; Overview sigue disponible vía efecto si se quiere).

## Gaps conocidos (ver evidence F7-T01/T02)

- Drag entre Spaces: implementado (DropArea → moveWindowToDesktop);
  DND fino con preview en vivo pendiente.
- Multi-monitor: overlay en pantalla primaria; MC-por-display pendiente.
- Miniaturas: ScreenShot2 como pipewire requiere portal; fallback
  icono+título hasta F7-T09.
