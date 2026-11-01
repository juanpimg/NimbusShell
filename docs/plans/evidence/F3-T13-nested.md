# F3-T13 — Presets y pin de la barra Nimbus (evidencia nested/offscreen)

Rama `plasma/f3-presets`. Sin VM en este host: verificación offscreen
(`QT_QPA_PLATFORM=offscreen`, Qt 6.12.0) + HOME temporal. Captura en VM
pendiente (aceptación F3-T12).

## Qué se implementó

- `packages/shell/nimbus-bar/presets/{default,compact,minimal}.json`
  (esquema `nimbus-bar-preset/1`: bar, clock, icons.order/hidden, osd,
  glass) + `presets/README.md` (esquema + pin) + `pins.txt`
  (qt 6.12, layershellqt 6.8.2, krema 0.12.0, klassy 6.7.3).
- `scripts/nimbus-bar-preset` (`--list/--apply/--check/--reset/--pin-check/
  --home`, `set -u`, sin root, idempotente, backup
  `nimbusshell-backup-barpreset`).
- Binding: `main.cpp:49` `loadBarPresetJson()` + `:63`
  `barPresetHeight()` → context `barPresetJson` (`:167`) y
  `setExclusiveZone(barHeight)` (`:204`); `Bar.qml:19` parse + `pNum/pStr/
  pHidden`, `:54` `applyPresetOrder()`, `:91` `clockFormat`, OSD por preset
  (`OSD.qml:22-24` props, `:95/:127-128` uso); `--dump-preset` (`main.cpp:
  215-269`, solo verificación, `fprintf` a stderr).
- `tests/bar/test_presets.sh` (esquema, script, pin, qmllint, build cmake +
  binding por preset y fallbacks, todo con HOME temporal).

## Test (`tests/bar/test_presets.sh`): PRESETS VERDE, 22 OK / 0 FAIL

Esquema (3 existen), script (`--list`, apply, idempotencia, check verde,
rechazo de esquema roto y de preset inexistente, reset restaura backup,
reset idempotente, reset sin backup elimina), `--pin-check` OK, qmllint
Bar+OSD OK, build cmake OK, binding por preset + fallbacks OK.

## Binding real (`--dump-preset`, binario offscreen, rc=0, sin errores QML)

- default: `name=default height=24 clockFormat=ddd d MMM HH:mm` +
  `rightBox=wifiItem:1,btItem:1,ccButton:1,batteryItem:1,tray:1,clock:1` +
  `osd=280x56 timeout=1500` + `clock='Sun 1 Nov 02:45'`.
- compact: `height=24 clockFormat=HH:mm`, `btItem:0`, resto visibles.
- minimal: `height=20`, `wifiItem:0,btItem:0,ccButton:0`,
  `osd=240x48 timeout=1200`, `clock='02:45'`.
- Fallbacks (sin preset y preset corrupto): `height=24 clockFormat=HH:mm`,
  todo visible, `osd=280x56 timeout=1500`, rc=0.
- Reorden custom (`clock,tray,battery,controlcenter,bluetooth,wifi`):
  `rightBox=clock:1,tray:1,batteryItem:1,ccButton:1,btItem:1,wifiItem:1`
  (orden visual vía `childItems()`), `orderError=` vacío.

## Pin (`scripts/nimbus-bar-preset --pin-check`): PINCHECK OK

`krema 0.12.0` (evidencia `F0-T03.md`), `klassy 6.7.3` (`F2-T01.md`),
`qt instalado 6.12.0 casa con pin 6.12`,
`layershellqt instalado 6.8.2 == pin`. Sin instalar nada.

## Bugs cazados por la verificación

1. `applyPresetOrder()` iteraba al revés: con orden invertido volvía al
   original. Corregido a pasada directa (y luego a holder intermedio).
2. Re-anexar al MISMO padre es no-op en Qt (ni `QObject::children()`
   cambia): se mueve por `orderHolder` y se vuelca `childItems()` en el
   dump. Lección: verificar orden visual, no lista QObject.
3. `qmltestrunner` y el runtime `qml` no sirven en este host: este Qt
   suprime todo logging QML (ver F3-T05-fix) y `qmltestrunner` falla hasta
   con un TestCase trivial (rc=1 sin salida); `grabToImage` offscreen no
   guarda. Por eso el binding se verifica con `--dump-preset` + `fprintf`.
   `tst_calendar.qml` no tocado; `qmllint` verde en todo `packages/`+`apps/`.

## Pendiente (no cierra F3-T12)

Captura nested/VM con cada preset + clics (reloj, CC, OSD) y
`diff -rq` dotfiles si se despliega el preset por defecto (no se tocó
`install.sh`/`dotfiles`: la barra funciona sin preset vía fallbacks).
