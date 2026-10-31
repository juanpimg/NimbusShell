# Research F3 — Fundación visual y barra superior (brief F3-T01..T13)

Fuentes: plan `docs/superpowers/plans/2026-10-31-plasma-migration.md` (F3, l.117-135),
spec `docs/superpowers/specs/2026-10-31-plasma-migration-design.md` (§2, §4),
tokens actuales en `dotfiles/.config/quickshell/MacShell/` y `hypr/`.
Rulings aplicables: R-GTK, R-DOCK, R-KLASSY, R-APPLE, R-CACHYOS. Nada de este doc
sustituye la verificación en VM (F3-T12): claves exactas `klassyrc`/appletsrc se
confirman con `kwriteconfig6` + captura en F2/F3-T02.

## 1. Klassy — opciones y preset Tahoe 12px (F3-T02, F4-T01)

- Upstream: `github.com/paulmcauley/klassy` (fork activo `ekaaty/klassy`); exige
  Plasma ≥ 6.3 en master. Arch: `klassy` (+ `klassy-qt5` solo si hay apps Qt5).
- Secciones del KCM (`System Settings → Appearance → Window Decorations → Klassy`
  o binario `klassy-settings`): tamaño de botón configurable, forma
  (rectángulos redondeados integrados por defecto, semáforos “traffic lights”,
  rectángulo full-height, círculo), iconos (Oxygen/Breeze/Redmond + tema
  generado que hereda Breeze y solo sobreescribe botones), pestaña
  Alignment & Spacing (márgenes, espaciado izq/der, radio de esquina, HiDPI),
  opacidad activa/inactiva + “maximizadas opacas”, outline fino con acento,
  sección Shadows (“Draw thin contrasting window outline”), animaciones.
- Preset Tahoe: botones 12px a la izquierda (orden cerrar/min/max),
  fondo semáforo + hover con glifo ×/−/+, inactiva en gris, radio Tahoe,
  sombra única, borde 1px. Se versiona en `packages/themes/klassy-preset/`
  (export de `klassy-settings`; importar con `klassy-settings --help` /
  opción de importar preset) y se aplica vía `kwinrc [org.kde.kdecoration2]
  library=org.kde.klassy` + `~/.config/klassyrc`.
- Limitaciones: los glifos ×/−/+ exactos NO vienen de serie → iconos
  `window-*-symbolic` propios (SVG original, R-APPLE) + “Force-colourize icons”;
  el gris inactivo se logra con opacidad/color de inactiva, no es un switch
  “estilo macOS”. Verificar 3 apps (Qt/GTK/CSD) en F3-T02.

## 2. Plasmoides QML — esqueleto (F3-T03..T05)

- Árbol por plasmoide `packages/plasma/plasmoids/org.nimbus.{bar,menu,controlcenter}/`:
  `metadata.json` + `contents/ui/main.qml` (+ `contents/config/main.xml` si expone opciones).
- `metadata.json` (Plasma 6): `{"KPlugin": {"Id": "org.nimbus.bar", "Name": "…",
  "Version": "0.1", "Category": "…"}, "X-Plasma-API-Minimum-Version": "6.0",
  "X-Plasma-MainScript": "ui/main.qml"}` — en Plasma 6 el entry es siempre
  `ui/main.qml` y sobra `X-Plasma-API` (ver `develop.kde.org/docs/plasma/widget/porting_kf6/`).
- `contents/ui/main.qml`: `import org.kde.plasma.plasmoid`, raíz `Plasmoid` con
  `compactRepresentation` / `fullRepresentation`; estado vía `plasmoid.*`;
  DataEngines legacy con `org.kde.plasma.private.plasma5support` (`DataSource`).
- Comandos: `kpackagetool6 -t Plasma/Applet -i <dir>`, `-u` upgrade, `-r` remove;
  probar con `plasmoidviewer6 -a org.nimbus.bar`. `org.nimbus.menu`: acciones
  Acerca de/Ajustes/Dormir/Bloquear/Sesión/Reiniciar/Apagar vía
  `executable` DataSource o `Qt.openUrlExternally` + `qdbus6 org.kde.{ksmserver,screensaver}`;
  `org.nimbus.controlcenter`: Wi-Fi/BT/volumen/brillo/oscuro/DND/batería vía
  DataSources `networkmanagement`, `bluetooth`, `audio`, `powerdevil`, `notifications`.

