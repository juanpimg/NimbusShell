#!/bin/bash
# Copia la capa Nimbus del live al sistema instalado (host, ${ROOT}).
set -u
ROOT="${1:-/}"
[ -d "$ROOT" ] || { echo "ERROR: ROOT no existe: $ROOT" >&2; exit 1; }
copy_dir() {
    src="$1"; dst="$2"
    [ -e "$src" ] || return 0
    mkdir -p "$dst"
    cp -a "$src/." "$dst/" || { echo "ERROR: copia $src -> $dst" >&2; exit 1; }
}
copy_dir /usr/share/sddm/themes/nimbus "$ROOT/usr/share/sddm/themes/nimbus"
copy_dir /usr/share/klassy-nimbus "$ROOT/usr/share/klassy-nimbus"
copy_dir /usr/share/nimbus/klassy "$ROOT/usr/share/nimbus/klassy"
copy_dir /usr/share/nimbus/themes "$ROOT/usr/share/nimbus/themes"
copy_dir /usr/share/nimbus/tokens "$ROOT/usr/share/nimbus/tokens"
copy_dir /usr/share/nimbus/bar "$ROOT/usr/share/nimbus/bar"
copy_dir /usr/share/nimbus/dock "$ROOT/usr/share/nimbus/dock"
# Solo los esquemas Nimbus: no pisar los de Breeze del target.
mkdir -p "$ROOT/usr/share/color-schemes"
for cs in /usr/share/color-schemes/Nimbus*.colors; do
    [ -f "$cs" ] || continue
    cp -a "$cs" "$ROOT/usr/share/color-schemes/$(basename "$cs")" || {
        echo "ERROR: no se pudo copiar $cs" >&2; exit 1; }
done
copy_dir /usr/share/dbus-1/services "$ROOT/usr/share/dbus-1/services"
copy_dir /usr/share/nimbus/user-guide "$ROOT/usr/share/nimbus/user-guide"
for d in /usr/share/kwin/scripts/nimbus-*; do
    [ -d "$d" ] || continue
    copy_dir "$d" "$ROOT/usr/share/kwin/scripts/$(basename "$d")"
done
for b in /usr/local/bin/nimbus-* /usr/local/bin/apply-theme; do
    [ -f "$b" ] || continue
    install -Dm755 "$b" "$ROOT/usr/local/bin/$(basename "$b")"
done
# Fondo NPS y logo propios.
copy_dir /usr/share/nimbus/assets "$ROOT/usr/share/nimbus/assets"
echo "OK: assets Nimbus copiados al target"
