# F7-T07 nested — App Exposé pulido + Show Desktop + display

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Mismo harness. Captura
`f7-mc-thumbs.png` con Exposé activo.

## Pulido Exposé

- `Tab` (Shortcut, sin Ctrl) alterna filtro por `currentApp`; cabecera
  `App Exposé — <app> (N de M)` (p. ej. `org.kde.kate (3 de 10)`) ✓
  (activado en test vía `/MC toggleExpose`, misma ruta).
- Grupos por app visibles también en Exposé (un solo grupo) ✓.

## Show Desktop

- `F11` (sin Ctrl) alterna `showDesktop(bool)` → passthrough a
  `org.kde.KWin showDesktop`. Verificado por DBus:
  `showingDesktop=true` y luego `false` (prop KWin leída) ✓.

## R-MC-DISPLAY (documentado)

Overlay solo en pantalla primaria (`primaryScreen()->geometry()`).
KWin VDM es global (no por monitor) y no hay segundo overlay
layer-shell sin Ruling → MC-por-display queda para F7-T10. Sin HW
multi-monitor en nested para medir.
