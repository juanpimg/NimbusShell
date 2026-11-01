#!/usr/bin/env bash
# tests/vm/nimbus-hw-check.sh — valida nimbus-hw y nimbus-backup.
# En VM: detección real + backup/restore en HOME temporal.
# Local: --check en seco, sin root, sin red, HOME temporal, fakes en PATH.
# Uso: bash tests/vm/nimbus-hw-check.sh [--check] [--out spikes/nested]
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="spikes/nested"; MODE="vm"
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="local-seco"; shift ;;
    --out) OUT="${2:-spikes/nested}"; shift 2 ;;
    *) echo "Uso: $0 [--check] [--out DIR]" >&2; exit 1 ;;
  esac
done
[ "$(id -u)" -eq 0 ] && { echo "ERROR: no como root" >&2; exit 1; }
mkdir -p "$REPO/$OUT"
LOG="$REPO/$OUT/nimbus-hw-check.log"; : > "$LOG"
echo "modo=$MODE (sin root, HOME temporal, fakes en PATH)" | tee -a "$LOG"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS: $*" | tee -a "$LOG"; }
no() { fail=$((fail+1)); echo "FAIL: $*" | tee -a "$LOG"; }
HW="$REPO/apps/nimbus-hw/nimbus-hw"; BK="$REPO/apps/backup/nimbus-backup"

bash -n "$HW" && ok "bash -n nimbus-hw" || no "bash -n nimbus-hw"
bash -n "$BK" && ok "bash -n nimbus-backup" || no "bash -n nimbus-backup"
"$HW" --json | python3 -m json.tool >/dev/null 2>>"$LOG" \
  && ok "--json válido" || no "--json válido"
"$HW" | grep -qiE 'wifi|audio|bluetooth|batería' \
  && ok "texto llano (wifi/audio/bt/batería)" || no "texto llano"

# Fakes: nmcli wifi conectada, lpstat con impresora, lsusb BT, pactl sink.
FAKE="$(mktemp -d /tmp/opencode/nimbus-fake-XXXXXX)"; trap 'rm -rf "$FAKE"' EXIT
cat > "$FAKE/nmcli" <<'EOF'
#!/usr/bin/env bash
echo "wlp3s0:wifi:conectada"
EOF
cat > "$FAKE/lpstat" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-e" ]; then echo -e "HP_LaserJet\nEpson_XP"; else echo "system default destination: HP_LaserJet"; fi
EOF
cat > "$FAKE/lsusb" <<'EOF'
#!/usr/bin/env bash
echo "Bus 001 Device 002: ID 0a12:0001 Bluetooth dongle"
EOF
cat > "$FAKE/pactl" <<'EOF'
#!/usr/bin/env bash
echo "alsa_output.pci.fake"
EOF
cat > "$FAKE/bluetoothctl" <<'EOF'
#!/usr/bin/env bash
echo "Controller AA:BB:CC:DD:EE:FF fake [default]"
EOF
chmod +x "$FAKE"/*
FJ="$(PATH="$FAKE:$PATH" "$HW" --json)"
echo "$FJ" | grep -q '"device":"wlp3s0"' && ok "fake wifi" || no "fake wifi ($FJ)"
echo "$FJ" | grep -q 'HP_LaserJet' && ok "fake impresora" || no "fake impresora"
echo "$FJ" | grep -qi 'bluetooth' && ok "fake bluetooth" || no "fake bluetooth"

# Backup/restore en HOME temporal (nunca el real).
TH="$(mktemp -d /tmp/opencode/nimbus-home-XXXXXX)"
mkdir -p "$TH/.config" "$TH/backups"
echo "SingleClick=false" > "$TH/.config/kdeglobals"
echo "[Windows]" > "$TH/.config/kwinrc"
NIMBUS_TEST_HOME="$TH" NIMBUS_BACKUP_DIR="$TH/backups" "$BK" save >>"$LOG" 2>&1 \
  && ok "backup save" || no "backup save"
TARBALL="$(ls -1t "$TH/backups"/nimbus-backup-*.tar.gz 2>/dev/null | head -1 || true)"
[ -n "$TARBALL" ] && ok "tarball $TARBALL" || no "tarball ausente"
echo "SingleClick=true" > "$TH/.config/kdeglobals"  # ensucia
NIMBUS_TEST_HOME="$TH" NIMBUS_BACKUP_DIR="$TH/backups" "$BK" restore --file "$TARBALL" >>"$LOG" 2>&1 \
  && ok "backup restore" || no "backup restore"
grep -q 'SingleClick=false' "$TH/.config/kdeglobals" \
  && ok "restore recupera valor" || no "restore recupera valor"
NIMBUS_TEST_HOME="$TH" "$BK" save --dry-run | grep -q DRY-RUN \
  && ok "dry-run sin cambios" || no "dry-run"
NIMBUS_TEST_HOME="$TH" NIMBUS_BACKUP_DIR="$TH/backups" "$BK" save >>"$LOG" 2>&1
N1="$(ls "$TH/backups"/*.tar.gz | wc -l)"
[ "$N1" -ge 2 ] && ok "idempotente (no borra previas: $N1)" || no "idempotente"
rm -rf "$TH" "$FAKE"; trap - EXIT

echo "== $pass PASS, $fail FAIL (log $LOG) ==" | tee -a "$LOG"
[ "$fail" -eq 0 ]
