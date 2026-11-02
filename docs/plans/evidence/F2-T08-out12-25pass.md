# Aceptación del sistema instalado NimbusOS

- Fecha: 2026-11-02T02:54:36Z
- Host: nimbusos
- Usuario: nimbus
- Sesión: wayland / KDE (wayland=True, plasma=True)
- Salida: /home/nimbus/aceptacion7

| Estado | Check | Detalle |
| --- | --- | --- |
| PASS | session.wayland | type=wayland WAYLAND_DISPLAY=wayland-1 |
| PASS | session.plasma | XDG_CURRENT_DESKTOP=KDE plasmashell_pid=1050 |
| PASS | user.identity | usuario=nimbus uid=1000 HOME=/home/nimbus |
| PASS | host.hostname | hostname=nimbusos |
| PASS | sddm.enabled | systemctl is-enabled sddm = enabled |
| PASS | skel.plasma-env | /home/nimbus/.config/plasma-workspace/env/nimbus-bar.sh (ejecutable) |
| PASS | skel.autostart | krema, hide-panel y theme-init presentes en /home/nimbus/.config/autostart |
| PASS | skel.kwinrc | /home/nimbus/.config/kwinrc |
| PASS | skel.kdeglobals | /home/nimbus/.config/kdeglobals |
| PASS | skel.klassyrc | /home/nimbus/.config/klassy/klassyrc |
| PASS | skel.kremarc | /home/nimbus/.config/kremarc |
| PASS | packages.klassy-nimbus | klassy-nimbus 6.7.3-1 |
| PASS | packages.krema | krema 0.12.0-1 |
| PASS | kwin.scripts | activos: nimbus-spotlight nimbus-apps-toggle nimbus-tabs nimbus-mc nimbus-zoom |
| PASS | theme.scheme | ColorScheme=NimbusTahoe |
| PASS | theme.accent | Colors:Window/DecorationFocus=10,132,255 |
| PASS | panel.stock | paneles=1 hiding=autohide (fuera de vista/auto-hide) |
| PASS | bar.process | nimbus-bar vivo (pid 583,598) |
| PASS | notifications.server | Nimbus: Nimbus/NimbusOS/1.0/1.2 |
| PASS | dbus.spotlight | Spotlight: activado por DBus (pid 1718) |
| PASS | dbus.apps | Apps: activado por DBus (pid 1752) |
| PASS | dbus.missioncontrol | Mission Control: activado por DBus (pid 1788) |
| PASS | kcm.nimbus | plugin + desktop + kpackage presentes |
| PASS | ydotool.binary | /usr/bin/ydotool |
| PASS | ydotool.input-group | grupos=nimbus network video storage optical input audio wheel |
| SKIP | shortcuts.real | no solicitado; usar --with-shortcuts (ydotool + spectacle, sin layout) |

**Resumen:** 25 PASS / 0 FAIL / 1 SKIP — **VEREDICTO: PASS**
