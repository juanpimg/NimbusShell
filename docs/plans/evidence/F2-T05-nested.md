# F2-T05 nested — panel superior base 24pt

Fecha: 2026-10-31. Harness `tests/vm/nested-plasma.sh --home
/tmp/opencode/f2t05home` (HOME temporal con los 7 configs del perfil +
appletsrc mínimo + Colorizer copiado a `.local/share/plasma/plasmoids/`).
4 runs anidados (iteración + control). Todos: 4/4 VIVO, cleanup limpio.

## Resultado: panel ARRIBA cargado; altura 24pt NO aplicada (gap medido)

- Appletsrc mínimo: `[Containments][1] plugin=org.kde.panel,
  location=3, formfactor=2` + `digitalclock`. plasmashell lo acepta sin
  errores (solo normaliza: añade `[ActionPlugins]`, contención folder
  `[3]`, popup size del reloj). Sin panel inferior default.
- Captura: `spikes/nested/f2-panel-base.png` — barra superior full-width
  con reloj (20:29), Kate debajo sin solape.
- Fichero shippeado: `dotfiles/.config/plasma/plasma-org.kde.plasma.desktop-appletsrc`
  (bytes normalizados que cargaron, con cabecera de procedencia).

## Gap exacto: thickness=24 sin efecto en shell stock

Medición por píxeles (PIL, centro x=200–1100, escala 1x): borde inferior
del panel en y≈37–38 → **~38 px** en 3 runs. Experimentos:
1. `thickness=24` en `[Containments][1]` + `[PlasmaViews][Panel]` → 38 px.
2. Control sin ningún `thickness` → **38 px idénticos**.
Conclusión: el panel stock ignora ambas claves; `thickness=24` queda como
declaración de contrato A1 para el shell/plasmoid propio (F3). 24 pt
exactos requieren otro mecanismo (altura por applet/contención o panel
custom). `floating=true` sí heredado (`[Panel 1] floating=1`).

## Fix 2026-10-31: el 38 px NO es configurable por fichero (5 runs)

Búsqueda del 38: `grep -rn "thickness|38"` en appletsrc/plasmarc/
plasmashellrc del HOME temporal → el 38 NO está guardado en ningún
fichero; es el default interno de `PanelView` (el QML usa
`panel.thickness` para alto: `Panel.qml:162-163`, slider en
`PanelConfiguration.qml:652-654` con mínimo `max(20, minThickness)`).

Claves probadas ( HOME temporal fresco, medir PIL borde superior,
run canónico `nested-plasma.sh --home <tmp>` ), TODAS → 38 px:
1. `thickness=24` en `[Containments][1]` → ignorado (persiste, sin efecto).
2. `panelHeight=24` en `[General]` + `[PlasmaViews][Panel] thickness=24`
   → heredados (`kreadconfig6` OK) pero sin efecto visual.
3. Pre-seed `[PlasmaViews][Panel 1] thickness=24` → **borrado** por
   plasmashell al arrancar.
4. Pre-seed `[PlasmaViews][Panel 1][Defaults] thickness=24` (canal que
   SÍ persiste en sesiones reales del host: 60/28/44) → **borrado**,
   con o sin `thickness` de contención, en 1er arranque Y en 2º
   (Updates ya hechas) → 38 px.
5. Panel vacío (sin reloj) → el shell AUTO-AÑADE `digitalclock` y fija 38.
6. Scripting `evaluateScript`: `panelIds` no existe en el contexto
   (`TypeError: Property 'panelIds' of object [null] is not a function`);
   sin API runtime accesible por D-Bus.

Conclusión: en Plasma 6.8.2 stock NO hay clave de fichero que dé 24; el
shell purga `thickness` foráneo y sujeta la altura a `minThickness`
(~38 con reloj auto-añadido). La propuesta es que **F3-T03 (panel
custom) fuerce 24 rendering propio**; el `thickness=24` shippeado queda
como declaración A1. Sin `f2-panel-24.png` (no existe estado 24 que
capturar); vale `f2-panel-base.png` (38 px medidos).

## Limitaciones

- Colorizer: ficheros presentes en el HOME temporal pero SIN activar
  (añadirlo al panel exige claves de applet no triviales; preset pendiente).
- Wallpaper: default del sistema; fondo NPS es F2-T04.
- krunner se automuestra al arrancar en nested (popup "Buscar..." vacío);
  no interfiere con el panel; documentado en F0-T04.
- Sin checkbox marcado.
