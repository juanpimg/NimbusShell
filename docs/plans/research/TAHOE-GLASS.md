# Research TAHOE-GLASS — Liquid Glass de macOS Tahoe y su implementación en NimbusShell (Plasma/KWin/QML)

> Solo investigación. No cambia código ni dotfiles. Sin activos Apple (R-APPLE): todo con arte propio.
> Alcance: qué es Liquid Glass, parámetros observables, estados, implementación Plasma/KWin/QML,
> medición, riesgos. Tablas con columna de confianza.

## 0. Resumen (<30 líneas)

1. Liquid Glass (Tahoe 26, 2025) es el material dinámico de la capa de controles/navegación,
   no del contenido: refracta y refleja el fondo en tiempo real, con highlights especulares,
   tinte adaptativo y sombras suaves (Apple HIG Materials; WWDC25 s219). Confianza: Alta.
2. Capas del material: blur de fondo + refracción/lente + dispersión cromática leve +
   tint/saturación + highlight de borde + sheen superior + sombra + grano anti-banding.
3. Apple no publica números; los rangos observables vienen de réplicas comunitarias
   (blur 0–26px, saturación ~1.2–1.5, refracción borde >> centro) y de NSVisualEffectView
   semántico (menu/popover/sidebar/headerView/titlebar). Confianza: Media.
4. Diferencias por superficie: barra de menú casi transparente; Dock esmerilado translúcido;
   sidebars/toolbar dejan pasar contenido al hacer scroll; popovers/menús más densos.
5. Estados: active/inactive (menos vibrancy), hover/pressed (iluminación interna),
   Reduce transparency (fondo sólido), Increase contrast (bordes), light/dark (tint invertido).
6. En Nimbus la base ya existe: `liquidglass.frag` + `dockglass.frag` + `GlassSlab.qml`
   (SDF rounded-box → bezel convexo → Snell n≈1.5 → blur disco gaussiano 24 taps con mips).
7. KWin aporta blur/contraste de fondo; QML aporta refracción/tint/specular/grano.
   No intentar refracción real en KWin: su blur es gaussiano sin lente.
8. Tiers: alto = shader completo + blur KWin + grano; bajo = rect frosted opaco
   (`GlassSlab glass:false` + Reduce transparency) sin ShaderEffectSource en vivo.
9. Medir con captura VM + diff contra golden propio (<15%), contraste WCAG AA en texto
   sobre vidrio, fps (objetivo ≥50 en iGPU, sin caídas >10%), y matriz light/dark × fondo.
10. Riesgos: blur a pantalla completa es costoso; refracción QML solo ve su
    ShaderEffectSource (no framebuffer real); ABI KWin/Plasma 6 cambia entre 6.x;
    Kvantum Qt6 blur exige versión reciente; R-APPLE prohíbe copiar radios/colores
    exactos o SF/wallpapers de Apple.

## 1. Qué es Liquid Glass (modelo)

Fuente primaria: Apple HIG "Materials" (rev. 09-09-2025), newsroom 09-06-2025,
WWDC25 s219 "Meet Liquid Glass", PDF "All New Features macOS Tahoe Sept 2025".
Confianza Alta en el modelo cualitativo; Baja en cualquier número atribuido a Apple.

- Un único material dinámico para la capa funcional (tab bars, toolbars, sidebars,
  menús, Dock, widgets, iconos, controles). El contenido hace scroll por debajo
  ("peek through") sin perder legibilidad del control.
- Reglas Apple: no usar en la capa de contenido; usar efectos con moderación;
  variante `regular` por defecto y `clear` solo sobre fondos visualmente ricos;
  en macOS se combina con materiales semánticos `NSVisualEffectView.Material`
  (titlebar, menu, popover, sidebar, headerView, sheet, hudWindow…) y modos
  `behindWindow` / `withinWindow`, más vibrancy en el foreground.
- Comportamiento: refleja y refracta el entorno en tiempo real, se tiñe con el
  contenido circundante, adapta luminosidad entre light/dark, responde al movimiento
  con highlights especulares, se ilumina desde dentro al interactuar y refleja
  sobre otros elementos Liquid Glass. Inspirado en visionOS, heredero de Aqua → iOS 7 → Dynamic Island.
