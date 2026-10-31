#!/bin/bash
# F2-T09 — Chequeo de seguridad base en VM (NO ejecutar en el host de
# desarrollo; se ejecutará en F2-T08). Requiere root en el guest instalado:
# comprueba firewalld activo, raíz sobre LUKS2, telemetría KDE off por
# usuario y journal sin errores críticos.
# Uso (en VM): sudo tests/vm/security-check.sh
# Aquí solo validación estática: bash -n + shellcheck.
set -u

fail=0
say() { printf '%s\n' "$1"; }

# 1. firewalld habilitado y activo (lo habilita iso/calamares/modules/services.conf).
if systemctl is-enabled firewalld >/dev/null 2>&1; then
    say "OK: firewalld habilitado ($(systemctl is-enabled firewalld))"
else
    say "FALLO: firewalld no habilitado" >&2; fail=1
fi
if systemctl is-active firewalld >/dev/null 2>&1; then
    say "OK: firewalld activo"
else
    say "FALLO: firewalld no activo" >&2; fail=1
fi
say "·· zona por defecto: $(firewall-cmd --get-default-zone 2>/dev/null || echo desconocida) (esperada: public)"

# 2. Raíz sobre LUKS2 (particionado guiado de iso/calamares/modules/partition.conf).
root_src="$(findmnt -no SOURCE / 2>/dev/null || echo desconocido)"
if [[ "$root_src" == /dev/mapper/* ]]; then
    map="${root_src#/dev/mapper/}"
    if cryptsetup status "$map" 2>/dev/null | grep -qi 'type:.*LUKS2'; then
        say "OK: / sobre LUKS2 ($root_src)"
        cryptsetup status "$map" 2>/dev/null | grep -iE 'cipher|type' | sed 's/^/·· /'
    else
        say "FALLO: $root_src no es LUKS2 (se esperaba cifrado)" >&2; fail=1
    fi
else
    say "FALLO: / no está en /dev/mapper ($root_src): sin LUKS" >&2; fail=1
fi

# 3. Telemetría KDE off: skel + cada usuario de /home.
if [ -f /etc/skel/.config/PlasmaUserFeedback ] \
    && grep -q '^FeedbackLevel=0' /etc/skel/.config/PlasmaUserFeedback 2>/dev/null; then
    say "OK: skel trae PlasmaUserFeedback FeedbackLevel=0"
else
    say "FALLO: /etc/skel/.config/PlasmaUserFeedback sin FeedbackLevel=0" >&2; fail=1
fi
for home in /home/*; do
    [ -d "$home" ] || continue
    user="${home#/home/}"
    level="$(sudo -u "$user" kreadconfig6 --file PlasmaUserFeedback --group Global --key FeedbackLevel --default unset 2>/dev/null || echo error)"
    if [ "$level" = "0" ]; then
        say "OK: telemetría off para $user (FeedbackLevel=0)"
    else
        say "FALLO: telemetría no off para $user (FeedbackLevel=$level)" >&2; fail=1
    fi
done

# 4. Journal sin errores críticos en el arranque actual.
crit="$(journalctl -p 3 -b --no-pager 2>/dev/null | wc -l)"
if [ "$crit" -eq 0 ]; then
    say "OK: journalctl -p 3 -b sin líneas críticas"
else
    say "FALLO: $crit línea(s) críticas en journalctl -p 3 -b:" >&2
    journalctl -p 3 -b --no-pager 2>/dev/null | head -20 >&2
    fail=1
fi

[ "$fail" -eq 0 ] && say "security-check: TODO OK" || say "security-check: FALLOS (fail=$fail)" >&2
exit "$fail"
