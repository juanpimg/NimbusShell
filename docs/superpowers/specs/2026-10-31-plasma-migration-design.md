# Migración NimbusShell → Plasma 6 — diseño (2026-10-31)

## 1. Decisión

NimbusShell pasa a ser la **capa de personalización macOS Tahoe de NimbusOS
sobre Plasma 6/KWin**, con un único componente fuera de Plasma: el Dock
(layer-shell). Objetivo: 1:1 en la experiencia, user-friendly para
switchers de Windows/Mac, y mantenible por 1-2 personas + IA.

**Stack primario:** Plasma 6 (panel + KCM) + Klassy (decoración) + KRunner
(Spotlight) + KWin Effect QML/JS (Mission Control) + **Dock layer-shell
(Krema base/fork/theme)**. Nada más corre fuera de Plasma sin Ruling nueva.

**Rechazado:** compositor propio (6-10 personas-año), fork de KWin,
Quickshell-on-KWin como producción (KWin no tiene screencopy →
sin previews ni blur-live; Quickshell pre-1.0), mantener Hyprland y Plasma
en paralelo más allá de F1.

## 2. Componente macOS → contenedor real → API

| Componente | Contenedor | API | Reutilización MacShell | Esfuerzo |
|---|---|---|---|---|
| Barra superior + reloj + control center | Plasmoide en panel Plasma | Plasma Applet QML (`plasmoid.*`) | Layouts, tokens, lógica reloj/calendario; se descarta `PopupWindow`/IPC Hyprland | S (2-3 sem) |
| Menú global | Plasmoide appmenu | `org.kde.plasma.appmenu` + dbusmenu | Estilos QML | S |
| Semáforos/titlebar | Klassy (pin) + reglas KWin | KDecoration3 | Solo paleta; no había código MacShell (era CSS Hyprland) | S |
| Spotlight | KRunner fullscreen skin | KRunner API + DBus | Modelo fuzzy, índices; se descarta ventana Quickshell | M (3-4 sem) |
| Launchpad | Application Dashboard de Plasma (tematizado) o ventana QtQuick layer-shell | Plasma applet / layer-shell-qt | Grid, paginación, búsqueda | M |
| Mission Control / Spaces | KWin Effect QML | KWin Effect API (timeline, `ShaderEffect`) | Solo spec; MacShell delegaba en Hyprland | L (6-10 sem; MVP con Overview stock) |
| Dock + magnificación | **Layer-shell standalone (Krema fork/theme)** | layer-shell-qt + QtQuick + TaskManager DBus | Pins/running/badges + parte visual; se descarta anclaje a panel | M-L (4-6 sem) |
| Ajustes/onboarding | KCM + System Settings + Discover | KCM, PackageKit/Flatpak | Defaults JSON, i18n | S-M |
| Lock/OSD/notificaciones | KDE nativo tematizado | kscreenlocker, Plasma OSD, notificationmanager | Se descarta MacLock | S |

**Deuda layer-shell permitida:** solo el Dock. Dueño: shell-team. Decisión
en F2: fork Krema definitivo o containment custom; fecha límite 1.0.

## 3. Qué se reutiliza de MacShell

- **Port directo (QML/GLSL/JS puro):** shaders `liquidglass/dockglass`,
  `GlassSlab` y primitivas (SPopUp, Spring, Marquee, MorphText, EdgeBlur,
  Corner, MenuBorder), `I18n.js` + `lang/`, `Fonts.js`, `GlassShape.js`,
  widgets (Calendar/Clock/Weather/Player/Card), `ClockApp`, `AboutApp`,
  `PlayerArt`, `LiveWall`.
- **Port con backend nuevo:** MacBar (menús/CC/Spotlight layouts),
  MacDock (UI, pins, zoom curve → tema Krema), MacWidgets (modelo/grid).
- **Reescribir:** contenedores Quickshell (`PanelWindow`, `Variants`,
  `IpcHandler`), gestión de ventanas/workspaces, servicios
  (tray/MPRIS/PipeWire/notificaciones), geometría/backdrop, OSD/lock.
- **Descartar:** `hyprland.*`, `macshell.lua`, `hyprbars`, `macshell-start`
  con `qs -c`, `MacLock` shim, `WindowBar.qml`, `MinimizeFx` (sustituido por
  Magic Lamp de KWin).

**% de reutilización: no se publica hasta el inventario `cloc` de F0.**
Las cifras 50-55% (Plasma nativo) / 75-80% (Quickshell-on-KWin) son
provisionales y no contractuales.

## 4. Proyectos a integrar / contribuir

| Proyecto | Uso | Contribuir |
|---|---|---|
| **Klassy** | Decoración C++ con semáforos 12px, gris inactivo | Preset Tahoe + fixes HiDPI/light-dark |
| **Krema** | Dock Wayland layer-shell con zoom parabólico y previews | Tema Nimbus, popup placement, badges |
| **Panel Colorizer + Window Buttons6** | Topbar translúcida + botones en maximizadas | Presets Tahoe |
| **Better Blur / Glass + Rounded Corners** | Blur, refracción y esquinas | Fixes por release KWin; no fork completo |
| **KRunner** | Spotlight (skin fullscreen + runners) | Runner Nimbus (apps/archivos/atajos) |
| **KWin Overview / Present Windows** | Mission Control; Spaces con virtual desktops | Efecto Nimbus si el stock no llega |
| **Global Menu widget** | Menú global Qt/KDE | Documentar límite GTK; no `appmenu-gtk` Wayland |
| **Konsave / KCM / Calamares** | Presets, ajustes, onboarding | Branding Nimbus, wizard |
| **kwshot + qdbus6 + KWin scripting** | Tests de aceptación en VM | Harness versionado |
| **CachyOS** | Base ISO (pin) | Nada; consumir kernel/settings opcionales |

