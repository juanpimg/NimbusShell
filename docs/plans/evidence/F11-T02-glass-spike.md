# F11-T02 — Spike de Glass (refracción real) en nested, 2026-11-02

## Qué se ha demostrado

`4v3ngR/kwin-effects-glass` (GPL-3.0) compila contra **KWin 6.8.2** y KWin lo
carga en una sesión nested (`loadedEffects` incluye `glass`). Con el efecto
activo, la barra y el CC muestran **blur + refracción** reales: el damero se
curva en los bordes de las cápsulas (perfil tipo Snell) y aparece un rim. No es
un gradiente QML.

Comparación sobre el mismo damero de 16 px:

- `glass-vs-blur.png`: arriba solo blur stock (`KWindowEffects`); abajo Glass
  (blur + refracción + rim). La diferencia en los bordes es evidente.
- `refraction-zoom.png`: zoom 4× del borde superior izquierdo del CC con Glass.
- `cc-glass-checker.png` / `-crop.png`: captura completa del CC con Glass.
- `cc-glass-wallpaper.png` / `-crop.png`: ajuste sutil sobre el wallpaper Nimbus.

## Build (sin tocar el host)

Dependencia de build que faltaba: ECM. Se instala en un prefijo temporal, no
en `/usr`:

```bash
git clone --depth 1 https://invent.kde.org/frameworks/extra-cmake-modules /tmp/ecm-src
cmake -S /tmp/ecm-src -B /tmp/ecm-src/build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/tmp/ecm-prefix -DBUILD_TESTING=OFF
cmake --build /tmp/ecm-src/build && cmake --install /tmp/ecm-src/build

git clone --depth 1 https://github.com/4v3ngR/kwin-effects-glass /tmp/kwin-glass
cmake -S /tmp/kwin-glass -B /tmp/kwin-glass/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/tmp/glass-prefix \
  -DCMAKE_PREFIX_PATH=/tmp/ecm-prefix
cmake --build /tmp/kwin-glass/build -j8
cmake --install /tmp/kwin-glass/build
```

Instala `lib/plugins/kwin/effects/plugins/glass.so` y
`.../configs/kwin_glass_config.so`. El id del efecto es `glass`; el grupo de
configuración es `[Effect-blurplus]`.

## Configuración nested

`tests/vm/nested-bar.sh` acepta ahora `--kwinrc FILE` y
`--plugin-path PREFIX/lib/plugins`. KWin recibe `QT_PLUGIN_PATH` y un kwinrc
temporal:

```ini
[Plugins]
blurEnabled=false
glassEnabled=true
translucencyEnabled=false

[Effect-blurplus]
RefractionStrength=6.0
RefractionEdgeSize=1.5
RefractionRGBFringing=0.5
PhysicallyBasedRefraction=true
RefractionNormalPow=4.0
RimSpecular=false
RimGlow=false
EdgeLighting=false
BlurStrength=6
BlurFinetune=3
```

Comando de la captura sutil:

```bash
bash tests/vm/nested-bar.sh \
  --bin /tmp/barblur2/nimbus-bar \
  --out spikes/glass-subtle --timeout 30 \
  --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-glass-subtle \
  --kwinrc /tmp/opencode/glass-kwinrc-subtle \
  --plugin-path /tmp/glass-prefix/lib/plugins \
  --bar-args "--open-cc"
```

## Hallazgos

- **Funciona en 6.8.2**: `GLASS_KWIN_68` compila; no hizo falta parche.
- El **rim/glow** de Glass se dibuja en el **borde de la ventana layer-shell**,
  no en cada cápsula QML. Con una sola ventana para todo el CC aparece un
  borde exterior blanco que Tahoe no tiene; con `RimSpecular=false`,
  `RimGlow=false` y `EdgeLighting=false` queda un hairline sutil. Para
  refracción por cápsula habría que usar una ventana por cápsula (coste y
  complejidad) o aceptar el panel continuo.
- El **scrim** del CC sigue sin Glass (correcto: no debe emborronar el
  escritorio).
- La barra gana refracción en su borde inferior; el texto sigue legible.
- El Dock (Krema) no está incluido todavía; requiere regla/forzado de Glass.
- Menú/calendario/OSD/notificaciones siguen sin Glass (allowlist actual:
  barra + CC).

## Límites y siguiente paso

- **Empaquetado preparado, no probado en ISO**: `packaging/glass/PKGBUILD`
  (pin `1edd1cd`, GPL-3.0-or-later) y `packaging/glass/README.md` con el
  kwinrc y la verificación. Falta compilarlo en la ISO, instalar en el
  staging, activar `glassEnabled`, desactivar blur stock por defecto y
  verificar en la VM. No se cambió `dotfiles/.config/kwinrc` todavía: hacerlo
  sin el paquete instalado dejaría la barra/CC sin blur.
- Falta **Reduce Transparency** y la medición de fps (llvmpipe/GPU).
- F11-T02 **no se cierra**: falta ISO/VM, menús/Dock/notificaciones y el
  criterio de fps.
