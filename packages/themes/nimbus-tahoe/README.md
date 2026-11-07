# nimbus-tahoe — tema base Nimbus (F2-T04)

Tema claro/oscuro según contrato §2.1 (`docs/design/tahoe-design-contract.md`,
fuente única R-TAHOE-TOKENS). Default: **dark**. Aplica con
`scripts/apply-theme [--variant light|dark] [--check] [--revert]`.

## Contenido

- `kdeglobals`: ColorScheme NimbusTahoe, fuentes Inter 10 / JetBrains Mono
  (código), iconos WhiteSur, cursor WhiteSur-cursors 24, doble clic.
- `colorschemes/NimbusTahoe.colors` (dark) + `NimbusTahoeLight.colors`
  (light): valores del contrato §2.1 (label/accent/bg/success/destructive…).
- `kvantum/nimbus.kvconfig`: basado en WhiteSur/Kvantum, translucidez Qt on.
- `aurorae/MacTahoeLiquidKde-Dark` y `-Light`: decoración de ventana con
  semáforos 12 px, radios Tahoe y variantes claro/oscuro.
- `wallpapers/`: `sequoia-light.jpg` → symlink a `assets/sequoia-light.jpg`
  (arte propio NPS, 1920x1080) + `metadata.json`.

`install.sh` ejecuta `scripts/apply-theme --variant dark` en una instalación
nueva y respeta la variante del usuario si ya existe
`~/.config/nimbus-theme-applied`.

## Atribución y licencias (R-APPLE: sin activos Apple)

- WhiteSur-kde (vinceliuice, GPL-3.0): iconos/cursor, base Kvantum.
  https://github.com/vinceliuice/WhiteSur-kde
- Kvantum (GPL-3.0): motor de temas Qt. https://github.com/tsujan/Kvantum
- Fuentes Inter (OFL) / JetBrains Mono (OFL): NO se empaquetan; el tema las
  referencia y el instalador las declara como dependencia.
- Wallpaper y tokens: arte propio NimbusShell, CC0. Nada de logos, SF,
  wallpapers o sonidos de Apple.

## Limitaciones conocidas

- Decoración de ventana = Aurorae `MacTahoeLiquidKde-*` (la aplica
  `scripts/apply-theme`); el preset Klassy queda como fallback histórico.
- Panel 24pt exactos = F3-T03 barra custom (el panel stock Plasma fija ~38px;
  ver evidencia F2-T05). El tema no cambia la altura del panel.
- Iconos/cursor WhiteSur deben estar instalados; si faltan, el script avisa
  y Plasma usa el fallback Breeze (no falla).
