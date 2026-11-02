# F2-T08 — Escritorio Nimbus en el sistema instalado (2026-11-01 23:45)

## Hito visual

El sistema instalado por Calamares arranca por UEFI (GRUB → SDDM → Plasma
6.8.2 Wayland). Con la capa Nimbus desplegada, el escritorio muestra:

- barra superior Nimbus de 24 px con menú N, menú global de la app activa,
  iconos Wi-Fi/Bluetooth/Spotlight/CC, batería y reloj;
- Dock Krema flotante (48 px, zoom 1.6, glass) con Dolphin/Konsole/Kate/CC;
- tema NimbusTahoe oscuro, fondo NPS `sequoia-dark.jpg`, panel stock oculto;
- capturas reales: `spikes/f2-install/26-installed-bar-dock.png` (con
  ventanas) y `27-installed-nimbus-desktop.png` (escritorio limpio).

## Gaps reales encontrados (sistema instalado)

1. **El instalador no copió `/etc/skel` ni `/usr/share/nimbus/pkgs`** al
   target: el usuario quedó sin autostart/kwinrc/kdeglobals/klassyrc y sin
   los paquetes Klassy/Krema. La barra y el dock no arrancaban solos.
2. **SDDM no quedó habilitado**: `displaymanager` no creó
   `display-manager.service`; el sistema arrancaba en tty1. Se habilitó a
   mano para validar.
3. **Tema SDDM `nimbus` → pantalla negra** (QML del greeter). Se usó Breeze
   para la validación; bug abierto en F2-T02.
4. **Usuario/hostname mal por la automatización**: los campos de Calamares
   venían prellenados y se escribió encima (`nimbusnimbus`, hostname
   inválido, `/etc/hostname` ausente). El E2E definitivo limpia cada campo
   con Ctrl+A antes de escribir.
5. **Notificaciones**: la barra arrancó después de plasmashell y no pudo
   registrar `org.freedesktop.Notifications`; el script de entorno
   `plasma-workspace/env/nimbus-bar.sh` debe arrancarla antes (incluido en
   la ISO final).
6. El panel stock no se ocultaba con `visible=false`; el script pasa a
   `visibilityMode = 1` (auto-hide) y en la VM se fijó por GUI.

## Fixes aplicados (commits)

- `6e92cb6`: `nimbus-assets.sh` copia `/etc/skel` y `pkgs`; setup crea el
  home si falta, habilita `sddm` y escribe `hostname` de respaldo.
- `f062405`: panel auto-hide (`visibilityMode = 1`) y SDDM Breeze por
  defecto hasta validar el tema Nimbus.
- `b566ec8`: barra desde `plasma-workspace/env` antes de plasmashell.
- `467e7e7`/`cde1c0b`/`df8b6bc`: Calamares en español, mirrors curados y
  DNS real del live.
- `2859358`/`8df921d`: target Arch-only, mirrors geo/fastly, hosts del
  chroot y resolv.conf.

Pendiente: reconstruir la ISO con estos fixes y repetir el E2E limpio; la
aceptación 1:1 de F3/F5/F6/F7 se hace sobre ese sistema, no sobre parches
manuales.

## Aceptación real en la VM instalada (2026-11-02 01:00)

Ejecutado `tests/vm/installed-acceptance.sh` (descargado por HTTP para evitar
la caché 9p) en la sesión `nimbus` del sistema out8:

- **22 PASS / 3 FAIL / 1 SKIP**. PASS: sesión Wayland/Plasma, usuario/home,
  hostname, SDDM enabled, skel (env, autostart, kwinrc, kdeglobals, klassyrc,
  kremarc), paquetes klassy-nimbus/krema, tema/acento, `bar.process`,
  `notifications.server`, DBus Spotlight/Apps/MissionControl, KCM, ydotool.
- FAIL: `kwin.scripts` (KWin lee `~/.config/kwinrc`; el dotfile estaba en
  `plasma/kwinrc`), `panel.stock` (`evaluateScript` devolvía vacío) y
  `ydotool.input-group` (usuario no en `input`). SKIP `shortcuts.real`.
- Evidencia visual: `29-installed-notification-bar.png` (banner FDO servido
  por la barra: `Nimbus / Reunión / Prueba`), `30-installed-mission-control.png`
  (Mission Control con 4 Spaces y thumbs, abierto por DBus).
- La barra arrancó por **systemd user** (`nimbus-bar.service`, `Type=simple`,
  `Before=plasma-plasmashell.service`); su log confirma
  `servidor org.freedesktop.Notifications activo` y `barHeight=24`.
- El tema SDDM corregido (`93c14ed`) renderiza en el greeter real:
  `31-installed-sddm-nimbus.png` (reloj, tarjeta glass, usuario, sesión,
  reiniciar/apagar; sin errores QML).

## Fixes integrados tras la aceptación

- `9a8fac2`: `dotfiles/.config/kwinrc` efectivo (copia byte a byte de
  `plasma/kwinrc` + cmp en CI), setup copia a home/skel y fija Klassy,
  `usermod -aG input` fuera del timer, `hide-panel` con `panels().length`,
  reintento 30 s y log.
- `93c14ed`: tema SDDM sin `QtQuick.Controls`/`contentItem` (NimbusButton,
  UserSelector propio); `QtVersion=6`; validado con `sddm-greeter-qt6
  --test-mode` en la VM.
- `a6b30d4`: arnés de aceptación versionado (JSON+MD, PASS/FAIL/SKIP).
- `636a723`: unit `Type=simple` (sin el bucle de `Type=dbus`), espera del
  socket Wayland en `nimbus-bar-start`, env script sin lanzar procesos,
  autostart como fallback no-systemd.
- `SDDM_THEME=nimbus` activado en `nimbus-installed-setup` para la ISO final.

Pendiente para cerrar: reconstruir la ISO con todo (`out9`), repetir el E2E
limpio y la aceptación; confirmar persistencia del panel y shortcuts reales.