## 3. Panel superior 28px + Colorizer + Window Buttons (F3-T13, F2-T05)

- Ficheros: `dotfiles/.config/plasma/plasma-org.kde.plasma.desktop-appletsrc`
  (containment `plugin=org.kde.panel`, `location` top, `thickness=28`, panel
  flotante de Plasma 6) + `plasmashellrc`; aplicar y recargar con
  `qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshViews`
  o `plasmashell --replace &`.
- Panel Colorizer: `github.com/luisbocanegra/plasma-panel-colorizer`
  (AUR `plasma6-applets-panel-colorizer`); preset Tahoe (translúcido + blur)
  versionado en `packages/plasma/` (cambia preset por D-Bus, ver su README).
- Window Buttons: `psifidotos/applet-window-buttons` (port Plasma 6, PR #214) o
  alternativa QML-only `luisbocanegra/plasma-simple-window-buttons` /
  `Sadi58/plasma6-window-buttons-applet`; solo para maximizadas con Klassy
  (los semáforos reales los pinta KWin, no el panel).
- Pin: fijar commit/tag de ambos en F3-T13 (R-CACHYOS/R-KLASSY) y documentar
  en `packages/plasma/README.md`; accept: instala en VM limpia + captura.

## 4. Menú global, tray, reloj, notificaciones, OSD (F3-T06..T10)

- Menú global Qt: plasmoide `org.kde.plasma.appmenu` en la barra + paquete
  `appmenu-qt6` (y `appmenu-qt5` si aplica); Kate/Dolphin exportan vía dbusmenu.
  R-GTK: GTK/libadwaita/Electron NO tienen menú global en Wayland (no perseguir
  `appmenu-gtk-module`; el `GTK_MODULES=appmenu-gtk-module` actual de
  `dotfiles/.config/hypr/` NO se porta) → menú in-window, la barra nunca vacía.
- Tray/SNI: `org.kde.plasma.systemtray` (nativo Plasma, sin código propio).
- Reloj/calendario: `org.kde.plasma.digitalclock` + popup calendario
  (eventos vía KHolidays); portar layouts MacShell, descartar su IPC Hyprland.
- Notificaciones: tematizar `org.kde.plasma.notifications`
  (`~/.config/plasmanotifyrc`: agrupación, DND, acciones); test:
  `notify-send --action` + captura.
- OSD: OSD nativo Plasma (plasma-pa volumen, powerdevil brillo), tema en
  `packages/themes/` (desktoptheme `osd.qml`, posición/tamaño); test con teclas
  + captura. Todo KDE nativo tematizado (spec §2: se descarta MacLock).

## 5. Tokens Nimbus y consumo en plasmoides (F3-T01, F3-T11)

- Valores extraídos de MacShell/Hypr (no inventar otros): acento `#0A84FF`
  (`LiquidSwitch.qml:12`), gris inactivo `#598E8E93` (`WindowBar.qml:176`),
  semáforos 12px (`WindowBar.qml:174`), pill radio 15 (`WindowBar.qml:155`),
  radios 24/12 (plan F3-T01), Inter (barra `hyprland.lua:218`, GTK `Inter 11`,
  `fontconfig/fonts.conf`), tamaños 12/13.
- Implementación: `packages/themes/nimbus-tokens/{colors,radii,spacing,typography}.qml`
  como singleton `NimbusTokens` importado en cada `main.qml`; cero valores
  mágicos en plasmoides. Claro/oscuro + acento vía `scripts/apply-theme`
  (cambio en vivo, F3-T11) con wallpaper NPS propio.
- Tests: demo que consume tokens + test de contraste WCAG; evidencia visual con
  `tests/screenshot-diff/compare.sh <golden> <captura> --umbral 15`
  (golden propio, R-APPLE), interacción `qdbus6`/`kwshot`, matriz en
  `tests/vm/topbar.sh` → `docs/plans/evidence/F3-T12.md` (accept: diff <15%, 0 errores).
