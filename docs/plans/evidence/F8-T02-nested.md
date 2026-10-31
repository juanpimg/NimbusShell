# F8-T02 — Evidencia nested (Apariencia real)

## Controles (todos leen al abrir y escriben con «Aplicar»)
- Tema Claro/Oscuro → `kdeglobals [General] ColorScheme` +
  `[KDE] LookAndFeelPackage`; en `save()` corre `scripts/nimbus-theme
  <modo> --accent X [--wallpaper …]` si está en PATH, si no
  `plasma-apply-colorscheme -a <hex> <esquema>` (fallback medido).
- Acento → `ColorDialog`; fondo → `FileDialog` + botón Automático
  (path en `nimbusrc [Appearance] Wallpaper`, `""` = auto según tema);
  aplica con `plasma-apply-wallpaperimage` (best-effort: sin plasmashell
  falla controlado y deja el fichero copiado, como el script).
- Dock Krema → `kremarc [General]`: `IconSize` 24–96 (48),
  `MaxZoomFactor` 1.0–2.0 (1.6), `VisibilityMode` 0/1 (autohide).
- Barra → `plasmashellrc [PlasmaViews][Panel *][Defaults] thickness`
  16–64 (24, iguala todos los paneles; aplica al reiniciar Plasma).
- Animaciones → `kwinrc [Compositing] AnimationSpeed` 0–3 (3) + `qdbus6
  …/KWin reconfigure` best-effort.
- Vista previa mock (barra + Dock con el acento) sin hex cableado;
  `Predeterminados` = canónico Nimbus (oscuro, `#0A84FF`, auto, 48/1.6,
  visible, 24, 3). `helperStatus` informa fallos blandos.

## Tests (`tests/kcm/test-pages.sh`, HOME por escenario, 24/24 PASS)
Escenario `appearance` (probe `save_probe` + `kreadconfig6`):
`ColorScheme=BreezeLight`, `LookAndFeelPackage=org.kde.breeze.desktop`,
`nimbusrc Wallpaper=/tmp/nimbus-wall.jpg`, `IconSize=64`,
`MaxZoomFactor=1.2`, `VisibilityMode=1`, dump `animationSpeed=2`,
`darkMode=false`, `accent=#FF9500`.

## Captura
`spikes/nested/f8-kcm-appearance.png`: KCM abierto en Apariencia
(radios, acento `#0A84FF`, fondo Automático, sliders Dock 48px/1.6×);
`QML_ERRORS=0` en `f8-kcm-appearance.log`.
