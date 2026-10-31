# iso/ — instalador NimbusOS Plasma (netinstall, F2-T06 + integración F2-ISO)

Netinstall primero (R-ISO; ISO Full tras 2 semanas verde): perfil
pinneado CachyOS/archiso (`profile/`) + branding y módulos Calamares
(`calamares/`) + script de staging (`build-iso.sh`). Sin AUR no fijado,
sin `latest` (R-CACHYOS).

- **Qué va:** `profile/profiledef.sh`, `profile/packages.x86_64`,
  `profile/pacman.conf`, `profile/airootfs/` (SDDM + `nimbus-installed-setup`),
  `calamares/branding.desc`, `calamares/settings.conf`, módulos Calamares,
  `build-iso.sh` (estagia dotfiles/scripts/temas/apps al perfil).
- **Qué no:** código de sesión Plasma (va en `dotfiles/`/`packages/`);
  nada que exija ISO se hace en este repo salvo el perfil (ver AGENTS.md §5).

## Requisitos

- Build real **solo en VM** (agente posterior): `mkarchiso` (paquete
  `archiso`), root, host Arch/CachyOS x86_64. **PROHIBIDO `mkarchiso`,
  `pacman -S`, `sudo` o builds de ISO en el host de desarrollo.**
- En el host solo: autoría, staging en `/tmp` y validación estática
  (`bash -n`, `shellcheck`, `build-iso.sh --check` / `--stage-only`).
- KVM disponible para la verificación de arranque (`qemu-system-x86`).
- Deps de build de apps (solo VM): `cmake`, `ninja`, `qt6-base`,
  `qt6-declarative`, `kf6-krunner` (paquete `krunner`), `layer-shell-qt`.

## Build (netinstall, en VM)

Orden obligatorio:

```sh
iso/build-iso.sh --check                              # 1. solo lectura, exit 0
iso/build-iso.sh --stage-only --out /tmp/nimbus-stage # 2. staging + verificación
sudo iso/build-iso.sh --out out                       # 3. staging + mkarchiso (root, VM)
sha256sum out/*.iso | tee out/SHA256SUMS              # 4. hash registrado
```

- `--skip-apps` omite compilar nimbus-bar/apps/spotlight (documentar el
  SKIP en la evidencia; el live no los traerá).
- Reproducibilidad: fijar `SOURCE_DATE_EPOCH` antes del build; `iso_version`
  en `profiledef.sh` deriva de ella.
- El staging copia `iso/profile` a temporal y superpone: `iso/calamares/*`
  → `airootfs/etc/calamares/`; `dotfiles/` (solo `.config`/`.icons`) →
  `airootfs/etc/skel/`; `scripts/{nimbus-theme,nimbus-privacy,
  nimbus-flatpak-perms,apply-theme}` → `airootfs/usr/local/bin/`; temas →
  `/usr/share/nimbus|/usr/share/sddm/themes/nimbus`; KWin scripts →
  `/usr/share/kwin/scripts/`; apps compiladas con `DESTDIR` a `/usr/local`.

## nimbus-installed-setup

`profile/airootfs/usr/local/bin/nimbus-installed-setup` (bash, `set -u`,
chroot como root, lo invoca `shellprocess@nimbus`): aplica skel al usuario
(solo añade lo que falte), SDDM `Current=nimbus`, preset Klassy
(`klassy-settings -i/-w` si existe), KWin scripts (`kpackagetool6` o copia),
telemetría off, `firewalld` enable, verifica locale/keyboard, limpia cachés.
Idempotente, log en `/var/log/nimbus-installed-setup.log`. No instala
paquetes (los pone Calamares) y no toca datos del usuario final.

## Parche klassy-hover-plus

`packages/kwin/decoration/nimbus-decoration/klassy-hover-plus.patch`
(Ruling: `+` macOS en maximizar). El AUR no lo trae: el paquete
`klassy` pinneado (F2-T01, R-KLASSY) debe aplicarlo en `build()` con
`patch -p1 < klassy-hover-plus.patch`; el staging lo deja en
`/usr/share/nimbus/klassy/` como referencia. Sin el parche, la ISO usa la
deco Breeze de fallback (degradación documentada, no fallo).

## Netinstall vs Full

- **Netinstall (este perfil):** ISO ligera con Plasma 6 + Calamares; los
  paquetes se descargan durante la instalación. Sin NVIDIA (se instala
  post-detección, F2-T10) y sin AUR no fijado (klassy aparte, R-KLASSY).
- **Full (F12):** ISO offline con todo incluido + perfil NVIDIA.
  No construir hasta 2 semanas de netinstall verde.

## Verificación

1. `bash -n` + `shellcheck -S warning` cero en `build-iso.sh` y
   `nimbus-installed-setup`.
2. `iso/build-iso.sh --check` (solo lectura) exit 0.
3. `iso/build-iso.sh --stage-only --out /tmp/nimbus-stage`: árbol verificado
   (calamares, skel, scripts, temas, binarios si se compilaron).
4. `find` del staging sin activos Apple (R-APPLE).
5. Registrar el hash: `sha256sum out/*.iso | tee out/SHA256SUMS`.
6. Boot en VM KVM con la ISO y comprobar que arranca el live Plasma +
   Calamares (aceptación F2-T06: ISO booteable con hash registrado).
7. Instalación completa con Calamares = F2-T07; VM limpia → primer boot
   Plasma = F2-T08.

## Dependencias y rollback

- Dependencias: snapshot CachyOS fijado en `profile/pacman.conf` (pin F2-T01);
  `packages.x86_64` documenta qué es runtime (`qt6-declarative`,
  `kdecoration`) y qué queda fuera (`klassy` AUR, `qt6-tools` solo build).
- Rollback: el staging es temporal (`--out` se limpia al re-ejecutar,
  idempotente); no toca `iso/profile` (solo lo lee). Si el build falla,
  borrar `/tmp/nimbus-stage`, `/tmp/nimbus-work` y `out/`; ningún cambio
  persiste en el repo.

## Limitaciones conocidas

- El pin del snapshot CachyOS (`<SNAPSHOT>` en `profile/pacman.conf`)
  se congela en F2-T01 tras validar en VM; hasta entonces el build usa
  el snapshot que se fije manualmente (R-CACHYOS).
- `klassy` (AUR) y `plasma-login-manager` (spike F8) no van en la ISO:
  la ISO usa SDDM (ruling D1 en `docs/plans/research/F2-decisions.md`).
- BIOS (`bios.syslinux`) + UEFI (`uefi.systemd-boot`) según
  `profiledef.sh` (archiso ≥v86, bootmodes unificados).
