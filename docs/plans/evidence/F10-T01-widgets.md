# Evidencia F10-T01 — ClockApp, Now Playing y Tiempo

Fecha: 2026-11-01 · Rama `plasma/f10-widgets` · Worktree exclusiva f10widgets.

## Qué funciona (verificado en nested KWin virtual, 1280x800)

- **nimbus-clock** (`apps/nimbus-clock/`, Qt6 Quick, CMake, sin KF):
  `f10-clock.png` muestra Reloj mundial con horas reales por zona
  (Madrid 19:49, Londres 18:49, Nueva York 13:49, Tokio 03:49 del día 2,
  indicador día/noche por ciudad). Pestañas Alarmas (lista + crear/borrar,
  persiste en `~/.config/nimbus-clock.ini`), Cronómetro (iniciar/pausar/
  vuelta/restablecer) y Temporizador (presets 1/5/10/25 + inicio/pausa/
  reset). Flags `--demo/--shot/--tab`. `f10-clock-alarm.png` = pestaña
  Alarmas. i18n `qsTr`, `Accessible.name` + Tab en todos los controles.
- **Now Playing** (`MediaWidget.qml` + `mprismodel.h/.cpp`, Qt6 DBus):
  tile glass arriba del Control Center con carátula 40px, título/artista
  y 3 botones (prev/play/next). `f10-media.png` lo muestra con datos demo
  (`--demo-media`: «Canción demo / Artista demo»). Sin reproductor el tile
  se oculta (`hasPlayer=false`); carátula solo `file://` local, sin red.
  Toggles Wi-Fi/BT intactos (mismo `Grid`, sin cambios de lógica).
- **Tiempo** (`WeatherWidget.qml` + `weathermodel.h/.cpp`, Qt6 Network):
  Open-Meteo (current + daily, `timezone=auto`), config
  `~/.config/nimbus-bar/weather.json` (Madrid por defecto), caché 10 min
  en `GenericCacheLocation/nimbus-bar/weather.json`. Integrado en
  `Calendar.qml` bajo el calendario (la barra sigue en 24px, contrato §3):
  `f10-weather.png` muestra ciudad, temp, condición, min/max y 3 días con
  iconos Canvas propios. Offline: última caché o «—», nunca aborta.
- **Menú N**: entrada «Reloj» (`nimbus-clock`, glifo ◷ propio) tras Ayuda;
  orden y resto de objetos sin cambios (popup 340→372 por +1 fila).

## Capturas (`spikes/nested/`)

`f10-clock.png`, `f10-clock-alarm.png`, `f10-media.png`, `f10-weather.png`.

## Tests

- `tests/vm/nested-f10widgets.sh`: kwin virtual + barra + reloj con
  HOME/XDG temporales. PASS: qmllint limpio (6 ficheros), 4 capturas OK,
  `QML_ERRORS=0`, `nimbus-bar: barHeight=24` (F3 intacto).
- Unit determinista (offscreen, sin compositor):
  `--demo-media --dump-media` → `has=1 title='Canción demo'
  artist='Artista demo' playing=1`; `--demo-weather --dump-weather` →
  `city='Madrid' temp='21°' cond='Despejado' code=0 minmax='14° / 24°'
  days=3 stale=0` (3 días fijos hoy/mañana/pasado). PASS.
- `shellcheck -S warning` (script + `iso/build-iso.sh`) PASS;
  `bash -n` + `iso/build-iso.sh --check` PASS (incluye `apps/nimbus-clock`
  en el loop de apps y verificación del binario).
- `tests/bar/test_presets.sh` (regresión F3-T13): 5 FAILs IDÉNTICOS con el
  árbol base intacto (verificado con `git stash -u`): preexistentes en este
  host (plasmashell posee el nombre de notificaciones + deriva
  `clockFormat` del test), no regresión de este cambio.
- `tests/qml/tst_calendar.qml` vía `qmltestrunner`: rc=1 silencioso
  TAMBIÉN con el `Calendar.qml` base (verificado con `git stash`):
  roto en este host, preexistente, no regresión de este cambio.

## Límites reales (honestos)

- MPRIS en nested: sin reproductor real; validado con `--demo-media` y
  con ocultación (`visible: mpris.hasPlayer`). En sesión real lista el
  primer `org.mpris.MediaPlayer2.*` del bus (poll 2s).
- Open-Meteo: en el nested de esta evidencia hubo red y llegaron datos
  reales (Madrid 16° Despejado); el modo `--demo-weather` blinda capturas
  deterministas y la caché de 10 min cubre caídas de red. Sin caché ni red
  se muestra «—».
- Alarmas/temporizador: sin sonido propietario (aviso visual `ringBox`);
  el temporizador no sigue con la app cerrada (proceso propio, sin
  demonio; documentado, no se finge lo contrario).
