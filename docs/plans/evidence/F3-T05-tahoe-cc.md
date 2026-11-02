# F3-T05 — Control Center Tahoe (worktree `plasma/f-cc-tahoe`, 2026-11-02)

## Resultado

Rediseño completo de `ControlCenter.qml` como panel flotante de **cápsulas de
vidrio independientes**, sin rectángulo opaco exterior:

- Panel de 356 px (contenido 344) anclado arriba-derecha, 8 px bajo la barra.
- Rejilla de 2 columnas de 166 px con gap 12.
- Cápsulas de 166×64, radio 28; sliders de 344×96, radio 26.
- Columna izquierda: Wi-Fi, Bluetooth, No molestar.
- Columna derecha: módulo grande Ahora suena + batería, y fila de dos círculos
  (modo oscuro, batería) + cápsula Enfoque.
- Ancho completo: Pantalla y Sonido (etiqueta + slider).
- Iconos dibujados con Canvas (Wi-Fi, Bluetooth, luna, batería, sol, altavoz,
  nota, play/pausa/prev/next). Sin letras ni activos Apple.
- Badge **blanco** con glifo de acento cuando el control está activo (Tahoe),
  badge gris cuando está desactivado; la cápsula no se rellena de acento.
- Textos en español, tipografía Inter y tokens `NimbusTokens.type.*`.

Además se corrigieron tres bugs funcionales del CC anterior:

1. **Tema claro/oscuro**: se lee `ColorScheme` del grupo `General` y se
   detecta `Light` en el nombre (antes se buscaba “Dark”, que NimbusTahoe no
   contiene); el botón aplica `NimbusTahoeLight`/`NimbusTahoe`, no Breeze.
2. **No molestar**: se enlaza a `notifServer.inhibited` (propiedad del servidor
   FDO propio) y el clic la conmuta; antes la consulta DBus devolvía varias
   líneas y el parseo `=== "true"` nunca acertaba, y `flip("dnd")` no existía.
3. **Sliders**: el ancho se calcula contra el `Row` con id (el `parent.width`
   dentro del `Slider` daba 0 y la pista/knob no se dibujaban).

## Verificación

- `qmllint packages/shell/nimbus-bar/qml/ControlCenter.qml` → rc 0.
- `cmake -S packages/shell/nimbus-bar -B /tmp/cc-build2 -G Ninja` + build →
  PASS.
- Captura nested real (KWin 6.8.2 virtual 1280×800, wallpaper Nimbus
  `sequoia-dark.jpg`, socket aislado `nimbus-cc-review3`):

```bash
bash tests/vm/nested-bar.sh \
  --bin /tmp/cc-build2/nimbus-bar \
  --out spikes/cc-review3 --timeout 30 \
  --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-cc-review3 --bar-args "--open-cc"
```

- `F3-T05-tahoe-cc.png`: captura completa 1280×800.
- `F3-T05-tahoe-cc-crop.png`: recorte del panel.
- Medición: panel en x=924..1268 (344 px de contenido), y=32..460; margen
  derecho 12 px; solape con la ventana de Kate correcto (capa Top).
- Estados reales en nested: Wi-Fi **Activado**, Bluetooth **Activado**,
  batería 79 %,sliders con pista/fill/knob visibles.

## Límites (no cerrar F3-T05 todavía)

- **No hay blur/refracción real en el CC**: las cápsulas son tinte alfa +
  hairline; el blur de compositor ya funciona en la barra (F11-T02) y hay que
  extenderlo a las ventanas layer-shell del CC/menús/notificaciones.
- La fila “dos círculos + Enfoque” es una aproximación: Tahoe usa dos círculos
  pequeños bajo el reproductor y una cápsula Focus ancha en la fila siguiente.
  Falta Stage Manager / Screen Mirroring.
- `--demo-cc` no inyecta estados falsos (Wi-Fi/BT off); para la captura de
  estados “on” se usó `--open-cc` con las lecturas reales del host nested.
- Sin validación en la VM instalada (out15/out16).