- Iconos/widgets Tahoe: multicapa de Liquid Glass con specular + sombra + tints
  claro/oscuro/clear personalizables; la barra de menú pasa a "completamente
  transparente" (PDF Apple) con opción "Show Menu Bar Background".

## 2. Parámetros observables (con confianza)

Apple no documenta píxeles. Los valores son rangos de réplicas/observación;
usarlos como punto de partida, no como spec. Confianza Media salvo indicación.

| capa | parámetro | valor observado | fuente | implementación Nimbus | conf. |
|---|---|---|---|---|---|
| blur fondo | radio | 0–26px+ según superficie; Dock/barra ~15–25px equivalentes; controles pequeños ~2–8px | réplica iOS26 (panel blur 0–26px); kube.io (Blur Level 0–1) | KWin blur strength + `blurPx` shader (`GlassSlab blurPx:1.5`, widgets +11 sobre dock) | Media |
| blur fondo | técnica | gaussiano + mipmaps, sin fantasmas | `liquidglass.frag:48-55` (24 taps, pesos gaussianos, IGN por píxel) | `blurredDisp()` con `textureLod` + `mipmap:true` en ShaderEffectSource | Alta |
| saturación | boost vibrancy | ~1.2–1.5× (réplicas usan Specular Saturation 4–9, Saturation 1.25 en MacShell) | kube.io; `GlassSlab.qml:99 saturation:1.25` | `mix(luma,col,saturation)` en ambos `.frag` | Media |
| opacidad/tint | mezcla a color plano | 0–1; controles ~0.2–0.45; Dock adaptativo 0.78–1.28× según luminancia | `dockglass.frag:151-158` (adapt), `GlassSlab tint:0.42×0.55` | `tintMix` (+`edgeTint` en Dock) | Alta (propio) / Media (Apple) |
| tint color | claro/oscuro | claro→blanco, oscuro→~#17171A (`vec3(0.09)`) + lift +0.055/0.020 | `liquidglass.frag:158-160` | `tintC=mix(blanco,negro,dark)` + `dark` 0/1 | Alta (propio) |
| refracción | modelo | SDF rounded-box → bezel convexo → Snell n≈1.5, shift lateral ×1.35 | `liquidglass.frag:136-147` | idem; `thickness` (GlassSlab 16×liquid×1.6), `bezel=min(h*0.36,26)×1.45` | Alta (propio) |
| refracción | distribución | borde >> centro; blur más nítido en el rim (`mix(0.45,1.0,smoothstep)`) | `liquidglass.frag:151` | idem | Alta (propio) |
| dispersión | split cromático | leve; réplicas Refraction Level 0.7–1.0, Specular Opacity 0.2–0.5 | kube.io | `dispersion:0.06×liquid×1.3` (GlassSlab), `disp*0.6` en shader | Media |
| lente | magnificación vertical | sutil (~5%) | `GlassSlab magnify:0.05×liquid×1.6` | `ps=(p.y-…)×(1-magnify×1.5)` | Alta (propio) |
| highlight | rim especular | luz desde arriba-izq `L=(-0.55,-0.83)`; hair exp(-t/1.1) + wide exp(-t/5) + menisco | `liquidglass.frag:172-185` | idem; `rim` (GlassSlab 0.1125 = CC×0.25) | Alta (propio) |
| highlight | Dock Tahoe | línea ~1px top +18%/bottom +30%, lados +2.5%, glow interno; color = vidrio×1.2 | `dockglass.frag:165-178` | `rimCol=clamp(col×1.2)`; `rim` escala ×11.11 | Media-Alta |
| borde | ringW | 0=ninguno; >0 línea AA; <0 "corner light" (Control Center, fade en esquinas TR/BL) | `liquidglass.frag:187-206` | `ringW`, `rimTint` (0=blanco,1=tono propio) | Alta (propio) |
| borde | hairline exterior | 1px oscuro fuera del vidrio en fondos claros lo dibuja Canvas QML, no el shader | `dockglass.frag:168-169` | `CornerBorder/MenuBorder` (`MenuBorder.qml:34`: alfa 0.12/0.16) | Alta (propio) |
| sombra | drop shadow | capa ambiental ancha + contacto estrecha, offset abajo; liquid: 0.30×shadowAmt, falloff -2..9px | ambos `.frag` | `shadowAmt` (GlassSlab default 0; Dock exige pad≥30) | Alta (propio) |
| grano | noise | triangular misma en los 3 canales (textura, no ruido color); `grain` ~0.006–0.03 | `*.frag:208-210` (`hash12`); Better Blur "Noise Strength anti-banding" | `grain` (GlassSlab 0.03×0.2) | Alta |
| radios | corner radius | pill=altura/2; Dock/sidebar grandes; `r=min(radius,min(hs))` | `GlassSlab cornerR=h/2`; F3 tokens 24/12, pill 15 | `radius`, `roundBox()` SDF | Alta (propio) |
| diferencias | barra vs Dock vs popover | barra: casi transparente, tint mínimo; Dock: esmerilado translúcido adaptativo; popover/menú: más denso; sidebar: deja pasar scroll | PDF Apple; Verge hands-on; HIG | barra `tintMix` bajo + `blurPx` alto; Dock `dockglass.frag`; menús Kvantum `reduce_menu_opacity` | Media |

