# Liquid Glass — investigación y arquitectura (2026-11-02)

## Qué es (Apple Tahoe)

Liquid Glass no es “un gradiente semitransparente”. Capas observadas en la
referencia y en implementaciones:

1. **Fondo real** detrás del control (contenido/ventana/wallpaper).
2. **Blur** del fondo (radio amplio, no uniforme).
3. **Refracción/lensing** del fondo en el borde (perfil convexo, Snell).
4. **Dispersión** sutil por canal (fringing RGB).
5. **Tinte adaptativo** según luminancia/color del fondo.
6. **Rim light / specular** en bordes y esquinas.
7. **Sombra** exterior y separación de capas.
8. **Animación** elástica y respuesta al puntero.

## Proyectos open source evaluados

| Proyecto | Qué aporta | Estado |
| --- | --- | --- |
| [4v3ngR/kwin-effects-glass](https://github.com/4v3ngR/kwin-effects-glass) | Efecto KWin GPL con blur, refracción Snell, rim/glow, force blur; shaders `glass.glsl`, `snells-glass.glsl`, `rim.glsl`; soporta KWin ≥6.4 y tiene rama `GLASS_KWIN_68` | **Mejor base Linux**. Requiere empaquetar/compilar contra KWin 6.8 |
| [taj-ny/kwin-effects-forceblur](https://github.com/taj-ny/kwin-effects-forceblur) | Blur forzado, esquinas, refracción; GPL-3.0 | Archivado; origen de Glass |
| [slynobody/kwin-effects-better-blur-dx-plus](https://github.com/slynobody/kwin-effects-better-blur-dx-plus) | “liquid look”, lens refraction, precompilados Debian/Arch | GPL-3.0; versiones atadas a Plasma 6.7.4/Qt 6.11 |
| [fsalinas26/qt-liquid-glass](https://github.com/fsalinas26/qt-liquid-glass) | `NSGlassEffectView` nativo macOS | **No usable en Linux** |
| CSS/WebGL liquid-glass | Shaders de refracción/displacement para web | Referencia de fórmulas, no integrable directo |

## Arquitectura propuesta para NimbusShell

**No reimplementar el blur en QML.** El compositor ya tiene el fondo real.

1. **Backend de compositor**: empaquetar/vendorizar `kwin-effects-glass`
   (GPL, atribución) compilado para KWin 6.8; activarlo y desactivar el blur
   stock/translucency. Force blur por clases:
   `nimbus-bar`, `nimbus-menu`, `nimbus-cc`, `nimbus-notification`,
   `nimbus-spotlight`, `nimbus-mc`, `krema`.
2. **QML transparente**: las superficies (`Bar.qml`, `Menu.qml`,
   `ControlCenter.qml`, notificaciones) dejan de pintar fondos opacos; usan
   `GlassSurface` con:
   - relleno/tinte adaptativo,
   - rim/specular y sombra,
   - ruido sutil,
   - animación de entrada,
   - fallback `MultiEffect` (blur+shadow) si el efecto KWin no está.
3. **Control Center Tahoe**: rediseño por módulos tipo cápsula, no la rejilla
   actual de 4 cuadrados:
   - conectividad (Wi‑Fi/BT/AirDrop o No molestar) en grupo 2x2,
   - foco,
   - pantalla/brillo,
   - sonido,
   - batería/estado,
   - “Ahora suena” si hay datos.
   Cada módulo es una cápsula grande con icono a la izquierda y estado
   principal/secundario; radios ~28-32 px; tipografía 13/11; 2 columnas.
4. **Orden de implantación** (una cosa por vez, con captura antes/después):
   1. GlassSurface + barra superior.
   2. Menú N.
   3. Control Center.
   4. Notificaciones.
   5. Dock.

## Riesgos

- `kwin-effects-glass` es un plugin binario: hay que compilarlo para KWin 6.8
  en la ISO y mantenerlo al actualizar; si KWin cambia, se rompe.
- GPL: incluir LICENSE, fuente y atribución; no copiar activos Apple.
- Coste GPU del blur/refracción en VM/llvmpipe; medir fps.
- El blur solo se ve si la superficie es transparente y declara/forzar blur.
- No usar el efecto Translucency de KWin (rompe el pipeline).

## Evidencia actual

- `docs/plans/evidence/matrix-out12/09-bar-control-center.png` (CC actual:
  300x500, 4 tiles, sliders; no Tahoe).
- `docs/plans/evidence/F3-T12-out15-both.png` (barra actual).
- Referencia Tahoe estudiada: captura pública de Six Colors
  (`tahoe-control-center-6c.png`, no se commiteará por ser material ajeno).

## Siguiente paso

Spike controlado: compilar Glass para KWin 6.8 en la VM de build, activarlo
en una sesión de prueba y capturar barra/menú/CC antes/después. Si el efecto
no es estable, Ruling y fallback `MultiEffect` (sin llamarlo Liquid Glass).
