# F3-T05 nested — Control Center en barra

Fecha: 2026-10-31. Harness `tests/vm/nested-bar.sh` (sin modificar) con
wrapper a `nimbus-bar --demo-cc` (abre el CC al arrancar; `demo=true`
inhibe `runner.run/query`, solo UI/log). Toggles reales NO ejecutados.

## Resultado: popup derecha, 4 tiles + batería + 2 sliders

- Captura `spikes/nested/f3-cc.png`: popup 300x380 anclado arriba-derecha
  (tiles Wi-Fi/BT/No molestar/Oscuro, "Batería —", sliders vol/brillo);
  barra 24 intacta, kate sin solape, cero errores QML en `nested-bar.log`.
- Medición PIL: tile azul (Oscuro, darkOn por defecto) en mitad derecha
  (2102 px vs 47 izq); estados en demo muestran "—" según spec.
- Lecturas host (referencia, no nested): wifi `enabled`, BT `Powered: yes`,
  batería 81%, volumen 0.70, `brightnessctl` ausente, sin D-Bus
  `org.kde.notificationmanager` en sesión mínima.

## Implementación

`commandrunner.h` (+`query(cmd,tag)`→`outputReady`, shell `/bin/sh -c`);
`ControlCenter.qml` (scrim+popup, CommandRunner+Timer 5s); `Bar.qml`
(botón CC propio de dos toggles + `cc.toggle()`); `main.cpp` (`--demo-cc`).

## Límites / gaps

- `x/y` ignorados en layer-shell: el popup salió a la izquierda; fix con
  `anchors: Top|Right` (la exclusiveZone 24 de la barra lo baja sola).
- En nested: batería/volumen/DND leen "—" (sin BAT en VM, sin PipeWire/
  D-Bus KDE en HOME temporal); sliders deshabilitados en demo.
- Esc/scrim cierran; sin test de tecla real. Sin iconos externos.
