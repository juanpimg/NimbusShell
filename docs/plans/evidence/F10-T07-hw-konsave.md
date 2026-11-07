# Evidencia F10-T07 — nimbus-hw, Konsave y harness de captura

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- Módulos de detección de hardware:
  - `apps/nimbus-hw/nimbus-hw`: texto llano y `--json` estructurado con estado de batería, audio, Wi-Fi, Bluetooth e impresoras.
  - `apps/nimbus-hw/nimbus-gpu-detect`: detección precisa de GPUs PCI (NVIDIA Pascal/Turing, AMD, Intel y soporte nativo para entornos de virtualización virtio/QEMU).
  - `apps/nimbus-hw/nimbus-gpu-setup`: gestión de perfiles de energía (power-profiles-daemon) y modo `--dry-run` seguro.
- Port de Konsave / Backup:
  - `apps/backup/nimbus-backup`: almacenamiento y restauración de configs de Plasma/KWin y dotfiles Nimbus en tarballs `.tar.gz` versionados, preservando copias de seguridad de archivos sobreescritos en `~/.config/nimbusshell-backup-*`.
- Suite de pruebas automatizada:
  - `tests/hw/test_hw.sh`: 8/8 checks OK.
  - `tests/vm/nimbus-hw-check.sh`: 14/14 PASS.
  - Comprobación de fakes en PATH para Wi-Fi, impresora, Bluetooth y virtio GPU en entorno virtual sin requerir privilegios de root ni hardware físico específico.

## Verificación
```bash
bash tests/hw/test_hw.sh
# Resultado: HARDWARE VERDE (todos los checks pasan).
```
