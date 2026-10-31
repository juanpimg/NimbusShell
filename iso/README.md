# iso/ — instalador NimbusOS Plasma

Netinstall primero (R-ISO; ISO Full tras 2 semanas verde): perfil
pinneado CachyOS/archiso (`profile/`) + branding y módulos Calamares
(`calamares/`). Sin AUR no fijado, sin `latest` (R-CACHYOS).

- **Qué va:** `profiledef.sh`, `packages.x86_64`, `pacman.conf`,
  `branding.desc`, `settings.conf`, módulos Calamares.
- **Qué no:** código de sesión Plasma (va en `dotfiles/`/`packages/`);
  nada que exija ISO se hace en este repo salvo el perfil (ver AGENTS.md §5).