## 3. Estados, accesibilidad y rendimiento

| estado | comportamiento Apple observable | fuente | implementación Nimbus | conf. |
|---|---|---|---|---|
| active/inactive | inactivo pierde énfasis/vibrancy, más gris/plano | NSVisualEffectView `state`, `isEmphasized` | `dark`/opacidad + tokens (gris inactivo `#598E8E93` en WindowBar); Klassy opacidad inactiva | Media |
| hover/pressed | el control "cobra vida": iluminación interna, refleja en vecinos | newsroom + s219 | `GlassSwitch/GlassSegmented`: knob/marker pasa a Liquid Glass al mantener/deslizar (`pressT`, `glassOn`) | Media-Alta |
| light/dark | el tint se invierte; iconos/widgets tienen looks light/dark/tinted/clear | PDF Tahoe; appearance settings | `dark` 0/1 en shaders + `scripts/apply-theme` + wallpaper NPS propio | Alta |
| Reduce transparency | reemplaza translucidez por fondo sólido; en Tahoe afecta barra/Dock/CC | Apple Support (unac089), Macworld, MacMost | tier bajo: `GlassSlab glass:false` (pane frosted: dark alfa 0.12 / light 0.78) + desactivar blur KWin; documentar como setting Accesibilidad | Alta |
| Increase contrast | añade bordes/delineados (exige Reduce transparency previo en Tahoe) | MacMost; Apple Support | `ringW≥1` + `CornerBorder lineW` + texto con contraste WCAG; no inventar bordes Apple | Media |
| Reduce motion | atenúa transformaciones/fluidéz | Apple Support; iboysoft perf | duraciones 140–450ms existentes (`WindowBar`, `MenuBorder`) → 0 con la opción | Media |
| rendimiento | Liquid Glass cuesta GPU; en Macs viejos se nota en Mission Control/espacios; Reduce transparency mejora | iboysoft; SlashGear | tiers + captura estática (glass congela último frame) + `blurPx` bajo + `live:false` donde aplique | Media |

## 4. Implementación en Plasma/KWin/QML sin assets Apple

### 4.1 Reparto de responsabilidades

- KWin = blur gaussiano + contraste/saturación del fondo (barato si es nativo, caro a pantalla completa).
  No sabe refractar ni dibujar rims: no pedirle lente/dispersión.
- QML = todo lo óptico propio (refracción Snell, dispersión, tint adaptativo, specular, grano, sombra).
  Reutilizar `liquidglass.frag` (genérico/CC) y `dockglass.frag` (Dock Tahoe); `GlassSlab.qml` para
  controles pequeños (pills, knobs). Compilar con `qsb --qt6` y cachear `.qsb` (ya lo hace `shell.qml`/MacDock).
