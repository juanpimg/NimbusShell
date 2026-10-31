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

## Limitaciones

- Colorizer: ficheros presentes en el HOME temporal pero SIN activar
  (añadirlo al panel exige claves de applet no triviales; preset pendiente).
- Wallpaper: default del sistema; fondo NPS es F2-T04.
- krunner se automuestra al arrancar en nested (popup "Buscar..." vacío);
  no interfiere con el panel; documentado en F0-T04.
- Sin checkbox marcado.
