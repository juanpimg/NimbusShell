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

## Aceptación corregida del panel (2026-11-02 01:50)

Diagnóstico en la VM con DBus real:

```text
$ qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'print(panels().length)'          -> 1
$ ... evaluateScript 'print(panels()[0].hiding)' -> autohide
```

Causa del falso FAIL anterior: `evaluateScript` **solo** devuelve lo que el
script pasa a `print()`; la expresión final `forEach(...)`/`panels().length`
produce salida vacía con exit 0. La propiedad correcta en Plasma 6.8 es
`hiding` (`autohide`), no `visibilityMode`/`visible`.

Correcciones verificadas:

- `nimbus-hide-panel`: aplica `p.hiding = "autohide"` y **verifica**
  `print(panels().map(...hiding...))`; log `OK: N panel(es) -> hiding=autohide`.
  Medido en la VM: `/tmp/hide-panel2` -> exit 0 y log con `hiding=autohide`.
- Arnés: `panel.stock` consulta `print(panels().length)` y
  `print(panels().map(p=>p.hiding))`; PASS con
  `paneles=1 hiding=autohide (fuera de vista/auto-hide)`.
- Tests: `test_kwinrc.sh` cubre `hiding=autohide`, fallo de `evaluateScript`
  y estado real `hiding=none`; `test_autostart.sh` actualizado.
  `tests/acceptance/test_installed_acceptance.sh`: 18/18; CI verde.

Aceptación real repetida (misma VM, sesión `nimbus`):

- **24 PASS / 1 FAIL / 1 SKIP** (`acceptance4`).
- PASS: sesión, SDDM, skel, paquetes, `kwin.scripts` (5 scripts activos),
  tema/acento, `panel.stock` (`hiding=autohide`), barra, notificaciones Nimbus,
  DBus Spotlight/Apps/MissionControl, KCM, ydotool.
- FAIL: `ydotool.input-group` — `usermod -aG input` se aplicó **después** de
  iniciar esta sesión; requiere re-login. En la ISO final el alta ocurre antes
  del primer login.
- SKIP: `shortcuts.real` (sin `--with-shortcuts`).

Evidencia: `F2-T08-acceptance-24pass.png` (tabla en la VM),
`F2-T08-acceptance-24pass.json` y `.md` (subidos desde el guest por HTTP POST,
porque 9p no propaga escrituras del guest al host).

## E2E limpio out10 y cierre de gaps (2026-11-02 03:13)

Instalación Calamares completa sobre disco/NVRAM nuevos (ISO out10,
`cc08b2bd…`), primer boot UEFI, SDDM Nimbus y login `nimbus`.

Aceptación inicial: **22 PASS / 3 FAIL / 1 SKIP**. Fallos y causa raíz:

1. `theme.scheme`/`theme.accent`: KDE lee `~/.config/kdeglobals`, pero el
   skel solo traía `~/.config/plasma/kdeglobals`. Además `~/.config` quedó
   **root:root** porque `nimbus-installed-setup` corre como root y crea
   directorios con `install -Dm644`; el usuario no podía escribir su tema.
2. `notifications.server`: la barra registraba `org.freedesktop.Notifications`
   después de que plasmashell arrancara (Type=simple no espera al nombre).
3. `ydotool.input-group`: el `usermod` se aplicó después del login de la
   sesión de prueba; en una instalación limpia ya estaba activo (PASS).

Fixes verificados en la misma VM:

- `dotfiles/.config/kdeglobals` (copia byte a byte de `plasma/kdeglobals`,
  `cmp` en CI) + setup copia al path efectivo si falta + build-iso lo exige.
- `nimbus-installed-setup` hace `chown -R $TARGET_USER:$TARGET_GROUP` de
  `.config/.local/.cache/.icons` (nunca ficheros personales).
- `nimbus-bar.service` pasa a `Type=notify` + `NotifyAccess=all`; el wrapper
  lanza la barra, espera a que `busctl --user status
  org.freedesktop.Notifications` tenga el PID de `nimbus-bar` y envía
  `systemd-notify --ready`. Si el nombre está tomado, notifica igualmente
  tras 5 s (sin bucle de Restart).
- Evidencia real: `busctl --user status org.freedesktop.Notifications` ->
  `Comm=nimbus-bar`, `UserUnit=nimbus-bar.service`; `notify-send` muestra el
  banner Nimbus (`35-out10-fdo-nimbus-bar.png`).
- Tema oscuro aplicado tras el chown (`ColorScheme=NimbusTahoe`).

Aceptación final sobre el sistema instalado (con fixes desplegados):
**25 PASS / 0 FAIL / 1 SKIP — VEREDICTO PASS**
(`F2-T08-out10-25pass.png/.json/.md`). El SKIP es `shortcuts.real`, que exige
`--with-shortcuts` + `ydotool`/`spectacle`.

Pendiente para el cierre definitivo: reconstruir ISO con estos fixes
(`out11`) y repetir el E2E limpio sin despliegue manual; el live actual
arranca en consola root y no trae usuario gráfico (workaround documentado:
crear `nimbus` y `systemctl start sddm`; gap de UX del live, no del target).

## Cierre definitivo: ISO out11 limpia (2026-11-02 03:56)

- ISO: `a926cec9a34f47738fa343f051ca5f33290308b3a89e46b5f5edb4dac8ea7526`.
- Instalación Calamares sobre disco y NVRAM nuevos; sin parches manuales en
  el target (solo se creó el usuario live porque el ISO live arranca en
  consola root; ver gap abajo).
- Primer boot UEFI: **3.25 s** (`systemd-analyze`: 714 ms kernel + 2.539 s
  userspace; `sddm ActiveEnterTimestampMonotonic=3251089`).
- Primer login: tema NimbusTahoe oscuro, barra Nimbus, Dock Krema, panel
  stock `hiding=autohide`, `nimbus-bar` dueño de
  `org.freedesktop.Notifications`, `sudo` operativo para `nimbus`.
- Aceptación final: **25 PASS / 0 FAIL / 1 SKIP — PASS**
  (`F2-T08-out11-25pass.png/.json/.md`). `shortcuts.real` queda SKIP
  porque no se pasó `--with-shortcuts`.
- `journalctl -p3 -b`: solo `virtio_tdx: TDX not supported by the host
  platform` (VM) — 0 errores críticos.
- Capturas: `36-out11-installed-sddm.png` (SDDM Nimbus instalado),
  `F2-T08-out11-25pass.png` (tabla).

Gap de UX del live (no del target): el ISO arranca en consola root y no
crea usuario gráfico; workaround `setup-live.sh` (useradd+chpasswd+sddm).
Queda abierto para la siguiente ISO: usuario live + SDDM habilitado, para
que el instalador se abra sin pasos manuales.
