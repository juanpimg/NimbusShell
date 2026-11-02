# F3-T05 — Control Center Tahoe (2026-11-02)

## Resultado

Rediseño completo de `ControlCenter.qml` como panel flotante de **cápsulas de
vidrio independientes**, sin rectángulo opaco exterior:

- Panel de 304 px (contenido 292, la medida ~292 pt de macOS) anclado
  arriba-derecha, 8 px bajo la barra.
- Rejilla de 2 columnas de 140 px con gap 12.
- Cápsulas de 140×64, radio 28; sliders de 292×96, radio 26.
- Columna izquierda: Wi-Fi, Bluetooth, Enfoque (DND; antes “No molestar”).
- Columna derecha: módulo grande Ahora suena + batería, y fila de dos
  círculos de 64 px (modo oscuro, batería). Se eliminó la cápsula “Enfoque”
  duplicada que repetía el mismo DND.
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

## Blur real del compositor (primera capa de Liquid Glass)

`main.cpp` aplica `KWindowEffects::enableBlurBehind()` a la barra y al popup
del CC (scope `nimbus-cc`) con región explícita. En KWin 6.8 Wayland usa
`ext-background-effect-v1`; el binding/capability es asíncrono y la región es
double-buffered, así que se registra al arrancar, se reaplica a los 500 ms y se
pide `requestUpdate()`.

- Damero de 16 px: dentro del CC el patrón queda promediado (blur); fuera
  sigue nítido. Evidencia `F3-T05-tahoe-cc-blur-checker.png` y recorte
  `...-crop.png`.
- Se descarta el **scrim** full-screen del CC (si se blurea, oscurece/
  emborrona todo el escritorio) y se comprueba la geometría como red de
  seguridad.
- **Allowlist**: de momento solo barra + CC. Registrar blur en el resto de
  popups ocultos (menú/calendario/tray/OSD/notificaciones) hacía que KWin 6.8
  blureara el output completo; se validarán uno a uno con captura antes de
  añadirlos. Esto **no es** Liquid Glass completo: falta refracción/lensing,
  dispersión y rim/specular (Glass, F11-T02).

## Verificación

- `qmllint packages/shell/nimbus-bar/qml/ControlCenter.qml` → rc 0.
- `cmake -S packages/shell/nimbus-bar -B /tmp/barblur2 -G Ninja` + build →
  PASS. `bash tests/bar/test_presets.sh` → VERDE.
- Capturas nested reales (KWin 6.8.2 virtual 1280×800, socket aislado):

```bash
# visual con wallpaper Nimbus
bash tests/vm/nested-bar.sh \
  --bin /tmp/barblur2/nimbus-bar \
  --out spikes/cc-292b --timeout 30 \
  --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-cc-292b \
  --kwinrc /tmp/opencode/glass-kwinrc-subtle \
  --plugin-path /tmp/glass-prefix/lib/plugins \
  --bar-args "--open-cc"

# prueba de blur sobre damero de alto contraste
bash tests/vm/nested-bar.sh \
  --bin /tmp/barblur2/nimbus-bar \
  --out spikes/final-checker --timeout 30 \
  --wallpaper /tmp/opencode/checker-1280x800.png \
  --socket nimbus-final-checker \
  --kwinrc /tmp/opencode/glass-kwinrc-subtle \
  --plugin-path /tmp/glass-prefix/lib/plugins \
  --bar-args "--open-cc --demo-menu"
```

- `F3-T05-tahoe-cc.png` / `-crop.png`: captura final con wallpaper.
- `F3-T05-tahoe-cc-blur-checker.png` / `-crop.png`: damero + blur real.
- Medición: ventana 304×450 en x=976..1280, y=24..474; contenido 292 px
  (x=976..1268), margen derecho 12 px; solape con Kate correcto (capa Top).
- El media module usa artwork 32 px y textos “Ahora suena” / “Sin música”
  para que no haya elisión a 292 px.
- Estados reales en nested: Wi-Fi **Activado**, Bluetooth **Activado**,
  batería 79 %, sliders con pista/fill/knob visibles.
- Log: `nimbus-bar: glass scope=nimbus-cc` y
  `nimbus-bar: blur compositor activo=1`.

## Límites (no cerrar F3-T05 todavía)

- Adaptación funcional: Tahoe pone AirDrop a la izquierda y Stage Manager /
  Screen Mirroring bajo el reproductor, con Focus ancho en la fila siguiente.
  Nimbus usa Enfoque (DND) a la izquierda y dos círculos funcionales
  (modo oscuro, batería) bajo el reproductor; no hay controles de relleno.
  Falta AirDrop/Stage Manager reales.
- Sin refracción real (solo blur de fondo); sin Reduce Transparency.
- `--demo-cc` no inyecta estados falsos (Wi-Fi/BT off); para la captura de
  estados “on” se usó `--open-cc` con las lecturas reales del host nested.
- Sin validación en la VM instalada (out15/out16).
