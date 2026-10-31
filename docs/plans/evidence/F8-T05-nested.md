# F8-T05 — Evidencia nested (Accesibilidad real)

## Controles (leen al abrir, escriben con «Aplicar»)
- Lupa → `kwinrc [Plugins] zoomEnabled` (efecto builtin `zoom.json`,
  categoría Accessibility; se activa con Meta+`+`/`−`).
- Invertir colores → `kwinrc [Plugins] invertEnabled` (builtin `invert.json`).
- Reducir movimiento → `kwinrc [Compositing] AnimationSpeed=0`;
  el slider de Apariencia y el toggle son coherentes (0 ⟺ reducido;
  al quitarlo vuelve a 3).
- Quitar transparencias → `kwinrc [Plugins] blurEnabled=false`
  (contrato §2.4: Reduce Transparency → blur off + sólido).
- Repetición → `kcminputrc [Keyboard] KeyboardRepeating` + `RepeatDelay`
  100–1000ms (500) + `RepeatRate` 5–50/s (25).
- Orca → `gsettings org.gnome.desktop.a11y.applications
  screen-reader-enabled` + espejo `kaccessrc [ScreenReader] Enabled` +
  `systemctl --user start/stop orca.service` best-effort; si Orca no está
  instalado se avisa en la página (el valor se guarda igual).
- Todo KWin aplica en vivo vía `reconfigure`; el resto al reiniciar sesión.

## Tests (dentro de `test-pages.sh`, 24/24 PASS)
Escenario `a11y`: `zoomEnabled=true`, `invertEnabled=true`,
`blurEnabled=false`, `AnimationSpeed=0`, `RepeatDelay=300`,
`RepeatRate=30`, `kaccessrc Enabled=true`.
Limitación medida: `dconf` no persiste en sandbox sin systemd
(`set` rc=0 pero `get` devuelve el defecto); el canal fichero
`kaccessrc` sí es verificable y es el que se aserta.

## Captura
`spikes/nested/f8-kcm-a11y.png`: KCM abierto en Accesibilidad
(toggles + sliders 500ms, repetición activa); `QML_ERRORS=0`.
