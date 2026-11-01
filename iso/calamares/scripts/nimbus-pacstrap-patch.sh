#!/bin/bash
# Aplica el pacstrap de Nimbus (sin paquetes CachyOS inexistentes) en el live.
set -u
SRC=/etc/calamares/scripts/pacstrap-main.py
DST=/usr/lib/calamares/modules/pacstrap/main.py
[ -f "$SRC" ] || { echo "ERROR: falta $SRC" >&2; exit 1; }
cp "$SRC" "$DST"
chmod 644 "$DST"
python3 -m py_compile "$DST"
