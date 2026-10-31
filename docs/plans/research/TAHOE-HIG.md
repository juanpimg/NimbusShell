# TAHOE-HIG — Lenguaje de diseño Apple / macOS Tahoe para NimbusShell

> Researcher de diseño. Solo investigación, sin código. Fecha: 2026-10-31.
> Alcance: traducir HIG + Liquid Glass / Tahoe a tokens Nimbus (Inter, QML, Hyprland).
> Restricción vinculante: sin activos propietarios Apple (SF, SF Symbols, sonidos, wallpapers, logos).

Fuentes primarias:

- HIG home + principios: https://developer.apple.com/design/human-interface-guidelines
- Novedades diseño: https://developer.apple.com/design/whats-new
- Liquid Glass overview: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Newsroom Liquid Glass (09-06-2025): https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- Tipografía HIG: https://developer.apple.com/design/human-interface-guidelines/typography
- Fuentes Apple (SF Pro/Compact/Mono/NY): https://developer.apple.com/fonts
- Color HIG: https://developer.apple.com/design/human-interface-guidelines/color
- Dark Mode HIG: https://developer.apple.com/design/human-interface-guidelines/dark-mode
- Materiales HIG: https://developer.apple.com/design/human-interface-guidelines/materials
- Motion HIG: https://developer.apple.com/design/human-interface-guidelines/motion
- Accesibilidad HIG: https://developer.apple.com/design/human-interface-guidelines/accessibility
- SF Symbols HIG: https://developer.apple.com/design/human-interface-guidelines/sf-symbols
- Iconos HIG: https://developer.apple.com/design/human-interface-guidelines/icons
- App icons HIG: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Audio HIG: https://developer.apple.com/design/human-interface-guidelines/playing-audio
- Haptics HIG: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Feedback HIG: https://developer.apple.com/design/human-interface-guidelines/feedback
- Principios diseño (2026): https://developer.apple.com/design/human-interface-guidelines/design-principles
- Botones / hit-targets: https://developer.apple.com/design/human-interface-guidelines/buttons
- Etiquetas: https://developer.apple.com/design/human-interface-guidelines/labels
- macOS Tahoe novedades (PDF): https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf
- Soporte Mac (escritorio/menú/Dock): https://support.apple.com/guide/mac-help/desktop-menu-bar-and-dock-mchlws12345m2/mac
- WWDC23 Animate with springs: https://developer.apple.com/videos/play/wwdc2023/10158
- WWDC25 Get to know the new design system: https://developer.apple.com/videos/play/wwdc2025/356
- WWDC26 Principles of great design: https://developer.apple.com/videos/play/wwdc2026/250

Valores hex de sistema verificados contra:

- https://colorsift.com/reference/apple-system-colors
- https://github.com/EvanBacon/expo-apple-colors/blob/main/spec.json

## Resumen (<30 líneas)

1. HIG clásica = clarity/deference/depth (2013-2025); HIG 2025-2026 = hierarchy/harmony/consistency + Liquid Glass.
2. Liquid Glass es capa funcional translúcida (refracta/refleja, se adapta claro/oscuro) para controles/navegación, no fondo de contenido.
3. Tahoe: menu bar totalmente transparente, toolbars/sidebars flotantes, Dock/sidebars de vidrio, esquinas más redondas, iconos en capas light/dark/tint/clear.
4. Tipo macOS: SF Pro 13pt base (body/headline 13/16), títulos 15/17/22/26; Inter es el sustituto libre más cercano (88% similitud, OFL).
5. Tracking siempre dependiente del tamaño (positivo en 11-12px, negativo en 17px+); prohibido un único letter-spacing global.
6. Color semántico, nunca hex fijo: label/secondary/tertiary/separator + systemBlue como único acento; custom color exige variante light+dark+alto contraste.
7. Contraste mínimo WCAG AA: 4.5:1 texto ≤17pt, 3:1 texto grande/negrita; objetivo 7:1 en texto pequeño propio.
8. Hit-target: 44×44pt iOS, 28×28pt por defecto macOS (mín. 20×20); Nimbus con puntero debe garantizar ≥24px WCAG y aspirar a 32-44px.
9. Spacing base 8pt: escala 4/8/12/16/20/24/32; márgenes ventana macOS 20pt, contenido 16pt; radios 8/10/12/20.
10. Materiales estándar bajo el vidrio: ultraThin/thin/regular/thick (+bar/ultraThick); regular = defecto; thick = mejor contraste texto.
11. Sobre material, usar siempre color vibrante; evitar quaternary sobre thin/ultraThin (contraste colapsa).
12. Movimiento: springs como defecto espacial (0.35-0.5s), ease solo para opacidad/color; todo >0.4s en macOS se percibe lento.
13. Accesibilidad no negociable: Reduce Transparency / Increase Contrast / Differentiate Without Color / VoiceOver label en todo icono.
14. Iconos: símbolo = peso igual al texto adyacente, 3 escalas (S/M/L), esquinas y uniones redondeadas; app icon = squircle, sin foto ni chrome UI dentro.
15. Sonido/háptica: feedback multimodal redundante (visual+sonido+háptica), nunca solo color o solo sonido; Nimbus usa sonidos propios sutiles + flash visual.
16. Regla Nimbus: `token semántico → QML/Hyprland`, jamás hex Apple cableado; cada token custom lleva modo claro+oscuro.

