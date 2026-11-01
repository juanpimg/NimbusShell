# F7-T10 nested — Aceptación: matriz de 10 interacciones + veredicto

Fecha: 2026-11-01. Rama `plasma/f7-mc`. Fase `f7t10` en
`nested-f7mc-inner.sh` (10 ventanas/4 Spaces) + T08 dual. Teclado vía
`/MC selftestKey` (misma ruta `ui*()` que los Shortcuts) + `/MC
uiState` observable; entrega física de teclas pendiente de key lab.

| # | Interacción | Evidencia | Veredicto |
|---|---|---|---|
| 1 | Abrir (show) | `1-abrir=true` | PASS |
| 2 | Cerrar (hide/Esc) | `key-Esc=ok vis=false` | PASS |
| 3 | Space switch | `currentDesktop=2` (KWin) | PASS |
| 4 | Activar ventana | `4-activar=KCalc` | PASS |
| 5 | Mover a Space | drag1/drag2 + totales 10→10→10 | PASS |
| 6 | App Exposé | `ok:Tab`, toggle true→false en `uiState` | PASS |
| 7 | Show Desktop | `showingDesktop=true` → `false` | PASS |
| 8 | Teclado | Left sel 0→9, Right →0, Enter vis=false | PASS (lógica; entrega Qt pendiente) |
| 9 | Drag tile→Space | misma ruta `moveWindowToDesktop` (E2E DBus + DropArea en código) | PASS parcial (click posicional pendiente) |
| 10 | Reduce motion | `f7-mc-rm.png` con footer `anim 150ms fade (RM)` | PASS |
| + | Multi-monitor | T08: `count=2`, MC en primaria | PASS parcial (R-MC-DISPLAY) |

**Veredicto: F7 ACEPTADO como base funcional** (T01–T10). Gaps
heredados: thumbs con `width=0` en 2/10 (dato KWin), 60fps en HW,
MC-por-display, click/key posicional en lab, `removeSpace`.
