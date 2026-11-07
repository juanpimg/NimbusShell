# Mapa de repositorios y carpetas

## NimbusShell — capa de escritorio

| Ruta | Responsabilidad |
|---|---|
| `dotfiles/` | **Fuente de verdad** de la configuración del escritorio (Plasma, KWin, Aurorae, barra, atajos, autostart). |
| `packages/plasma.list` | Paquetes oficiales del perfil Plasma. |
| `packages/shell/nimbus-bar/` | Barra superior C++/QML. |
| `packages/dock/` | Preset y launchers del Dock Krema. |
| `packages/kcm/kcm_nimbus/` | Módulo de Ajustes Nimbus. |
| `packages/themes/` | Tema Tahoe, Aurorae, SDDM, lock, notificaciones, sonidos. |
| `apps/` | Apps propias (Spotlight, Apps, Mission Control, Welcome, About, Clock, Help, HW, Migrate, Backup, Bug Report, Wallpaper). |
| `scripts/build-components` | Compila e instala GUI + KCM en un prefijo de usuario. |
| `scripts/nimbus-skel-sync` | Port aditivo de `dotfiles/` al skel de NimbusOS. |
| `scripts/ci.sh` | Gate local (lint, tests, ledger, packaging). |
| `tests/` | Pruebas unitarias, integración, a11y, aceptación, build, deploy y skel. |
| `docs/architecture/` | Modelo de producto, mapa y ramas. |
| `docs/plans/evidence/` | Evidencia real por fase. |
| `legacy/hyprland/` | Perfil Hyprland/MacShell **congelado**; no se mantiene. |
| `iso/` | Perfil archiso de NimbusOS que consume esta capa (compatibilidad/build). |

## NimbusOS — sistema instalable

| Ruta | Responsabilidad |
|---|---|
| `build_iso.sh` | Build reproducible de la ISO. Perfil `plasma` (nuevo) y `legacy-hypr` (estable). |
| `packages.nimbus-plasma.append` | Paquetes del sistema + escritorio Plasma (nuevo). |
| `packages.nimbus.x86_64.append` | Paquetes del perfil Hyprland (legacy estable). |
| `nimbus-overlay-plasma/` | Delta Plasma: SDDM, Calamares, barra, skel y tema. |
| `nimbus-overlay/` | Overlay base histórico (live, Calamares, systemd, theming). |
| `iso.manifest` | Pins reproducibles (upstream CachyOS, NimbusShell, AUR). |
| `docs/architecture/` | Modelo de producto y mapa (espejo del de NimbusShell). |
| `docs/MIGRACION-PLASMA.md` | Checklist y estado del corte Hyprland → Plasma. |
| `scripts/verify-*.sh` | Suites de verificación por área. |

## Frontera en una frase

NimbusOS pone la casa y los cimientos; NimbusShell pone el interior. El interior
se diseña una vez en NimbusShell y NimbusOS lo instala sin copiarlo a mano.
