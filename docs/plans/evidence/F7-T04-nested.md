# F7-T04 nested — Thumbnails reales ScreenShot2 + grupos y tamaños

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Mismo harness (10 ventanas).
Captura `spikes/nested/f7-mc-thumbs.png` (App Exposé + thumbs).
`thumbLog` completo en `spikes/nested/f7mc-nested.log`.

## Hallazgo: ScreenShot2 devuelve RAW, no PNG (medido, no inventado)

- Servicio `org.kde.KWin.ScreenShot2`, path
  `/org/kde/KWin/ScreenShot2`. `CaptureWorkspace(opciones, pipe)` →
  **4096000 bytes = 1280×800×4 RAW BGRA32** (sin cabecera). Los
  `CaptureWindow(handle, opciones, pipe)` → RAW del tamaño de la ventana
  (p. ej. 908×493, 766×566, 646×513).
- **Handle aceptado = `internalId` del scripting** (UUID en Plasma 6,
  p. ej. `{f7271a40-…}`): 8/8 ventanas `OK`, 0 rechazos.
- Las dimensiones/stride vienen en el reply (`width/height/stride`,
  workspace stride=5120). El backend envuelve en
  `QImage(raw, w, h, stride, Format_RGB32)` y guarda PNG (colores
  verificados visualmente en la captura).
- Lección del intento previo: leer el pipe hasta EOF cuelga a KWin
  (retiene su extremo) — lectura con `poll()` + corte tras 500ms de
  silencio con datos, tope 4s; extremo de escritura propio cerrado
  después del envío (si no, EOF imposible).

## R-MC-THUMB

`requestThumbs()` (workspace + hasta 10 ventanas, en cadena sin
bloquear UI): si hay PNG, `hasThumbnails=true` y tiles/space-activo
muestran `Image`; si no, fallback icono+título + error exacto en
`thumbLog()` (vía `/MC thumbLog`).

## Medidas

- `workspace PNG 1280x800` + 10/10 ventanas `PNG … OK` (dims reales
  variadas) ✓. Captura: grupo `org.kde.kate · 3` con 3 thumbs legibles,
  thumb del workspace en tile `Escritorio 1`, label
  `Miniaturas en vivo (ScreenShot2)` ✓. **0 errores QML** (cero
  `Image: Error decoding`).
- Grupos por app (cabecera `app · N`) + 3 tamaños S/M/L por área real
  (`sizeClass`: <300k / <900k / resto; tiles 170/220/275px) ✓.

## Gaps

- 2/10 ventanas reportan `frameGeometry.width=0` vía scripting (tiles
  muestran `0×493`, `0×566`; sizeClass cae a S). Dato KWin, no cálculo.
- Thumbs conservados por `internalId` entre refresh; si KWin recicla el
  id tras cerrar, thumb obsoleta hasta el próximo `requestThumbs`.