## 1. Principios HIG y cambio Tahoe / Liquid Glass

Clásico (iOS 7 → macOS Sequoia): clarity (legibilidad, precisión), deference (UI al servicio del contenido, edge-to-edge), depth (capas, blur, movimiento comunican jerarquía). Tahoe/Liquid Glass (WWDC25, v26 unificada: iOS 26 / macOS Tahoe 26) lo literaliza: capa de vidrio refractivo sobre contenido edge-to-edge. HIG actual resume en hierarchy / harmony / consistency, más página de principios 2026 (familiarity, feedback, flexibilidad, delight).

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| hig-clarity | Contenido legible, pocos elementos, jerarquía tipográfica | HIG overview + principios.design iOS 11 | Alta | Regla lint visual: 1 acción primaria por vista, títulos Inter semibold |
| hig-deference | Chrome mínimo, contenido a sangre bajo toolbar/sidebar flotante | Newsroom Liquid Glass 09-06-2025 | Alta | Toolbars QML flotantes con fondo blur, no barras opacas gruesas |
| hig-depth | Capas + blur + sombra sutil + movimiento físico = jerarquía | HIG Motion + Materials | Alta | z-order: fondo → contenido → material regular → LiquidGlass-chrome → popover/sombra |
| hig-hierarchy-26 | Controles elevan y distinguen el contenido | HIG home (Hierarchy) | Alta | Popovers/menús siempre con elevación + blur, nunca plano sobre plano |
| hig-harmony-26 | Concéntrico con hardware/software, coherente entre vistas | HIG home (Harmony) | Media | Mismo radio/escala en Dock, bar, Spotlight, Launchpad; paleta única |
| hig-consistency-26 | Convenciones plataforma, adapta a tamaño/ventana | HIG home (Consistency) | Alta | Atajos, semáforos izq., menú global, Spotlight: no reinventar |
| tahoe-menubar | 100% transparente, controles se expanden in-situ | PDF Tahoe Sept 2025 p.2 | Alta | `nimbus.topbar`: transparente + blur on-content, sin franja sólida |
| tahoe-sidebar | Liquid Glass, inmersiva, contenido fluye debajo | PDF Tahoe p.2 | Alta | Sidebars QML translúcidas, scroll-edge blur, no panel opaco |
| tahoe-corners | Ventanas más redondas que Sequoia | PDF Tahoe p.2 | Media | Token `radius-window` 12-14px (ver §4); medir en captura VM |
| tahoe-icons | Capas de vidrio, variantes light/dark/tint/clear | PDF Tahoe p.2-3 | Alta | Iconos N propios con 4 variantes (light/dark/tint/clear), ver §8 |

## 2. Tipografía: SF Pro → Inter

SF Pro: 9 pesos, 4 anchuras, ópticos Text (≤19pt: formas anchas, trazo grueso, tracking generoso) vs Display (≥20pt: estrecho, tracking negativo). Sistema elige automáticamente por `opsz`. Pesos macOS reales: Regular/Medium/Semibold/Bold/Heavy (no usar Ultralight/Thin en UI). Mono: SF Mono 6 pesos para código/temporizadores. Inter (OFL, Rasmus Andersson) es el equivalente libre recomendado: misma x-height grande y misión "para pantallas"; compensar con tracking algo más cerrado en display y `font-kerning:normal`.

Estilos built-in macOS (HIG Typography, pt):

