# Glass (KWin effect) — integración NimbusOS

Efecto de compositor que añade **blur + refracción** al vidrio de NimbusShell.
Es la capa que convierte el blur stock en Liquid Glass real.

- Upstream: https://github.com/4v3ngR/kwin-effects-glass
- Pin: commit `1edd1cdb382dacf0c8b9cb4bd28011c8de95eb58` (2026-10-30),
  compila contra KWin 6.8.2 (`GLASS_KWIN_68`).
- Licencia: **GPL-3.0-or-later**. Al distribuir la ISO hay que incluir
  `LICENSE`, la fuente del commit pinneado y atribución en la documentación
  legal de NimbusOS.
- Se compila en la VM/ISO; no se instala desde AUR en el equipo final.

## Build/instalación

`PKGBUILD` en este directorio. El árbol fuente debe estar como
`kwin-effects-glass-1edd1cd.tar.gz` (o ajustar `source` al tarball del ISO).
Instala:

- `/usr/lib/qt6/plugins/kwin/effects/plugins/glass.so`
- `/usr/lib/qt6/plugins/kwin/effects/configs/kwin_glass_config.so`

## Activar (kwinrc)

Sustituir el blur stock; no usar ambos a la vez:

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

`[Effect-blurplus]` es el grupo legado del fork (no `[Effect-glass]`).
Para el Dock (cuando Krema exponga superficie translúcida):
`BlurDocks=true`, `DockBlurStrength=6`, `DockCornerRadius=14`.

Aplicar sin reiniciar sesión:

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect glass
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass
```

## Verificación

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded glass   # true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadedEffects | tr ',' '\n' | grep -x glass
```

Captura obligatoria sobre **damero de alto contraste**: el borde de las
cápsulas debe curvar el fondo (refracción), no solo promediarlo. Evidencia del
spike: `docs/plans/evidence/F11-T02-glass-spike.md`.

## Límites conocidos (no cerrar F11-T02)

- El rim/glow se dibuja en el **borde de la ventana layer-shell**, no por
  cápsula QML; con `Rim*/EdgeLighting=false` queda sutil. Refracción por
  cápsula exigiría una ventana por cápsula.
- Menú/calendario/OSD/notificaciones aún no tienen Glass (allowlist actual de
  `nimbus-bar`: barra + CC). El menú tiene además un problema de scrim/
  LayerOverlay que oscurece la pantalla; se arregla antes de activarlo.
- El Dock (Krema) sigue opaco: hay que hacer que su superficie sea translúcida
  y pedir blur, o forzar `BlurDocks` cuando exponga alpha.
- Falta **Reduce Transparency** (fallback opaco legible) y medir fps en
  llvmpipe/GPU.
- KWin valida la API del efecto: **recompilar Glass en cada upgrade de kwin**.
