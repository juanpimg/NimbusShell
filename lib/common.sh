#!/bin/bash
# lib/common.sh — utilidades compartidas del instalador NimbusShell.
# Requiere bash. Respeta `set -u` del llamador; nunca pide sudo ni escribe
# fuera de lo que cada función documenta.
# Estado global: CHECK_FAIL (0 verde, 1 con [FALTA]).

CHECK_FAIL="${CHECK_FAIL:-0}"

nimbus_ok()   { echo "  [OK] $1"; }
nimbus_info() { echo "$1"; }
nimbus_fail() { echo "  [FALTA] $1" >&2; CHECK_FAIL=1; }

require_nonroot() {
    if [ "$(id -u)" = "0" ]; then
        echo "ERROR: no ejecutar como root. Entra como tu usuario (con sudo) y reintenta." >&2
        exit 2
    fi
}

require_pacman() {
    if ! command -v pacman >/dev/null 2>&1; then
        echo "ERROR: sin pacman: esto no parece Arch Linux (NimbusShell solo cubre Arch y derivados)." >&2
        exit 2
    fi
}

read_list() { # $1=fichero -> stdout: paquetes (sin comentarios ni vacías)
    # Corta comentarios inline (#...), quita CR (edits CRLF), recorta
    # espacios y elimina vacías. Un paquete por línea, sin espacios internos.
    sed 's/#.*//; s/\r//g; s/^[[:space:]]*//; s/[[:space:]]*$//' "$1" | grep -v '^[[:space:]]*$'
}

make_backup_dir() { # stdout: ruta de backup con timestamp (no la crea)
    echo "$HOME/.config/nimbusshell-backup-$(date +%Y%m%d-%H%M%S)"
}

copy_dotfiles() { # $1=origen $2=HOME $3=backup: copia idempotente con backup, jamás borra
    local src_dir="$1" home_dir="$2" backup_dir="$3"
    local src rel dst n_new n_upd n_same
    n_new=0; n_upd=0; n_same=0
    while IFS= read -r src; do
        rel="${src#"$src_dir"/}"
        dst="$home_dir/$rel"
        if [ ! -e "$dst" ]; then
            mkdir -p "$(dirname "$dst")" \
                || { echo "ERROR: no se pudo crear $(dirname "$dst") (revisa permisos/disco)" >&2; return 1; }
            cp -a "$src" "$dst" \
                || { echo "ERROR: no se pudo copiar $rel a tu HOME (revisa permisos/disco)" >&2; return 1; }
            n_new=$((n_new + 1))
        elif ! cmp -s "$src" "$dst"; then
            mkdir -p "$backup_dir/$(dirname "$rel")" \
                || { echo "ERROR: no se pudo crear el backup en $backup_dir (revisa permisos/disco)" >&2; return 1; }
            cp -a "$dst" "$backup_dir/$rel" \
                || { echo "ERROR: no se pudo respaldar $rel (revisa permisos/disco)" >&2; return 1; }
            cp -a "$src" "$dst" \
                || { echo "ERROR: no se pudo actualizar $rel (tu original sigue en $backup_dir/$rel)" >&2; return 1; }
            n_upd=$((n_upd + 1))
        else
            n_same=$((n_same + 1))
        fi
    done < <(find "$src_dir" \( -type f -o -type l \) | sort)
    echo "    nuevos=$n_new actualizados=$n_upd (backup en $backup_dir) identicos=$n_same"
    # Solo quita el dir si quedó vacío (rmdir, no rm -rf): si otra ejecución
    # creó un backup con el mismo timestamp, su contenido se conserva.
    rmdir "$backup_dir" 2>/dev/null || true
}

check_dotfiles() { # $1=origen $2=HOME: solo lectura; marca CHECK_FAIL si hay drift
    local src_dir="$1" home_dir="$2"
    local src rel dst n_ok drift
    n_ok=0; drift=0
    while IFS= read -r src; do
        rel="${src#"$src_dir"/}"
        dst="$home_dir/$rel"
        if [ ! -e "$dst" ]; then nimbus_fail "falta en HOME: $rel"; drift=$((drift + 1));
        elif ! cmp -s "$src" "$dst"; then nimbus_fail "difiere de HOME: $rel"; drift=$((drift + 1));
        else n_ok=$((n_ok + 1)); fi
    done < <(find "$src_dir" \( -type f -o -type l \) | sort)
    [ "$drift" = "0" ] && nimbus_ok "dotfiles 1:1 con el repo ($n_ok ficheros)"
}
