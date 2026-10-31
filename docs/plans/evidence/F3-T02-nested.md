# F3-T02 nested — Klassy cargado en KWin anidado

Fecha: 2026-10-31. Plugin (solo lectura):
`/tmp/klassy-prefix/lib/plugins/org.kde.kdecoration3/org.kde.klassy.so`
(+ `libklassycommon6.so.6.7.3`). Harness: flag nuevo `--klassy`
(`QT_PLUGIN_PATH`+`LD_LIBRARY_PATH`+`XDG_DATA_DIRS` al prefix,
`kwinrc [org.kde.kdecoration2] library=org.kde.klassy`, XIA, kate+konsole).
Comando: `nested-plasma.sh --out spikes/nested --timeout 60 --klassy
--home /tmp/opencode/f3homeN`. 3 runs, 4/4 VIVO, cleanup limpio.

## Plugin CARGADO

`supportInformation` (bus anidado): `Plugin: org.kde.klassy`. KWin no
crashea. Titlebar renderizada por Klassy: 30 px (y70–99 @1x, kate izquierda).

## Geometría por scripting: SÍ funciona

`--qwindowgeometry` lo ignora el shell; en su lugar `kwin-layout.js`
(`frameGeometry`, vía `/Scripting loadScript+start`): kate 10..626,
konsole 650..1270 medidos por bordes (pedidos 620+10 / 620+650). Flip de
foco con `kwin-focus-toggle.js` (`workspace.activeWindow`). Los .js quedan
generados en `spikes/nested/` (no commiteados). Sin ydotool: este es el
canal de foco/hover del harness.

## Medidas vs contrato (PIL, `f3-klassy-active.png`)

| Ítem | Contrato | Medido | Estado |
|---|---|---|---|
| titlebar | — | 30 px | ref |
| orden | XIA izq | XIA izq | OK |
| offset borde→btn1 | 8–9 px | ~8 px (borde x6–10, glifo desde x14) | OK~ |
| gap | 8 px | no uniforme (shape default ancho) | NO |
| semáforo Ø | 12 px | glifo ~10 px, sin círculos | NO |
| colores | R/A/V | monocromo | NO (→F4-T01) |

Capturas: `f3-klassy-active.png` (kate activa), `f3-klassy-inactive.png`
(konsole activa). Activo/inactivo casi indistinguibles: default Klassy
`LockButtonColorsActiveInactive=true`.
