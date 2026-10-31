# TAHOE-UI — Anatomía exacta de la UI de macOS Tahoe 26 (research)

> Ámbito: NimbusShell (clon Tahoe 1:1). Solo investigación. No editar código/dotfiles.
> Fecha: 2026-10-31. Versión base: macOS Tahoe 26.0 (15-sep-2025); se cita 26.6/26.7.1 donde aplica.
> Regla del repo: todo lo que se vea o comporte distinto de un Mac real es un bug con nombre.

## Resumen (<30 líneas)

1. Tahoe 26 = re-skin Liquid Glass sobre la misma carcasa: menu bar 24pt ahora 100% transparente, ventanas más redondas, Dock/sidebars/toolbars de vidrio.
2. Semáforos siguen 12px, 8px offset, ~8px gap; colores #FF5F57/#FEBC2E/#28C840; hover ×−+; inactivo gris.
3. Radio de ventana ya no es único: 16pt sin toolbar, 26pt con toolbar/sidebar (concentricidad); título ahora alineado a la izquierda.
4. Sidebar flotante separada del borde + toolbar de vidrio concéntrica; desactivable con `NSSplitViewItemSidebarDefaultsToFloatingAppearance=false` (inferido útil para NimbusShell).
5. Dock: tilesize 16–128px, magnificación opcional, Genie/Scale, bounce al abrir, punto de running, autohide por borde; un solo Dock que salta al monitor con el cursor.
6. Launchpad MUERE en Tahoe: lo sustituyen Apps/Spotlight Cmd+1 (categorías, sin carpetas ni páginas personalizables).
7. Spotlight es el mayor cambio funcional: overlay con 4 modos Cmd+1..4 (Apps/Files/Actions/Clipboard), Quick Keys ≤12 caracteres, acciones con App Intents, historial clipboard.
8. Control Center totalmente editable (galería, drag a menu bar, paneles múltiples, resize); atajo Fn-C; OSD de brillo/volumen se expande dentro del menu bar.
9. Notificaciones: Banner (temporal) vs Alert (persistente); Notification Center = calendario+widgets a la derecha; previews Always/When Unlocked/Never.
10. Tipografía sistema SF Pro en todo; menu bar usa variante menuBarFont ~13pt; HIG tipográfico no cambia en Tahoe salvo titulares más bold/izquierda.
11. Liquid Glass = capa funcional flotante (regular/clear), refracta lo de debajo, `ConcentricRectangle` (fixed/capsule/concentric: r_interior = r_exterior − padding).
12. Gaps para NimbusShell: medidas de píxel de Spotlight/Control Center/sombras no están publicadas → inferir desde capturas + verificación en VM obligatoria.

---

## Cómo leer este doc

- Tabla canónica: `componente | propiedad | valor | fuente | confianza`.
- Confianza: **Alta** = HIG/Apple Support/WWDC/código medido; **Media** = prensa + 2 fuentes coincidentes; **Baja** = inferido de capturas/comunidad (marcado `[INFERIDO]`).
- URLs completas en columna fuente (sin acortar).
- Nada de activos propietarios: valores numéricos y descripciones, no imágenes de Apple.

---

## 1. Menu bar

Referencias madre:

