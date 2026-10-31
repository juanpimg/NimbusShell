# F3-T02/F4-T01 Klassy — preset Tahoe sin parche C++ (evidencia nested)

Fecha: 2026-10-31. Harness `tests/vm/nested-plasma.sh --klassy --home <seed>`
+ copia sin sonda en `/tmp` (el harness stock fuerza `ButtonSpacingLeft`
al arrancar y una sonda runtime a 20; ver §6). Deco `org.kde.klassy`
6.7.3 stock de `/tmp/klassy-prefix` en `supportInformation`, KWin estable.

## 1. Canal de aplicado real (nuevo)

- Claves sueltas NO bastan: el primer arranque importa el preset bundled.
- Lo que funciona: `klassy-settings -i nimbus-tahoe.klpw` +
  `klassy-settings -w Klassy` (escribe `klassy/klassyrc` por grupos +
  `kwinrc`), y arrancar el nested con ese HOME como seed.
- Las claves sobreviven al arranque (post-run intactas salvo
  `[Global] LookAndFeelSet` añadido por Klassy y el pre-seed del harness).

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
| gap filo | 8 | 8 (x 30→39 y 39→59 filo, spacing 6) | OK |
| close | #FF5F57 lleno | (255,95,87) centro | OK |
| minimize | #FEBC2E lleno | (254,188,46) centro | OK |
| maximize | #28C840 lleno | (40,200,64) centro | OK |
| inactivo | #8E8E93 | (142,142,147) ×3, sin glifo | OK |
| glifos normal | ninguno (macOS) | `ShowCloseIconNormally*=false`; resto ya sin glifo | OK |
| offset | 8–9 | 9 (borde ventana→filo close) | OK |
| titlebar | 26–28 | 26–27 (filas claras + separador 1 px) | OK |

## 4. Límite duro: hover (sin parche, reportado exacto)

- Maximizar pinta □ (`RenderStyleMaterialDynamic18By18::renderMaximizeIcon`,
  `libbreezecommon/stylematerialdynamic.cpp:18`); ningún `style*` dibuja
  `+` (grep `Plus` vacío). Hover `+` imposible por config.
- Hover físico no inyectable en nested (sin puntero; KWin scripting solo
  geometría/foco). Glifos hover ×/−/□ configurados
  (`Show*OnHover*=true`, `WhiteWhenHoverPress`) pero NO verificados.
- Propuesta: plugin propio R-DECO (ya decidido en rama); sin parche
  inventado aquí.

## 5. Archivos

- `packages/themes/klassy-preset/nimbus-tahoe.klpw` (preset; deltas en cabecera)
- `packages/kwin/decoration/nimbus-decoration/README.md` (aplicar/construir/pin)
- Sin `klassy-12px.patch`: no hay cambio C++ que justifique diff.

## 6. Trampas del harness (para el dueño de la rama)

- `tests/vm/nested-plasma.sh:87-90` pre-seed `ButtonShape` +
  `ButtonSpacingLeft=8` en el HOME dado (pisó seeds 2 y 3: gap 10
  idéntico con spacing 6 y 4; causó el "spacing ignorado" aparente).
- Sonda runtime `spacing 8→20` + `/KWin reconfigure` antes de las capturas.
- `klassy-settings -w` genera iconos en `XDG_DATA_HOME`: redirigirlo o
  ensucia `~/.local/share/icons` (limpiado tras el test).
