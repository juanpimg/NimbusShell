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
