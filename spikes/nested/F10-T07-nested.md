# F10-T07 — Evidencia nested: nimbus-hw y Konsave

## Ficheros
- `apps/nimbus-hw/nimbus-hw`: Wi-Fi (`nmcli`+`lspci`), impresora
  (`lpstat`), audio (`pactl`/ALSA), Bluetooth, batería (sysfs);
  GPU delega en `nimbus-gpu-detect`; `--json`; aborta como root.
- `apps/backup/nimbus-backup save|restore|list`: tarball KDE
  configs + `packages-*.txt`; restore respalda en
  `nimbusshell-backup-*`; `--dry-run`; sin root; sufijo -2/-3.
- `tests/vm/nimbus-hw-check.sh`: fakes en PATH + HOME temporal.

## Detección (host real, solo lectura)
- `gpu: nvidia AD107M → nvidia-open-dkms`; `wifi: wlan0
  [connected]`; `bluetooth: activo`; `batería: 81%`;
  `--json` válido (`python3 -m json.tool`).

## Tests (`spikes/nested/nimbus-hw-check.log`)
- `shellcheck -S warning` 0 en los 3 scripts; `bash -n` OK.
- 13 PASS, 0 FAIL: json/llano, 3 fakes, save/restore
  (recupera valor), dry-run, idempotente (2 tarballs, sin borrar).
- Bug cazado: parseo `for+${!i}` tragaba el valor de
  `--file` (restore caía en `*)`); reescrito a `while+shift`.

## Commit / límites
- Commit `feat(F10-T07): nimbus-hw y Konsave` en `plasma/f10-hw`.
- Pendiente VM (QEMU/KVM): detección virtio + restore en guest;
  hardware NVIDIA real sin probar; NO merge (requiere orden).
