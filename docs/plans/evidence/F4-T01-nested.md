# F4-T01 nested — skin semáforos Klassy (PENDIENTE canal config)

Fecha: 2026-10-31. Parte de `f3-klassy-active/inactive.png` (F3-T02):
deco Klassy carga pero dibuja botones estilo Breeze monocromo
(X _ □, sin círculos ni R/A/V). Foco flip OK por scripting; hover físico
pendiente (sin inyección de puntero en nested).

## Claves reales probadas (de `klassy-decoration.kcfg`, sin inventar)

`klassy/klassyrc`: `[Windeco] ButtonShape=ShapeSmallCircle`,
`[ButtonSizing] ButtonSpacingLeft=8`. Resultado: SIN efecto —
mismo mapa de glifos antes/después; `spacing 8→20` + `/KWin reconfigure`
tampoco cambia nada.

## Causa (evidencia, no especulación)

- El `.so` de la deco NO contiene `ShapeSmallCircle` ni `klassyrc`
  (`strings`); solo `libklassycommon` referencia `buttonShape`/`Windeco Presets`.
- Klassy escribe en nuestro `klassyrc` (`[Global] LookAndFeelSet` añadido
  en primer arranque = importa preset bundled) pero ignora nuestras claves
  tanto pre-seed como en runtime.
- Hipótesis: el preset bundled pisa la config, o la 6.7.3 exige el path
  del KCM (`kcm_klassydecoration`, `klassysettings`) para aplicar. Sin
  instrumentar el KCM no se distingue; NO se toca `/tmp/klassy-prefix`.

## Siguiente paso (no en este commit)

Probar `klassysettings --apply` / D-Bus del KCM dentro del nested, o volcar
el `klassyrc` que genera el KCM en host de referencia (lectura) y
replicar claves exactas. Hasta entonces: gap abierto, deco base OK.
