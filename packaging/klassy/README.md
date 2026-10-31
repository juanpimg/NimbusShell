# klassy-nimbus — paquete Klassy pinneado (F4-T09)

Decoración KWin estilo macOS Tahoe: Klassy **6.7.3 pinneado** + parche
`+` de maximizar + preset `nimbus-tahoe.klpw`. Sin activos Apple
(R-APPLE: colores y métricas propios, sin logos/fuentes/wallpapers ajenos).

## Pin

- Upstream: `paulmcauley/klassy`, tag **`v6.7.3`** (con `v`; `6.7.3` sin
  prefijo da 404).
- Tarball: `https://github.com/paulmcauley/klassy/archive/refs/tags/v6.7.3.tar.gz`
- sha256: `a3e9b96723cda1b3c46d6f456d495e5e34d051940e6f71aa9a345e8fb850e1fb`
  (verificado contra el árbol de build del host `/tmp/klassy-src`: `diff`
  limpio en `libbreezecommon`; `PROJECT_VERSION "6.7.3"` en `CMakeLists.txt`).
- El `PKGBUILD` copia el parche y el preset desde este directorio
  (`klassy-hover-plus.patch`, `nimbus-tahoe.klpw` son copias de
  `packages/kwin/decoration/nimbus-decoration/` y
  `packages/themes/klassy-preset/`). Si cambias el original, recopia
  y actualiza el `sha256sums` del parche si se usa suma fija (hoy `SKIP`
  porque son ficheros locales versionados en el repo).
- Licencia: `GPL-2.0-or-later` (árbol upstream `LICENSES/`).

## Por qué no el AUR stock

`klassy-bin`/`klassy-git` siguen `latest`/master sin pin reproducible,
sin el parche Nimbus (`+` macOS en maximizar, Ruling documentada en el
parche) y sin el preset Tahoe. Este paquete fija los tres juntos para
que la ISO y la VM instalen exactamente lo verificado.

## Construir e instalar

```bash
scripts/install-klassy-nimbus            # construye en /tmp e instala
scripts/install-klassy-nimbus --check    # solo verifica (sin compilar)
```

Nota host: si `extra-cmake-modules` no está instalado como paquete del
sistema, el `build()` falla en `find_package(ECM)`; NO instalar nada en
el host — para validar basta
`CMAKE_PREFIX_PATH=/tmp/ecm-prefix makepkg -f --nodeps` (el tarball pin
sigue verificándose por sha256). En VM/ISO los `makedepends` cubren ECM.

Tras instalar, reinicia KWin (`qdbus6 org.kde.KWin /KWin reconfigure`
o re-login) y aplica el preset:

```bash
klassy-settings -i /usr/share/klassy-nimbus/nimbus-tahoe.klpw
klassy-settings -w NimbusTahoe
```

## Upgrade / rebuild por Plasma

Cada salto mayor de Plasma/Qt6 (p. ej. 6.x → 6.y) exige reconstruir:
sube `pkgrel` (+1) sin tocar `pkgver` y recompila con
`scripts/install-klassy-nimbus`. Si upstream publica un 6.7.x con fixes,
actualiza `pkgver`, el `source` y el `sha256sums`, re-verifica el parche
(`patch -p1 --dry-run`) y el preset (se re-importa con `-i/-w`).

## Rollback

- `pacman -U /var/cache/pacman/pkg/klassy-nimbus-<anterior>-x86_64.pkg.tar.zst`
  (guarda el `.pkg.tar.zst` previo antes de actualizar).
- O desinstala y vuelve al KWin stock: `pacman -R klassy-nimbus`
  (la decoración vuelve a Breeze; el preset queda sin efecto).
