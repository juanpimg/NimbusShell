# F3-T03 — Arranque determinista de nimbus-bar + auto-hide del panel stock

Fecha: 2026-11-02. Rama `plasma/f-autostart2`. Sin VM (pendiente): toda la
evidencia es con HOME/XDG temporales, fakes en PATH y bus de sesión de
prueba (`dbus-run-session`); el `$HOME` y la sesión del host no se tocan.

## 1. Diagnóstico (sistema instalado out8, Plasma 6.8.2 Wayland)

- Krema y el tema arrancan solos; **nimbus-bar no arranca** y el panel stock
  sigue visible. Lanzada a mano funciona (`barHeight=24`) y el FDO ya está
  tomado (`org.freedesktop.Notifications ya registrado (plasmashell stock?)`).
- Causa raíz (vía researcher, fuente `startplasma.cpp runEnvironmentScripts`):
  `plasma-workspace/env/*.sh` solo sirve para **variables de entorno**;
  `startplasma-wayland` los hace *source* antes de kwin/plasmashell, pero
  lanzar un proceso desde ahí no es mecanismo soportado. El env script nunca
  fue vía válida de arranque.
- Además `nimbus-hide-panel` corría en autostart sin esperar a plasmashell:
  el `evaluateScript` fallaba en silencio durante el login.

## 2. Diseño (vía correcta: systemd de usuario, Type=simple)

- Unidad `nimbus-bar.service` (skel `~/.config/systemd/user/`):
  `Type=simple`, `WantedBy=plasma-workspace.target`,
  `PartOf=plasma-workspace.target`, `After=plasma-kwin_wayland.service`,
  `Before=plasma-plasmashell.service`, `ExecStart=nimbus-bar-start`,
  `Restart=on-failure`, `RestartSec=2`. Solo aplica con arranque systemd
  (default Plasma 6).
- `Type=simple` a propósito (review): el registro FDO es no fatal dentro de
  la barra; `Type=dbus` + `BusName=` se descartó porque con el nombre tomado
  systemd nunca la ve ready, `Restart=on-failure` entraría en bucle y
  `Before=plasmashell` retrasaría al shell stock.
- `nimbus-installed-setup` la enlaza en
  `~/.config/systemd/user/plasma-workspace.target.wants/` (NO
  `default.target.wants`, que no la ordenaría con plasmashell); sin
  `daemon-reload` en chroot (el user manager lee los wants al login).
- Fallback no-systemd: SOLO autostart `nimbus-bar.desktop`. El env script
  quedó vacío de lanzamientos (solo comentarios): lanzar desde
  `plasma-workspace/env/*.sh` era el bug real (`Failed to create
  wl_display`, el script corre antes de que exista Wayland).
- `nimbus-bar-start` espera al socket `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY`
  (hasta ~10 s) tanto bajo systemd como en autostart/manual, y sale 0 sin
  lanzar si `org.nimbus.Bar` ya tiene dueño (sonda qdbus; si no hay qdbus
  decide el binario). Así servicio y autostart no se pisan.
- Riesgo documentado: al poseer `org.freedesktop.Notifications`, el
  applet/historial/DND de plasmashell deja de funcionar; si el daemon muere
  nadie re-registra (mitigado con `Restart=on-failure`). Escape:
  `nimbus-bar-start --no-notifications` (barra sin nombre FDO).
- `nimbus-hide-panel`: `visibilityMode=1` es AUTO-HIDE, no eliminación
  (criterio F3-T03: "panel no visible/auto-hide", no "eliminado"). La
  eliminación permanente (`panel.remove()`) no está verificada en
  Plasma 6.8 y queda pendiente.

## 3. Ficheros

- `iso/profile/airootfs/usr/local/bin/nimbus-bar-start` (`set -u`, sin
  root, idempotente, log `~/.local/state/nimbus/bar.log`): guarda pgrep
  exacta, sonda `org.nimbus.Bar` por qdbus (tomado → exit 0), espera al
  socket Wayland ~10 s; bajo systemd hace `exec` en primer plano, fuera de
  systemd lanza con `nohup` en segundo plano.
- `packages/shell/nimbus-bar/main.cpp`: single-instance `org.nimbus.Bar`
  (tomado → log + exit 0); sin bus de sesión se permite el arranque con
  aviso (nested/offscreen/CI). No toca `org.freedesktop.Notifications`
  (registro no fatal intacto) ni `--no-notifications`.
- `iso/profile/airootfs/etc/skel/.config/systemd/user/nimbus-bar.service`
  (`Type=simple`, orden KWin → barra → plasmashell),
  `.../autostart/nimbus-bar.desktop` (único fallback no-systemd),
  env `nimbus-bar.sh` (sin lanzamientos; 644 en profiledef.sh).
- `nimbus-hide-panel`: detecta `qdbus6`/`qdbus`, espera hasta 40 intentos a
  `org.kde.plasmashell`, aplica auto-hide (`visibilityMode = 1` +
  `visible = false`), log `hide-panel.log`, exit 0 sin panel/sin bus.
- `nimbus-installed-setup` §4c (aditivo; SDDM/tema intactos): instala la
  unidad en el home destino y la enlaza en
  `plasma-workspace.target.wants`; asegura 755 del autostart.
- `iso/profile/profiledef.sh` + `iso/build-iso.sh`: permisos y `--check` de
  los ficheros.
- `tests/bar/test_autostart.sh`: aserciones (ver §4).

## 4. Verificación

- `tests/bar/test_autostart.sh`: **AUTOSTART VERDE**: shellcheck cero
  warnings; start idempotente con fakes pgrep; espera de socket Wayland
  (socket presente → lanza + log; ausente → espera, avisa y lanza); sonda
  `org.nimbus.Bar` por qdbus falso (tomado → exit 0 sin lanzar);
  build CMake real + prueba DBus real (`dbus-run-session`, offscreen, sin
  `--no-notifications`): primera instancia viva, segunda sale 0 con
  `org.nimbus.Bar ya registrado`; hide-panel con qdbus6 falso (ok / sin
  panel / sin bus, rc 0 y `visibilityMode = 1` en la llamada); unidad
  `Type=simple` + orden Plasma, sin `Type=dbus`/`BusName`; env script sin
  lanzamientos; setup con wants de plasma-workspace (y sin
  default.target.wants); `qmllint Bar.qml` OK.
- `iso/build-iso.sh --check`: OK (incluye los 4 ficheros nuevos).
- `qmllint packages/shell/nimbus-bar/qml/Bar.qml`: OK.

## 5. Pendiente de VM

- Arranque real en sesión Plasma: `systemctl --user show -p After
  plasma-plasmashell.service`, `busctl --user status
  org.freedesktop.Notifications` (propietario = nimbus-bar), panel stock
  oculto tras login limpio, sin duplicados con Krema/tema.
- `nimbus-installed-setup --check` y real (exige root/chroot: solo en VM).
