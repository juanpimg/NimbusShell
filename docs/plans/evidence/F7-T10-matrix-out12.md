# Matriz de interacción out12 (2026-11-02 05:00-06:00)

Sistema instalado con Calamares desde out12
(`32c700ca26ee3fc22ad43e13e9f7bb689dc2fcdd24ba3a1559ebce98e90cce93`),
sesión `nimbus`, Plasma 6.8.2 Wayland, 1280x800.

## Dock (Krema 0.12)

| Caso | Resultado | Evidencia |
| --- | --- | --- |
| Hover con magnificación | PASS: icono crece (1.6x) y muestra etiqueta | `01-dock-hover.png` |
| Preview de ventana | PASS: miniatura Dolphin/Kate a los ~500 ms | `02-dock-preview.png`, `06-dock-preview-kate.png` |
| Click en app fijada (Dolphin) | PASS: abre Dolphin; punto de running | `03-dolphin-open.png` |
| Menú contextual | PASS: Unpin/New Instance/Close/Settings/About/Quit | `04-dock-context-menu.png` |
| Icono de Kate | **FAIL visual**: abre Kate y la etiqueta es correcta, pero el icono es un globo genérico (no el de Kate) | `05-kate-abre-icono-globo.png` |

El icono erróneo persiste tras reiniciar Krema (`pkill krema` + relanzar):
no es caché de arranque; queda como bug de resolución de icono de Krema/theme.

## Barra superior

| Caso | Resultado | Evidencia |
| --- | --- | --- |
| Menú N | PASS: Acerca de, Ayuda, Reloj, Ajustes, Dormir, Bloquear, Cerrar sesión, Reiniciar, Apagar | `07-bar-n-menu.png` |
| Reloj/calendario | PASS: noviembre 2026, día actual, Madrid 6°, previsión | `08-bar-calendar.png` |
| Control Center | PASS: Wi-Fi, BT, No molestar, Oscuro/NimbusTahoe, Batería, sliders | `09-bar-control-center.png` |

## Mission Control (F7-T10)

| Caso | Resultado | Evidencia |
| --- | --- | --- |
| Meta+W abre MC | PASS: 4 Spaces, thumbs y títulos reales | `10-mc-open.png` |
| Click en miniatura | **FAIL inicial**; tras fix: PASS (Nimbus Welcome enfocada/raised) | `11-mc-click-kate.png` (fallo), `16-mc-click-focus.png` (fix) |
| Crear Space con «+» | PASS: 6 Spaces reales | `13-mc-create-space.png` |
| Cambiar Space Meta+Ctrl+→ | PASS: Space 2 activo (barra sin app) | `14-space-switch.png`, `15-mc-space2-active.png` |
| Drag ventana a Space 2 | **FAIL**: el drop parece mover (Space 2 marcó 2 ventanas) pero al volver Space 2 queda 0 y Space 1 conserva 6 | `12-mc-drag-space2.png` |

### Causa raíz del fallo de click/activación (corregida en repo)

`KWinBackend::runOneshotScript` escribía en `/tmp/opencode/...`, que **no
existe en un sistema instalado**; `QFile::open` fallaba en silencio, así que
MC no refrescaba ni activaba (usaba estado/IDs obsoletos). Además
`loadScript+start()` re-ejecutaba one-shots viejos y el QML activaba antes de
ocultar el overlay (KWin devolvía el foco al desmapear).

Fix validado en VM con binario recompilado:

- runtime dir (`QStandardPaths::RuntimeLocation`) + `QDir().mkpath()`.
- `Script<id>.run` (DBus espera) en vez de `Scripting.start`.
- `workspace.stackingOrder` en vez de `windowList`.
- QML: ocultar overlay y luego `backend.activateWindow(id)`.

Tras el fix, click en la miniatura de Nimbus Welcome la enfoca y eleva
(`16-mc-click-focus.png`). El binario corregido **no está en out12**; debe
entrar en la próxima ISO (out13).

## Multi-monitor / HiDPI

No ejecutado: la VM target tiene **una sola salida** virtual (VNC). Falta
añadir una segunda salida QEMU/`virtio-gpu` o un nested KWin con `--virtual`
para probar panel/Dock/MC por display. F7-T08/F5-T05 siguen abiertos.

## Límites del ledger

Esta matriz **no cierra** F7-T10 (drag falla y falta multi-monitor), ni
F3-T12 (faltan clics de todos los menús/multi-monitor), ni las tareas F5 de
zoom/previews/launch (hacen falta métricas y 20 ciclos). Se usa como
evidencia de avance, no como PASS global.

### Corrección (2026-11-02 06:20)

El supuesto bug del icono de Kate **no era tal**: el SVG
`/usr/share/icons/breeze/apps/48/kate.svg` del ISO, renderizado con
`rsvg-convert`, es el globo azul con el ave blanca que muestra Krema. La
etiqueta «Kate» y la apertura de Kate eran correctas. Se elimina ese gap.

El drag entre Spaces sigue **abierto**: se probaron `drag.target` y
`Drag.active`/`Drag.hotSpot`; el `DropArea` no persiste el movimiento. No se
declara PASS.