- Kvantum = translucidez de apps Qt (Dolphin etc.): `translucent_windows=true`, `blurring/popup_blurring=true`,
  `reduce_window_opacity`, `menu_blur_radius≤10`, `contrast/saturation/intensity 0–2`. Exige Kvantum ≥1.1 para
  blur Qt6/KF6 WindowEffects. Alternativa sin Kvantum: reglas KWin de opacidad (solo transparencia, sin blur real).
- Plasma desktop theme = SVG `panel-background` + `plasmarc` (`[BlurBehindEffect] enabled`, fallback Breeze);
  panel 28px flotante + Panel Colorizer para tint por preset (ver F3-visual §3). Transparencia real necesita
  tema con alfa + blur KWin activo.

### 4.2 Mapeo de parámetros (qué mover para parecerse a Tahoe sin copiarlo)

| efecto Tahoe | control KWin/Better Blur | control QML Nimbus | receta inicial |
|---|---|---|---|
| esmerilado fondo | Blur Strength (medio), Noise Strength bajo, Force Contrast | `blurPx` 1–3 (Dock), 1.5 (slabs); widgets = dock+11 | subir `blurPx` antes que el strength global (más barato localizar) |
| vibrancy | Brightness ~1, Saturation 1.1–1.3, Contrast ~1 | `saturation:1.25`, lift +0.055/0.020 | no pasar de 1.4 o quema blancos |
| translucidez | opacidad panel/ventana, Kvantum reduce_opacity | `tintMix` (barra bajo, Dock medio+adaptativo, popover alto) | Dock usa `adapt 0.78–1.28` por luminancia, no un plano fijo |
| lente/refracción | — (no existe en KWin) | `thickness`, `bezel`, `magnify`, `dispersion` | `thickness 16`, `bezel h*0.36≤26`, `dispersion 0.06`, `magnify 0.05`, todo ×`liquid` |
| specular/borde | — | `rim`, `ringW`, `rimTint`, `edgeTint` (Dock), `CornerBorder` | Dock: rim medido top/bottom; CC: `ringW<0` corner-light; resto `ringW=0` |
| sombra | sombra decoración (Klassy/KWin) | `shadowAmt`, pad≥30 en Dock | una sola sombra (regla F3: "sombra única") |
| grano | Noise Strength | `grain` 0.006–0.03 mono | subir hasta que desaparezca banding en degradados, no más |

### 4.3 Tiers alto/bajo (rendimiento y accesibilidad)

- Alto (dGPU / iGPU moderna): KWin blur on + `liquidglass/dockglass` completos (24 taps, mips, dispersión,
  grano) + ShaderEffectSource `live:true`. Vigilar fps en scroll y Mission Control-like (Overview).
- Bajo (iGPU vieja, batería, VM sin GL, Reduce transparency): `GlassSlab glass:false` + panel/plasmoides
  con rect frosted opaco + KWin blur off/static + `live:false` (frame fijo) + sin dispersión/grano.
  El shader ya prevé fallback (`ses.scheduleUpdate`, `failed()` → Normal Blur) y pausa de captura
  tras fullscreen (ver `shell.qml:79`, `lang/es.js:158`). Exponer como un único interruptor
  "Rendimiento / Reducir transparencia" mapeado a ambos mundos (KWin + QML), no dos ajustes separados.

## 5. Cómo medir / verificar (evidencia VM, R-APPLE)

1. Capturas antes/después en VM (QEMU/KVM) o sesión anidada, como exige AGENTS.md: mismo wallpaper NPS
   propio, misma ventana, light+dark. Medir coordenadas en la captura actual (`hyprctl cursorpos`,
   detección de píxeles), nunca a ojo (lección M1: recolocación entre sesiones).
2. Diff contra golden propio: `tests/screenshot-diff/compare.sh <golden> <captura> --umbral 15`
   (aceptación F3-T12: diff <15%, 0 errores). Goldens propios, nunca capturas de macOS.
3. Contraste texto-sobre-vidrio: test WCAG AA en barra/Dock/popover con 3 fondos
   (claro, oscuro, foto) × light/dark. Si falla, subir `tintMix`/adapt antes que opacar todo.
