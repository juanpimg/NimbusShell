# F3-T02/F4-T01 Klassy — preset Tahoe + parche hover `+` (evidencia nested)

Fecha: 2026-10-31. Harness `tests/vm/nested-plasma.sh --klassy --no-probe
--home <seed>` (flag nuevo: respeta el klassyrc del seed; antes el
pre-seed `ButtonSpacingLeft=8` y la sonda runtime a 20 lo pisaban).
Deco `org.kde.klassy` 6.7.3 stock de `/tmp/klassy-prefix` en
`supportInformation`, KWin estable; build parcheado en
`/tmp/klassy-nimbus-prefix` para el `+`.

## 1. Canal de aplicado real (nuevo)

- Claves sueltas NO bastan: el primer arranque importa el preset bundled.
- Lo que funciona: `klassy-settings -i nimbus-tahoe.klpw` +
  `klassy-settings -w NimbusTahoe` (escribe `klassy/klassyrc` por grupos +
  `kwinrc`), y arrancar el nested con ese HOME como seed.
- El nombre interno del preset pasó de Klassy a NimbusTahoe para evitar
  el import bundled stock (F4-T02).
- Las claves sobreviven al arranque (post-run intactas salvo
  `[Global] LookAndFeelSet` añadido por Klassy).

## 2. Causas raíz de los "NO" anteriores (código, no especulación)

- Overrides `#hex` ignorados: `ButtonOverrideColors*` son blobs JSON
  (`{"BackgroundNormal":[r,g,b],...}`), parseados en
  `libbreezecommon/decorationbuttoncolors.cpp:decodeButtonOverrideColors`.
  `#FF5F57` falla en `QJsonDocument::fromJson` → se ignora en silencio.
  Mapeo índice↔botón en `libbreezecommon/breeze.h:buttonTypeToKcfgColorIndex`
  (Close=5, Minimize=3, Maximize=4 = nombres de clave del preset).
- Ø20: `IconSize=IconLargeMedium` (base 22/fondo 20 en
  `kdecoration/breezedecoration.cpp:calculateIconSizes`). `IconVerySmall`
  da base 14/fondo 12 = Ø12 sin tocar C++.
- Gap: `m_leftButtons->setSpacing()` (`breezedecoration.cpp:1278`) SÍ
  aplica, en arranque y por `/KWin reconfigure`. Modelo medido:
  gap filo-a-filo = spacing + 2 (1 px de centrado por lado: padded 14
  vs fondo 12). Puntos: spacing 20→22, 8→10.
- Offset: `setPos(hPadding + borderLeft())` con
  `hPadding = TitleBarLeftMargin − border(Normal 4)`; `TitleBarLeftMargin=8`
  → círculo en 9 px del borde.

## 3. Medidas finales (`spikes/nested/f3-klassy-active/inactive.png`, kate)

| Ítem | Contrato | Medido @1x (PIL) | Estado |
|---|---|---|---|
| orden | XIA izq | XIA izq | OK |
| Ø círculo | 12 | 12×12 (w=h=12 saturado) | OK |
| gap filo | 8 | 8 (stock `--no-probe`, seed intacto) | OK |
| close | #FF5F57 lleno | (255,95,87) centro | OK |
| minimize | #FEBC2E lleno | (254,188,46) centro | OK |
| maximize | #28C840 lleno | (40,200,64) centro | OK |
| inactivo | #8E8E93 | (142,142,147) ×3, sin glifo | OK |
| glifos normal | ninguno (macOS) | ninguno en reposo (PIL: 0 px oscuros en los 6 círculos) | OK |
| offset | 8–9 | 9 (filo close x=19 − borde x=10, método abajo) | OK |
| titlebar | 26–28 | 26–27 (filas claras + separador 1 px) | OK |

## 4. Hover `+`: parcheado y verificado con glifos forzados (F4-T01 parcial)

- Parche `packages/kwin/decoration/nimbus-decoration/klassy-hover-plus.patch`
  (+48/−1, aplica limpio con `patch -p1` sobre 6.7.3): maximize pinta `+`.
- Build `-DBUILD_QT5=OFF -DBUILD_QT6=ON` + install a
  `/tmp/klassy-nimbus-prefix` (137 targets, sin errores); `KLASSY_PREFIX`
  del harness ahora admite entorno (ya no hardcodea `/tmp/klassy-prefix`).
- Captura `spikes/nested/f3-klassy-plus.png` (seed con glifos forzados
  siempre visibles A PROPÓSITO, sin puntero): `+` 8×9 px en verde, ×/−
  intactos, Ø12/gap8/colores sin cambios. No confundir con reposo: el
  preset shippeado oculta todos los glifos hasta hover.
- Método offset (reproducible): borde = primer píxel claro en la fila del
  titlebar (y=84 abs); filo = primer píxel saturado del close. Medido en
  activa e inactiva: borde x=10, filo x=19 → 9. Un borde en 12–13 no es
  reproducible en estas capturas (posible sombra); `TitleBarLeftMargin=8`
  se mantiene.
- Alcance: **F3-T02 (estático) cerrable** — Ø12/gap8/colores/inactivas/
  offset/titlebar medidos @1x. **F4-T01 (hover real con puntero) NO** —
  el nested no inyecta puntero y el `+` solo se verificó con glifos
  forzados; el hover físico exige VM.

## 5. Archivos

- `packages/themes/klassy-preset/nimbus-tahoe.klpw` (preset; deltas en cabecera)
- `packages/kwin/decoration/nimbus-decoration/README.md` (aplicar/construir/pin)
- `packages/kwin/decoration/nimbus-decoration/klassy-hover-plus.patch`
- `spikes/nested/f3-klassy-plus.png` (glifo `+` con build parcheado)

## 6. Harness reproducible (`--no-probe`)

- Antes: pre-seed `ButtonShape` + `ButtonSpacingLeft=8` y sonda runtime
  `8→20` + `/KWin reconfigure` pisaban el seed (causó el "spacing
  ignorado" aparente). Ahora `--no-probe` omite ambos; el seed manda.
- Gap 8 re-capturado con harness stock (`exit=0`, seed intacto,
  sin sonda en log). Sin `--no-probe` el comportamiento anterior sigue
  (compatibilidad con runs previos).
- `KLASSY_PREFIX` por entorno (defecto `/tmp/klassy-prefix`); fix del
  crash `LOG: variable sin asignar` con `set -u` en runs `--klassy`.
- `klassy-settings -w` genera iconos en `XDG_DATA_HOME`: redirigirlo o
  ensucia `~/.local/share/icons` (limpiado tras el test).
