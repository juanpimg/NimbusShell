# F4-T04 nested — fullscreen KWin (Meta+F)

Fecha: 2026-10-31. Rama `plasma/f4-windows`. Extiende el script F4-T03
(`packages/kwin/scripts/nimbus-zoom/`, ahora 24 líneas `main.js`):
`registerShortcut("Nimbus Fullscreen", …, "Meta+F")` alterna
`window.fullScreen` con `print("FS on/off")`. El zoom (verde) sale de
fullscreen antes de aplicar (ya existía; aquí se ejercita).

## Evidencia (KWin 6.8.2 anidado 1280x800 + Kate + barra 24px, journal)

```
FS on     # invoke 1 → Kate fullscreen real (captura: sin deco ni barra)
FS off    # invoke 2 → Kate flotante, barra visible
FS on     # invoke 3 → fullscreen otra vez
ZOOM zoomed x=0 y=24 w=1280 h=776   # verde sale de FS y llena bajo barra
```

`isScriptLoaded nimbus-zoom` → `true`; `shortcutNames` lista
`Nimbus Zoom` + `Nimbus Fullscreen`; los 4 `invokeShortcut` → rc=0.

## Barra layer-shell en fullscreen: SE OCULTA (sin gap)

- `spikes/nested/f4-fullscreen.png` (tras FS on): Kate cubre los 1280x800
  completos, sin decoración y SIN barra — KWin fullscreen tapa la
  layer-shell Top. Equivale a macOS (menubar oculto en fullscreen).
- `spikes/nested/f4-fullscreen-exit.png` (tras FS off): Kate flotante y
  la barra Nimbus visible arriba (logo, Wi-Fi/BT/batería, hora).
- NO hay gap para F4-T04/bar en este eje.

## Hallazgos (2, 1 fixeado en el script, 1 gap abierto)

1. FIX: `w.fullScreen = !w.fullScreen; print(w.fullScreen…)` miente —
   la relectura inmediata devuelve el valor previo (setter asíncrono).
   Fix: `var on = !w.fullScreen; w.fullScreen = on; print("FS "+(on?…))`.
   Re-verificado: journal post-fix muestra on→off→on ✓.
2. GAP (zoom+barra, no de este ticket): con la barra viva (zona exclusiva
   24px), `MaximizeArea.y=24` y el zoom suma +24 → `y=48, h=752` (24px
   muertos entre barra y ventana). Sin barra: `y=24` ✓. Si la barra va a
   reservar zona exclusiva siempre, el +24 debería ser condicional
   (`area.y==0`). Se deja como gap para F4-T04/bar, no se toca aquí.
3. Nota harness: `nimbus-bar` muere si se arranca tras plasmashell/kate
   (log vacío, causa sin aislar); arrancar la barra justo tras KWin
   funciona (BAR-VIVA). Plasmashell anidado escupe `signal 6` en servicios
   portal — se omitió (la barra no lo necesita).
