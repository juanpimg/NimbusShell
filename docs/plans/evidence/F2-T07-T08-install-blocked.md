# F2-T07 / F2-T08 — Instalación Calamares (BLOQUEADA al 2026-11-01 01:50)

## Estado

- Calamares Nimbus **abre** con branding/páginas propias: Welcome, Location, Keyboard, Partitions, Users, Package selection, Summary, Finish.
- Partición "Erase disk" seleccionable; plan 300 MiB EFI + 29,71 GiB btrfs (sin swap).
- Usuario `nimbus`, hostname `nimbusos`; Summary correcto.
- **`exec` nunca arranca**: al pulsar Next/Install se pasa a Finish ("All done") sin jobs. El disco `/dev/vda` conserva las particiones previas (4G/26G); no hay sistema instalado.
- Log `/root/.cache/calamares/session.log`: no hay `Starting job` para las sesiones de 20:08+ (solo la vieja de 00:10, en modo emergencia); no hay error de módulo.

## Fixes probados (sin éxito)

1. Ids únicos de instancias (`nimbus-netinstall`, `nimbus-shellprocess`) — commit `e9c518e`.
2. `prompt-install: false` en vivo.
3. `shellprocess` con `/bin/bash ...` (permiso).
4. Boost 1.91 inyectado (48 libs) para que Calamares arranque.
5. Branding en `/usr/share/calamares/branding/nimbus` + wrapper.
6. `initialPartitioningChoice: erase` / `initialSwapChoice: none`.
7. Copiar `/usr/share/calamares/settings.conf` (CachyOS) como `/etc/calamares/settings.conf`; su nav tiene pestaña Install explícita, pero tampoco ejecuta jobs.
8. Escala 0.8 para ver botones; panel oculto; clics VNC (`vncdotool`) verificados.

## Sospechas abiertas

- Calamares 3.4.2 (cachyos) y `sequence.exec` de nuestro `settings.conf`: el show funciona, exec no; pendiente `calamares -d` con traza de `Settings`/`ViewManager` y comparación con un `settings.conf` mínimo oficial.
- Posible incompatibilidad del módulo `partition` de CachyOS con el esquema de config Nimbus, o el estado de emergencia persistido en `/root/.cache/calamares` (se borró y no cambió).
- El test se hizo en live con root y sin sesión de usuario normal; un Calamares de ISO real (autologin liveuser) puede comportarse distinto.

## Evidencia

- `spikes/f2-install/05-finish-sin-instalar.png` (Finish sin instalación).
- `spikes/f2-install/06-error-update-mirrorlist.png` (primer fallo CachyOS).
- `spikes/f2-install/03-users.png`, `04-summary.png`.

## Veredicto

- **F2-T07: `[ ]`** — instalación completa no lograda.
- **F2-T08: `[ ]`** — sin primer boot ni métricas; el disco target no se modificó.
- Próximo paso: debug dedicado de `sequence.exec`/Calamares 3.4.2 o instalar con `archinstall`/pacstrap en la VM para desbloquear F2-T08, documentando R-CALAMARES-RUNTIME.
