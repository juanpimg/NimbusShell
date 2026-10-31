# Contrato de diseño Tahoe 1:1 — NimbusShell (Plasma)

> Fuente única aplicable. Sustituye a TAHOE-HIG/UI/GLASS como spec. Todo valor lleva `[HIG]`/`[MEDIDO]`/`[INFERIDO]`. `[INFERIDO]` = provisional: medir en VM antes de aceptar. Sin activos Apple (R-APPLE).

## 1. Principios y confianza

1. Jerarquía/armonía/consistencia `[HIG]` (HIG 2025-26). Chrome mínimo, contenido a sangre bajo vidrio `[HIG]`. z-order: fondo → contenido → material regular → glass-chrome → popover+sombra `[HIG]`.
2. Glass = solo capa funcional (bar/Dock/toolbar/sidebar/menú/Spotlight), jamás fondo de contenido `[HIG]`. Variante `regular` por defecto; `clear` solo sobre fondo rico `[HIG]`.
3. Color y tipo son semánticos, nunca hex/tamaño cableado `[HIG]`. Cada token custom exige light+dark+alto contraste `[HIG]`.
4. R-CONFIDENCE: ningún `[INFERIDO]` cierra tarea; su evidencia VM lo promueve a `[MEDIDO]` o lo corrige.

## 2. Tokens definitivos

### 2.1 Color semántico (light / dark)

| token | light | dark | uso |
|---|---|---|---|
| `label` | `#000000` `[HIG]` | `#FFFFFF` `[HIG]` | texto principal |
| `label2` | `rgba(60,60,67,.6)` `[HIG]` | `rgba(235,235,245,.6)` `[HIG]` | subtítulos |
| `label3` | `rgba(60,60,67,.3)` `[HIG]` | `rgba(235,235,245,.3)` `[HIG]` | placeholder |
| `label4` | `rgba(60,60,67,.18)` `[HIG]` | `rgba(235,235,245,.18)` `[HIG]` | decorativo; prohibido sobre thin/ultraThin `[HIG]` |
| `separator` | `rgba(60,60,67,.29)` / opaco `#C6C6C8` `[HIG]` | `rgba(84,84,88,.6)` / `#38383A` `[HIG]` | hairline 1px físico |
| `accent` | `#007AFF` `[HIG]` | `#0A84FF` `[HIG]` | única acción primaria |
| `success/destructive/warning` | `#34C759/#FF3B30/#FF9500` `[HIG]` | `#30D158/#FF453A/#FF9F0A` `[HIG]` | un uso por vista |
| `bg / bgElevated / bg2` | `#FFFFFF/#FFFFFF/#F2F2F7` `[HIG]` | `#000000/#2C2C2E/#1C1C1E` `[HIG]` | popover siempre elevated |
| Sobre vidrio | texto vibrante (label>secondary>tertiary), auto-invertido mono `[HIG]` | idem invertido | jamás `#888` fijo ni quaternary sobre thin |

### 2.2 Tipografía (Inter, sustituto SF; nunca empaquetar SF)

`font-family: Inter, system-ui, sans-serif`. `font-kerning: normal`; tabular-nums en reloj/código (JetBrains Mono para código) `[HIG]`.

| token | size/peso | tracking | lh |
|---|---|---|---|
| `t11` tab/status/caption | 11px / 500 | `+0.01em` `[HIG]` | 15px (1.40) |
| `t12` secundario | 12px / 400 | `0` `[HIG]` | 15px (1.25) |
| `t13` body base | 13px / 400 | `-0.006em` `[HIG]` | 16px (1.23) |
| `t13b` headline | 13px / 700 | `-0.006em` `[HIG]` | 16px |
| `t15` title3 | 15px / 400 (600 enf.) | `-0.015em` `[HIG]` | 20px (1.33) |
| `t17` title2 | 17px / 400 (700 enf.) | `-0.025em` `[HIG]` | 22px (1.29) |
| `t22` title1 | 22px / 400 (700 enf.) | `-0.02em` `[HIG]` | 26px (1.18) |
| `t28` hero/diálogo | 28px / 600 | `-0.02em` `[HIG]` | 34px (1.21) |
| `eyebrow` | 11px / 600 UPPER | `+0.08em` `[HIG]` | — |

