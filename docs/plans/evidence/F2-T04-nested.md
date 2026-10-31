# F2-T04 nested — tema base Nimbus aplicable

Fecha: 2026-10-31. Rama `plasma/f2-theme`. Sin root, sin tocar `~/.config`
del host; todo en HOME/XDG temporales.

## Qué se entrega

- `packages/themes/nimbus-tahoe/`: `kdeglobals` (ColorScheme NimbusTahoe,
  Inter/JetBrains Mono, iconos WhiteSur, cursor WhiteSur-cursors, doble
  clic), `colorschemes/NimbusTahoe[Light].colors` (contrato §2.1),
  `kvantum/nimbus.kvconfig` (base WhiteSur, translucidez on),
  `wallpapers/` (symlink a `assets/sequoia-light.jpg` NPS + metadata),
  `README.md` (atribución WhiteSur/Kvantum GPL, R-APPLE).
- `scripts/apply-theme [--variant light|dark] [--check] [--revert]`:
  `set -u`, idempotente, backup `nimbusshell-backup-*`, usa
  `kwriteconfig6`/`plasma-apply-wallpaperimage` con fallback a copia.

## Test nested (2 runs, bus+HOME temporales, kwin virtual 1280x800)

Base: seed con dotfiles plasma sin tema → `spikes/nested/f2-theme-base.png`.
Tema: `HOME=<seed> scripts/apply-theme` (APPLY_OK dark) y misma sesión →
`spikes/nested/f2-theme.png`. Los 4 procesos VIVO en ambos.

`kreadconfig6` en sesión con tema: `ColorScheme=NimbusTahoe`,
`SingleClick=false`, `Icons=WhiteSur`, `Font=Inter,…`, Kvantum `theme=nimbus`;
`color-schemes/NimbusTahoe{,Light}.colors` + wallpaper presentes en
`.local/share`. `--check` → CHECK_OK; 2ª aplicación → idempotente;
`--revert` → restaura backup y limpia artefactos propios (verificado byte).

## Diff base vs tema: 0.002% (idénticas a ojo)

Gap exacto, no es bug del tema: en nested (igual que en host sin paquetes)
WhiteSur/Inter no están instalados → Plasma usa fallback Breeze; el
wallpaper solo quedó copiado (`plasma-apply-wallpaperimage` pre-sesión sin
bus no-op) y Kate renderiza Breeze oscuro en ambas. El tema queda aplicado a
nivel config + ficheros; el render 1:1 exige WhiteSur+fuentes instalados
(dependencias ISO, F2-T06) y se verificará en VM.

## Limitaciones

- Klassy/deco ventanas = F3 (R-DECO, decoración propia).
- Panel 24pt (R-TOPBAR/A1): el panel stock fija ~38px (F2-T05); el tema no lo
  cambia, pendiente panel custom F3-T03.
- `bash -n` + `shellcheck -S warning` cero warnings. Sin checkbox.
