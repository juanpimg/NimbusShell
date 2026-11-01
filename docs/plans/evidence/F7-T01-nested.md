# F7-T01 nested (R2) — Spaces: 4 por defecto, crear, cambiar, mover

Fecha: 2026-10-31. Rama `plasma/f7-mc`. Nested (`kwin_wayland --virtual
--no-lockscreen`, bus privado, HOME/XDG temporales). Harness
`tests/vm/nested-f7mc.sh` (10 ventanas: 3 kate + 3 konsole + 2 dolphin +
kwrite + kcalc). Captura `spikes/nested/f7-mc-spaces.png`.

## R-SPACES

MC garantiza 4 Spaces al arrancar (`ensureSpaces(4)` una sola vez por
proceso): crea los que falten con `VirtualDesktopManager.createDesktop
(pos, "Escritorio N")`; **no renombra ni borra** los existentes. `+`
(`createSpace()`) crea `Escritorio N` real + re-push. Nombres de KWin
llegan vía `pushState` del helper scripting (el struct `a(iss)` por QDBus
aborta el proceso — hallazgo T01-R1, sin cambios). Divergencia 1:1:
en Plasma 6 los escritorios son globales, no por monitor.

## Medidas

- Sesión parte de 1 Space → `desktopCount=4` tras arrancar MC ✓
  (`Escritorio 1..4`, el 1 con 10 ventanas).
- `setCurrentDesktopByIndex` (clic en Space) sin errores.
- Meta+Ctrl+← stock: `invokeShortcut "Switch One Desktop to the Left"`
  rc=0, `currentDesktop=1` (MC no bindea Ctrl; convive con KWin) ✓.
- `open_ms=100` (<300 A7) ✓; **0 errores QML**.

## Gaps

- Sin `removeSpace` (borrar Space) — no exigido; solo `removeDesktop`
  documentado en API.