Prohibido un letter-spacing global `[HIG]`. Máx 6 tamaños por vista `[HIG]`. Sobre blur <60% opaco: +0.005em y +1 peso `[INFERIDO]`.

### 2.3 Spacing / radios / controles

Escala `4/8/12/16/20/24/32` `[HIG]`; `marginWindow 20`, `padContent 16`, toolbar-h 52, sidebar-w 240, row 28 (hit), lectura max 672 `[HIG/MEDIDO]`.
Radios: `r-sm 8` controles, `r-md 10-12` cards, `r-lg 20` grande `[HIG]`; ventana Tahoe **16 sin toolbar / 26 con toolbar o sidebar (concéntrico)** `[HIG]` (Lapcat). Regla: `r_int = r_ext − padding` (fixed/capsule `r=h/2`/concentric) `[HIG]`. En Mac, vidrio concéntrico al borde, no cápsula con margen `[HIG]`.
Controles: `btnH 28/32/36` `[HIG]`; hit macOS 28×28 (mín 20) `[HIG]`; floor Nimbus **≥24px** (WCAG), objetivo 32-44; Dock/táctil hit 44 (icono 24+pad 10) `[HIG]`. Gap botones 8-12, listas sin bezel 16-24 `[HIG]`.

### 2.4 Glass por capa (QML+KWin; números Nimbus `[MEDIDO]` propio, efecto Apple `[HIG]`)

| capa | blur | tintMix/sat | specular/sombra/grano |
|---|---|---|---|
| menu bar | KWin medio + `blurPx` alto; tint mínimo (casi transparente) `[HIG]` | sat ≤1.4 | rim sutil; sin sombra propia |
| Dock | `dockglass.frag`, blur ~15-25px eq. `[INFERIDO]`, adapt 0.78-1.28 por luminancia | sat 1.25 | rim top 1px +18% / bottom +30% `[MEDIDO]`; sombra única, pad≥30; grano 0.006-0.03 mono |
| popover/menú | más denso que Dock `[HIG]`; `menu_blur_radius≈2` | tintMix alto | hairline Canvas alfa .12/.16; sombra única |
| sidebar/toolbar | deja pasar scroll (scroll-edge blur) `[HIG]` | medio | sin color custom en bars `[HIG]` |
| slab pequeño | `blurPx 1.5`, thickness 16, bezel `min(h*.36,26)`, Snell n≈1.5, disp 0.06, magnify 0.05 | — | rim `L=(-0.55,-0.83)`; `ringW=0` (CC: `ringW<0` corner-light) |

Reduce Transparency → todo sólido `bgElevated` + blur off (un solo interruptor KWin+QML) `[HIG]`. Increase Contrast → `ringW≥1` + pesos texto `[HIG]`.

### 2.5 Motion / estados / a11y

` t-instant 150ms` (hover/press <100ms), `t-quick 250ms`, `t-normal 350ms ease-in-out`, `t-modal 350ms`, MC/Spaces 400-500ms máx; curva `cubic-bezier(.25,.1,.25,1)`; springs defecto espacial (stiffness~300, damping 20-24; cierre sin rebote damping 1); salida = entrada×0.7 `[HIG]`; todo cancelable `[HIG]`; Genie/Scale, bounce 1-2 ciclos `[HIG]`; Dock autohide ~500ms `[INFERIDO]`. Reduce Motion → fade 150ms, sin bounce/parallax/Genie `[HIG]`.
Estados: hover/pressed = iluminación interna `[HIG]`; disabled 30-50% + sin hover; focus = anillo `accent` 2px + contraste 3:1; inactivo = gris `#DDD`, semáforos gris, sin vibrancy `[HIG]`.
A11y: contraste 4.5:1 (≤17pt) / 3:1 (grande/bold), objetivo 7:1 pequeño `[HIG]`; nunca solo color (icono+texto) `[HIG]`; todo IconButton con `Accessible.name` `[HIG]`; layout refluye a 135% `[HIG]`; sonidos propios <300ms −14LUFS + cue visual redundante `[HIG]`.

