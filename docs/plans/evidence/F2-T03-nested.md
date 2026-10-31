# F2-T03 nested — herencia de configs Plasma (harness anidado)

Fecha: 2026-10-31. Fuente: rama `plasma/f2-configs`, worktree
`NimbusShell-f2cfg/dotfiles/.config/plasma/` (7 ficheros + README, SOLO
lectura; esa worktree no se modifica). Despliegue a HOME temporal con
`--home` + `--plasma-src`; `plasmashell`/`krunner`/`kate` arrancan con
`HOME=$temporal` en bus anidado. Comando: ver F0-T04-nested.md.

## Resultado: herencia SÍ (5/6), 1 gap real

`kreadconfig6` dentro del bus anidado (mismos valores que la fuente):

| Clave | Fuente | Nested | OK |
|---|---|---|---|
| `kdeglobals [KDE] SingleClick` | false | false | SÍ |
| `kwinrc [org.kde.kdecoration2] ButtonsOnLeft` | XIA | XIA (Kate con XIA izq. en captura) | SÍ |
| `ButtonsOnRight` | (vacío) | (vacío) | SÍ |
| `plasmashellrc [General] panelHeight` | 24 | 24 | SÍ |
| `plasmashellrc [PlasmaViews][Panel] thickness/floating` | 24 / true | 24 / true | SÍ* |
| `krunnerrc [General] FreeFloating` | true | true | SÍ |
| cero Ctrl en `kglobalshortcutsrc` | 0 | **16** | NO — gap |

Evidencia: `spikes/nested/f2-panel.png` (escritorio + Kate + panel inferior),
`nested-plasma.log` (bloque F2-T03).

## Gap exacto 1 (real): KGlobalAccel fusiona defaults con Ctrl

El dotfile solo define grupos `[krunner]` y `[kwin]` (todo Meta, 0 Ctrl),
pero al arrancar la sesión kglobalaccel AÑADE grupos del sistema
(`[ksmserver] Log Out=Ctrl+Alt+Del`, `[kwin] Switch to Desktop N=Ctrl+F1…`,
`[mediacontrol]`, `[plasmashell] show dashboard=Ctrl+F12`…) → 16 líneas con
Ctrl en el HOME temporal. Para "cero Ctrl" runtime, F2-T03 debe shippear
overrides explícitos (`=none`) de CADA default, no basta con no declararlos.

## Falso gap (harness, fixado)

`floating`/`thickness` salían vacíos: sintaxis `kreadconfig6 --group
"PlasmaViews][Panel"` no resuelve subgrupos; la correcta es
`--group PlasmaViews --group Panel`. El fichero SÍ se heredó intacto
(diff: solo añade `[PlasmaViews][Panel 2]` thickness=46 del panel default
que crea plasmashell + bloque `[Updates]`).

## Notas

- Panel visible = default Breeze (el appletsrc custom es F2-T05, fuera de
  alcance); `panelHeight/thickness=24` se verifican a nivel config.
- Sin checkbox marcado (F2-T03 sigue pendiente de port a este worktree).