Large Title 26/32 Regular(Bold enf.), Title 1 22/26, Title 2 17/22, Title 3 15/20 Semibold, Headline 13/16 Bold(Heavy), Body 13/16 Regular(Semibold), Callout 12/15, Subhead 11/14, Footnote 12/14, Caption 1 11/13, Caption 2 10/12 aprox. Mínimo UI macOS 10pt, iOS 11pt.

Tracking SF Pro oficial (1/1000 em → pt): 11pt +6 (+0.06pt), 12pt 0, 13pt −6 (−0.08pt), 14pt −11 (−0.15pt), 15pt −16 (−0.23pt), 16pt −20 (−0.31pt), 17pt −26 (−0.43pt). Fórmula CSS: `letter-spacing = tracking_em × font-size` (ej. −26/1000×17px = −0.44px). Mayúsculas/tabs: +0.05→+0.08em siempre.

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| type-11-caption | SF 11 Regular, track +0.06pt (+0.005em), lh 13-15px | HIG Typography tracking table | Alta | Inter 11px / Medium 500, `ls +0.01em`, `lh 1.40 (15px)`; tab/status |
| type-12-callout | SF 12 Regular, track 0, lh 15px | HIG macOS text styles | Alta | Inter 12px / 400, `ls 0`, `lh 1.25 (15px)`; secundario |
| type-13-body | SF 13 Regular, track −0.08pt (−0.006em), lh 16px | HIG macOS Body/Headline | Alta | Inter 13px / 400, `ls −0.006em`, `lh 1.23 (16px)`; **body base Nimbus** |
| type-13-headline | SF 13 Bold, track −0.08pt, lh 16px | HIG macOS Headline | Alta | Inter 13px / 700, mismo ls/lh; énfasis |
| type-15-title3 | SF 15 Regular(−0.23pt/−0.016em), lh 20px, enf. Semibold | HIG Title 3 | Alta | Inter 15px / 400 (600 enf.), `ls −0.015em`, `lh 1.33 (20px)` |
| type-17-title2 | SF 17 Regular(−0.43pt/−0.026em), lh 22px, enf. Bold | HIG Title 2 | Alta | Inter 17px / 400 (700 enf.), `ls −0.025em`, `lh 1.29 (22px)` |
| type-22-title1 | SF 22 Regular, track ≈−0.02em, lh 26px | HIG Title 1 | Alta | Inter 22px / 400 (700 enf.), `ls −0.02em`, `lh 1.18 (26px)` |
| type-28-display | SF 28 Display, track ≈−0.02em, lh 34px | HIG iOS Title 1 28/34 extrapolado macOS | Media | Inter 28px / 600, `ls −0.02em`, `lh 1.21 (34px)`; hero/diálogos |
| type-mono | SF Mono, 6 pesos, tabular nums | developer.apple.com/fonts | Alta | `JetBrains Mono / ui-monospace`, código + relojes; nums tabulares |
| type-caps-label | ALL-CAPS +0.05→+0.08em, 10-12px hasta +0.15em | HIG + práctica tracking | Alta | `.nimbus-eyebrow { 11px, 600, uppercase, ls +0.08em }` |
| type-glass-bump | Sobre vidrio translúcido +0.005em extra | Síntesis legibilidad glass | Baja | Si texto va sobre blur <60% opaco, sumar +0.005em y subir 1 peso |
| type-stack | `-apple-system` → SF real; fuera Apple: Inter | Práctica fallback HIG | Alta | `font-family: Inter, "SF Pro Text", system-ui, sans-serif` (nunca empaquetar SF) |
| type-scale-max | No superar ~6 tamaños distintos por vista | HIG + audit pattern | Media | Lint: contar `font-size` distintos en QML por pantalla, máx 6 |

## 3. Color semántico, light/dark, vibrancy

Regla HIG: definir por propósito, no por apariencia; prohibido reutilizar (separator como texto, secondaryLabel como fondo). Todo custom color exige light+dark+alto contraste, incluso si la app es single-appearance (Liquid Glass adapta claro/oscuro según contenido). Vibrancy: labels/fills sobre materiales usan variantes vibrantes pre-ajustadas; sobre vidrio pequeño el sistema invierte a monocromo (oscuro sobre claro y viceversa).

