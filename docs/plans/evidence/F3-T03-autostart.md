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

## 2. Diseño (vía correcta: systemd de usuario, Type=dbus)

- Unidad `nimbus-bar.service` (skel `~/.config/systemd/user/`):
  `Type=dbus`, `BusName=org.freedesktop.Notifications`,
  `WantedBy=plasma-workspace.target`, `PartOf=plasma-workspace.target`,
  `After=plasma-kwin_wayland.service`, `Before=plasma-plasmashell.service`,
  `ExecStart=/usr/local/bin/nimbus-bar-start`. Solo aplica con arranque
  systemd (default Plasma 6).
- Fallback no-systemd: autostart `nimbus-bar.desktop` + env script (el env
  script ahora solo delega en `nimbus-bar-start`, sin `exec`; Plasma puede
  *sourcearlo*). Single-instance `org.nimbus.Bar` hace inocua la
  concurrencia de las tres vías.
- Riesgo documentado: al poseer `org.freedesktop.Notifications`, el
  applet/historial/DND de plasmashell deja de funcionar; si el daemon muere
  nadie re-registra (mitigado con `Restart=on-failure`). Escape:
  `nimbus-bar-start --no-notifications` (barra sin nombre FDO; entonces la
  unidad Type=dbus no debe usarse con ese flag porque el BusName nunca
  llegaría).

## 3. Ficheros

- `iso/profile/airootfs/usr/local/bin/nimbus-bar-start` (nuevo; `set -u`,
  sin root, idempotente, log `~/.local/state/nimbus/bar.log`): guarda
  pgrep exacta, espera `WAYLAND_DISPLAY` bajo systemd y hace `exec` del
  binario (Type=simple/dbus sigue su ciclo de vida); fuera de systemd lanza
  en segundo plano con `nohup`.
- `packages/shell/nimbus-bar/main.cpp`: single-instance `org.nimbus.Bar`
  (tomado → log + exit 0); sin bus de sesión se permite el arranque con
  aviso (nested/offscreen/CI). No toca `org.freedesktop.Notifications`
  (registro no fatal intacto) ni `--no-notifications`.
- `iso/profile/airootfs/etc/skel/.config/systemd/user/nimbus-bar.service`
  (nuevo), `.../autostart/nimbus-bar.desktop` (nuevo, fallback),
  env `nimbus-bar.sh` (adelgazado a delegar).
- `nimbus-hide-panel` (endurecido): detecta `qdbus6`/`qdbus`, espera hasta
  40 intentos a `org.kde.plasmashell`, aplica `visibilityMode = 1` +
  `visible = false`, log `hide-panel.log`, exit 0 sin panel/sin bus.
- `nimbus-installed-setup` §4c (nuevo, aditivo; SDDM/tema intactos):
  instala la unidad en el home destino y la enlaza en
  `default.target.wants`; asegura 755 de env/autostart.
- `iso/profile/profiledef.sh` + `iso/build-iso.sh`: permisos y `--check` de
  los 4 ficheros nuevos.
- `tests/bar/test_autostart.sh` (nuevo): 30 aserciones (ver §4).

## 4. Verificación

- `tests/bar/test_autostart.sh`: **AUTOSTART VERDE** (30/30): shellcheck
  cero warnings; start idempotente con fakes pgrep (lanza / no lanza / rc);
  build CMake real + prueba DBus real (`dbus-run-session`, offscreen):
  primera instancia viva, segunda sale 0 con `org.nimbus.Bar ya registrado`;
  hide-panel con qdbus6 falso (ok / sin panel / sin bus, rc 0 y
  `visibilityMode = 1` en la llamada); unidad con las 7 claves; setup con
  servicio + wants + 755 + SDDM intacto; `qmllint Bar.qml` OK.
- `iso/build-iso.sh --check`: OK (incluye los 4 ficheros nuevos).
- `qmllint packages/shell/nimbus-bar/qml/Bar.qml`: OK.

## 5. Pendiente de VM

- Arranque real en sesión Plasma: `systemctl --user show -p After
  plasma-plasmashell.service`, `busctl --user status
  org.freedesktop.Notifications` (propietario = nimbus-bar), panel stock
  oculto tras login limpio, sin duplicados con Krema/tema.
- `nimbus-installed-setup --check` y real (exige root/chroot: solo en VM).
