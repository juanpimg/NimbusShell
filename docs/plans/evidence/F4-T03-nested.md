# F4-T03 nested — zoom KWin (botón verde macOS)

Fecha: 2026-10-31. Rama `plasma/f4-windows`. KWin 6.8.2 anidado
(`kwin_wayland --virtual`, bus D-Bus privado, HOME/XDG temporales;
`~/.config` del host intacto, sin root).

## Qué hace

`packages/kwin/scripts/nimbus-zoom/` (34 líneas `main.js` + `metadata.json`
KWin/Script): `registerShortcut("Nimbus Zoom", …, "Meta+Z")`; `toggleZoom()`
llena el área de trabajo bajo la barra de 24px (`y=area.y+24`,
`h=area.height-24`, fs=0), guarda la geometría por ventana y el 2.º invoke
la restaura. Desactiva `fullScreen`/maximizado antes de aplicar.

## API KWin 6.8 verificada (nada inventado)

- `workspace.clientArea(KWin.MaximizeArea, …)` EXISTE y funciona
  (journal: `ZOOM area via MaximizeArea`). Fallbacks en el script:
  `WorkArea` → `PlacementArea` → `FullArea`.
- `w.setMaximize(false,false)`, `w.frameGeometry` (lectura/escritura),
  `w.fullScreen`, `workspace.activeWindow`, `registerShortcut` — todos OK.
- `qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded nimbus-zoom` → `true`;
  `…/component/kwin …shortcutNames` lista `Nimbus Zoom`;
  `…invokeShortcut "Nimbus Zoom"` → rc=0 (las 2 veces).

## Evidencia (journal del KWin anidado, 3 runs idénticos)

```
ZOOM loaded
ZOOM area via MaximizeArea
ZOOM zoomed x=0 y=24 w=1024 h=744      # y=24, h=768-24 ✓
ZOOM restored x=189 y=127 w=646 h=513  # geometría original ✓
```

Nota: el `--virtual 1280x800` se parseó como resolución por defecto
1024x768 (la sintaxis es `--width/--height`); irrelevante porque la
matemática es relativa al área (`h=area-24` se cumple igual).

Captura `spikes/nested/f4-zoom.png` (tras invoke #1): Kate llena la
pantalla con gap negro arriba; medido por píxel filas 0–23 = `(0,0,0)`,
fila 24+ = titlebar `(61,61,62)` → y=24 exacto.

## Pendiente (documentado, no bloquea)

- Drag/pointer físico: sin inyección de puntero en nested; el toggle por
  shortcut cubre la geometría, el arrastre queda para VM.
- Rama `fullScreen`/maximizado previo: Kate no estaba maximizada; el
  código la desactiva primero pero ese camino no se ejercitó.
- Los `print("ZOOM …")` van al journal (`journalctl -g ZOOM`), no al
  stderr de kwin_redirigido (journald los reclama).