Hex de referencia (solo diseño, en runtime resolver dinámico; dark no es inversión exacta):

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| label-primary | light `#000000` / dark `#FFFFFF` | colorsift + expo-apple-colors (`label`) | Alta | `nimbus.label` / `nimbus.labelDark`; texto principal |
| label-secondary | `rgba(60,60,67,0.6)` / `rgba(235,235,245,0.6)` (hex aprox `#3C3C43 60%`) | expo spec `secondaryLabel` + SO #64888882 | Alta | `nimbus.label2`; subtítulos, metadata |
| label-tertiary | `rgba(60,60,67,0.3)` / dark 0.3 | expo spec `tertiaryLabel` | Alta | `nimbus.label3`; placeholders secundarios |
| label-quaternary | `rgba(60,60,67,0.18)` / dark 0.18 | expo spec `quaternaryLabel` | Alta | `nimbus.label4`; solo decorativo, jamás sobre thin/ultraThin |
| separator | light `rgba(60,60,67,0.29)` / dark `rgba(84,84,88,0.6)`; opaco `#C6C6C8` / `#38383A` | expo spec + colorsift | Alta | `nimbus.separator` 1px físico (`0.5pt` retina); hairline |
| accent | light `#007AFF` / dark `#0A84FF` (accesible `#0040DD`/`#0A84FF+`) | colorsift System Blue | Alta | `nimbus.accent` único; fondo de acción primaria, no tintear texto masivo |
| sys-green/red/orange | `#34C759/#30D158`, `#FF3B30/#FF453A`, `#FF9500/#FF9F0A` | colorsift System Colors | Alta | `nimbus.success/destructive/warning`; un solo uso por vista |
| gray-ramp | Gray `#8E8E93`→Gray6 `#F2F2F7/#1C1C1E` (no simétricos) | colorsift Gray Colors | Alta | Fondos agrupados `nimbus.bg2 #F2F2F7 / #1C1C1E` |
| bg-base | light `#FFFFFF` / dark `#000000`; elevated popover `#FFFFFF/#2C2C2E` | HIG Dark Mode base/elevated | Alta | `nimbus.bg` + `nimbus.bgElevated`; popover siempre elevated |
| vibrancy-rule | Sobre material usar `label vibrante`, no gray plano | HIG Materials (poor vs good contrast fig.) | Alta | Texto QML sobre blur usa rol vibrante (opacity + blur-aware), no `#888` fijo |
| glass-tint-rule | Glass toma color del contenido; toolbar/tab adapta light/dark | HIG Color > Liquid Glass color | Alta | Blur Nimbus con `tint: contentAverage`, más texto monocromo auto-invertido |
| contrast-floor | 4.5:1 ≤17pt, 3:1 ≥18pt o bold (AA); objetivo propio 7:1 pequeño | HIG Accessibility table | Alta | CI: calcular contraste de cada par `label/bg` light+dark, fallo = bug |

## 4. Layout: grid, spacing, controles, hit-targets

Base 8pt; escala canónica 4/8/12/16/20/24/32. Padding bezel 12pt, unbezelled 24pt. Márgenes: iPhone 16pt, iPad 20pt, macOS ventana 20pt / contenido 16pt, toolbar macOS 52pt alto, sidebar 200-300pt ancho / fila 24pt. Radios: controles 8, cards/sheets 10, continuo grande 20. Fila tabla 44pt (56 con subtítulo). Ancho lectura 672pt.

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| space-4/8/12/16/20/24/32 | 4,8,12,16,20,24,32pt (=px @1x) | HIG spacing synthesis + design-rules-ai | Alta | Tokens `s1..s7` en theme QML; prohibido valor off-grid |
| margin-window-mac | 20pt ventana, 16pt contenido | macOS Spacing guide | Media | `nimbus.marginWindow: 20`, `nimbus.padContent: 16` |
| control-h-28/32/36 | Push 28 def., 32 grande, 36 prominente (macOS) | HIG Buttons macOS + audit | Media | `nimbus.btnH: 28/32/36`; visual puede ser 24 pero hit ≥32 |
| hit-ios-44 | Hit-region ≥44×44pt (visionOS 60×60) | HIG Buttons + Tips (Hit Targets) | Alta | Dock/Launchpad táctil: hit 44; icono 24 + padding invisible 10 |
| hit-mac-28 | macOS default 28×28, mín. 20×20 | apple-design-skill tabla plataformas | Media | Ventana/botón puntero: visual 28, hit ≥28; nunca <20 |
| hit-nimbus-floor | Web/puntero WCAG 2.5.8: 24px mín. | WCAG Understanding 2.5.8 | Alta | CI puntero: fallo si hit <24px; objetivo 32-44px |
| gap-bezel-12 | ~12pt alrededor de controles con borde | HIG touch-target checker | Media | `gap-buttons: 8-12px`; iconos adyacentes 8-10px |
| gap-plain-24 | ~24pt alrededor de controles sin borde | HIG touch-target checker | Media | Listas/toolbar sin bezel: 16-24px respiración |
| radius-controls/cards/big | 8 / 10-12 / 20px | HIG synthesis CSS `--radius-*` | Media | `r-sm 8, r-md 10-12, r-lg 20, r-window 12-14 (Tahoe)`; verificar captura |
| sidebar-240 | Ancho 200-300, fila 24, pad 8 | macOS Spacing guide | Media | Finder-sidebar Nimbus: 240px, row 28px (hit), pad 8 |
| safe-area | Respetar notch/Dynamic Island/home/toolbar | HIG Layout safe area | Alta | Topbar + Dock reservan safe-area; contenido nunca debajo |

