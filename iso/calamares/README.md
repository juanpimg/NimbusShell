# iso/calamares — branding y módulos (F2-T07)

Calamares para la ISO netinstall (`iso/profile/`). Orden unificado F2/F9
(Ruling D2 en `docs/plans/research/F2-decisions.md`).

## Orden (`settings.conf`)

- **show:** welcome → locale → keyboard → partition → users →
  netinstall@nimbus → summary → finished.
- **exec:** partition → mount → unpackfs → machineid → fstab → locale →
  keyboard → localecfg → users → displaymanager → networkcfg → hwclock →
  grub → packages → netinstall@nimbus → services → shellprocess@nimbus →
  umount.
- `finished` va en **show** (canónico upstream), no en exec.
- `removeuser` comentado: **solo OEM** (`dont-chroot`); no descomentar
  en netinstall.

## Build / install en VM (PENDIENTE)

1. Construir la ISO: `sudo mkarchiso -v -w /tmp/nimbus-work -o out iso/profile`
   (requiere root + `archiso`; **no ejecutar `calamares` ni `mkarchiso`
   en el host de desarrollo**).
2. Boot de la ISO en VM KVM y lanzamiento de Calamares en el live Plasma.
3. Instalación completa guiada (aceptación F2-T07) + primer boot
   (F2-T08: <20 min, 0 errores críticos en `journalctl -p 3 -b`).
4. Estado: **PENDIENTE de VM** — sin captura no hay "listo".

## netinstall vs Full

- **netinstall (este perfil):** ISO ligera; `packages.conf`
  (`install`/`try_install`) descarga la lista Plasma durante la
  instalación; `netinstall@nimbus` ofrece el grupo `plasma` opcional;
  `remove` elimina paquetes solo-live (calamares, archiso).
  Sin NVIDIA (post-detección, F2-T10) y sin AUR no fijado (R-KLASSY).
- **Full (F12):** ISO offline con todo incluido + perfil NVIDIA.
  Requiere lista cerrada en `packages.conf` (sin netinstall).

## Notas

- `branding.desc`: NimbusOS 2026.11.01, colores Nimbus, `bootLoader: grub`,
  `slideshow` opcional (`slideshow/slideshow.qml`, aún no incluido).
  Imágenes `images/nimbus-*`: **placeholders propios pendientes (F8)**;
  ningún activo Apple (R-APPLE).
- `partition.conf`: LUKS2 opcional/recomendado + btrfs con subvolúmenes
  para snapper. `displaymanager.conf`: SDDM (Ruling D1).
  `shellprocess@nimbus`: ejecuta `/usr/local/bin/nimbus-installed-setup`
  (script pendiente, F2-T08).
- Sin secretos ni rutas de usuario hardcodeadas en ningún `.conf`.
