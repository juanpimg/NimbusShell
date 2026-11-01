# apps/backup (`org.nimbus.backup`)

## F10-T07 — `nimbus-hw` / `nimbus-backup`

`nimbus-hw [--json]` (solo lectura, aborta como root): GPU vía
`nimbus-gpu-detect --json`, Wi-Fi (`nmcli` + `lspci` Network),
impresoras (`lpstat -e/-d`), audio (`pactl` o `/proc/asound/cards`),
Bluetooth (`bluetoothctl`/`lsusb`), batería (sysfs). No instala drivers.
`apps/backup/nimbus-backup save|restore|list [--dry-run] [--dest/--file]`:
tarball con KDE configs + `packages-*.txt`; restore respalda lo
sobrescrito en `~/.config/nimbusshell-backup-*`; sin root; idempotente
(sufijo -2/-3 si colisiona el segundo). Harness
`tests/vm/nimbus-hw-check.sh --check` (fakes nmcli/lpstat/lsusb/pactl/
bluetoothctl en PATH + HOME temporal): 13 PASS. Evidencia
`spikes/nested/F10-T07-nested.md`.

Soporte y persistencia del usuario: backup/restore vía Konsave (tarball
restorable probado en VM), `nimbus-bug-report` (journal, `kinfo`, `qdbus6`)
y botón Ayuda (F9-T10).

- **Qué no:** snapshots del sistema/rollback (snapper/Btrfs, F9-T08).
