# nimbus-decoration — semáforos Tahoe sobre Klassy stock (sin parche C++)

Resultado F3-T02/F4-T01: **no hace falta parchear ni recompilar Klassy**.
Todo el contrato estático se alcanza con el preset
`packages/themes/klassy-preset/nimbus-tahoe.klpw` (= `Klassy.klpw` 6.7.3 +
deltas documentados en su cabecera) aplicado por el canal real
(`klassy-settings -i/-w`, no claves sueltas). Ver evidencia en
`docs/plans/evidence/F3-T02-klassy-patch.md`.

## Por qué no hay `klassy-12px.patch`

Auditado el código 6.7.3, ningún cambio C++ es necesario para los estados
estáticos (ver evidencia); cada gap tenía causa configurable. El único
parche C++ es `klassy-hover-plus.patch` (§ Hover +).

- Ø20→12: `IconSize=IconVerySmall` (base 14 / fondo 12 en
  `kdecoration/breezedecoration.cpp:calculateIconSizes`, sin tocar código).
- Overrides `#hex` ignorados: `ButtonOverrideColors*` NO son colores, son
  blobs JSON (`{"BackgroundNormal":[r,g,b],...}`); los parsea
  `libbreezecommon/decorationbuttoncolors.cpp:decodeButtonOverrideColors`.
  Un `#FF5F57` falla en `QJsonDocument::fromJson` y se ignora en silencio.
- Gris inactivo: mismo mecanismo con los tres estados a `[142,142,147]`.
- Gap: `ButtonSizing/ButtonSpacing*` sí aplica (verificado por
  `/KWin reconfigure` en nested); el "ignorado" anterior era el preset
  bundled pisando claves sueltas al primer arranque.
- Titlebar 26: sale solo de `max(fm.height, padded 14) + 3.6 + 3.6`.

Límites duros (requieren plugin propio, R-DECO): hover `+` en maximizar
(ningún `style*` lo dibuja; `stylematerialdynamic.cpp:renderMaximizeIcon`
pinta □) y hover físico no inyectable en nested. No se inventa parche.

## Hover + (`klassy-hover-plus.patch`)

Parche mínimo (3 ficheros, +48/−1): `renderPlusMaximizeIcon()` nuevo en
`RenderDecorationButtonIcon18By18` (cruz inscrita en el mismo
`maximizeRect` y `maximizePenWidth` que ×/−, con su snap par/impar,
opacidad y rama `m_strokeToFilledPath`) y `renderMaximizeIcon()` de
MaterialDynamic llamándolo en vez de `renderSquareMaximizeIcon`.
Verificado en nested con el build de `/tmp/klassy-nimbus-prefix` y glifos
forzados siempre visibles: `+` de 8×9 px, mismo box/stroke que ×/−
(`spikes/nested/f3-klassy-plus.png`). El preset shippeado mantiene los
glifos solo en hover (macOS); el hover físico sigue sin verificador.

## Aplicar el preset (canal real)

```bash
klassy-settings -i packages/themes/klassy-preset/nimbus-tahoe.klpw
klassy-settings -w Klassy   # escribe klassy/klassyrc por grupos + kwinrc
qdbus6 org.kde.KWin /KWin reconfigure
```

`-i` sin `-w` solo guarda en `klassy/windecopresetsrc` (no aplica).
Claves sueltas con `kwriteconfig6` en `klassy/klassyrc` las pisa el import
del preset bundled en el primer arranque: no usar.

## Construir Klassy 6.7.3 (pin, solo si hay que recompilar)

```bash
cp -a /tmp/klassy-src /tmp/klassy-nimbus-src   # nunca tocar el original
cmake -S /tmp/klassy-nimbus-src -B /tmp/klassy-nimbus-build \
  -DBUILD_QT5=OFF -DBUILD_QT6=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=/tmp/ecm-prefix \
  -DCMAKE_INSTALL_PREFIX=/tmp/klassy-nimbus-prefix
cmake --build /tmp/klassy-nimbus-build -j"$(nproc)"
cmake --install /tmp/klassy-nimbus-build
```

Uso en nested: el harness `tests/vm/nested-plasma.sh --klassy` expone
`/tmp/klassy-prefix` (build 6.7.3 stock de las mismas fuentes; al no haber
parche, es binariamente equivalente). La receta de arriba con
`/tmp/klassy-nimbus-prefix` es para reconstrucción independiente.

Pin: `PROJECT_VERSION "6.7.3"` en `CMakeLists.txt`; Plasma 6 host
(Qt 6.12, KF6 sistema, ECM en `/tmp/ecm-prefix`).
