# iso/ — instalador NimbusOS Plasma (netinstall, F2-T06)

Netinstall primero (R-ISO; ISO Full tras 2 semanas verde): perfil
pinneado CachyOS/archiso (`profile/`) + branding y módulos Calamares
(`calamares/`). Sin AUR no fijado, sin `latest` (R-CACHYOS).

- **Qué va:** `profile/profiledef.sh`, `profile/packages.x86_64`,
  `profile/pacman.conf`, `calamares/branding.desc`,
  `calamares/settings.conf`, módulos Calamares.
- **Qué no:** código de sesión Plasma (va en `dotfiles/`/`packages/`);
  nada que exija ISO se hace en este repo salvo el perfil (ver AGENTS.md §5).

## Requisitos

- `mkarchiso` (paquete `archiso`) instalado, sesión con privilegios root
  para el build, host Arch/CachyOS x86_64.
- KVM disponible para la verificación de arranque (`qemu-system-x86`).

## Build (netinstall)

```sh
sudo mkarchiso -v -w /tmp/nimbus-work -o out iso/profile
```

- `-w` directorio de trabajo temporal, `-o` salida de la ISO.
- Reproducibilidad: fijar `SOURCE_DATE_EPOCH` antes del build; `iso_version`
  en `profiledef.sh` deriva de ella.

## Netinstall vs Full

- **Netinstall (este perfil):** ISO ligera con Plasma 6 + Calamares; los
  paquetes se descargan durante la instalación. Sin NVIDIA (se instala
  post-detección, F2-T10) y sin AUR no fijado (klassy aparte, R-KLASSY).
- **Full (F12):** ISO offline con todo incluido + perfil NVIDIA.
  No construir hasta 2 semanas de netinstall verde.

## Verificación

1. Registrar el hash: `sha256sum out/*.iso | tee out/SHA256SUMS`.
2. Boot en VM KVM con la ISO y comprobar que arranca el live Plasma +
   Calamares (aceptación F2-T06: ISO booteable con hash registrado).
3. Instalación completa con Calamares = F2-T07; VM limpia → primer boot
   Plasma = F2-T08.

## Limitaciones conocidas

- El pin del snapshot CachyOS (`<SNAPSHOT>` en `profile/pacman.conf`)
  se congela en F2-T01 tras validar en VM; hasta entonces el build usa
  el snapshot que se fije manualmente (R-CACHYOS).
- `klassy` (AUR) y `plasma-login-manager` (spike F8) no van en la ISO:
  la ISO usa SDDM (ruling D1 en `docs/plans/research/F2-decisions.md`).
- BIOS (`bios.syslinux`) + UEFI (`uefi.systemd-boot`) según
  `profiledef.sh` (archiso ≥v86, bootmodes unificados).