## 5. Estructura de repo propuesta

```
dotfiles/.config/plasma/{plasmarc,plasmashellrc,kwinrc,kglobalshortcutsrc,
  krunnerrc,kscreenlockerrc,kdeglobals}
dotfiles/.config/autostart/nimbus-shell.desktop
packages/plasma/plasmoids/org.nimbus.{bar,menu,controlcenter}/
packages/kwin/effects/nimbus-overview/
packages/kwin/scripts/nimbus-spaces/
packages/kcm/kcm_nimbus/            # 6 páginas: apariencia, red, atajos, a11y, sistema/usuarios, updates
packages/themes/{look-and-feel,desktoptheme,klassy-preset,icons,cursors}/
packages/dock/                      # fork/theme Krema o dependencia pinneada
apps/{nimbus-welcome,nimbus-migrate,nimbus-hw}/
iso/{calamares,profile}/            # netinstall primero
tests/{vm,golden,interaction}/
legacy/hyprland/                    # congelado, solo lectura
install.sh                          # --profile=plasma|legacy-hypr|--check
```

`install.sh` modular (`lib/{plasma,kwin,themes,dock,apps,verify}.sh`),
`set -u`, backups `~/.config/nimbusshell-backup-*`, sin root, `bash -n` +
`shellcheck -S warning` cero warnings, `--check` solo lectura.

## 6. Fases y aceptación

- **F0 — Spike + medición (2 sem). Go/no-go.**
  - T1 Dock layer-shell (Krema fork mínimo): zoom ≥55 fps en VM, 15 apps,
    sin jank >2 frames, fuera del panel.
  - T2 KRunner fullscreen skin: abre centrado, blur, <50 ms, Esc cierra,
    no rompe KRunner normal.
  - T3 KWin Overview mínimo: thumbs de 4 ventanas + switch, no crashea,
    toggle <300 ms.
  - Inventario `cloc` (portable / Quickshell / Hyprland) + matriz de apps
    (Qt, GTK, Electron, libadwaita) + golden propio.
  - No-go: se recorta el componente del MVP (Overview stock, Dock temporal)
    con Ruling.
- **F1 — Look MVP (3-4 sem):** topbar + Klassy + tema + Inter/iconos/fondo
  + KRunner skin. Aceptación: screenshot-diff vs golden <15% píxeles;
  sesión sin errores; qdbus6 smoke.
- **F2 — Dock + ventanas + Mission Control (4-6 sem):** Dock Krema,
  TaskManager, zoom; Klassy final; Overview/Spaces. Aceptación: launch/pin/
  unpin, zoom 60fps, drag entre Spaces, clic abre app.
- **F3 — User-friendly (4-6 sem):** KCM Nimbus, Discover simple, wizard 6
  pasos, migrador Win/Mac, toggle Cmd/Ctrl, Btrfs/snapper rollback, a11y.
  Aceptación: usuario nuevo llega a escritorio sin terminal; rollback
  revierte un update roto; Orca/teclado probados.
- **F4 — ISO netinstall (4-6 sem):** Calamares + perfil CachyOS pinneado,
  instalación en VM, primer arranque → wizard. ISO Full offline después.
- **Total (refinado en el plan maestro):** MVP 18-22 semanas; 1.0 9-12 meses con 1-2 personas + IA. Plan maestro con 112 tareas y ledger de progreso: `docs/superpowers/plans/2026-10-31-plasma-migration.md`.

## 7. Rulings

- **R-GTK:** menú global solo Qt/KDE; GTK/libadwaita/Electron usan menú
  in-window. No se persigue `appmenu-gtk` en Wayland. Excepción documentada
  del 1:1.
- **R-DOCK:** Dock layer-shell (Krema fork/theme); prohibido intentar zoom
  en panel (KDE bug 495100 WONTFIX).
- **R-KLASSY:** versión pinneada + CI de rebuild al subir Plasma; fallback
  KDecoration custom si el preset no alcanza.
- **R-APPLE:** cero activos Apple; golden screenshots propios (Inter, logo
  N, Sequoia NPS) para diffs.
- **R-ISO:** netinstall primero; ISO Full solo tras 2 semanas verde.
- **R-HYPR:** la migración es breaking change; migrador en 1.0, no en MVP.
- **R-CACHYOS:** perfil ISO pinneado + CI por snapshot; sin `latest`.

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| KWin/Klassy/Krema rompen por release | Pin + CI + ventana de prueba; vendor de presets, no forks completos |
| Dock no llega a 60fps | Spike T1; fallback Crystal Dock/panel temporal con Ruling |
| Overview custom se va de scope | MVP con Overview stock tematizado; efecto propio en 1.0 |
| Menú GTK rompe el 1:1 | R-GTK + matriz de apps + comunicación al usuario |
| CachyOS cadence | Pin snapshot; kernel opcional |
| A11y en superficies custom | Audit Orca/teclado en F3; no bloquear MVP |
| Burnout 1-2 personas | F0 gate, MVP corto, no forks, contribuir upstream |
| Activos Apple | R-APPLE; arte propio |

## 9. Qué NO hacer

- No compositor propio, no fork de KWin/Plasma/Quickshell.
- No Dock plasmoide con zoom; no `PopupWindow` Quickshell reciclado.
- No menú global GTK/Electron; no flags Firefox como requisito.
- No % de reutilización sin `cloc`; no timeboxes de 11 semanas.
- No ISO Full antes de netinstall; no CachyOS `latest`.
- No mantener Hyprland y Plasma en producción en paralelo.

## 10. Siguiente paso

Aprobar **F0** (2 semanas): tres pruebas de viabilidad + inventario LOC +
matriz de apps. Sin esas evidencias no se migra código.
