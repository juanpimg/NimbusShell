# F4-T03 nested — zoom KWin (botón verde macOS)

Fecha: 2026-10-31. Rama `plasma/f4-windows`. KWin 6.8.2 anidado
(`kwin_wayland --virtual`, bus D-Bus privado, HOME/XDG temporales;
`~/.config` del host intacto, sin root).

## Qué hace

`packages/kwin/scripts/nimbus-zoom/` (19 líneas `main.js` + `metadata.json`
KWin/Script): `registerShortcut("Nimbus Zoom", …, "Meta+Z")`; `toggleZoom()`
aplica `frameGeometry = clientArea` tal cual (fs=0), guarda la geometría por
ventana y el 2.º invoke la restaura. Desactiva `fullScreen`/maximizado antes.

**Regla (fix F4, 2026-10-31):** el target es `area.y`/`area.height` SIN
sumar nada. `MaximizeArea` ya excluye la zona exclusiva de la barra, así
que `+24` la contaba dos veces (daba `y=48` con barra viva). Con barra:
`y=24`; sin barra: `y=0` (llena todo; en producción la barra siempre está).

## API KWin 6.8 verificada (nada inventado)

- `workspace.clientArea(KWin.MaximizeArea, …)` EXISTE y funciona
  (journal: `ZOOM area via MaximizeArea`). Fallbacks en el script:
  `WorkArea` → `PlacementArea` → `FullArea`.
- `w.setMaximize(false,false)`, `w.frameGeometry` (lectura/escritura),
  `w.fullScreen`, `workspace.activeWindow`, `registerShortcut` — todos OK.
- `qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded nimbus-zoom` → `true`;
  `…/component/kwin …shortcutNames` lista `Nimbus Zoom`;
  `…invokeShortcut "Nimbus Zoom"` → rc=0 (las 2 veces).

## Evidencia (journal del KWin anidado; fix F4 re-testeado en 1280x800)

```
# CON barra viva (zona exclusiva 24px):
ZOOM zoomed x=0 y=24 w=1280 h=776      # antes del fix: y=48 (doble reserva)
# SIN barra:
ZOOM zoomed x=0 y=0 w=1280 h=800       # llena el área completa
ZOOM restored x=189 y=127 w=646 h=513  # geometría original ✓ (run previo)
```

Nota histórica: el primer run usó `--virtual 1280x800` (mal parseado →
1024x768); los runs del fix usan `--width/--height` (1280x800 real).

Captura `spikes/nested/f4-zoom.png` (CON barra, tras invoke): barra Nimbus
visible filas 0–23, titlebar Kate desde fila 24 = `(61,61,62)` → y=24 exacto.
Captura `spikes/nested/f4-zoom-nobar.png` (SIN barra): titlebar desde fila 0
→ y=0, sin gap.

## Pendiente (documentado, no bloquea)

- Drag/pointer físico: sin inyección de puntero en nested; el toggle por
  shortcut cubre la geometría, el arrastre queda para VM.
- Rama `fullScreen`/maximizado previo: Kate no estaba maximizada; el
  código la desactiva primero pero ese camino no se ejercitó.
- Los `print("ZOOM …")` van al journal (`journalctl -g ZOOM`), no al
  stderr de kwin_redirigido (journald los reclama).
