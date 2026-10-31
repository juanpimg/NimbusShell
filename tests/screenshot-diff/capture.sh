#!/usr/bin/env bash
# Captura la pantalla de la VM (QEMU screendump) a tests/golden/local/<nombre>.png.
# Uso: capture.sh <nombre> [socket_hmp]
# No falla si la VM esta apagada: mensaje claro y exit 2.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUTDIR="$REPO/tests/golden/local"
VM_HOME="${HOME}/.cache/nimbusshell-vm"
SOCK="${2:-$VM_HOME/hmp.sock}"

usage() {
  cat <<'EOF'
Uso: capture.sh <nombre> [socket_hmp]
Guarda tests/golden/local/<nombre>.png desde la VM (QEMU screendump).
Requiere la VM arrancada (run-vm.sh expone hmp.sock).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 1 ]]; then usage >&2; exit 2; fi
if [[ ! -S "$SOCK" ]]; then
  echo "VM apagada o sin monitor HMP: no existe $SOCK" >&2
  echo "Arranca la VM primero (p. ej. ~/.cache/nimbusshell-vm/run-vm.sh) y reintenta." >&2
  exit 2
fi

name="$1"
mkdir -p "$OUTDIR"
tmp="$(mktemp /tmp/nimbus-cap-XXXXXX.ppm)"
trap 'rm -f "$tmp"' EXIT

if ! python3 "$VM_HOME/hmp.py" "$SOCK" screendump "$tmp" >/dev/null; then
  echo "error: fallo al pedir screendump a la VM" >&2
  exit 2
fi
if [[ ! -s "$tmp" ]]; then
  echo "error: la VM no devolvio imagen (screendump vacio)" >&2
  exit 2
fi
python3 "$VM_HOME/ppm2png.py" "$tmp" "$OUTDIR/$name.png"
