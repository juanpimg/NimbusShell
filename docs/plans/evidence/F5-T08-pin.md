# F5-T08 — Pin/unpin y persistencia (parcial, 2026-11-02 09:00)

- Clic derecho en Dolphin del Dock -> menú con
  Unpin from Dock/New Instance/Close/Settings/About/Quit
  (`F5-T08-context-menu.png`).
- Unpin from Dock: Dolphin desaparece como pin (`F5-T08-unpinned.png`).
- Reinicio de Krema: el pin no reaparece, aunque el icono de app en ejecución
  sigue en el Dock (`F5-T08-persist-restart.png`).
- Falta cerrar la app y confirmar que no queda icono, re-pin y reorder; por eso
  F5-T08 **no se marca**.

## Cierre, re-pin y persistencia (2026-11-02 09:08)

- Tras unpin + reinicio de Krema, Dolphin desaparece del Dock.
- Se relanza Dolphin, clic derecho en el icono de app -> **Pin to Dock**
  (`F5-T08-pin-menu.png`).
- Se reinicia Krema y se cierra Dolphin con un one-shot KWin:
  el icono **permanece** en el Dock (`F5-T08-pin-persist-closed.png`),
  por lo que el pin persiste y no depende de que la app esté viva.
- Falta drag-reorder, reset y comprobación del JSON; F5-T08 sigue abierto.

## Reorder y reset (2026-11-02 09:15)

- Krema 0.12 persiste el estado en `~/.config/kremarc` (INI), **no JSON**.
- Reorder por `PinnedLaunchers` (Dolphin primero) + reinicio de Krema:
  el orden se aplica y persiste (`F5-T08-reordered.png`).
- Reset: copia de `/usr/share/nimbus/dock/kremarc-nimbus` y reinicio:
  vuelve al preset por defecto (`F5-T08-reset.png`).
- El reorder por **drag visual** de iconos sigue sin validarse con la entrada
  disponible; F5-T08 no se marca hasta probarlo o acordar Ruling.
