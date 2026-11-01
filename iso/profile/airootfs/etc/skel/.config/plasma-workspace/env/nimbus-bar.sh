#!/bin/sh
# NimbusOS (R-NOTIF-SERVER): fallback de arranque temprano de la barra.
# El camino principal es nimbus-bar.service; esto cubre sesiones sin el
# servicio habilitado. nimbus-bar-start no bloquea (segundo plano) y la
# barra es single-instance (org.nimbus.Bar): duplicar no crea dos barras.
# Sin `exit`/`exec`: Plasma puede sourcear este script y no debe cortar
# el arranque de la sesión.
if [ -x /usr/local/bin/nimbus-bar-start ]; then
    /usr/local/bin/nimbus-bar-start
fi