## 5. Materiales: thick/regular/thin/ultraThin + Liquid Glass

Dos familias: Liquid Glass (capa funcional: controles/navegación/tab/dock/menu, refracta+refleja, clear/light/dark/tint) vs standard materials (capa contenido: ultraThin/thin/regular/thick + ultraThick/bar, blur+luminosidad+vibrancy). Regular = defecto, blurea y ajusta luminosidad para legibilidad; thicker = más opaco = mejor contraste; thinner = más contexto. Scroll-edge effect eleva controles sobre scroll. Settings Reduce Transparency / Increase Contrast cambian apariencia: elegir por rol semántico, no por color aparente.

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| glass-chrome | Refract/reflect tiempo real, morph con foco, variantes clear/regular | Liquid Glass tech overview + HIG Materials | Alta | `NimbusGlass { blur: 30-40, saturación 150%, refracción sutil }` solo en chrome (topbar/Dock/Spotlight), jamás en fondo contenido |
| mat-ultraThin | Casi translúcido; full-screen que exige esquema claro | HIG Materials tabla + SwiftUI `ultraThin` | Alta | Overlay pantalla completa sobre fondo claro; evitar texto fino encima |
| mat-thin | Más translúcido que opaco; overlay que oscurece parcial + esquema claro | HIG Materials tabla | Alta | Hover/selección botones, text-field; `blur ~20-40` |
| mat-regular | Algo translúcido; defecto overlays | HIG Materials ("Most system components use this") | Alta | `nimbus.material = regular` por defecto en popovers/menús |
| mat-thick | Más opaco que translúcido; overlay que exige esquema oscuro | HIG Materials tabla | Alta | Panel sobre fondo complejo, terminal, texto denso; `blur ~60-85` |
| mat-bar | Estilo toolbar sistema | SwiftUI `Material.bar` | Media | Altura 52px, blur bar + hairline inferior |
| vibrancy-labels | `label > secondary > tertiary > quaternary` (contraste desc.) | HIG Materials vibrancy | Alta | Roles texto sobre blur en ese orden; quaternary prohibido en thin/ultraThin |
| legibility-rule | Sin vibrante el gris colapsa (fig. poor vs good) | HIG Materials contraste | Alta | Test captura: texto sobre blur debe pasar 4.5:1, si no subir a thick |
| reduce-transparency | Material colapsa a sólido | HIG Materials + Accessibility Settings | Alta | `nimbus.reduceTransparency: blur→sólido bgElevated opaco` (switch real) |
| rn-intensity-map | ultraThin≈20 / thin≈40 / regular≈60 / thick≈85 (expo-blur) | apple-hig-skills color-and-materials | Baja | Guía inicial `intensity` en Hyprland/QML hasta medir blur real en VM |

## 6. Movimiento: duraciones, curvas, springs, reduce motion

