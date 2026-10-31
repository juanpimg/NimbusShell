# F4-T04 nested — fullscreen KWin (Meta+F)

Fecha: 2026-10-31. Rama `plasma/f4-windows`. Extiende el script F4-T03
(`packages/kwin/scripts/nimbus-zoom/`, ahora 19 líneas `main.js`):
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
2. FIX F4 (aplicado, cierra el gap): el zoom ya NO suma +24 — target =
   `clientArea` tal cual. Re-testeado: con barra `y=24 h=776` ✓, sin barra
   `y=0 h=800` ✓. Capturas: `f4-zoom.png` (barra + Kate en y=24),
   `f4-zoom-nobar.png` (Kate en y=0). Detalle en `F4-T03-nested.md`.
3. Nota harness: `nimbus-bar` muere si se arranca tras plasmashell/kate
   (log vacío, causa sin aislar); arrancar la barra justo tras KWin
   funciona (BAR-VIVA). Plasmashell anidado escupe `signal 6` en servicios
   portal — se omitió (la barra no lo necesita).