## 3. Componentes

- **Menu bar: 24pt** (48px@2x) `[HIG]`; notch 27/29/34/37/43pt según escala `[HIG]`; 100% transparente + `Show menu bar background` / Reduce Transparency lo opaca `[HIG]`; extras 22pt, icono ideal 16×16 `[HIG]`; fuente ~13pt `[INFERIDO]`; orden |app-bold|File…|Live Activities|extras|CC|privacy|Spotlight|Siri|reloj `[HIG]`; Cmd+drag reordena `[HIG]`; privacy naranja/morado/verde/flecha, prioridad cámara>mic `[HIG]`; OSD brillo/volumen se expande in-situ `[HIG]`; reloj siempre visible, clic abre NC `[HIG]`.
- **Ventana: semáforos 12px**, offset 8-9, gap 8 (centros ~19.9) `[HIG]`; `#FF5F57/#FEBC2E/#28C840` (±calibración) `[HIG]`; borde 0.5-1px rgba(0,0,0,.06-.1) `[INFERIDO]`; hover ×−+ 7×7 stroke 1.2 round `[HIG]`; inactivo gris + hover colorea `[HIG]`; titlebar ~28px, zona drag Tahoe ~50px con toolbar `[INFERIDO]`; título a la izquierda `[HIG]`; radio 16/26 concéntrico `[HIG]`; sombra activa `0 20-22px 30-50px rgba(0,0,0,.2-.7)` `[INFERIDO]`; verde=zoom, Opt=fullscreen, Cmd+Ctrl+F fullscreen→Space propio `[HIG]`; sheets inset + dimming si modal `[HIG]`; doble-clic = zoom/min/fill/nothing `[HIG]`.
- **Toolbar/sidebar:** vidrio flotante concéntrica, contenido debajo `[HIG]`; sidebar flotante separada del borde (override lab `…FloatingAppearance=false`) `[HIG]`; fila 24-28, sin color custom `[HIG]`.
- **Dock:** tilesize 16-128 (`defaults … tilesize`), defecto visual 48-64 `[HIG]`; largesize 16-128, curva proximidad `[HIG]`; bottom/left/right global `[HIG]`; Genie/Scale + minimizar-en-icono `[HIG]`; running dot ~4px `[INFERIDO]`; separador/spacer-tile, Trash siempre al final `[HIG]`; Grid/List/Fan stacks `[HIG]`; badge rojo; autohide delay ~0.5s `[INFERIDO]`; un solo Dock que salta al monitor con cursor `[HIG]`; recientes opcional; looks Default/Dark/Clear/Tinted + folder color `[HIG]`; padding/fondo vidrio `[INFERIDO]`.
- **Spotlight:** Cmd+Espacio toggle, Opt+Cmd+Espacio Finder-search `[HIG]`; overlay centrado tercio superior, ancho 600-700 `[INFERIDO]`; **Cmd+1..4 = Apps/Files/Actions/Clipboard** `[HIG]`; `/` filtra, `↑` historial, Tab busca-en-app, Return/Cmd-R/doble-clic/Espacio-QuickLook `[HIG]`; preview derecha + drag&drop `[HIG]`; 100+ acciones + App Intents + Shortcuts, Esc vuelve `[HIG]`; Quick Keys ≤12 `[A-Z0-9]` (sm/ar/ft…) `[HIG]`; clipboard texto <16384 sin formato, sin Passwords/Universal, Mail falla `[HIG]`; replicar tabla mh26783 completa.
- **Apps (NO Launchpad):** Tahoe elimina Launchpad: ventana centrada + Cmd+1, categorías fijas + Suggestions, vistas Icons/List, orden Category/Name, **sin carpetas/páginas/reorden** `[HIG]`; phantom Launchpad por Terminal rompe Spotlight `[HIG]`; workaround = carpeta Applications en Dock (Grid) `[HIG]`.
- **Mission Control/Spaces:** MC = capa ventanas + Spaces bar `[HIG]`; entrar Ctrl+↑/F3/swipe↑3-4/doble-tap2/hot corner `[HIG]`; drag a thumbnail mueve, drop en fullscreen crea Split `[HIG]`; Spaces `+`/reorden, cambio Ctrl+←/→ o swipe↔4 `[HIG]`; App Exposé swipe↓4, Show-Desktop spread, MC por display `[HIG]`; animación rejilla 300-500ms `[INFERIDO]`; sin rediseño Tahoe salvo vidrio `[HIG]`.
- **CC/notif/OSD/Settings/login/diálogos:** CC Fn+C, panel arriba-der, galería+`+`+drag+resize+multipanel+Reset, Timer/tiling/Shortcuts/Controls API, `Show in Menu Bar/Don't/When Active`, cabecera privacidad `[HIG]`; notif None/Banner/Alert, Banner ~5s `[INFERIDO]`, sonido/badge/previews Always/WhenUnlocked/Never, grouping, summaries `[HIG]`; NC = clic reloj o swipe←2, calendario+widgets arriba, lista por app `[HIG]`; widgets S/M/L al desktop, looks Default/Dark/Clear/Tinted `[HIG]`; folders 7 colores tag + picker + símbolo/emoji, no en System/Library `[HIG]`; lock = Liquid Glass + 6 tipografías reloj + Live Activities `[HIG]`; diálogo: default acento derecha, destructive izquierda `[HIG]`.

