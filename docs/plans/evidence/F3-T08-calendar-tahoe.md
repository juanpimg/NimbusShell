# F3-T08 — Calendario Tahoe compacto sin eventos falsos

Fecha: 2026-11-02 · Rama `feat/calendar-tahoe` · Worktree
`NimbusShell-calendar` · Nested local (sin tocar la VM out15 ni la dev).

## Qué cambia

- **`Calendar.qml`**: popover 300x368 (antes 280x470), radio 14, vidrio
  `popupBg` 0.66 (sin fondo opaco). Cabecera 15 semibold con ‹ › de 24,
  fila L M X J V S D de 11, rejilla fija 6x7 (42 celdas) de 30 px, hoy con
  **círculo** de acento y número blanco, sábado/domingo atenuados. Sin
  `placeholderDays`: **cero puntos de evento** (no hay fuente real).
  Se añade `today()` + botón «Hoy» (`calToday`); se conservan
  `opened/toggle/open/close`, `prev/next`, `calPrev/calNext/calHeader`,
  `calDay:N`, `calWeather`, Esc/scrim y foco de teclado.
- **`WeatherWidget.qml`**: mismo modelo (`weather`, `wxHead`, `wxSub`,
  3 días) como pie compacto: icono Canvas 28 (lienzo lógico 36 escalado),
  ciudad/temp 13, condición 11, sin hueco muerto bajo el tiempo.
- **i18n**: nueva cadena `Hoy` → `Today` en `scripts/nimbus-i18n`; TS
  regenerados (`--extract`) y verificados (`--check`, 363 cadenas).
- **Test**: `test_today` en `tests/qml/tst_calendar.qml`.

## Comandos y resultado

```bash
qmllint packages/shell/nimbus-bar/qml/Calendar.qml \
        packages/shell/nimbus-bar/qml/WeatherWidget.qml      # RC=0
/usr/lib/qt6/bin/qmlformat -i packages/shell/nimbus-bar/qml/{Calendar,WeatherWidget}.qml
bash -n scripts/nimbus-i18n; shellcheck -S warning scripts/nimbus-i18n  # RC=0
cmake -S packages/shell/nimbus-bar -B /tmp/opencode/nimbus-build-calendar \
      -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build ...          # RC=0
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner \
      -input tests/qml/tst_calendar.qml                                # 9 passed, 0 failed
scripts/nimbus-i18n --extract                                       # EXTRACT_OK: 363
scripts/nimbus-i18n --check                                         # CHECK_OK: 363, 0 unfinished
```

Nested (harness principal, `--bin /tmp/opencode/nimbus-build-calendar/nimbus-bar`):

```bash
bash tests/vm/nested-bar.sh --bin /tmp/opencode/nimbus-build-calendar/nimbus-bar \
  --out spikes/cal-tahoe \
  --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-cal-tahoe --kwinrc /tmp/opencode/glass-kwinrc-subtle \
  --plugin-path /tmp/glass-prefix/lib/plugins --bar-args "--demo-calendar"
```

Salida relevante (`spikes/cal-tahoe/nested-bar.log`, exit 0):

```
nimbus-bar: window title=nimbus-cal geom=300x368 scope=nimbus-cal
nimbus-bar: glass scope=nimbus-cal
nimbus-bar: blur compositor activo=1
[bar] nimbus-bar VIVO pid=410164
[bar] f3-bar-24.png OK
... NIMBUS win ... geom=980,24,300,368
```

Sin errores QML: el log solo contiene avisos benignos de
xdg-desktop-portal/PipeWire del entorno nested. El plugin Glass y el blur
del compositor estaban disponibles y activos (`/tmp/glass-prefix`).

## Medición antes/después (capturas reales)

- Antes (`F3-T08-calendar-before.png`, recorte de
  `spikes/glass-all2/f3-bar-24.png`): popup **280x470**
  en x≈1000, y=24..491; último contenido del tiempo en y≈323 y borde
  inferior en y≈491 ⇒ **≈168 px vacíos** bajo el pie. Puntos falsos en los
  días 1 y 15.
- Después (`F3-T08-calendar-tahoe.png`, 1280x800): popup **300x368**
  (x=980, y=24..391); último contenido en y≈363 y borde interior en y≈390
  ⇒ **≈27 px** de respiro. El área de contenido queda llena.
- Hoy: círculo de acento detectado (≈1050 px azules en el popup; antes el
  resaltado era un cuadrado de 6 px de radio).
- `grep -n "placeholderDays\|width: 4" Calendar.qml` → sin resultados.

## Capturas

- `docs/plans/evidence/F3-T08-calendar-tahoe.png` — 1280x800, barra +
  calendario abierto sobre fondo Sequoia.
- `docs/plans/evidence/F3-T08-calendar-tahoe-crop.png` — recorte 310x380
  del popover para inspección de tipografía/espaciado.
- `docs/plans/evidence/F3-T08-calendar-before.png` — recorte 310x490 del
  popover anterior (280x470, puntos en 1/15 y hueco inferior).

## Límites honestos

- Nested no inyecta clic/Esc reales: `close()` es el mismo camino que
  ejercita el scrim y el `Shortcut`, cubierto por `test_open_close`.
- No hay eventos reales en Nimbus, así que el popover no dibuja ninguno;
  si en el futuro se cablea una fuente (CalDAV/ICS), habrá que añadir dots.
- «Hoy» es una acción propia de Nimbus (el popover de macOS no la muestra
  como botón; allí vive en la app Calendario). Se mantiene porque el
  contrato de F3-T08 exige `today` y `calToday`.
- Tiempo en nested: datos reales/caché de Open-Meteo (Madrid 19°); sin red
  ni caché muestra «—», sin inventar.
- `/usr/bin/qmltestrunner` falla en silencio en este host (preexistente);
  se usó `/usr/lib/qt6/bin/qmltestrunner` (Qt 6.12).
