#!/usr/bin/env bash
# Wrapper del diff de capturas (R-APPLE: goldens propios).
# Uso: compare.sh <golden.png> <captura.png> [--threshold N] [--crop x,y,w,h] [--out diff.png]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<'EOF'
Uso: compare.sh <golden.png> <captura.png> [--threshold N] [--crop x,y,w,h] [--out diff.png]
Compara dos PNG e imprime el % de pixeles distintos.
Exit: 0 si diff <= umbral, 1 si lo supera, 2 error (fichero, tamano, crop).
Ejemplo: compare.sh tests/golden/local/barra.png /tmp/ahora.png --threshold 15
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 2 ]]; then usage >&2; exit 2; fi

exec python3 "$HERE/compare.py" "$@"
