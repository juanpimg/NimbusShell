# apps/nimbus-hw (`org.nimbus.hw`)

Detección de hardware estilo chwd: GPU (incl. perfil NVIDIA Wayland,
`modeset=1`), Wi-Fi, impresora, energía (`power-profiles-daemon`).

- **Qué va:** detección, presets por hardware, tests en VM + hardware.
- **Qué no:** el perfil ISO en sí (vive en `iso/profile/`); aquí solo la
  herramienta de detección y presets.

## F2-T10 — `nimbus-gpu-detect` / `nimbus-gpu-setup`

Ambos `set -u`, no root, idempotentes. `--json` (detect) para KCM/Calamares;
`--dry-run` (setup, por defecto) sin cambios; `--apply` exige root.

| GPU | Driver recomendado | Paquete |
|-----|--------------------|---------|
| NVIDIA Turing+ (GTX 16xx, RTX) | abierto | `nvidia-open-dkms` |
| NVIDIA anterior (GTX 10xx-, Quadro K/M) | propietario | `nvidia-dkms` |
| AMD | abierto | `mesa` (+ `vulkan-radeon` en live) |
| Intel | abierto | `mesa` (+ `vulkan-intel` en live) |
| VM (virtio/QEMU/VirtualBox) | virtio | ninguno (mesa) |
| Híbrida (Intel/AMD+NVIDIA) | según dGPU + `prime-run` offload | uno de los NVIDIA |

`nimbus-gpu-setup` aplica: `nvidia_drm.modeset=1` en grub,
módulos `nvidia*` en `MODULES` de mkinitcpio, `systemctl enable
power-profiles-daemon`; la suspensión no se fuerza (la gestiona
powerdevil). Backups `*.bak-<fecha>`; rollback: restaurar y regenerar
grub/initramfs. NUNCA `--apply` en el host de desarrollo.

## Hook post-instalación (F2-Iso, `nimbus-installed-setup` aún no existe)

Cuando exista `iso/profile/airootfs/usr/local/bin/nimbus-installed-setup`,
añadir antes del paso de tema/SDDM:

```bash
if nimbus-gpu-detect --json | grep -q '"vendor":"nvidia"'; then
  nimbus-gpu-setup --apply
fi
```

Solo NVIDIA ejecuta `--apply`; AMD/Intel/VM no necesitan cambios
(power-profiles-daemon ya viene habilitado por `services.conf`).

## Límites

Hardware NVIDIA real pendiente de prueba (solo host híbrido + dry-run);
la VM live usa virtio (sin driver propietario que validar).