Filosofía: motion = feedback/estado/continuidad, nunca decoración gratuita; breve, preciso, cancelable, consistente con el gesto (si entra deslizando abajo, sale igual). Sistema ya anima; el custom debe aportar información. Springs = defecto espacial (interrumpibles, con velocidad inicial); easing solo para no-espacial (opacidad/color). Duración `.default` 0.35s ease-in-out; AppKit `NSAnimationContext` 0.25s; regla macOS: >0.4s = lento. Entrada ease-out, salida ease-in (65-75% de la entrada), on-screen ease-in-out, loops lineales. Tahoe añade morph de vidrio y Draw/variable rendering en símbolos.

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| dur-instant | 0.15s sistema (apertura menú), hover <0.10s | motion synthesis + LottieFiles tables | Media | `t-instant 150ms`; hover/press sin delay perceptible |
| dur-default | 0.35s ease-in-out (SwiftUI `.default`) | SO #74211440 + WWDC23 springs | Alta | `t-normal 350ms`; transición estándar ventana/popover |
| dur-appkit | 0.25s (NSAnimationContext) | Doc NSAnimationContext | Media | `t-quick 250ms`; micro-interacción botón/toggle 120-180ms |
| dur-modal | 300-400ms modal/dialog; página 400-600ms | LottieFiles timing tables | Media | `t-modal 350ms`; Mission Control/Spaces 400-500ms máx |
| curve-apple | `cubic-bezier(0.25,0.1,0.25,1)` iOS default | LottieFiles easing standards | Media | `easing-apple` en Hyprland/QML para opacidad/deslizamiento |
| spring-default | `.spring(duration 0.35-0.5, bounce 0-0.15)`; `.smooth/.snappy/.bouncy` | WWDC23 10158 + SwiftUI Animation | Alta | `spring-normal: stiffness ~300, damping ~20-24`; re-target gestos |
| spring-gentle | `dampingRatio 1` = sin oscilación; <1 = rebote | UIKit `animate withSpring` docs | Alta | Cierre ventana/minimize sin rebote (`damping 1`); pick/drop con bounce ≤0.3 |
| exit-rule | Salida = 65-75% duración entrada | LottieFiles enter-vs-exit | Media | `t-exit = t-enter × 0.7`; fade-out rápido |
| reduce-motion | Sustituir slide/escala/blur-anim por fade; sin oscilación ni parallax | HIG Motion + Accessibility | Alta | `nimbus.reduceMotion: springs→fade 150ms, sin bounce/parallax/Genie` |
| cancelable | No bloquear input durante animación | HIG Motion (Let people cancel) | Alta | Toda animación QML `cancellable:true`, Genie/Space interrumpible |
| dock-560 | Mostrar/ocultar Dock ~0.5s | macos-defaults `autohide-time-modifier` | Baja | `t-dock 500ms ease-out`; medir en VM antes de fijar |

## 7. Accesibilidad (contraste, transparencia, color, VoiceOver)

Matriz Apple de testeo: Bold Text, Larger Text (+tamaños accesibilidad), Button Shapes, On/Off Labels, Reduce Transparency, Increase Contrast, Differentiate Without Color, Color Filters, Reduce Motion, Dim Flashing Lights, VoiceOver/VoiceControl. Inspector usa WCAG AA (4.5:1 / 3:1). Colores sistema traen variantes accesibles automáticas; custom debe proveerlas. Dynamic Type hasta 135% (140% watchOS) sin romper layout.

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| a11y-contrast | 4.5:1 texto, 3:1 grande/bold; 7:1 objetivo pequeño | HIG Accessibility tabla | Alta | Gate CI: medir light+dark; setting `Increase Contrast` sube pesos y oscurece fills |
| a11y-transparency | Reduce Transparency → todo sólido legible | HIG Materials + Settings test matrix | Alta | Switch funcional en Centro de Control Nimbus; blur→`bgElevated` |
| a11y-nocolor | Nunca solo color: icono/forma/texto redundante | HIG Accessibility + App Store criteria | Alta | Errores/estados con icono + texto, no solo punto rojo/verde; tvOS: foco con escala, no color |
| a11y-voiceover | Label+hint+trait en todo control, orden y agrupación lógica | HIG Accessibility + UIKit Supporting VoiceOver | Alta | Todo `IconButton` QML con `Accessible.name/description`; rotor/orden foco testeado |
| a11y-dynatype | Layout refluye a 135% sin truncar/solapar | HIG Accessibility dynamic type | Alta | Texto QML con wrap/elide + layout fluido; test a 135% en VM |
| a11y-motion | Reduce Motion + Dim Flashing Lights + prefer-cross-fade | HIG Motion + test matrix | Alta | Ver §6 `reduceMotion`; sin autoplay/oscilación sostenida |
| a11y-multimodal | Sonido + háptica + visual redundantes | HIG Feedback (Make all feedback accessible) | Alta | Cada ping sonoro lleva flash/badge; cada color lleva icono |