4. Rendimiento: fps con `qdbus`/HUD o conteo en Overview+scroll; objetivo ≥50 en iGPU, sin caídas >10%
   al activar vidrio; registrar blur strength, `blurPx`, nº superficies con `live:true`.
5. Qué es fiel vs aproximación (decirlo en la evidencia):
   fiel = blur gaussiano con mips, tint adaptativo, rim superior/inferior, grano mono, radios pill,
   estados active/inactive y Reduce-transparency→sólido. Aproximación = refracción (solo ve su
   ShaderEffectSource, no el framebuffer real como Metal), dispersión (constante, no espectral),
   reflejos entre vidrios, física de luz/movimiento del dispositivo, materiales semánticos exactos.

## 6. Riesgos

| riesgo | detalle | mitigación |
|---|---|---|
| blur costoso | fullscreen + varias superficies `live:true` tumban iGPU/VM | tiers; `live:false`/frame fijo; static blur (Better Blur/forceblur) solo si documentado; medir fps |
| artefactos | ghosting/duplicados si taps sin mips; banding sin grano; "korners" (blur cuadrado tras esquinas redondas) | 24 taps + `textureLod` + IGN (ya hecho); grano mono; `Corner radius` en Better Blur + `roundBox` AA; `menu_blur_radius≈2` |
| ABI KWin/Plasma | efectos externos (Better Blur DX, forceblur, Panel Colorizer) se rompen entre Plasma 6.x; `keyword` inexistentes, `hyprctl reload` pierde estado | pinear commit/tag (F3-T13, R-CACHYOS/R-KLASSY); preferir blur stock si basta; verificar carga (`qs log`, sin `property` duplicados) |
| Kvantum Qt6 | blur Qt6 exige Kvantum ≥1.1 + KF6 WindowEffects; Flatpak ajeno al tema | documentar versión mínima; aceptar in-window opaco en GTK/Flatpak (R-GTK: no perseguir menú global GTK) |
| R-APPLE | copiar radios/colores/iconos/wallpapers/SF de Apple o goldens con capturas macOS | arte propio (Inter, logo N, Sequoia NPS); SVG propios; goldens propios; este doc no incluye ningún asset Apple |
| Alcance ISO | Calamares/greetd/drivers no van aquí | abrir port en NimbusOS, solo documentar dependencia |

## Fuentes

- Apple HIG Materials (rev. 09-09-2025); newsroom 09-06-2025; PDF All New Features macOS Tahoe Sept 2025;
  WWDC25 s219 Meet Liquid Glass (+ Adopting Liquid Glass, Icon Composer s361, s356).
- NSVisualEffectView / Material / BlendingMode / vibrancy (docs Apple + docs.rs).
- Réplicas: kube.io "Liquid Glass in the Browser" (desplazamiento + specular, params 0–1);
  conor.fyi Liquid Glass reference (lensing vs blur, API `glassEffect`, reduce transparency/motion);
  demo iOS26 (blur 0–26px, base opacity, edge/top highlight, shadow, saturation, refraction).
- KWin: `kwin/src/plugins/blur/blur.cpp` (downsample/upsample/noise passes), Effect::Blur/Contrast;
  taj-ny Better Blur (features: force/static/refraction, brightness/saturation/contrast, corner radius);
  harnocca Better Blur DX `docs/configuration.md`; Plasma theme `develop.kde.org/docs/plasma/theme/`.
- Kvantum: `Theme-Config` (translucent_windows, blurring, popup_blurring, menu/tooltip_blur_radius 0–10,
  contrast/saturation/intensity 0–2), INSTALL (blur Qt6≥1.1); KvGlass (ejemplo translúcido).
- Accesibilidad/rendimiento: Apple Support unac089 (Reduce transparency, Increase contrast);
  Macworld/MacMost/SlashGear/iboysoft (efectos, pasos, coste GPU).
- Nimbus propio: `MacShell/{liquidglass,dockglass}.frag`, `GlassSlab.qml`, `GlassSwitch/Segmented.qml`,
  `MenuBorder.qml`, `MacWidgets.qml:42`, `shell.qml:79`; research `F3-visual.md`; AGENTS.md + `docs/HANDOFF.md`
  (carga, eco+md5, evidencia posicional).
