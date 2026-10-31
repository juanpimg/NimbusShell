# F7-T02 nested — Toggle DBus y atajo Meta+W (Ruling stock Overview)

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Mismo harness/capturas que
F7-T01 (`tests/vm/nested-f7mc.sh`, `spikes/nested/f7-mc.png`,
`f7mc-nested.log`).

## 1. Toggle `org.nimbus.MissionControl /MC`

Slots medidos en nested (qdbus6, rc=0 siempre):

- `toggle` 6ms / 10ms (dos llamadas; cierra y reabre + `refresh` +
  `requestActivate`). Muy por debajo del presupuesto A7 (<300ms).
- `hide` / `show` rc=0; `refresh` rc=0 (`windowCount` 4→5 tras re-push,
  sin duplicados); `windowCount/desktopCount/openLatencyMs` usados como
  sondas del test.

## 2. Atajo Meta+W vía KWin script (`kwin/nimbus-mc.js`)

One-shot: `callDBus("org.nimbus.MissionControl", "/MC",
"org.nimbus.MissionControl", "toggle")`. Instalación documentada en
`apps/nimbus-missioncontrol/README.md` (atajo personalizado que ejecuta
`qdbus6 … /MC …toggle`; sin binds `CTRL-*`, Meta como Cmd).

## 3. Ruling R-MC-STOCK (propuesta)

Nimbus MC **reemplaza a Overview stock como overlay por defecto**:
desactivar Meta+W/F3 de kwin en `kglobalshortcutsrc` para no duplicar
overlays; el efecto Overview sigue disponible vía
`/Effects toggleEffect` si se quiere. Sin reescribir upstream
(filosofía anti-fork: overlay propio + scripting, ningún parche KWin).

## 4. Gaps

- Bind automático de Meta+W en dotfiles (`kglobalshortcutsrc` componente
  `nimbus-mc`) → al port de dotfiles (T03+, con Ruling arriba).
- Latencia con 10-20 ventanas y 60fps (vídeo) → F7-T09/T10.