## 8. Iconografía y sonidos (equivalentes propios, sin assets Apple)

SF Symbols (>7000, 9 pesos ultralight→black + 3 escalas S/M/L relativas a cap-height, vectoriales, RTL y 20+ scripts, animables Draw/variable) y SF Pro son propietarias: prohibido empaquetarlas o imitar confusamente en logos/app-icons. Principios reutilizables: peso símbolo = peso texto adyacente; escala ajusta énfasis sin romper weight-matching; trazo uniforme, caps/joins redondeados, grid de círculos/rectángulos redondeados/45°; variantes por tamaño (simplificar a 16px); modos monochrome/hierarchical/palette/multicolor; iconos interfaz en negro+clear para tintar; app icon = squircle, fondo full-bleed, contenido centrado en safe-circle, sin foto ni chrome UI, outline convertido, PNG lossless. Sonido: sutil, varía pitch/volumen para no fatigar, respeta silencio/volumen sistema, siempre con alternativa visual/háptica; diseño multimodal CoreHaptics (WWDC21 10278).

| token | valor | fuente | confianza | equivalente Nimbus |
|---|---|---|---|---|
| icon-stroke | Trazo uniforme = peso texto, caps/joins redondos | HIG Icons + SF Symbols weights/scales | Alta | Set `NimbusGlyphs` propio (SVG, stroke 1.5-2px @24px, round caps) |
| icon-scale-S/M/L | S/M/L relativo a cap-height, centrado óptico vertical | WWDC19 Introducing SF Symbols 206 | Alta | Componente `NIcon { size 16/20/24, weight Light/Reg/SBold }` acoplado a `type-*` |
| icon-sizes | Botón 18-24 en hit 44; fila 20-29 (29 color); feature 40-64; empty 64-96 | HIG Icons synthesis | Media | `glyph-row 20, glyph-btn 20, glyph-feature 48, glyph-empty 72`; medir captura |
| icon-modes | Mono (mayoría) / jerárquico / paleta / multi | HIG SF Symbols rendering modes | Media | `NIcon.mode: mono/hierarchical/duotone`; duotono con `accent+label2` |
| icon-a11y | `alt-text` en todo custom glyph | HIG Icons best practices | Alta | `Accessible.name` obligatorio; CI falla sin label |
| appicon-squircle | Máscara squircle sistema, safe-circle centrado, grid Apple Resources | HIG App icons | Alta | Icono N: squircle, 4 variantes Tahoe (light/dark/tint/clear), fondo Sequoia NPS propio |
| appicon-forbid | No foto, no captura UI, no símbolo sistema en logo | HIG App icons + SF Symbols terms | Alta | Logo N geométrico propio; jamás glifo Apple en Dock/logo |
| snd-subtle | Corto, suave, pitch/volumen variable, respeta mute/volumen | HIG Playing Audio + WWDC21 10278 | Alta | `nimbus/sounds/*.ogg` propios (open/close/error/trash/empty), <300ms, −14 LUFS |
| snd-redundant | Todo cue audio lleva cue visual/háptica | HIG Feedback + Accessibility haptics | Alta | Error = sonido + shake 300ms + icono; éxito = tick + check fade |
| snd-spatial | Spatial Audio solo si aporta posición; evitar loop molesto | HIG Playing Audio visionOS | Baja | Escritorio: estéreo simple; sin loops ambientales por defecto |

## Apéndice: mappings rápidos Nimbus → ficheros

- Theme QML: `label/label2/label3/separator/accent/bg/bgElevated` (§3) + `s1..s7`, `r-sm/md/lg/window`, `t-quick/normal/modal`, `spring-normal` (§4-6).
- `TopBar/Dock/Spotlight/Launchpad`: `glass-chrome` + `mat-regular/thin` + `type-13/11` + `hit-44/28`.
- Finder/sidebar: `mat-regular`, fila 28px, `sidebar-240`, `type-13-body`.
- Settings: switches reales `Reduce Transparency / Increase Contrast / Reduce Motion / Differentiate Without Color` (§7).
- Assets propios: `assets/n-glyphs/*.svg`, `assets/n-icon-*.png` (4 variantes), `assets/n-sounds/*.ogg`, fondo Sequoia NPS. Nada `SF/Symbols/wallpaper Apple`.

## Historial

- 2026-10-31: creación inicial researcher (HIG + Tahoe + Liquid Glass, 8 bloques, tablas token).
