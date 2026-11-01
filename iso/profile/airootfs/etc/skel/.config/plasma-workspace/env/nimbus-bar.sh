#!/bin/sh
# NimbusOS (R-NOTIF-SERVER): la barra debe registrar
# org.freedesktop.Notifications ANTES de plasmashell; los scripts de
# entorno de Plasma corren al inicio de sesión, antes del shell.
[ -x /usr/local/bin/nimbus-bar ] || exit 0
pgrep -f '/usr/local/bin/nimbus-bar' >/dev/null 2>&1 && exit 0
/usr/local/bin/nimbus-bar >/tmp/nimbus-bar.log 2>&1 &
