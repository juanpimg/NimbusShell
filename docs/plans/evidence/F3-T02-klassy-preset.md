# F3-T02 Klassy Tahoe — preset + semáforos en nested

Fecha: 2026-10-31. Harness `--klassy --home <tmp>` (4 runs). Deco
`org.kde.klassy` en `supportInformation`, KWin estable, cleanup limpio.

## Mecanismo real: preset completo, NO claves sueltas

- Claves sueltas pre-seed (`ButtonShape`, spacing) se ignoran: el primer
  arranque importa el preset bundled y la deco no las aplica.
- Lo que SÍ funciona: replicar las ~179 claves del preset en
  `klassy/klassyrc` agrupadas según `klassy-decoration.kcfg`
  (mapeo total salvo `version` de cabecera). Las claves sobreviven al
  arranque (180 líneas post-run, +`LookAndFeelSet`).
- Shippeado: `packages/themes/klassy-preset/nimbus-tahoe.klpw`
  (=`Klassy.klpw` 6.7.3 + 16 deltas Tahoe; resto idéntico, nada inventado).

## Deltas que SÍ aplican (verificado PIL @1x, kate activa)

`KwinButtonsOnLeft=XIA` (izq, offset ~8 px OK), `ButtonShape=
ShapeSmallCircle` (Ø20 px), `ButtonBackgroundColorsActive=
AccentTrafficLights` (ver abajo), `ShowBackgroundNormally*=true`,
`ButtonBackgroundOpacity*=100`.

## Medidas (`f3-klassy-active.png` kate activa; inactiva en `f3-klassy-inactive.png`)

| Ítem | Contrato | Medido | Estado |
|---|---|---|---|
| orden | XIA izq | XIA izq | OK |
| offset | 8–9 px | ~8 px | OK |
| Ø círculo | 12 px | 20 px | NO (IconSize=IconLargeMedium; probar IconSmall) |
| gap | 8 px | 22 px filo a filo | NO (`ButtonSpacing*=8` ignorado) |
| close | #FF5F57 lleno | (218,0,22) lleno + glifo × | ~ (paleta Klassy, no hex) |
| minimize | #FEBC2E lleno | (244,166,96) lleno (activo) | ~ |
| maximize | #28C840 lleno | (96,200,140) ANILLO + glifo □ | NO (hueco) |
| titlebar | ideal 16/26 | 30 px | documentado (Klassy fija) |
| inactivo | gris #8E8E93 | close sigue rojo; resto anillos pálidos | NO (`LockButtonColorsActiveInactive=false` + overrides hex ignorados) |
| glifos ×/−/+ | hover | solo × en close; resto sin glifo | parcial (hover físico pendiente: sin puntero) |

## Claves que NO funcionan (error exacto: sin error, se ignoran)

- `ButtonOverrideColorsActiveClose/Minimize/Maximize=#hex`: sobreviven en
  fichero pero los fondos siguen la enum `ButtonBackgroundColorsActive`
  (los overrides no pintan fondos; contra `AccentNegativeClose` daban
  close rojo + resto hueco pálido).
- `ButtonSpacingLeft/Right=8`: gap medido 22 px igual que con 6 o 20.
- `LockButtonColorsActiveInactive=false` + overrides inactivos: inactivo
  idéntico salvo anillos pálidos; close rojo siempre.

## Foco sin ydotool (canal del harness)

`/Scripting loadScript+start`: `frameGeometry` posiciona (kate 10..626,
konsole 650..1270 medidos); `activeWindow=` no deja rastro verificable
(`print()` no llega al log). Flip fiable: minimizar konsole
(`minimized=true`) → kate sola y activa en `f3-klassy-active.png`.
