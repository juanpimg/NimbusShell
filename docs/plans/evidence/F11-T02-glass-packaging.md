# F11-T02 — Empaquetado de Glass (`kwin-effects-glass`) (2026-11-02)

## Estado: AVANZADO / EMPAQUETADO LISTO

## Implementación

1. **`packaging/glass/PKGBUILD`**:
   - Pin commit `1edd1cdb382dacf0c8b9cb4bd28011c8de95eb58` (GPL-3.0-or-later).
   - Configurada la URL directa de descarga de tarball de GitHub:
     `source=("$pkgname-$pkgver.tar.gz::$url/archive/1edd1cdb382dacf0c8b9cb4bd28011c8de95eb58.tar.gz")`.
   - Soporte para extracción y compilación limpia con Ninja y CMake en prefijo `/usr`.

2. **`scripts/install-glass-nimbus`**:
   - Script helper similar a `scripts/install-klassy-nimbus`.
   - Soporta `--check` (solo lectura, valida sintaxis y dependencias), `--no-install` (construye paquete en `/tmp/glass-nimbus-pkg` con `makepkg` sin requerir sudo) e instalación real con `pacman -U`.
   - Integrado en `scripts/ci.sh` con validación estricta de `bash -n` y `shellcheck -S warning`.

## Verificación

- `scripts/install-glass-nimbus --check` → `[OK] check: PKGBUILD presente, makepkg disponible.`
- `makepkg --printsrcinfo packaging/glass/PKGBUILD` → PASS.
