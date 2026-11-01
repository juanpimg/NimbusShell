# Guía de usuario NimbusShell (perfil Plasma)

Nimbus es un escritorio Plasma con sabor a Mac: menú global arriba, Dock
abajo, Spotlight con `Cmd+Espacio` (`Meta` hace de `Cmd`), semáforos a la
izquierda y Mission Control con `Meta+W`. Todo lo que sigue describe lo
que **está implementado** en este repo; los límites están marcados como
`Límite`.

- Chuleta de atajos: [shortcuts.md](shortcuts.md) (autogenerada desde
  `dotfiles/.config/plasma/kglobalshortcutsrc`), también como
  [HTML imprimible](shortcuts.html) (`scripts/nimbus-i18n --export html`)
  y [PDF](shortcuts.pdf) (`--export pdf`; se genera si hay weasyprint o
  pandoc+motor PDF).
- Idiomas y traducción: [../i18n.md](../i18n.md) (español e inglés).

## Primeros pasos

1. Al primer arranque se abre el asistente **Nimbus**
   (`apps/nimbus-welcome`): 7 pasos (Bienvenida, Idioma, Wi-Fi, Tu cuenta,
   Apariencia, Diseño, Apps recomendadas) con progreso `N de 7 · paso`.
   Ver evidencia en [F9-T02](../plans/evidence/F9-T02-nested.md).
2. El paso **Idioma** cambia entre español e inglés en vivo y lo guarda
   para todo el sistema (`backend.setLanguage`).
3. El paso **Diseño** elige Mac (Meta como Cmd, semáforos a la izquierda,
   Dock abajo, el predeterminado), Windows o Nimbus (mezcla). Se aplica
   con `scripts/nimbus-layout` si existe.
4. Nada del asistente instala paquetes: las apps marcadas aparecen en
   Discover para instalarlas tú.

`Límite`: el asistente no crea usuarios ni particiona; eso es instalador
ISO (fuera de este repo).

## Spotlight, Apps, Mission Control y Dock

- **Spotlight** (`apps/nimbus-spotlight`, `Meta+Espacio` reservado;
  historial con `Meta+Alt+Espacio`): pestañas Apps, Archivos, Acciones y
  Portapapeles (`⌘1`–`⌘4` dentro de la ventana). `A–L` salta al resultado,
  `Tab` recorre controles, `Ctrl+Tab` repite en KRunner, `Esc` cierra.
  La pestaña Portapapeles tiene vistas Historial y Emoji con filtro por
  categoría. Evidencia: `docs/plans/evidence/F6-T0*.md`.
- **Apps** (`apps/nimbus-apps`): rejilla y lista, filtro por nombre,
  categorías (Todas, Productividad, Desarrollo, Gráficos, Juegos,
  Multimedia, Utilidades, Internet, Ajustes).
- **Mission Control** (`apps/nimbus-missioncontrol`): `Meta+W` vía el
  script KWin `kwin/nimbus-mc.js` (one-shot por DBus a `/MC toggle`); el
  Overview de stock se desactiva para no duplicar overlays (R-MC-STOCK).
- **Dock** (`packages/dock/kremarc-nimbus`): abajo, con auto-ocultado
  opcional; tamaño, ampliación y ocultado se ajustan en
  Ajustes Nimbus → Apariencia.

`Límite`: `Cmd+1…4` globales están reservados para Apps/Spotlight pero el
binding global aún no está cableado (ver `kglobalshortcutsrc`: `none`).

## Ajustes Nimbus (KCM)

`Ajustes del sistema en lenguaje claro` (`packages/kcm/kcm_nimbus`):
Apariencia, Red, Atajos, Accesibilidad, Sistema y Actualizaciones. Cada
sección tiene `Restablecer esta sección` y todo aplica con `Aplicar`.

## Claro, oscuro y acento

- `scripts/nimbus-theme [light|dark|auto] [--accent <hex>] [--wallpaper <img>] [--revert]`
  fija esquema, tema global y fondo con backup en
  `~/.config/nimbusshell-backup-*` (idempotente, sin root).
- El acento por defecto es `#007AFF` (claro) / `#0A84FF` (oscuro).

`Límite`: Plasma 6.8 no cambia el tema solo de día/noche; el auto se hace
con un timer de usuario propio (`nimbus-theme-auto.timer`).

## Accesibilidad

En Ajustes Nimbus → Accesibilidad: lupa de KWin (`Meta++` / `Meta+−`),
invertir colores, reducir animaciones, quitar transparencias, repetición
de teclado y lector Orca. Todo aplica con `Aplicar`; KWin relee solo su
configuración y el resto rige tras reiniciar la sesión.

`Límite`: si Orca no está instalado, el interruptor se guarda pero no hay
voz hasta instalarlo (el propio KCM lo avisa).

## Actualizaciones y rollback

- `scripts/nimbus-updates` (`--check` por defecto: solo lectura, lenguaje
  llano), `--apply` (crea snapshot snapper y actualiza; único modo que
  puede pedir root), `--rollback-list` y `--rollback N`.
- Lo mismo en Ajustes Nimbus → Actualizaciones, con aviso diario opcional
  (timer de usuario, sin root) y botón a Discover.

`Límite`: sin snapper no hay copias automáticas (el KCM lo indica); sin
Discover, la actualización es `pacman -Syu` en terminal.

## Solución de problemas

- Cada script tiene `--check` de solo lectura; `scripts/ci.sh` corre los
  lints y tests sin sudo, sin red y sin escribir.
- Si algo visual falla tras desplegar QML, mata el shell
  (`pkill -9 -f 'qs -c MacShell'`) y revisa su log: un `property`
  duplicado rompe la carga en silencio (ver [HANDOFF](../HANDOFF.md)).
- Los backups de cada cambio están en `~/.config/nimbusshell-backup-*`;
  `nimbus-theme --revert` y `nimbus-updates --rollback N` deshacen.
