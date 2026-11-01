# F4-T02 nested — titlebar / sombra / borde Klassy

Fecha: 2026-10-31. Rama `plasma/f4-windows`. KWin 6.8.2 anidado
1280x800 (`--virtual --width/--height`), bus privado, HOME/XDG temporales,
deco `/tmp/klassy-prefix` (solo lectura). Seed: HOME temporal +
`klassy-settings -i nimbus-tahoe.klpw && klassy-settings -w NimbusTahoe`
+ `kwinrc [org.kde.kdecoration2] library=org.kde.klassy, XIA`.
Kate+konsole (foco por `/Scripting loadScript+run`), dolphin maximizado
de fondo oscuro para medir sombra; maximizada por `kwinrulesrc`
(force, `titlematch=2`). Sin root, sin `--replace`.

## Claves kcfg reales (`/tmp/klassy-src`, solo lectura)

Altura titlebar: **SIN clave directa**. Fuente
`breezedecoration.cpp:853`: `borderTop = snap(max(fm.height(), btn)) +
sep + topMargin + bottomMargin` (`btn` de `IconSize`; `sep` 1px si
`DrawTitleBarSeparator`). Separador: `titleBarSeparatorColor()` solo
ventana ACTIVA, color `buttonFocus` fijo (**sin clave de color**).

| Clave | Default | Preset final |
|---|---|---|
| `TitleBarTopMargin`/`TitleBarBottomMargin` (Double) | 3.6/3.6 | **4/4** |
| `DrawTitleBarSeparator` (Bool) | true | **false** |
| `ShadowSizeActive/Inactive` (enum None/S/M/L/XL) | Large | **Medium**/Large |
| `ShadowStrengthActive/Inactive` (Int 25-255) | 255/128 | **100**/128 |
| `ShadowColorActive/Inactive` | 0,0,0 | 0,0,0 |
| `WindowOutlineThickness` (Double 0.5-10) | 1.0 | 1 |
| `WindowOutlineStyle*` | Contrast | Contrast |
| `TitleBarOpacityActive/Inactive` | 100/100 | 100/100 (sin dim) |
| `ShowIconNormally*` (default **true**) | — | false (solo hover) |
| Color texto título | **SIN clave** (viene del color-scheme) | — |
| Dim contenido inactivo | **SIN clave** (no existe en la deco) | — |

Px reales sombra (`breezedecoration.cpp:91-99`): Small r16/off4,
Medium r32/off8, Large r48/off12, VLarge r64/off16 (+2.ª sombra c/u).

## Medidas PIL (`spikes/nested/f4-titlebar-*.png`, fuente seed = Inter prod.)

| Ítem | Contrato | Medido | Estado |
|---|---|---|---|
| titlebar flotante (toolbar) | 26 | **26** (filas 100–125, sin separador) | OK |
| titlebar maximizada | — | 26 (filas 0–25) | ref |
| sombra activa abajo/arriba/izq/der | 20–22 | **20–21** / ~8 / ~15 / ~15 | OK (asimetría por offset 0,8) |
| sombra Large/255 (baseline) | — | ~44 abajo | ref (motivó Medium/100) |
| borde flotante | 0.5–1px | **1px** (1 px transición, `(1,2,2)` sobre negro) | OK |
| borde maximizada | — | ausente (`DrawBorderOnMaximizedWindows=false`) | OK |
| semáforos | Ø12 | R x69–80 = 12px | OK |

Regla altura (fuente Inter estable): banda = 16 + snap(top)+snap(bottom);
márgenes 4/4 → 26. Ojo: la fuente del seed manda (sin `kdeglobals` la
banda varió 26↔22 entre runs con el mismo preset; con Inter es estable
24/26/28 para 3.6/4/5 — documentado, no es bug del preset).

## Gap 16 vs 26

Klassy no distingue apps con/sin toolbar: **una sola altura global**.
16 inalcanzable (mínimo = max(fm,btn)+márgenes ≥ 16+0, y rompería el
caso toolbar). Se fija 26 (toolbar: kate/konsole/dolphin). Sin toolbar:
gap abierto para VM (medir app real sin toolbar).

## Notas harness (vinculantes para próximos runs)

- Host bloqueado ⇒ KWin anidado se bloquea al segundo (ve el logind del
  host por el bus de sistema). Fix: `DBUS_SYSTEM_BUS_ADDRESS=unix:path=/dev/null`
  en el env anidado (con `--virtual` no rompe nada). `SetActive false`
  es rechazado; `XDG_SESSION_ID` unset NO basta.
- `w.setMaximize()` por scripting dejó de aplicarse (funcionó en el run
  baseline; `MAXKATE` journal muestra geometría intacta; `w.maximized`
  = `undefined` en 6.8). Maximizada conseguida por `kwinrulesrc` force.
  `invokeShortcut "Window Maximize"` tampoco movió (kate acabó en
  648x512@0,0 sin explicación; pendiente).
- `nimbus-bar`/plasmashell no usados aquí (fondo = dolphin maximizado).
- Captura activa: konsole aún mapeando (solo kate+dolphin); la inactiva
  trae las tres ventanas. `TitleAlignment` sigue `AlignCenterFullWidth`
  (fuera de alcance; macOS también centra).