- https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- https://support.apple.com/en-gb/guide/mac-help/mchlp1446/26/mac/26 (What's in the menu bar, Tahoe 26)
- https://support.apple.com/en-ie/guide/mac-help/mchlad96d366/26/mac/26 (Change Menu Bar settings)
- https://bjango.com/articles/designingmenubarextras (medidas 24pt/37pt notch)
- https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf (menu bar transparente, OSD expandido)

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| menu-bar | altura estándar | **24pt** (24px @1x, 48px @2x). Antes: 19pt (Sys1) → 21pt (OSX beta) → 22pt (Yosemite) → 24pt (Big Sur→Tahoe) | https://developer.apple.com/design/human-interface-guidelines/the-menu-bar ("menu bar's height is 24pt"); https://bjango.com/articles/designingmenubarextras | Alta |
| menu-bar | altura con notch (MBP 14/16") | **37pt** nominal; según escala: 27/29/34/37/43pt (14") y 33 en vez de 34 en el tramo medio (16") | https://bjango.com/articles/designingmenubarextras | Alta |
| menu-bar | fondo en Tahoe | **Completamente transparente**, deja ver el wallpaper ("makes display feel larger"). Opción `Show menu bar background` + `Reduce transparency` (Accessibility→Display) lo vuelve opaco | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://support.apple.com/en-ie/guide/mac-help/mchlad96d366/26/mac/26; https://nexasphere.io/blog/how-to-fix-macos-tahoe-menu-bar | Alta |
| menu-bar | auto-ocultado | `Automatically hide and show`: Never / In Full Screen Only / Always. Valor leído vía `NSMenu.menuBarHeight` (=0 si oculta) | https://support.apple.com/en-ie/guide/mac-help/mchlad96d366/26/mac/26; https://developer.apple.com/documentation/appkit/nsmenu/menubarheight | Alta |
| menu-bar | tipografía | SF Pro, variante `menuBarFont(ofSize:)`. Tamaño efectivo **~13pt** (estilo Body/Headline macOS: 13/16) `[INFERIDO]` | https://developer.apple.com/design/human-interface-guidelines/typography; https://github.com/rhast2ax/apple-hig-26/blob/main/foundations/typography.md | Media |
| menu-bar | color texto | Blanco/negro adaptativo según wallpaper + modo (claro/oscuro); template images (solo alfa) para extras | https://bjango.com/articles/designingmenubarextras | Alta |
| menu-bar | área útil extras | **22pt** de alto fijo aunque la barra mida 24–43pt; icono circular ideal **16×16pt** para igualar peso visual a items del sistema | https://bjango.com/articles/designingmenubarextras | Alta |
| menu-bar | orden izquierda→derecha |  menu \| app menu (bold) \| File/Edit/View/Window/Help… \| (Live Activities iPhone, Tahoe nuevo) \| extras sistema \| Control Center \| privacy dot \| Spotlight \| Siri \| Notification Center (reloj+fecha a la derecha del todo) | https://support.apple.com/en-gb/guide/mac-help/mchlp1446/26/mac/26; https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever | Alta |
| menu-bar | menús app | Obligatorios App/File/Edit/View/Window/Help (File omitible si no es doc-based); atajos estándar Cmd-Q/H/M etc. | https://github.com/ehmo/platform-design-skills/blob/main/skills/macos/SKILL.md; https://developer.apple.com/design/human-interface-guidelines/the-menu-bar | Alta |
| menu-bar | status items reorder | Cmd+arrastrar reordena; Cmd+arrastrar-fuera elimina (los de terceros dependen de la app) | https://support.apple.com/en-mz/guide/mac-help/mchlp1446/26/mac/26 | Alta |
| menu-bar | reloj | Siempre visible; `Clock Options`: formato fecha/hora, segundos, día, separadores | https://support.apple.com/en-ie/guide/mac-help/mchlad96d366/26/mac/26 | Alta |
| menu-bar | privacy indicators | Punto **naranja**=mic, **verde**=cámara, **morado**=audio sistema, **flecha**=localización; a la derecha de Control Center; solo uno visible (prioridad cámara>mic); panel detalle al abrir CC | https://support.apple.com/en-mz/guide/mac-help/mchlp1446/26/mac/26 | Alta |
| menu-bar | Live Activities (Tahoe) | Las de iPhone cercano aparecen compactadas en menu bar; clic expande debajo; texto a veces demasiado pequeño (crítica MacStories) | https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever; https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3 | Media |
| menu-bar | OSD brillo/volumen (Tahoe) | Sliders que **se expanden dentro del menu bar** al pulsar teclas de función, en vez de overlay central grande | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3 | Alta |
| menu-bar | modo oscuro | Afecta a menús, CC, sidebars; iconos/widgets con looks Default/Dark/Clear/Tinted (Appearance) | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://macmost.com/customizing-your-mac-with-icon-widget-styles.html | Alta |
| menu-bar | reloj+notificaciones | Clic en fecha/hora abre Notification Center (ya no icono separado) | https://support.apple.com/en-mz/guide/mac-help/mchlp1446/26/mac/26 | Alta |

---

## 2. Ventana (titlebar/toolbar, semáforos, sidebar, esquinas, sombra)

Referencias madre:

- WWDC25/310 Build an AppKit app with the new design: https://developer.apple.com/videos/play/wwdc2025/310/
- Lapcat (radios no uniformes): https://lapcatsoftware.com/articles/2026/3/1.html y https://lapcatsoftware.com/articles/2026/3/4.html
- Override descubierto: https://github.com/mansarip/mac-window-corners (+ https://talk.tidbits.com/t/adjust-tahoe-window-corner-radius/33791)
- Semáforos Tahoe medidos: https://github.com/aw3r1se/macOS-traffic-lights + https://www.npmjs.com/package/macos-traffic-lights
- Recopilatorio Big Sur (base aún válida): https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| semáforos | diámetro | **12×12px** (círculo, border-radius 50%). En Tahoe paquete SVG usa canvas 14×14pt sobre grid 28u (1u=1px @2x) `[ compatible ]` | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md; https://github.com/aw3r1se/macOS-traffic-lights | Alta |
| semáforos | posición | **left 8–9px, top 8–9px** (8px doc comunitario; 9px GPUI/macOS nativo). Contenedor ~52px ancho | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md; https://longbridge.github.io/gpui-component/docs/components/title-bar | Alta |
| semáforos | spacing | **gap 8px** (centros a ~19.89px); margen der 3.5–5px según implementación | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md; https://codepen.io/atdrago/pen/yezrBR | Alta |
| semáforos | colores activo | close **#FF5F57** (borde #E0443E), minimize **#FEBC2E** (≈#FFBD2E/#F8CE52 según fuente), maximize **#28C840** (≈#28C941/#27C93F/#5FCF65). Variación por calibración; trío canónico #FF5F57/#FEBC2E/#28C840 | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md; https://github.com/boriskrasko/macos-big-sur-terminal | Alta (con tolerancia) |
| semáforos | borde/anillo | stroke **~0.5–1px rgba(0,0,0,0.06–0.1)**; Tahoe añade rim medido del sistema (ver SVG) | https://codepen.io/atdrago/pen/yezrBR; https://github.com/aw3r1se/macOS-traffic-lights | Media |
| semáforos | hover | Muestra glifos **× / − / +** (SVG 7×7, stroke 1.2 round); pressed oscurece (ej. rojo #E0443E→activo) | https://codepen.io/icaromh/pen/PobPvvr; https://www.npmjs.com/package/macos-traffic-lights | Alta |
| semáforos | inactivo | Los 3 en **gris #DDD / rgba(0,0,0,0.05)** con borde oval; al pasar el puntero muestran hover coloreado igualmente | https://codepen.io/atdrago/pen/yezrBR; https://github.com/ceorkm/macos-design-skill/blob/main/references/layout-and-composition.md | Alta |
| semáforos | busy | Variante close con indicador de proceso en curso (icono `busy`) | https://www.npmjs.com/package/macos-traffic-lights | Media |
| titlebar | altura | **~28px** clásica; Tahoe con toolbar about **~50px** zona arrastrable superior (sidebar+topbar) `[INFERIDO de layouts]` | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md; https://github.com/ceorkm/macos-design-skill/blob/main/references/layout-and-composition.md | Media |
| titlebar | título Tahoe | Ahora **alineado a la izquierda** (antes centrado); documentado como regresión/estilo por Lapcat | https://lapcatsoftware.com/articles/2026/3/4.html | Media |
| titlebar | doble-clic | Zoom / Minimize / Fill / Nothing (Desktop & Dock → "Double-click a window's title bar") | https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta |
| toolbar | estilo Tahoe | **Liquid Glass flotante**, concéntrica con la ventana; contenido fluye por debajo (Safari tabs) | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://developer.apple.com/videos/play/wwdc2025/219/?time=996 | Alta |
| sidebar | estilo Tahoe | **Flotante** (separada del borde, sobre vidrio, tinte ambiental del contenido). Override: `defaults write -g NSSplitViewItemSidebarDefaultsToFloatingAppearance -bool false` | https://developer.apple.com/videos/play/wwdc2025/310/ (vía https://lapcatsoftware.com/articles/2026/3/4.html); https://talk.tidbits.com/t/adjust-tahoe-window-corner-radius/33791 | Alta |
| ventana | radio esquina Tahoe | **16pt sin toolbar / 26pt con toolbar o sidebar**. Lógica: radio = concéntrico al elemento superior (search icon 26pt). Titlebar-only conserva radio pequeño | https://lapcatsoftware.com/articles/2026/3/1.html; https://lapcatsoftware.com/articles/2026/3/4.html; https://github.com/mansarip/mac-window-corners; https://www.reddit.com/r/MacOSBeta/comments/1lb2jt5/window_corner_radius_in_macos_tahoe_depends_on | Alta |
| ventana | radio pre-Tahoe | **10–11px** (Big Sur/Sequoia). Presets útiles: Sharp 0, Subtle 4, Classic 10 | https://github.com/mansarip/mac-window-corners; https://github.com/m4rkw/macos-corner-fix | Alta |
| ventana | override radio (privado) | `defaults write -g NSConvolutionOverride1 -float 10` (windows/sheets/alerts) + `NSConvolutionOverride2` (panels); 0 se ignora → usar 0.01 para square `[solo NimbusShell-lab, no producción]` | https://github.com/mansarip/mac-window-corners; https://talk.tidbits.com/t/adjust-tahoe-window-corner-radius/33791 | Media |
| ventana | borde | Hairline 0.5px separador + borde vidrio sutil; no documentado exacto `[INFERIDO]` | — (inspección visual pendiente en VM) | Baja |
| ventana | sombra | Activa `0 20–22px 30–50px rgba(0,0,0,0.2–0.7)` según tema; inactiva `rgba(244,244,244,0.9)` fondo | https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md | Media |
| ventana | zoom/fullscreen | Verde = zoom (opt=fullscreen); `Cmd+Ctrl+F` fullscreen; fullscreen crea Space propio en Spaces bar | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27; https://github.com/ehmo/platform-design-skills/blob/main/skills/macos/SKILL.md | Alta |
| ventana | sheets/diálogos | Radio aumentado, half-sheet inset (deja ver contenido debajo); al expandir → más opaco; dimming layer si es modal bloqueante | https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | Alta |

---

## 3. Dock

Referencias madre:

- https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 (Desktop & Dock settings)
- MDM keys ( Medidas exactas ): https://developer.apple.com/documentation/devicemanagement/dock
- https://appish.app/blog/customize-mac-dock-icons-folders-themes ; https://joshtronic.com/2024/12/15/set-dock-icon-size-on-macos-cli

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| dock | tamaño icono | Slider `tilesize` **16–128** (px/pt). Set exacto: `defaults write com.apple.dock tilesize -int 48 && killall Dock` | https://developer.apple.com/documentation/devicemanagement/dock; https://joshtronic.com/2024/12/15/set-dock-icon-size-on-macos-cli | Alta |
| dock | estándar visual | Defecto típico **~48–64px** según pantalla; iconos 1024px master, radio Dock-icon ~12px @48px `[INFERIDO]` | https://github.com/ehmo/platform-design-skills/blob/main/skills/macos/SKILL.md; https://github.com/golepu/bigsur-design-specs/blob/main/macos-big-sur-design-specs.md | Media |
| dock | magnificación | Toggle + slider `largesize`/`magnification` **16–128**; iconos crecen al hover (curva de proximidad, no lineal) `[INFERIDO curva]` | https://developer.apple.com/documentation/devicemanagement/dock; https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta |
| dock | posición | bottom / left / right (global, no por monitor) | https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta |
| dock | minimizar efecto | Genie o Scale (`mineffect`); "Minimize into application icon" opcional | https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta |
| dock | bounce (apertura) | `launchanim` (Animate opening applications): **salto vertical** 1–2 ciclos hasta quedar fijo | https://developer.apple.com/documentation/devicemanagement/dock; https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta |
| dock | running dots | `show-process-indicators`: punto **~4px** bajo icono (negro claro / blanco oscuro) | https://developer.apple.com/documentation/devicemanagement/dock; https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0 | Alta (tamaño Media `[INFERIDO]` ~4px) |
| dock | separadores | Línea vertical entre apps / stacks-trash; spacer custom: `persistent-apps -array-add '{"tile-type"="spacer-tile";}'` | https://appish.app/blog/customize-mac-dock-icons-folders-themes | Media |
| dock | stacks | Carpeta en Dock: vista Grid / List / Fan (auto según nº items); Tahoe Apps-folder → Grid alfabético `[INFERIDO fan en desuso]` | https://eshop.macsales.com/blog/97761-missing-launchpad-after-upgrading-to-macos-tahoe-heres-how-to-get-it-back | Media |
| dock | trash | Siempre al final (derecha/abajo); vaciado con badge/contador en Finder | https://support.apple.com/en-bh/guide/mac-help/dock-mh35859/10.15/mac/10.15 (vía settings) | Alta |
| dock | menús | Clic derecho: opciones app, recientes, mostrar en Finder, abrir al iniciar; badge rojo con nº | https://github.com/ehmo/platform-design-skills/blob/main/skills/macos/SKILL.md | Alta |
| dock | autohide | `Automatically hide and show`; delay ~0.5s `[INFERIDO]`, reveal al tocar borde; magnification ayuda si hay muchos iconos | https://support.apple.com/en-bh/guide/mac-help/mchlp1119/15.0/mac/15.0; https://discussions.apple.com/thread/255788259 | Alta (delay Baja) |
| dock | multi-monitor | **Un solo Dock**: salta a la pantalla con el cursor / abajo del Space activo; sin réplicas | https://appish.app/blog/customize-mac-dock-icons-folders-themes | Alta |
| dock | recientes | `show-recents`: sección sugeridas/recientes al extremo derecho | https://developer.apple.com/documentation/devicemanagement/dock | Alta |
| dock | Tahoe looks | Iconos multicapa Liquid Glass: Default / Dark / Clear / Tinted (+ folder color global y por carpeta) | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://macmost.com/customizing-your-mac-with-icon-widget-styles.html | Alta |
| dock | padding/fondo Tahoe | Vidrio flotante con highlights especulares; métricas de padding no publicadas `[INFERIDO de capturas]` | https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design | Baja |

---

## 4. Spotlight (biggest update ever, Tahoe)

Referencias madre:

- https://support.apple.com/en-ie/guide/mac-help/mh26783/mac (atajos)
- https://support.apple.com/guide/mac-help/take-actions-and-shortcuts-in-spotlight-mchl4953dfeb/mac (acciones/quick keys)
- https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf (browse modes)
- https://www.computerworld.com/article/4041433/spotlight-is-much-better-in-macos-tahoe-heres-whats-new.html ; https://macmost.com/how-to-use-the-spotlight-clipboard-history-in-macos-tahoe.html

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| spotlight | invocación | **Cmd+Espacio** abre/cierra; **Opt+Cmd+Espacio** Finder con búsqueda; icono en menu bar opcional | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac | Alta |
| spotlight | overlay | Centrado horizontal, tercio superior; blur/material vidrio; un solo campo + iconos de modo a la derecha (Tahoe) `[geometría exacta INFERIDA, medir en VM]` | https://www.macworld.com/article/2644146/macos-26-features-latest-update-release-date-beta.html; https://www.idownloadblog.com/2025/08/06/how-to-use-new-spotlight-search-mac | Media |
| spotlight | tamaño | Ancho ~600–700px `[INFERIDO de capturas]`; alto crece con resultados/preview | — (pendiente captura VM) | Baja |
| spotlight | search field | Placeholder contextual; `/` filtra; `↑` historial; `Tab` tras nombre de app = buscar dentro de esa app | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac; https://www.idownloadblog.com/2025/08/06/how-to-use-new-spotlight-search-mac | Alta |
| spotlight | modos browse | **Cmd+1 Apps / Cmd+2 Files / Cmd+3 Actions / Cmd+4 Clipboard** (o → 1–4 veces) | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac; https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Alta |
| spotlight | resultados | Agrupados + ranking inteligente (hora/rutina, recientes, personalizadas con parámetros pre-rellenados); `↓/↑` navegar, `Return` abrir, `Cmd` ver path, `Cmd-R/doble-clic` mostrar en app, `Espacio` Quick Look | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac; https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Alta |
| spotlight | previews | Panel derecho con preview + acciones (Open, Copy, Open in Browser para URLs Safari; drag&drop desde clipboard) | https://macmost.com/how-to-use-the-spotlight-clipboard-history-in-macos-tahoe.html | Media |
| spotlight | acciones | **100+ built-in** (crear evento, grabar audio, reproducir podcast, mandar mensaje…) + App Intents terceros + Shortcuts; `Esc` vuelve a búsqueda | https://support.apple.com/guide/mac-help/take-actions-and-shortcuts-in-spotlight-mchl4953dfeb/mac; https://www.computerworld.com/article/4041433/spotlight-is-much-better-in-macos-tahoe-heres-whats-new.html | Alta |
| spotlight | quick keys | Strings **≤12 chars [A-Z0-9]**, ej. `sm`=send message, `ar`=add reminder, `ft Ashely`=llamar; se auto-sugieren tras 1 uso; gestión en vista Actions | https://support.apple.com/guide/mac-help/take-actions-and-shortcuts-in-spotlight-mchl4953dfeb/mac; https://www.computerworld.com/article/4041433/spotlight-is-much-better-in-macos-tahoe-heres-whats-new.html | Alta |
| spotlight | clipboard | Historial texto/imagen/link/fichero; **texto <16384 chars, sin formato, sin passwords de Passwords.app, sin Universal Clipboard, algunas apps (Mail) fallan**; doble-clic pega, botón lateral = set-clipboard, Ctrl-clic = Paste/Copy | https://macmost.com/how-to-use-the-spotlight-clipboard-history-in-macos-tahoe.html | Alta |
| spotlight | ranking/filtros | Filtros por tipo (`/screenshots`, texto dentro de screenshots), iCloud Drive/Finder vía Tab, menús de la app activa buscables, Siri/ChatGPT fallback | https://www.apple.com/my/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Alta |
| spotlight | atajos tabla | Ver tabla Apple Support mh26783 (general + narrow). NimbusShell debe replicar todos | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac | Alta |

---

## 5. Launchpad → Apps (Tahoe lo elimina)

Referencias madre:

- https://www.macworld.com/article/2830963/macos-tahoe-apps-replaces-launchpad.html
- https://www.macrumors.com/2025/06/09/macos-tahoe-launchpad-app-library
- https://macmost.com/how-to-use-the-new-spotlight-applications-launcher.html

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| launchpad (≤Sequoia) | layout | Fullscreen grid paginado, iconos arrastrables, **carpetas con nombre**, páginas custom, search arriba, gesto pinch pulgar+3 dedos / F4 / hot corner | https://support.apple.com/en-us/102482; https://eshop.macsales.com/blog/97761-missing-launchpad-after-upgrading-to-macos-tahoe-heres-how-to-get-it-back | Alta |
| launchpad (≤Sequoia) | drag | Arrastrar icono sobre otro = crear carpeta; reorden entre páginas | https://www.macworld.com/article/2830963/macos-tahoe-apps-replaces-launchpad.html | Alta |
| apps (Tahoe) | qué es | Sustituto: ventana centrada pequeña + modo Spotlight Cmd+1; **categorías fijas** (Utilities/Productivity/Creativity/Social/…) + Suggestions arriba; vistas Icons/List, orden Category/Name | https://www.macrumors.com/2025/06/09/macos-tahoe-launchpad-app-library; https://www.macworld.com/article/2830963/macos-tahoe-apps-replaces-launchpad.html | Alta |
| apps (Tahoe) | qué NO tiene | **Sin carpetas, sin páginas, sin reorden manual**; phantom Launchpad (alias tenue) solo compat scripts en betas; en release rompe Spotlight si se fuerza por Terminal | https://www.macworld.com/article/2830963/macos-tahoe-apps-replaces-launchpad.html; https://www.macworld.com/article/2846899/this-terminal-trick-brings-back-launchpad-on-macos-26.html | Alta |
| apps (Tahoe) | workarounds | Applications folder en Dock (Grid), alias manuales, Launchie/LaunchOS de terceros | https://eshop.macsales.com/blog/97761-missing-launchpad-after-upgrading-to-macos-tahoe-heres-how-to-get-it-back; https://www.wired.com/story/how-to-bring-back-launchpad-in-macos | Media |
| nimbus-ruling | decisión | NimbusShell replica **Apps Tahoe** (no Launchpad clásico): categorías + search + Cmd+1; carpetas custom = fuera de alcance salvo Ruling explícita | — (decisión de diseño, no Apple) | — |

---

## 6. Mission Control / Spaces (+ App Exposé)

Referencias madre:

- https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27
- https://support.apple.com/en-us/102482 (gestos)
- https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/27/mac/27

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| mission-control | qué muestra | Todas las ventanas del desktop activo en una capa + **Spaces bar** arriba (thumbnails de Spaces, fullscreen, Split View) | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27 | Alta |
| mission-control | entrar/salir | Trackpad **swipe ↑ 3 dedos** (algunas versiones 4), Magic Mouse **doble-tap 2 dedos**, teclado **Ctrl+↑ / tecla MC / F3**, hot corners | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27; https://support.apple.com/en-us/102482 | Alta |
| mission-control | animación | Rejilla con física de fluido, ventanas escalan sin solape; duración ~0.3–0.5s `[INFERIDO, medir en VM]` | — | Baja |
| mission-control | drag | Arrastrar ventana a thumbnail de Space = mover; arrastrar sobre app fullscreen = crear Split View; `Cmd+MC` muestra desktop para soltar ficheros | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27 | Alta |
| spaces | gestión | `+` al pasar cursor a la derecha del Spaces bar; reorden por drag; fullscreen/Split auto-crean Space; prefs en Desktop & Dock → Mission Control | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27 | Alta |
| spaces | cambio | **Swipe ↔ 4 dedos** (3 en algunas versiones), **Ctrl+←/→**, Cmd+Tab aparte | https://support.apple.com/en-us/102482 | Alta |
| app-exposé | gesto | **Swipe ↓ 4 dedos** (3 en algunas versiones): todas las ventanas de la app activa | https://support.apple.com/en-us/102482 | Alta |
| show-desktop | gesto | Spread pulgar+3 dedos; `Cmd+MC` temporal | https://support.apple.com/en-us/102482 | Alta |
| multi-monitor | comportamiento | MC por display: solo ventanas/spaces de ese monitor | https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27 | Alta |
| tahoe-delta | cambios | Sin rediseño anunciado; mismo modelo + vidrio sutil. Tiling de ventanas (Sequoia→) convive | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Media |

---

## 7. Control Center, notificaciones, OSD, Settings, lock/login, diálogos

### 7a. Control Center

Madre: https://support.apple.com/guide/mac-help/quickly-change-settings-mchl50f94f8f/26/mac/26 ; https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3 ; https://soundsupport.biz/2026/07/22/control-center-is-improved-and-highly-customizable-in-macos-26-tahoe

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| control-center | apertura | Icono en menu bar (derecha) o **Fn+C**; panel anclado arriba-derecha | https://soundsupport.biz/2026/07/22/control-center-is-improved-and-highly-customizable-in-macos-26-tahoe | Alta |
| control-center | Tahoe nuevo | **Galería tipo widgets** (sidebar categorías+search), `+` verde para añadir a CC o a menu bar, drag&drop libre, **resize de controles, múltiples paneles** (ej. panel HomeKit), Reset abajo del todo | https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3; https://soundsupport.biz/2026/07/22/control-center-is-improved-and-highly-customizable-in-macos-26-tahoe | Alta |
| control-center | controles nuevos | Timer, window tiling, Shortcuts (cualquier shortcut/colección), controles terceros vía Controls API (ej. Cardhop) | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf; https://soundsupport.biz/2026/07/22/control-center-is-improved-and-highly-customizable-in-macos-26-tahoe | Alta |
| control-center | menu-bar-only | System Settings→Control Center→ `Show in Menu Bar / Don't Show / Show When Active` por módulo | https://nexasphere.io/blog/how-to-fix-macos-tahoe-menu-bar | Alta |
| control-center | privacidad | Cabecera con app usando mic/cámara/pantalla/localización reciente → abre Privacy | https://soundsupport.biz/2026/07/22/control-center-is-improved-and-highly-customizable-in-macos-26-tahoe | Alta |

### 7b. Notificaciones + Notification Center

Madre: https://developer.apple.com/design/human-interface-guidelines/notifications ; https://support.apple.com/en-asia/guide/mac-help/mh40583/mac ; https://appleinsider.com/articles/26/02/17/how-to-manage-notifications-on-mac

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| notificación | estilos | **None / Banners / Alerts** por app; Banner=temporal auto-dismiss (~5s `[INFERIDO]`, `bannerTime` ya no funciona desde 10.10); Alert=persistente hasta dismiss | https://support.apple.com/en-asia/guide/mac-help/mh40583/mac; https://appleinsider.com/articles/21/06/15/how-to-make-mac-notifications-show-longer-or-leave-faster | Alta (timeout Baja) |
| notificación | opciones | Sonido, badge, previews (Always/When Unlocked/Never), grouping (Automatic/por cuenta), time-sensitive/critical, summaries con Apple Intelligence | https://support.apple.com/en-asia/guide/mac-help/mh40583/mac; https://appleinsider.com/articles/26/02/17/how-to-manage-notifications-on-mac | Alta |
| notification-center | apertura | Clic en **fecha/hora** (extremo derecho menu bar); swipe ← 2 dedos desde borde derecho | https://support.apple.com/en-mz/guide/mac-help/mchlp1446/26/mac/26 | Alta |
| notification-center | layout | Columna derecha: arriba calendario/widgets, abajo lista agrupada por app; widgets S/M/L arrastrables al desktop (Tahoe, look Liquid Glass) | https://9to5mac.com/2025/09/15/macos-tahoe-26-now-available-heres-what-to-test-first; https://www.thetechtips.blog/customize-macos-notification-center | Media |
| notificación | anatomía HIG | Icono app/avatar grande en comunicación, título, cuerpo, acciones; no usar para errores (usar Alert) | https://developer.apple.com/design/human-interface-guidelines/notifications | Alta |

### 7c. OSD / Settings / lock-login / diálogos

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| OSD | volumen/brillo (Tahoe) | Pill del menu bar que se expande in-situ (ver §1); resto de OSD legacy centrado con blur `[parcial INFERIDO]` | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Media |
| settings | apariencia Tahoe | Appearance → Color Themes (Multicolor/acento), **Icon & Widget Style: Default/Dark/Clear/Tinted**, Folder Color global + per-folder (tag) + símbolo/emoji | https://macmost.com/customizing-your-mac-with-icon-widget-styles.html; https://www.idownloadblog.com/2025/06/26/customize-mac-folder-icon | Alta |
| folders | custom | Clic derecho → Customize Folder: 7 colores tag + picker + símbolos/SF + emoji; no en Applications/Library/System/Users; sync iCloud | https://www.idownloadblog.com/2025/06/26/customize-mac-folder-icon; https://macmost.com/how-to-customize-folders-in-macos-tahoe.html | Alta |
| lock/login | Tahoe | Fondo Liquid Glass, reloj con **6 tipografías** elegibles, Contact Posters en FaceTime, Live Activities | https://www.apple.com/os/pdf/All_New_Features_macOS_Tahoe_Sept_2025.pdf | Media |
| diálogos/sheets | HIG | Botón default (acento) a la derecha, destructive a la izquierda; sheets ancladas al titlebar con dimming; alerts centrados modales | https://developer.apple.com/design/human-interface-guidelines/notifications (ver Alerts); https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | Alta |
| atajos globales clave | lista mínima | Cmd-Espacio Spotlight, Opt-Cmd-Espacio Finder-search, Ctrl-↑ MC, Ctrl-←/→ Spaces, Fn-C CC, Shift-Cmd-A Applications, Cmd-1..4 modos SP, `/` filtrar, `↑` historial | https://support.apple.com/en-ie/guide/mac-help/mh26783/mac; https://support.apple.com/guide/mac-help/view-open-windows-spaces-mission-control-mh35798/27/mac/27 | Alta |

---

## 8. Tahoe-specific: Liquid Glass, sidebars flotantes, radios concéntricos, nuevo CC/Spotlight

Madre: https://developer.apple.com/documentation/technologyoverviews/liquid-glass ; WWDC25/219 https://developer.apple.com/videos/play/wwdc2025/219/ ; WWDC25/356 https://developer.apple.com/videos/play/wwdc2025/356/ ; HIG Materials https://developer.apple.com/design/human-interface-guidelines/materials ; Adopting https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass

| componente | propiedad | valor | fuente | confianza |
|---|---|---|---|---|
| liquid-glass | qué es | Material dinámico que **refracta/refleja en tiempo real** (lensing), no solo blur; forma **capa funcional flotante** de navegación/controles sobre el contenido | https://developer.apple.com/documentation/technologyoverviews/liquid-glass; https://developer.apple.com/videos/play/wwdc2025/219/?time=996 | Alta |
| liquid-glass | variantes | **regular** (defecto legible) y **clear** (solo sobre fondos ricos); `.glassEffect(.regular.tint(.orange).interactive())`, no aplicar en capa de contenido, con moderación | https://developer.apple.com/design/human-interface-guidelines/materials; https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views | Alta |
| liquid-glass | comportamiento | Aparece por **materialize** (modula lensing, no fade); luz interna al interactuar; al profundizar (drag sheet ↑) se vuelve más opaco+grande; respeta Reduce Transparency/Contrast | https://developer.apple.com/videos/play/wwdc2025/219/?time=996 | Alta |
| liquid-glass | superficies | Dock, menu bar (transparente), sidebars, toolbars, tab bars, widgets, app icons multicapa (specular highlights), sheets | https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design | Alta |
| concentricidad | tipos | **fixed** (radio constante) / **capsule** (r=h/2) / **concentric** (r_interior = r_exterior − padding); API `ConcentricRectangle`, `.rect(corners:isUniform:)` | https://developer.apple.com/videos/play/wwdc2025/356/?time=376; https://developer.apple.com/documentation/swiftui/concentricrectangle | Alta |
| concentricidad | reglas | Controles de vidrio anidan concéntricos en esquinas de ventana; en Mac usar forma concéntrica al borde (no cápsula con margen como en iPhone); fallback radius si el componente vive solo; revisar contenido pegado a esquinas (WebKit clip bug) | https://developer.apple.com/videos/play/wwdc2025/356/; https://github.com/WebKit/WebKit/commit/643493bea2f9824959ebb9824bfb011aedf7498c (vía https://lapcatsoftware.com/articles/2026/3/1.html) | Alta |
| sidebar/toolbar | receta | Sidebar flotante + toolbar vidrio concéntrica; mayor row height/padding en listas, secciones más redondas; no customizar bars con color (agrupar por layout) | https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass; https://wwdcnotes.com/documentation/wwdcnotes/wwdc25-356-get-to-know-the-new-design-system/ | Alta |
| iconos Tahoe | sistema | Capas bold simples, Icon Composer, auto-tint claro/oscuro, Clear adopta fondo; consistentes cross-device y concéntricos | https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | Alta |
| nuevo CC/SP | delta | Ver §4 y §7a; son **el cambio funcional** de Tahoe junto a Phone/Live Activities, Shortcuts+Apple Intelligence, Journal/Games | https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever | Alta |
| tipografía Tahoe | delta | Más bold, alineada a izquierda, jerarquía estable; SF Pro/Compact/Rounded + NY; sin Dynamic Type en macOS | https://wwdcnotes.com/documentation/wwdcnotes/wwdc25-356-get-to-know-the-new-design-system/; https://developer.apple.com/design/human-interface-guidelines/typography | Alta |

---

## Gaps → verificación VM obligatoria (NimbusShell)

1. Ancho/alto exacto del overlay Spotlight Tahoe y del panel Control Center (medir en captura con detección de píxeles + `hyprctl cursorpos`).
2. Padding/gap del Dock Tahoe y radio de su fondo vidrio.
3. Sombras/bordes de ventana Tahoe (color manager mediante).
4. Duraciones/curvas de animación (MC, Genie, bounce, materialize) — cronometrar a 60fps.
5. Tamaño del punto running, grosor del separador Dock, altura de filas de menú (22–24px?).
6. Comportamiento notch (37pt) en pantallas 16:9 sin notch vs MBP — NimbusShell debe parametrizar `menuBarHeight`.
7. Spotlight clipboard límites (16k chars) y exclusiones — replicar como spec de privacidad.

## Fuentes top (re-verificar antes de implementar)

- HIG menu bar / materials / typography / notifications / designing for macOS (developer.apple.com).
- Apple Support Tahoe 26: menu bar (mchlp1446, mchlad96d366), Spotlight shortcuts (mh26783), Actions (mchl4953dfeb), Mission Control (mh35798), Desktop & Dock (mchlp1119), Notifications (mh40583).
- Apple PDF All New Features Tahoe Sept 2025 + newsrooms Liquid Glass + macOS Tahoe.
- WWDC25 219 (Meet Liquid Glass), 356 (design system), 310 (AppKit new design), 102 (Platforms State of Union).
- Medidas comunitarias verificables: Bjango (menu extras), aw3r1se/macos-traffic-lights (Tahoe SVG), mansarip/mac-window-corners + TidBITS (radios/override), Lapcat (corner essay), MacStories/Computerworld/MacMost (CC/Spotlight hands-on).