## 4. Mapeo Plasma/KDE

| Tahoe | Plasma | Fiel / aproximado |
|---|---|---|
| semáforos/titlebar/radio/sombra | plugin propio KDecoration3 `nimbus-decoration` (12px/gap8/inactivas/hover); Klassy solo fallback | fiel geometría+color+estados; sombra/borde `[INFERIDO]` medir |
| topbar/menús/CC/reloj/tray | barra layer-shell custom 24pt (`org.nimbus.bar`, port MacBar) + appmenu Qt, R-GTK in-window; panel stock 38px solo base temporal | fiel layout/altura; blur-live aproximado |
| Spotlight | KRunner `FreeFloating`+skin RunCommand + runners Nimbus (apps/archivos/ajustes/calc/web/clipboard) | fiel atajos/Cmd1-4/QuickKeys; ranking aproximado |
| Apps | Dashboard tematizado o layer-shell QtQuick (categorías+search, SIN carpetas) | fiel si respeta §3 |
| MC/Spaces | Overview stock tematizado (MVP) → efecto `nimbus-overview` QML | stock fiel thumbs; física fluido aproximada |
| Dock | layer-shell Krema (tema Nimbus, TaskManager libtaskmanager, kpipewire previews) | fiel tilesize/zoom/badge; refracción aproximada (ShaderEffectSource≠framebuffer) |
| Glass | KWin blur (fondo) + `liquidglass/dockglass.frag`+`GlassSlab` (lente/tint/specular/grano) + Kvantum (Qt) + SVG panel-background; tiers alto/bajo | fiel blur/tint/rim/grano/estados; dispersión/reflejos entre vidrios aproximados |
| Settings/onboarding | KCM Nimbus 6 págs + wizard + Calamares + ki18n/.ts único | fiel |
| Lock/OSD/notif/sonidos | kscreenlocker/SDDM/OSD/notificationmanager tematizados + sonidos propios | fiel salvo lock-tipografías (arte propio) |

## 5. Aceptación medible (valor · cómo · umbral → tareas)

