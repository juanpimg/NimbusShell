# Aceptación del sistema instalado NimbusOS

- Fecha: 2026-11-02T00:48:46Z
- Host: nimbusos
- Usuario: nimbus
- Sesión: wayland / KDE (wayland=True, plasma=True)
- Salida: /home/nimbus/aceptacion4

| Estado | Check | Detalle |
| --- | --- | --- |
| PASS | session.wayland | type=wayland WAYLAND_DISPLAY=wayland-1 |
| PASS | session.plasma | XDG_CURRENT_DESKTOP=KDE plasmashell_pid=602 |
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
| PASS | bar.process | nimbus-bar vivo (pid 586) |
| PASS | notifications.server | Nimbus: Nimbus/NimbusOS/1.0/1.2 |
| PASS | dbus.spotlight | Spotlight: activado por DBus (pid 1613) |
| PASS | dbus.apps | Apps: activado por DBus (pid 1646) |
| PASS | dbus.missioncontrol | Mission Control: activado por DBus (pid 1689) |
| PASS | kcm.nimbus | plugin + desktop + kpackage presentes |
| PASS | ydotool.binary | /usr/bin/ydotool |
| FAIL | ydotool.input-group | usuario no está en input (grupos='nimbus network video storage optical audio wheel'); ydotool no podrá abrir uinput |
| SKIP | shortcuts.real | no solicitado; usar --with-shortcuts (ydotool + spectacle, sin layout) |

**Resumen:** 24 PASS / 1 FAIL / 1 SKIP — **VEREDICTO: FAIL**
