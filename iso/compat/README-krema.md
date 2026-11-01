# Krema 0.12.0 (F5) — paquete local pinneado

Compilado en la VM de build (CachyOS live, Plasma 6.8.2, Qt 6.12) desde el
tarball upstream `v0.12.0` con `packaging/krema/PKGBUILD` (GPL-3.0-or-later
+ MIT-CMU, licencias incluidas en el paquete).

La ISO lo instala con `nimbus-installed-setup` (pacman -U, sin AUR) y el
Dock arranca por autostart con `packages/dock/kremarc-nimbus` (tema Nimbus
pinneado). Recompilar si cambia el SONAME de Plasma/Qt del target.
