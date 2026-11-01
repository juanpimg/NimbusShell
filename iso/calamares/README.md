# iso/calamares — branding y módulos (F2-T07)

Calamares para la ISO netinstall (`iso/profile/`). Orden unificado F2/F9
(Ruling D2 en `docs/plans/research/F2-decisions.md`).

## Orden (`settings.conf`)

- **show:** welcome → locale → keyboard → partition → users →
  netinstall@nimbus → summary → exec → finished (segundo show).
- **exec:** partition → mount → unpackfs → machineid → fstab → locale →
  keyboard → localecfg → users → displaymanager → networkcfg → hwclock →
  grub → packages → netinstall@nimbus → services → shellprocess@nimbus →
  umount.
- `finished` va en un **segundo show** DESPUÉS de exec; si va en el primero, Calamares omite todos los jobs (causa raíz 2026-11-01).
- `removeuser` comentado: **solo OEM** (`dont-chroot`); no descomentar
  en netinstall.

## Build / install en VM (PENDIENTE)

1. Copiar la config Calamares al overlay del perfil (el live la espera
   en `/etc/calamares/`; `groupsUrl` apunta a
   `file:///etc/calamares/groups-nimbus.json`):
   `mkdir -p iso/profile/airootfs/etc && cp -r iso/calamares iso/profile/airootfs/etc/`
   (**PENDIENTE**: hacerlo al preparar el build en VM, F2-T08; no existe
   `airootfs/` aún para no adelantar el build).
2. Construir la ISO: `sudo mkarchiso -v -w /tmp/nimbus-work -o out iso/profile`
   (requiere root + `archiso`; **no ejecutar `calamares` ni `mkarchiso`
   en el host de desarrollo**).
2. Boot de la ISO en VM KVM y lanzamiento de Calamares en el live Plasma.
3. Instalación completa guiada (aceptación F2-T07) + primer boot
   (F2-T08: <20 min, 0 errores críticos en `journalctl -p 3 -b`).
4. Estado: **PENDIENTE de VM** — sin captura no hay "listo".

## netinstall vs Full

- **netinstall (este perfil):** ISO ligera; `packages.conf`
  (`install`/`try_install`) descarga la lista Plasma durante la
  instalación; `netinstall@nimbus` ofrece los grupos de
  `groups-nimbus.json` (`base`, `plasma` requeridos + `dev`, `gaming`,
  `office`, `browser` opcionales); `remove` elimina paquetes solo-live
  (calamares, archiso).
  Sin NVIDIA (post-detección, F2-T10) y sin AUR no fijado (R-KLASSY).
- **No-solape verificado:** ningún paquete de los grupos existe en
  `packages.conf` (`install`/`try_install`); el grupo `plasma` trae solo
  apps extra (gwenview, okular, ark, kate), nunca `plasma-meta`.
- **Full (F12):** ISO offline con todo incluido + perfil NVIDIA.
  Requiere lista cerrada en `packages.conf` (sin netinstall).

## Notas

- `branding.desc`: NimbusOS 2026.11.01, colores Nimbus, `bootLoader: grub`,
  `slideshow` opcional (`slideshow/slideshow.qml`, aún no incluido).
  Imágenes `images/nimbus-*`: **placeholders propios pendientes (F8)**;
  ningún activo Apple (R-APPLE).
- `partition.conf`: LUKS2 opcional/recomendado + btrfs con subvolúmenes
  para snapper (claves documentadas en la cabecera, F2-T09). `services.conf`
  (F2-T09): habilita `firewalld` (zona `public`) en el instalado.
  `displaymanager.conf`: SDDM (Ruling D1).
  `shellprocess@nimbus`: ejecuta `/usr/local/bin/nimbus-installed-setup`
  (script pendiente, F2-T08).
- Sin secretos ni rutas de usuario hardcodeadas en ningún `.conf`.
