# F3-T11 — Fondo, claro/oscuro y acento (evidencia nested)

Fecha: 2026-10-31. Plasma 6.8.2 (host CachyOS). Todo con HOME/XDG temporales;
el `$HOME` real no se toca (ver §5).

## 1. Canales reales Plasma 6.8 (medidos, no supuestos)

- `plasma-apply-colorscheme [-a <hex>] <scheme>`: fija esquema y reescribe los
  roles de acento en kdeglobals. **No existe clave `[General] AccentColor`**:
  con `-a '#FF9500'` el tool reescribe `DecorationFocus/Hover` y
  `ForegroundActive/Link` en todos los grupos `[Colors:*]` (verificado por
  diff en HOME temporal).
- `plasma-apply-desktoptheme <tema>`: solo en vivo (sin sesión Plasma no
  escribe ficheros; verificado con HOME temporal). Base temporal
  `breeze-light`/`breeze-dark` hasta que exista `org.nimbus.desktop`.
- `plasma-apply-wallpaperimage <img>`: solo en vivo; **actúa sobre la sesión
  del bus aunque el HOME sea ajeno** (cambió el fondo del host durante las
  pruebas; restaurado a `MacTahoe-Dark`, ver §5). Por eso `nimbus-theme` solo
  llama a los tres canales en vivo si el plasmashell en ejecución pertenece
  al mismo `$HOME` (comparado vía `/proc/<pid>/environ`); si no, modo
  fichero + `AVISO ... (LIVE=0)`.
- Cambio automático claro/oscuro: **Plasma 6.8 no lo trae**. `kcm_nighttime`
  ("Ciclo día-noche") es solo el horario de Night Light (filtro azul), no
  cambia el tema. Se usa timer systemd de usuario propio
  (`nimbus-theme-auto.timer`, cada 15 min; light 7:00–19:00, configurable en
  `dotfiles/.config/plasma/nimbus-theme.conf`).

## 2. Ficheros

- `scripts/nimbus-theme` (`set -u`, no root, idempotente, backup
  `~/.config/nimbusshell-backup-*`, `--check`/`--revert`): aplica scheme
  Nimbus (paleta completa incrustada en kdeglobals + ficheros `.colors`),
  acento (defecto `#007AFF` light / `#0A84FF` dark, contrato §2), wallpaper
  por variante y `plasmarc [Theme]`.
- `assets/sequoia-dark.jpg` (arte propio NPS nocturno 1920x1080, CC0) +
  copia en `packages/themes/nimbus-tahoe/wallpapers/`; `metadata.json`
  extendido con `variants {light, dark}` (claves antiguas intactas).
- `packages/themes/nimbus-tahoe/colorschemes/*.colors`: convertidos
  `#RRGGBB` → `r,g,b` (formato que lee KColorScheme; el hex no aplicaba).
  Reparado además el symlink colgante `wallpapers/sequoia-light.jpg`
  (apuntaba a `packages/assets`, inexistente) sustituyéndolo por el fichero.
- `dotfiles/.config/systemd/user/nimbus-theme-auto.{service,timer}`,
  `dotfiles/.config/plasma/nimbus-theme.conf`.
- `tests/vm/nested-plasma.sh`: parche aditivo (5 líneas) que siembra
  `$HOME/.local/share` del home temporal en el `XDG_DATA_HOME` temporal;
  sin `.local` previo no cambia nada.

## 3. Test nested (harness `tests/vm/nested-plasma.sh`, HOME temporal)

Staging: `HOME=<tmp> scripts/nimbus-theme light|dark` → `--check` OK en
ambos; `DecorationFocus` verificado por `kreadconfig6`
(`0,122,255` = `#007AFF`; con `--accent '#FF9F0A'` → `255,159,10`).

| caso | captura | resultado |
|---|---|---|
| light | `spikes/nested/f3-theme-light.png` | panel claro, deco clara, KRunner claro (fondo blanco, selección azul) |
| dark | `spikes/nested/f3-theme-dark.png` | panel oscuro, deco oscura, KRunner oscuro |
| light + krunner | `spikes/nested/f3-theme-light-krunner.png` | popup "Terminal" claro, latencia en log |
| dark + krunner | `spikes/nested/f3-theme-dark-krunner.png` | popup "Terminal" oscuro |

Kate sale oscura en ambas capturas con perfil fresco (katerc sin theme):
es el default propio de Kate, no el esquema del sistema (KRunner/panel/deco
sí siguen la variante). Gap exacto de wallpaper en nested: el containment de
escritorio se autocrea con el fondo por defecto e ignora la inyección
`[Containments][3][Wallpaper]` en el appletsrc desplegado; el canal en vivo
(`plasma-apply-wallpaperimage`) quedó probado funcional en host (incidente
§5) y el fichero se verifica por `--check` (JPEG 1920x1080 reales).

`bash -n` + `shellcheck -S warning` cero warnings en `scripts/nimbus-theme`
y `tests/vm/nested-plasma.sh`.

## 4. Cambio en vivo

Sí para los tres canales dentro de la sesión propia (LIVE=1); en nested
pre-despliegue es modo fichero (la sesión nested lo lee al arrancar:
`plasma-apply-colorscheme -l` en sondeo reportó `NimbusTahoeLight` actual).
Auto: `--auto enable` despliega unidades + symlink `~/.local/bin` e
intenta `enable --now` (probado bajo `dbus-run-session`: copia + aviso sin
bus con manager; en sesión real hace enable).

## 5. Límites e incidentes

- Incidente: `plasma-apply-wallpaperimage` con HOME ajeno cambió el fondo
  vivo del host (containments 138/139). Restaurado a `MacTahoe-Dark`
  (gemelo del lock screen) y añadida la guarda `session_is_mine`. Estado
  final del host verificado: scheme `WhiteSurDark`, theme `Sweet`, fondo
  `MacTahoe-Dark`, sin `~/.config/nimbus-theme-applied`, sin unidades
  `nimbus-theme-auto.*`, sin `~/.local/bin/nimbus-theme`.
- `org.nimbus.desktop` no existe como paquete: L&F temporal
  `org.kde.breeze(.dark).desktop` + `plasmarc [Theme] breeze-light/dark`.
- `f2-panel.png` residual aparece en los OUT del harness (lo genera el
  propio harness, no este cambio).