| # | valor | comando/captura | umbral | actualiza |
|---|---|---|---|---|
| A1 | barra 24pt transparente | `kwshot` + medir px + diff `compare.sh` | diff<15%, h=24pt | F2-T05 (28px→24), F3-T12 |
| A2 | semáforos 12px/colores/offset/gap | captura + picker RGB | ±1px, ΔE colores calib. | F3-T02, F4-T01/T10 |
| A3 | radio 16/26 concéntrico | captura + `r_int=r_ext−pad` | 16/26 ±1 | F3-T01 (24/12→16/26), F4-T02 |
| A4 | contraste texto/vidrio 3 fondos×light/dark | test WCAG | AA (4.5:1/3:1) | F3-T01/T11, F11-T03 |
| A5 | Dock ≥55fps VM, boot<1s extra, RAM<150MB | qmlprofiler/contador, 15-30 apps | sin jank>2f | F0-T03, F5-T04/T11/T12 |
| A6 | Spotlight <50ms, Esc, Cmd1-4, QuickKeys, clip<16k | `qdbus6`, 20 consultas | <50ms, tabla mh26783 100% | F0-T04, F6-T01..T09 |
| A7 | Overview <300ms, 60fps, drag Spaces | 10-20 ventanas, vídeo | <300ms | F0-T04, F7-T09/T10 |
| A8 | hit ≥24px, objetivo 32-44 | pointer lab | 0 fallos | F4-T05, F11-T04 |
| A9 | Reduce Transparency/Motion/Contrast funcionales | toggles + captura | blur→sólido, springs→fade150 | F8-T05, F11-T02/T04 |
| A10 | i18n es/en 0 sin traducir | lint ki18n | 0 | F11-T05/T06 |

## 6. Rulings propuestos

- **R-TAHOE-TOKENS:** §2 es fuente única; prohíbe mágicos; F3-T01 se reescribe (fuera radios 24/12, gris `#598E8E93` como token).
- **R-MENUBAR:** altura 24pt (notch parametrizable `menuBarHeight`); F2-T05 28px = panel Plasma, no spec Apple.
- **R-TITLEBAR:** 16 sin toolbar / 26 con toolbar-sidebar, concéntrico; titlebar-only conserva radio pequeño.
- **R-APPSVIEW:** replicar Apps Tahoe (categorías, sin carpetas/páginas/reorden); F6-T04/T05 se reescriben; carpetas custom exigen Ruling nueva.
- **R-CONFIDENCE:** `[INFERIDO]` no acepta tarea; §5 fija comando+umbral.

## 7. Gaps y correcciones exactas

1. F2-T05 "panel 28px" contradice menu bar 24pt `[HIG]` → corregir a 24pt + nota Plasma.
2. F3-T01 tokens (radios 24/12, gris, Inter 12/13) contradicen §2 → reescribir con §2 + test contraste.
3. F3-T02/F4-T01 omiten offset 8-9/gap 8/colores exactos/hover SVG → añadir.
4. F4-T02 "28px, radio Tahoe" omite 16/26 concéntrico + título izquierda → añadir.
5. F5: fps 55 (F0) vs 60 (F5) → unificar: spike ≥55, producto 60 (A5).
6. F6-T04/T05 "Launchpad carpetas/paginación/drag" contradice eliminación Tahoe → reescribir a R-APPSVIEW; faltan Cmd1-4/QuickKeys/clip-límites → añadir a F6-T02/T03.
7. F3-T10/F10-T05 omiten OSD in-situ en menu bar → añadir.
8. F7 omite App Exposé/Show-Desktop/MC-por-display/Split-drag → añadir a F7-T07/T08.
9. F8-T01 dice "5 páginas" pero plan lista 6-7 (F8-T02..T07) → unificar a 6.
10. F11-T01/T02 sin duraciones/curvas/tiers → usar §2.5 + tiers GLASS §4.3; preferir blur stock antes de Better Blur.
11. Spec §2 "5 páginas KCM" vs plan 6-7 → corregir spec a 6.
12. UI §2 titlebar "~28px/toolbar ~50px" y sombras/Dock-padding/Spotlight-600-700/autohide-0.5s son `[INFERIDO]` → lista §5-A1/A2/A6 pendiente VM.
