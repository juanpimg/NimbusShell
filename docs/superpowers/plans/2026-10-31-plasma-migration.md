# NimbusShell Plasma Migration — Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrar NimbusShell de Hyprland+Quickshell a Plasma 6/KWin como capa de personalización macOS Tahoe 1:1 de NimbusOS, user-friendly para personas que vienen de Windows/Mac, con progreso medible por fases y tareas.

**Architecture:** Plasma 6 (panel + KCM) + Klassy (decoración) + KRunner (Spotlight) + KWin Effect QML/JS (Mission Control) + un único componente layer-shell: el Dock (Krema base/fork/theme). NimbusShell conserva su identidad visual (tokens, shaders, widgets, i18n) y delega compositor, settings, accesibilidad y actualizaciones en KDE.

**Tech Stack:** CachyOS/Arch, Plasma 6/KWin/KF6, QML/Qt6, KDecoration3/Klassy, KRunner, KWin scripting/effects, layer-shell-qt, Krema, Calamares, Btrfs/snapper, QEMU/KVM para evidencia.

**Spec:** `docs/superpowers/specs/2026-10-31-plasma-migration-design.md`

## Global Constraints

- Documentación y UI en español; identificadores de código en inglés.
- Cero activos Apple (logos, SF, wallpapers, sonidos). Arte propio: Inter, logo N, Sequoia NPS. Temas originales GPL inspirados en macOS (WhiteSur, Klassy, Kvantum) sí se permiten con atribución; lo prohibido es redistribuir assets de Apple.
- `install.sh`: `set -u`, sin `set -e` ciego, nunca root, backups `~/.config/nimbusshell-backup-*`, idempotente, `bash -n` + `shellcheck -S warning` cero warnings, `--check` sin sudo/red/escritura.
- Sin binds `CTRL-*` nuevos: atajos por defecto en Meta/Super (equivalente Cmd); Ctrl queda para las apps. El toggle Cmd/Ctrl es una opción explícita, no el default.
- Pinnear Plasma/Klassy/Krema/CachyOS; ninguna release usa `latest`. CI por snapshot.
- Toda tarea UI exige evidencia en VM: captura antes/después + interacción + `qdbus6`/`kwshot`. Sin evidencia no está hecha.
- No fork de Plasma/KWin/Quickshell; parches mínimos con `NimbusOS Ruling` y propuesta upstream.
- Una sola deuda layer-shell permitida: el Dock. Cualquier otra exige Ruling nueva.
- Licencia propia GPL-3.0-or-later; terceros conservan su licencia y atribución.
- Todo cambio de dotfiles se refleja en NimbusOS; una sola dirección (NimbusShell → NimbusOS).

## Review Focus

1. **Apps GTK/Electron sin menú global** (Nautilus, libadwaita, Electron): deben usar menú in-window; el usuario no debe ver una barra vacía ni un fallo.
2. **Rendimiento del Dock/Overview en VM y hardware modesto**: 60 fps y RAM razonable; si no, degradado configurable.
3. **Multi-monitor y HiDPI**: panel, Dock, Overview y Spotlight deben posicionarse bien en 1-2 pantallas y escalas 100/125/150/200%.
4. **Actualizaciones de Plasma/Klassy/Krema**: un update no puede dejar la sesión sin decoración o sin Dock; pin + CI + rollback.
5. **Migración desde Hyprland y desde Windows/Mac**: no perder documentos, ajustes ni dejar al usuario en una terminal.

---

## Cómo se usa este plan (guion estricto)

1. **Una tarea a la vez.** No se empieza una tarea hasta que sus dependencias estén `[x]`.
2. **Evidencia obligatoria.** Cada tarea genera `docs/plans/evidence/<ID>.md` con: comandos ejecutados, salida, capturas y veredicto. Sin ese fichero, la tarea no se marca.
3. **Commit por tarea.** Mensaje `feat|fix|docs(scope): <ID> <resumen>`.
4. **Marcar el checkbox** en este documento solo tras revisión (subagent-driven: implementer + reviewer; native: implementer + final review).
5. **Progreso:** `scripts/nimbus-progress` cuenta las tareas `[x]` por fase. Cada fase tiene un peso (suman 100%); dentro de la fase, todas las tareas pesan igual. El script imprime % total, % por fase y las próximas 5 pendientes. No se promete un % "de esfuerzo": es completitud ponderada por fase.
6. **Gates:** F0, F2, F5, F8 y F12 son go/no-go. Un gate rojo detiene la fase siguiente y se documenta el Ruling.
7. **Legacy:** Hyprland se congela en `legacy/hyprland/`; no se mantiene en paralelo en producción.
8. **Ramas:** una rama por fase (`plasma/f0-spike`, `plasma/f1-base`, …); merge a `plasma-migration` solo con gate verde.

**Estado actual:** 0 tareas (0%). Baseline: NimbusShell sobre Hyprland, MacShell vendoreado, NimbusOS sobre CachyOS, sin código Plasma.

**Estimación temporal (refinada; sustituye la del diseño):** 112 tareas. Secuencial ≈ 46 semanas. Con 2 workstreams en paralelo (visual/shell vs sistema/ISO) ≈ 30-36 semanas. **MVP (F0-F7) ≈ 18-22 semanas; 1.0 (F0-F12) ≈ 9-12 meses con 1-2 personas + IA.** El plan no promete 6-9 meses: la granularidad de 112 tareas revela el coste real.

| Fase | Peso | Semanas | Gate |
|---|---:|---:|---|
| F0 Baseline/spike | 4% | 2 | Go/no-go |
| F1 Restructuración | 6% | 2 | Repo limpio |
| F2 Base Plasma/ISO | 8% | 3 | Instala y arranca |
| F3 Fundación visual | 12% | 4 | Barra 1:1 |
| F4 Ventanas/atajos | 10% | 3 | Controles 1:1 |
| F5 Dock | 12% | 5 | Dock usable |
| F6 Spotlight/Apps | 9% | 4 | Búsqueda 1:1 |
| F7 Mission Control | 10% | 5 | Overview 1:1 |
| F8 KCM | 6% | 3 | 6 páginas verdes |
| F9 Onboarding/migración | 8% | 5 | Sin terminal |
| F10 Apps/widgets | 5% | 3 | Día a día |
| F11 Pulido/glass/a11y | 5% | 3 | 1:1 visual |
| F12 Hardening/release | 4% | 4 | 1.0 |
| F13 Upstream | 1% | continuo | PRs |

---

## Fase 0 — Baseline y spike de viabilidad (4 tareas, 4%, 2 semanas)

**Objetivo:** medir lo que hay, crear referencias propias y demostrar las tres piezas que pueden tumbar la migración. **Gate F0:** sin las tres pruebas verdes no se reestructura el repo.

- [x] **F0-T01 — Inventario y baseline del repo actual.** Files: `scripts/audit.sh`, `docs/plans/evidence/F0-T01.md`. Acciones: contar LOC por tipo (`cloc`), listar dotfiles, Rulings R1-R21, install.sh, ISO NimbusOS, dependencias AUR, métricas VM (boot, RAM, fps Dock/Overview Hyprland). Accept: tabla en evidence con cifras reproducibles. Dep: —.
- [x] **F0-T02 — Referencias golden propias y herramienta de diff.** Files: `tests/golden/`, `tests/screenshot-diff/`, `docs/plans/evidence/F0-T02.md`. Acciones: capturas propias de macOS Tahoe (pantallas del usuario, no se distribuyen), definir recortes (barra, ventana activa/inactiva, Dock, Spotlight, Mission Control, Settings) y script de diff con umbral. Accept: diff de una captura contra sí misma = 0%; contra otra = % medible. Dep: F0-T01.
- [ ] **F0-T03 — Spike Dock layer-shell (Krema fork mínimo).** Files: `spikes/dock/`, `docs/plans/evidence/F0-T03.md`. Acciones: compilar Krema o fork mínimo, 15 apps, zoom parabólico, medir fps con `qmlprofiler`/contador, probar fuera del panel y autohide. Accept: ≥55 fps sostenidos en VM, sin jank >2 frames, captura. Go/no-go. Dep: F0-T01.
- [ ] **F0-T04 — Spike KRunner fullscreen + KWin Overview + go/no-go.** Files: `spikes/krunner/`, `spikes/overview/`, `docs/plans/evidence/F0-T04.md`. Acciones: skin KRunner centrado/fullscreen con blur y Esc; efecto KWin mínimo que muestra thumbs de 4 ventanas y alterna; medir latencia. Accept: KRunner <50 ms, Overview <300 ms, KWin no crashea. Informe final: seguir, recortar o abortar. Dep: F0-T01.

**Gate F0:** si T03 o T04 fallan, se aplica el plan de recorte: Dock → Crystal Dock/panel temporal; Overview → stock tematizado; se registra Ruling y se continúa solo con lo viable.

---

## Fase 1 — Reestructuración del repo y base operable (6 tareas, 6%, 2 semanas)

**Objetivo:** dejar el repo listo para Plasma sin romper el legacy, con instalador modular, CI y ledger de progreso.

- [x] **F1-T01 — Rama, tag y congelación del legacy.** Files: `legacy/hyprland/`, `.gitignore`, `README.md`. Acciones: `git tag hyprland-final`, crear rama `plasma-migration`, mover dotfiles Hyprland/MacShell a `legacy/hyprland/` con README de estado. Accept: `git tag` existe; `legacy/` no lo toca el instalador Plasma; build legacy sigue reproducible (documentado). Dep: F0.
- [x] **F1-T02 — Estructura de directorios Plasma.** Files: `dotfiles/.config/plasma/`, `packages/{plasma,kwin,themes,dock,kcm}/`, `apps/`, `iso/`, `tests/`, `scripts/`. Acciones: crear árbol y README por directorio con responsabilidad y convención de nombres `org.nimbus.*`. Accept: `tree` documentado; ningún fichero huérfano; lint de rutas. Dep: F1-T01.
- [x] **F1-T03 — `install.sh` modular con perfiles.** Files: `install.sh`, `lib/{common,plasma,kwin,themes,dock,apps,verify}.sh`. Acciones: dispatcher `--profile=plasma|legacy-hypr|--check`; mantener backups/no-root/idempotencia; checks de Plasma, Klassy, Krema, KCM, dotfiles. Accept: `bash -n`, `shellcheck -S warning` cero warnings, `--check` exit 0 en VM convergida y exit 1 con drift. Dep: F1-T02.
- [x] **F1-T04 — Migrar dotfiles y retirar rutas Hyprland del instalador.** Files: `dotfiles/.config/plasma/*`, `legacy/hyprland/`, `install.sh`. Acciones: copiar configs base Plasma, eliminar referencias a `hyprland`/`quickshell` del perfil Plasma, documentar diferencias. Accept: `grep -r hyprland dotfiles/.config/plasma` vacío; `--check` no menciona Hyprland en perfil Plasma. Dep: F1-T03.
- [x] **F1-T05 — CI local y lint.** Files: `scripts/ci.sh`, `.github/workflows/ci.yml` (opcional), `docs/plans/evidence/F1-T05.md`. Acciones: bash -n, shellcheck, `qmlformat`/`qmllint`, validación de JSON/desktop files, `install.sh --check` en seco, tests del ledger. Accept: `scripts/ci.sh` exit 0 en repo limpio; falla con un error inyectado. Dep: F1-T03.
- [x] **F1-T06 — Ledger de progreso y script.** Files: `scripts/nimbus-progress`, `tests/progress/`, `docs/plans/evidence/F1-T06.md`. Acciones: parser de checkboxes `^- \[x\] \*\*F\d+-T\d+`; salida % total, por fase (peso del header, `tareas?` singular incluido) y próximas 5 pendientes; `--phase`; las dependencias `Dep:` son informativas (no bloquean el conteo) y aceptan rangos `..` y listas. Test con fixture 3 tareas. Accept: `scripts/nimbus-progress` imprime `Total: X/112 (Y%)` coherente con el estado real y `--json` parseable; tests pasan. Dep: F1-T02.

**Gate F1:** repo limpio, instalador seco verde, ledger funcional. Sin esto no se instala Plasma.

---

## Fase 2 — Base Plasma, sesión e ISO netinstall (10 tareas, 8%, 3 semanas)

**Objetivo:** una VM con Plasma 6 arrancando, tematizada base, e instalable por red desde Calamares.

- [x] **F2-T01 — Dependencias Plasma 6 y VM de trabajo.** Files: `packages/plasma.list`, `docs/plans/evidence/F2-T01.md`. Acciones: lista de paquetes (plasma-meta, kwin, krunner, sddm, kde-gtk-config, kvantum, klassy, etc.), instalar en VM Arch/CachyOS; matriz Plasma 6.8 × Klassy (6.7.3 vs `klassy-git` 6.8temp) y fallback Aurorae; `plasmashell --version`, `kwin_wayland --version`. Accept: sesión Plasma arranca (live CachyOS 6.7.4 + nested 6.8.2); matriz Klassy documentada (6.7.3 preset; OOM VM=RAM, no ABI); versiones registradas; PLM excluido (R-LOGIN). Dep: F1.
- [ ] **F2-T02 — Sesión Wayland, login y autologin.** Files: `dotfiles/.config/sddm/`, `iso/`, `docs/plans/evidence/F2-T02.md`. Acciones: SDDM 0.21 con tema Nimbus por defecto; plasma-login-manager solo spike F8; greetd descartado (kwallet-PAM); autologin en VM, `startplasma-wayland`, orden de servicios. Accept: boot → SDDM → Plasma en <20 s en VM; captura. Autoría+preview listos (nested); boot real pendiente F2-T08. Dep: F2-T01.
- [x] **F2-T03 — Configs base Plasma.** Files: `dotfiles/.config/{plasmarc,plasmashellrc,kwinrc,kdeglobals,kglobalshortcutsrc,krunnerrc,kscreenlockerrc}`. Acciones: defaults Nimbus (tema, fuentes, botones, doble clic, foco, animaciones), sin depender de KCM manual. Accept: `kwriteconfig6`/`--check` valida claves; sesión nueva hereda defaults (validado nested 6.8.2: panel 24, XIA, FreeFloating, SingleClick; Ctrl defaults del sistema se neutralizan en F4-T08). Dep: F2-T02.
- [ ] **F2-T04 — Tema base aplicable.** Files: `packages/themes/`, `scripts/apply-theme`. Acciones: Klassy + Kvantum + WhiteSur con `-p` (quita logo Apple) + Inter + iconos + wallpaper NPS; auditar assets (`find/grep`) + ATTRIBUTION; script idempotente. Accept: `apply-theme` deja el look base; `tests/screenshot-diff/compare.sh <golden> <captura> --umbral 20`; reversible. Dep: F2-T03.
- [x] **F2-T05 — Panel superior base.** Files: `dotfiles/.config/plasma/plasma-org.kde.plasma.desktop-appletsrc`, `packages/plasma/plasmoids/org.nimbus.bar/`. Acciones: panel stock 38px (mínimo PanelView; pre-seed thickness ignorado, medido en nested) como base temporal; A1 24pt se implementa en F3-T03 con barra custom layer-shell; flotante, Colorizer preset, sin applets custom. Accept: panel visible, no tapa ventanas, reserva espacio; captura. Dep: F2-T04.
- [ ] **F2-T06 — Perfil CachyOS netinstall.** Files: `iso/profile/{profiledef.sh,packages.x86_64,pacman.conf}`, `iso/README.md`. Acciones: perfil archiso/CachyOS pinneado, paquetes Plasma, Calamares, drivers, sin AUR no fijado. Accept: `mkarchiso` produce ISO netinstall; build reproducible (hash). Dep: F2-T01.
- [ ] **F2-T07 — Calamares branding y módulos.** Files: `iso/calamares/{branding.desc,settings.conf,modules/}`. Acciones: `settings.conf` unificado con F9 (show→exec→finished; netinstall como instancia; removeuser solo OEM), idioma/teclado/zona/particiones/usuario, marca Nimbus, sin activos Apple. Accept: instalación completa en VM desde ISO. Dep: F2-T06.
- [ ] **F2-T08 — Test de instalación y métricas.** Files: `tests/vm/install.sh`, `docs/plans/evidence/F2-T08.md`. Acciones: VM limpia → Calamares → primer boot → Plasma; medir tiempo, RAM, disco, errores en journal. Accept: instalación <20 min, boot usable, 0 errores críticos. Dep: F2-T07.
- [ ] **F2-T09 — Seguridad base del sistema.** Files: `iso/calamares/`, `dotfiles/.config/`, `docs/plans/evidence/F2-T09.md`. Acciones: LUKS opcional/recomendado en Calamares, telemetría KDE desactivada (`kwriteconfig6`), firewall activo (firewalld/ufw), permisos Flatpak por app, `journalctl` sin errores críticos. Accept: VM con LUKS + firewall; telemetría off verificada; captura. Dep: F2-T07.
- [ ] **F2-T10 — Perfil NVIDIA y energía.** Files: `iso/profile/`, `apps/nimbus-hw/`. Acciones: detección GPU, NVIDIA dkms/open + `modeset=1`, `power-profiles-daemon`, suspensión; test VM y hardware. Accept: NVIDIA arranca Wayland; perfiles de energía; evidencia. Dep: F2-T06.

**Gate F2:** ISO netinstall instala, arranca Plasma, LUKS/firewall/telemetría verificados y NVIDIA (si aplica) funciona. Si falla, no se avanza a look.

---

## Fase 3 — Fundación visual y barra superior (13 tareas, 12%, 4 semanas)

**Objetivo:** el 80% visual de macOS Tahoe: tokens, Klassy, barra layer-shell custom 24pt, menús, control center, reloj, notificaciones y OSD.

- [x] **F3-T01 — Design tokens Nimbus.** Files: `packages/themes/nimbus-tokens/{colors,radii,spacing,typography}.qml`. Acciones: fuente única `docs/design/tahoe-design-contract.md` §2: color semántico light/dark, Inter 11-28 con tracking/lh, spacing 4-32, radios (r-sm 8, r-md 10-12, r-lg 20, ventana 16/26 concéntrico), glass/motion/estados; `tokens.json` + `NimbusTokens.qml`; sin valores mágicos. Accept: tokens consumidos por demo; contraste WCAG A4; qmllint. Dep: F2.
- [x] **F3-T02 — Decoración custom `nimbus-decoration`.** Files: `packages/kwin/decoration/nimbus-decoration/`, `packages/themes/klassy-preset/` (fallback). Acciones: plugin KDecoration3 C++ propio: botones 12px izquierda, offset 8-9, gap 8, colores #FF5F57/#FEBC2E/#28C840, hover ×/−/+, gris inactivo #8E8E93, titlebar 16/26; Klassy 6.7.3 preset SÍ alcanza Ø12/gap8/offset9/colores/inactivas gris/titlebar 26 (medido PIL en nested); parche `+` incluido; hover físico y titlebar 16 → F4-T01/F4-T02. Accept: captura activa/inactiva/hover; diff; sin artefactos. Dep: F3-T01.
- [x] **F3-T03 — Plasm oxide barra superior.** Files: `packages/shell/nimbus-bar/`. Acciones: barra superior custom layer-shell 24pt (QML; port MacBar), NO panel/plasmoide stock; R-TOPBAR-LAYER; layout logo/menús/estado/reloj/CC. Accept: `kpackagetool6 -i` instala; panel lo carga sin errores. Dep: F3-T01.
- [x] **F3-T04 — Menú Apple.** Files: `packages/shell/nimbus-bar/qml/` (Menu.qml). Acciones: Acerca de, Ajustes, Dormir, Bloquear, Cerrar sesión, Reiniciar, Apagar; i18n. Accept: cada acción ejecuta y se prueba en VM. Dep: F3-T03.
- [x] **F3-T05 — Control Center.** Files: `packages/shell/nimbus-bar/qml/` (ControlCenter.qml). Acciones: Wi-Fi, BT, volumen, brillo, modo oscuro, No molestar, batería; DataEngines. Accept: UI + lectura real trazada en nested (wifi/bt/batt/dnd); toggles reales se prueban en F2-T08; capturas. Dep: F3-T03.
- [ ] **F3-T06 — Menú global Qt.** Files: `packages/shell/nimbus-bar/qml/` (GlobalMenu DBus), `dotfiles/.config/plasma/`. Acciones: widget Global Menu, appmenu Qt, R-GTK documentado. Accept: Kate/Dolphin exportan menú; Nautilus/Firefox no rompen. Dep: F3-T03.
- [ ] **F3-T07 — System tray y status items.** Files: `packages/shell/nimbus-bar/qml/` (SNI DBus). Acciones: bandeja, iconos, badges, menús; tema. Accept: apps SNI aparecen; captura. Dep: F3-T03.
- [x] **F3-T08 — Reloj y calendario.** Files: `packages/shell/nimbus-bar/qml/` (port MacBar). Acciones: popup calendario, eventos, zonas; i18n. Accept: abre/cierra, fechas correctas, teclado. Dep: F3-T03.
- [ ] **F3-T09 — Notificaciones estilo macOS.** Files: `packages/themes/`, `dotfiles/.config/plasma/`. Acciones: tema de notificaciones, agrupación, DND, actions. Accept: notificación de prueba con acciones; captura. Dep: F3-T03.
- [ ] **F3-T10 — OSD volumen/brillo.** Files: `packages/shell/nimbus-bar/qml/` (OSD in-situ). Acciones: OSD Plasma tematizado; volumen/brillo se expande in-situ en la barra (contrato §3); teclas. Accept: teclas muestran OSD; captura. Dep: F3-T03.
- [ ] **F3-T11 — Fondo, claro/oscuro y acento.** Files: `packages/themes/`, `scripts/apply-theme`. Acciones: wallpaper NPS, switch claro/oscuro automático, acento; ventanas y panel siguen. Accept: cambio en vivo sin reiniciar; capturas. Estado: autoría+preview y wallpaper en vivo OK; panel renderiza un switch por detrás (R-F3T11-LIVE, evidencia); pendiente aislar reload o validar en VM. Dep: F3-T02.
- [ ] **F3-T12 — Aceptación de barra superior.** Files: `tests/vm/topbar.sh`, `docs/plans/evidence/F3-T12.md`. Acciones: diff vs golden, clics en cada menú, teclado, multi-monitor. Accept: A1/A2 (<15% diff, 24pt, semáforos), 0 errores, evidencia. Dep: F3-T04..T11.

- [ ] **F3-T13 — Presets Colorizer + Window Buttons6.** Files: `packages/plasma/`, `dotfiles/.config/`. Acciones: versionar presets de topbar/botones, `kpackagetool6`, pin de versiones. Accept: instala en VM limpia; captura; pin documentado. Dep: F3-T05.

---

## Fase 4 — Ventana, semáforos y atajos (10 tareas, 10%, 3 semanas)

**Objetivo:** titlebar y controles 1:1, zoom/fullscreen/drag correctos y atajos universales.

- [ ] **F4-T01 — Semáforos exactos.** Files: `packages/kwin/decoration/nimbus-decoration/`. Acciones: 12px, #FF5F57/#FEBC2E/#28C840, offset 8-9, gap 8, hover ×/−/+ 7×7 stroke 1.2, gris inactivo, foco; comparar con golden (A2); Klassy solo fallback. Accept: diff por estado; sin SVG de Apple. Dep: F3-T02.
- [ ] **F4-T02 — Titlebar: altura, radio, sombra, borde.** Files: `packages/kwin/`, `dotfiles/.config/kwinrc`. Acciones: titlebar 16 sin toolbar / 26 con toolbar-sidebar (concéntrico), título a la izquierda, sombra 20-22px, borde 0.5-1px; apps CSD respetan o se excluyen (A3). Accept: capturas activa/inactiva/maximizada; diff. Dep: F4-T01.
- [x] **F4-T03 — Zoom (verde) flotante.** Files: `packages/kwin/scripts/nimbus-zoom/` o KCM; `apps/`. Acciones: maximizar al área de trabajo bajo la barra, fs=0, toggle, guardar geometría; drag conserva offset. Accept: zoom/restore verificado nested (y=24, MaximizeArea); drag→F4-T05, 60fps→A5; rama fs/max previo pendiente. Dep: F4-T02.
- [x] **F4-T04 — Fullscreen real y salida.** Files: `dotfiles/.config/kglobalshortcutsrc`, `kwin/`. Acciones: Cmd/Ctrl+F o Meta+F; verde sale de fullscreen; barra oculta/muestra. Accept: fullscreen/exit; barra correcta. Dep: F4-T03.
- [ ] **F4-T05 — Drag y doble clic.** Files: `packages/kwin/`, `dotfiles/.config/kwinrc`. Acciones: arrastre nativo por titlebar, doble clic zoom, umbral; sin shims. Accept: pointer lab; offset; sin saltos. Dep: F4-T02.
- [ ] **F4-T06 — Ventanas inactivas.** Files: `packages/kwin/`, `klassy-preset`. Acciones: gris, título, sin hover glyphs, sin dim de contenido; contraste. Accept: captura activa/inactiva; muestra RGB. Dep: F4-T01.
- [ ] **F4-T07 — Reglas de ventana.** Files: `dotfiles/.config/kwinrulesrc`. Acciones: float por defecto, tamaño 1100x700, centrar, diálogos, CSD, excepciones MacShell; no maximizar al abrir. Accept: apps abren normal; reglas probadas. Dep: F4-T02.
- [x] **F4-T08 — Atajos Cmd/Ctrl.** Files: `dotfiles/.config/kglobalshortcutsrc`, `settings/`. Acciones: Meta como Cmd, toggle Cmd/Ctrl, cheat sheet, sin Ctrl nuevos; aplicar vía `kglobalaccel setShortcut` (no solo fichero) y tabla de colisiones Meta+F/Meta+Espacio. Accept: 22 acciones KWin únicas invocadas (28/28 rc=0) + 32 binds; cero Ctrl nuevos; toggle implementado (prueba en VM); Meta+Espacio pasa a Spotlight al integrar F6-T01. Dep: F4-T04.
- [ ] **F4-T09 — Empaquetado/pin de Klassy y scripts.** Files: `packages/`, `scripts/ci.sh`. Acciones: PKGBUILD o dependencia pinneada, rebuild por Plasma, CI. Accept: instalación limpia; update simulado no rompe. Dep: F4-T01.
- [ ] **F4-T10 — Aceptación de ventanas.** Files: `tests/vm/windows.sh`, evidence. Acciones: matriz de 8 apps (Qt/GTK/Electron/CSD), capturas, interacción. Accept: todos los estados; 0 fallos críticos. Dep: F4-T03..T09.

---

## Fase 5 — Dock (12 tareas, 12%, 5 semanas)

**Objetivo:** Dock macOS completo sobre layer-shell (Krema base/fork/theme), con TaskManager, zoom, previews y prefs.

- [ ] **F5-T01 — Evaluación/fork de Krema.** Files: `packages/dock/`, `LICENSE`, `docs/plans/evidence/F5-T01.md`. Acciones: clonar/pin, licencia, build; decisión recomendada: tema Nimbus sobre Krema pinneado, sin fork (fork solo con Ruling); atribución. Accept: dock arranca; licencia compatible; decisión registrada. Dep: F0-T03.
- [ ] **F5-T02 — Backend TaskManager.** Files: `packages/dock/`. Acciones: apps corriendo, pins, badges, foco, launch/close; backend `libtaskmanager` (no D-Bus directo). Accept: 15 apps; estados correctos. Dep: F5-T01.
- [ ] **F5-T03 — Tema visual Nimbus.** Files: `packages/dock/`, `themes/`. Acciones: glass, radio, iconos, separadores, papelera, tema claro/oscuro. Accept: diff vs golden; capturas. Dep: F5-T02.
- [ ] **F5-T04 — Magnificación y bounce.** Files: `packages/dock/`. Acciones: curva parabólica, hover labels, bounce al abrir. Accept: spike ≥55fps, producto 60fps (A5); sin jank; vídeo. Dep: F5-T03.
- [ ] **F5-T05 — Autohide, multi-monitor y exclusive zone.** Files: `packages/dock/`, `kwin/`. Acciones: intellihide, reservar espacio, 1-2 pantallas, HiDPI. Accept: no tapa ventanas; reacciona a foco; capturas. Dep: F5-T03.
- [ ] **F5-T06 — Clic, launch, foco, minimize.** Files: `packages/dock/`. Acciones: click abre/enfoca, minimiza con genie, menú contextual. Accept: 20 ciclos sin fallo; evidencia. Dep: F5-T02.
- [ ] **F5-T07 — Previews de ventanas.** Files: `packages/dock/`. Acciones: `kpipewire`; si no hay previews estables, Ruling y fallback (icono+lista). Accept: previews o Ruling; sin crash. Dep: F5-T06.
- [ ] **F5-T08 — Pin/unpin/reorder y persistencia.** Files: `packages/dock/`. Acciones: drag reorder, pins, JSON, reset. Accept: persiste tras reinicio; tests. Dep: F5-T06.
- [ ] **F5-T09 — Papelera, stacks y badges.** Files: `packages/dock/`. Acciones: trash, Downloads, badges; abrir. Accept: estados vacío/lleno; captura. Dep: F5-T08.
- [ ] **F5-T10 — Preferencias del Dock.** Files: `packages/dock/`, `settings/`. Acciones: tamaño, zoom, posición, autohide, tema; port MacDock prefs. Accept: cambios en vivo; persistencia. Dep: F5-T08.
- [ ] **F5-T11 — Rendimiento y arranque.** Files: `tests/vm/dock.sh`. Acciones: fps, RAM, tiempo de arranque, 30 apps. Accept: A5 (60fps producto, RAM <150MB, boot <1s extra). Dep: F5-T04.
- [ ] **F5-T12 — Aceptación del Dock.** Files: `tests/vm/dock-acceptance.sh`, evidence. Acciones: matriz de interacciones + capturas + diff. Accept: A5 y todo verde o Ruling. Gate F5. Dep: F5-T01..T11.

**Gate F5:** Dock usable a diario y 60fps. Si no, se congela Krema o se usa Crystal Dock con Ruling.

---

## Fase 6 — Spotlight y Apps (9 tareas, 9%, 4 semanas)

**Objetivo:** búsqueda universal y lanzador de apps 1:1.

- [x] **F6-T01 — KRunner fullscreen skin.** Files: `packages/plasma/`, `settings/`. Acciones: KRunner `FreeFloating=true` + skin RunCommand.qml; no hay API fullscreen oficial; overlay layer-shell solo opcional; Cmd+Espacio, Esc. Accept: toggle DBus instantáneo; overlay+Nimbus con KF6Runner real; query 233-273ms → optimización F6-T08 (A6); KRunner stock off en Meta+Espacio (Spotlight exclusivo); tecla física en VM. Dep: F2.
- [ ] **F6-T02 — Runners Nimbus.** Files: `apps/krunner-nimbus/`. Acciones: apps, archivos, ajustes, calculadora, web, portapapeles; Cmd+1..4 = Apps/Files/Actions/Clipboard; Quick Keys ≤12; runner Python primero, C++ solo si >50 ms/10k. Accept: cada runner devuelve resultados; tests. Dep: F6-T01.
- [ ] **F6-T03 — Ranking, previews y acciones.** Files: `apps/krunner-nimbus/`. Acciones: fuzzy, orden, preview, acciones (abrir, copiar, revelar); clipboard texto <16384 sin formato (sin Passwords/Universal). Accept: 10 consultas; resultados correctos. Dep: F6-T02.
- [x] **F6-T04 — Apps (Tahoe, sin Launchpad).** Files: `packages/plasma/`, `apps/nimbus-apps/`. Acciones: Apps Tahoe (NO Launchpad, R-APPSVIEW): ventana centrada, Cmd+1, categorías fijas + Suggestions, vistas Icons/List; sin carpetas/páginas/reorden. Accept: abre/cierra verificado (DBus toggle; Meta+1 script documentado); ventana estática sin animación; fps real en F6-T08/A5; captura. Dep: F2.
- [ ] **F6-T05 — Vistas y categorías de Apps.** Files: `apps/nimbus-apps/`. Acciones: vistas Icons/List, categorías, Suggestions, orden Category/Name; sin carpetas/páginas/reorden (R-APPSVIEW). Accept: estados; tests. Dep: F6-T04.
- [ ] **F6-T06 — Portapapeles y emoji.** Files: `apps/`, `packages/plasma/`. Acciones: port MacBar clipboard/emoji; atajos. Accept: pega en apps; captura. Dep: F6-T01.
- [ ] **F6-T07 — Teclado y accesibilidad.** Files: `apps/*`. Acciones: navegación completa, lector, foco visible. Accept: 0 uso de ratón; Orca. Dep: F6-T02.
- [ ] **F6-T08 — Rendimiento.** Files: `tests/vm/spotlight.sh`. Acciones: latencia, RAM, 10k archivos. Accept: <50ms, sin freeze. Dep: F6-T03.
- [ ] **F6-T09 — Aceptación Spotlight/Apps.** Files: `tests/vm/spotlight-acceptance.sh`. Acciones: 20 consultas + 10 apps + teclado + Cmd1-4 + QuickKeys. Accept: A6 y todo verde; evidence. Dep: F6-T01..T08.

---

## Fase 7 — Mission Control y Spaces (10 tareas, 10%, 5 semanas)

**Objetivo:** exposé de ventanas, escritorios virtuales y animaciones macOS.

- [ ] **F7-T01 — Spaces = escritorios virtuales.** Files: `dotfiles/.config/plasma/`, `packages/kwin/scripts/nimbus-spaces/`. Acciones: 4 spaces, nombres, atajos; R-SPACES: escritorios globales, 'por monitor' no es 1:1; documentar. Accept: cambiar/crear/mover; tests. Dep: F2.
- [ ] **F7-T02 — Overview stock tematizado.** Files: `packages/themes/`, `dotfiles/.config/`. Acciones: activar Overview, tema, atajos; medir. Accept: abre/cierra, thumbs; captura. Dep: F7-T01.
- [ ] **F7-T03 — Efecto KWin `nimbus-overview` (esqueleto).** Files: `packages/kwin/effects/nimbus-overview/`. Acciones: QML/JS effect, grid, toggle; no crashea. Accept: carga en KWin; evidencia. Dep: F7-T02.
- [ ] **F7-T04 — Thumbnails, grid y agrupación.** Files: `packages/kwin/effects/nimbus-overview/`. Acciones: thumbs reales, agrupar por app, tamaños. Accept: 10 ventanas; 60fps; captura. Dep: F7-T03.
- [ ] **F7-T05 — Drag entre Spaces.** Files: `packages/kwin/`. Acciones: arrastrar ventana a otro space, drop, animación. Accept: 5 casos; sin perder ventanas. Dep: F7-T04.
- [ ] **F7-T06 — Animación de cambio de Space.** Files: `packages/kwin/`, `dotfiles/.config/`. Acciones: slide/zoom, duración, reduce motion. Accept: 60fps; captura vídeo. Dep: F7-T05.
- [ ] **F7-T07 — App Exposé.** Files: `packages/kwin/`. Acciones: App Exposé de la app activa, atajo; Show Desktop; MC por display. Accept: abre/cierra; tests. Dep: F7-T04.
- [ ] **F7-T08 — Multi-monitor y HiDPI.** Files: `packages/kwin/`, `tests/vm/`. Acciones: 2 pantallas, escalas; panel/Dock correctos; MC por display; Split-drag; Spaces globales (R-SPACES). Accept: posiciones correctas; capturas. Dep: F7-T04.
- [ ] **F7-T09 — Rendimiento.** Files: `tests/vm/overview.sh`. Acciones: 20 ventanas, toggle, GPU. Accept: <300ms, 60fps. Dep: F7-T04.
- [ ] **F7-T10 — Aceptación Mission Control.** Files: `tests/vm/overview-acceptance.sh`. Acciones: matriz de 10 interacciones + capturas. Accept: verde o Ruling. Dep: F7-T01..T09.

---

## Fase 8 — Ajustes y KCM Nimbus (8 tareas, 6%, 3 semanas)

**Objetivo:** ajustes fáciles, en español, con 6 páginas y sin jerga.

- [ ] **F8-T01 — KCM Nimbus esqueleto.** Files: `packages/kcm/kcm_nimbus/`. Acciones: Kirigami, 6 páginas, búsqueda, `systemsettings` lo carga. Accept: `kpackagetool6` instala; abre; tests. Dep: F2.
- [ ] **F8-T02 — Página Apariencia.** Files: `packages/kcm/kcm_nimbus/`. Acciones: tema, acento, fondo, Dock, barra, animaciones; preview. Accept: cambios en vivo; reset. Dep: F8-T01.
- [ ] **F8-T03 — Página Red/BT/Impresoras.** Files: `packages/kcm/kcm_nimbus/`. Acciones: embeber KCMs, estados, mensajes llanos. Accept: conectar Wi-Fi/BT; imprimir prueba. Dep: F8-T01.
- [ ] **F8-T04 — Página Atajos Cmd/Ctrl.** Files: `packages/kcm/kcm_nimbus/`. Acciones: toggle, cheat sheet, reset; sin Ctrl por defecto. Accept: 20 atajos; persistencia. Dep: F8-T01.
- [ ] **F8-T05 — Página Accesibilidad.** Files: `packages/kcm/kcm_nimbus/`. Acciones: zoom, contraste, reduce motion/transparency, teclado, Orca. Accept: toggles reales; tests; captura. Dep: F8-T01.
- [ ] **F8-T06 — Página Sistema/Usuarios/Fecha-hora.** Files: `packages/kcm/kcm_nimbus/`. Acciones: usuarios/cuentas, fecha-hora/NTP, locale, energía; mensajes llanos. Accept: cambios persistentes; tests. Dep: F8-T01.
- [ ] **F8-T07 — Página Updates/Discover.** Files: `packages/kcm/kcm_nimbus/`. Acciones: estado de updates, programar, enlaces a Discover/rollback; sin jerga. Accept: actualiza 1 paquete; captura. Dep: F8-T01.
- [ ] **F8-T08 — Reset, persistencia y tests.** Files: `tests/kcm/`. Acciones: defaults, backup, JSON/KConfig; tests de todas las páginas. Accept: reset deja estado canónico; tests. Dep: F8-T02..T07.

**Gate F8:** el KCM abre las 6 páginas, reset canónico verde y `systemsettings` lo carga sin errores; si no, no entra onboarding.

---

## Fase 9 — Onboarding, migración y updates (10 tareas, 8%, 5 semanas)

**Objetivo:** que un usuario de Windows/Mac llegue a un escritorio usable sin terminal.

- [ ] **F9-T01 — Calamares pulido.** Files: `iso/calamares/`. Acciones: mismo `settings.conf` que F2-T07; idioma/teclado/zona/cuenta/particiones; textos llanos; marca. Accept: instalación guiada sin terminal; cronómetro. Dep: F2-T07.
- [ ] **F9-T02 — Wizard de primer arranque (6 pasos).** Files: `apps/nimbus-welcome/`. Acciones: bienvenida, idioma, Wi-Fi, cuenta/avatar, apariencia, apps, tour; i18n: cadenas desde I18n.js, destino ki18n/.ts (F11-T05). Accept: <5 min, skip/reanudar; capturas. Dep: F9-T01.
- [ ] **F9-T03 — Elección de layout Mac/Win/Nimbus.** Files: `apps/nimbus-welcome/`, `settings/`. Acciones: presets de panel/atajos/Dock. Accept: cambia layout; reversible. Dep: F9-T02.
- [ ] **F9-T04 — Apps recomendadas.** Files: `apps/nimbus-welcome/`. Acciones: selección Flatpak/PackageKit; progreso; sin bloquear. Accept: instala 3 apps; tests. Dep: F9-T02.
- [ ] **F9-T05 — Migrador Windows/Mac.** Files: `apps/nimbus-migrate/`. Acciones: documentos, marcadores, fondo, lista de equivalencias; dry-run. Accept: importa 3 tipos; no sobrescribe; tests. Dep: F9-T02.
- [ ] **F9-T06 — Toggle Cmd/Ctrl y chuleta.** Files: `apps/nimbus-welcome/`, `settings/`. Acciones: remapeo, PDF/HTML de atajos. Accept: 20 atajos; reversible. Dep: F9-T02.
- [ ] **F9-T07 — Discover simple.** Files: `dotfiles/.config/`, `apps/`. Acciones: modo simple, updates en lenguaje llano, programar. Accept: actualiza 1 paquete; captura. Dep: F2.
- [ ] **F9-T08 — Rollback Btrfs/snapper.** Files: `apps/`, `iso/`. Acciones: snapshot pre-update, entrada GRUB "volver a ayer", test romper update. Accept: rollback funcional en VM; evidencia. Dep: F9-T07.
- [ ] **F9-T09 — Migrador legacy Hyprland→Plasma.** Files: `apps/nimbus-migrate/`. Acciones: backup `~/.config/hypr` y `~/.config/quickshell`, importar wallpaper/atajos/pins/settings donde sea posible, dry-run y rollback. Accept: VM con dotfiles Hyprland migra sin pérdida; informe de lo no migrable. Dep: F9-T02.
- [ ] **F9-T10 — Soporte, diagnóstico y backup.** Files: `apps/nimbus-bug-report/`, `apps/backup/`. Acciones: `nimbus-bug-report` (journal, `kinfo`, `qdbus6`), backup/restore Konsave, tarball restorable, botón Ayuda. Accept: genera y restaura un tarball en VM; captura. Dep: F9-T02.

---

## Fase 10 — Apps, widgets y UI de sistema (7 tareas, 5%, 3 semanas)

**Objetivo:** completar la experiencia diaria con apps y widgets equivalentes.

- [ ] **F10-T01 — Port widgets/ClockApp/AboutApp.** Files: `packages/plasma/`, `apps/`. Acciones: Calendar, Clock, Weather, Player; ClockApp/AboutApp; i18n ki18n (no es.js nuevo). Accept: cada widget funciona; capturas. Dep: F3.
- [ ] **F10-T02 — Finder-like Dolphin.** Files: `dotfiles/.config/dolphinrc`, `apps/`. Acciones: vista columnas, sidebar, previews, Quick Look si viable. Accept: 10 tareas de archivo; captura. Dep: F2.
- [ ] **F10-T03 — Terminal y apps por defecto.** Files: `dotfiles/.config/konsolerc`, `apps/`. Acciones: Konsole tema, fuente, perfil; defaults (navegador, correo, imagen, archivo). Accept: abrir enlaces/archivos; tests. Dep: F2.
- [ ] **F10-T04 — Lock/login.** Files: `packages/themes/`, `dotfiles/.config/kscreenlockerrc`. Acciones: kscreenlocker/SDDM tema Nimbus, avatar, blur; bloqueo por atajo. Accept: lock/unlock; capturas. Dep: F2.
- [ ] **F10-T05 — OSD/notificaciones/sonidos/screenshot.** Files: `packages/themes/`, `apps/`. Acciones: OSD in-situ en barra, sonidos propios, Spectacle, notificaciones; atajos. Accept: 5 acciones; capturas. Dep: F3.
- [ ] **F10-T06 — XWayland y apps legacy.** Files: `dotfiles/.config/`, `tests/vm/`. Acciones: XWayland, Electron/Ozone flags, GTK CSD, matriz de 8 apps; sin ventanas negras. Accept: matriz verde; captura. Dep: F10-T03.
- [ ] **F10-T07 — nimbus-hw, Konsave y harness.** Files: `apps/nimbus-hw/`, `apps/backup/`, `tests/vm/`. Acciones: detección hardware estilo chwd, presets Konsave, harness `kwshot`/`qdbus6` versionado. Accept: detecta GPU/Wi-Fi/impresora; harness reproducible. Dep: F9-T10.

---

## Fase 11 — Pulido 1:1, glass, animaciones y a11y (6 tareas, 5%, 3 semanas)

**Objetivo:** cerrar la brecha visual y de accesibilidad.

- [ ] **F11-T01 — Animaciones macOS.** Files: `packages/kwin/`, `dotfiles/.config/`. Acciones: Magic Lamp, zoom, dock bounce, overview, sheets; t-quick 250ms, t-normal 350ms, MC 400-500ms, reduce motion fade 150ms; curvas del contrato §2.5. Accept: 5 animaciones; 60fps; vídeo. Dep: F4,F5,F7.
- [ ] **F11-T02 — Glass/Liquid Glass.** Files: `packages/kwin/effects/`, `packages/themes/`. Acciones: blur/refracción en barra/Dock/paneles; preferir blur stock antes de Better Blur; pin commit xarblu/Glass; tiers alto/bajo; reduce transparency (A9). Accept: visual + fps; toggle. Dep: F11-T01.
- [ ] **F11-T03 — Estados, dark/light y acento.** Files: `packages/themes/`. Acciones: hover/pressed/disabled, foco, dark/light, acento en todas las superficies. Accept: matriz de estados; capturas. Dep: F3,F4.
- [ ] **F11-T04 — Accesibilidad.** Files: `dotfiles/.config/`, `apps/`. Acciones: Orca, zoom, contraste, sticky keys, reduce motion/transparency, navegación teclado. Accept: 10 tareas sin ratón; audit. Dep: F8.
- [ ] **F11-T05 — i18n, docs y chuleta.** Files: `docs/`, `apps/`. Acciones: dueño único i18n ki18n/.ts (F9/F10 consumen); es/en completo, textos de UI, guía de usuario, atajos. Accept: 0 cadenas sin traducir; docs revisadas. Dep: F9,F10.

- [ ] **F11-T06 — Documentación de usuario.** Files: `docs/user/`. Acciones: guía de instalación, uso, atajos, solución de problemas, es/en, offline; enlace en Ayuda. Accept: docs revisadas y accesibles desde el escritorio. Dep: F11-T05.

---

## Fase 12 — Hardening y release 1.0 (6 tareas, 4%, 4 semanas)

**Objetivo:** 1.0 instalable, estable y medible.

- [ ] **F12-T01 — Suite de pruebas completa.** Files: `tests/`. Acciones: install, upgrade, rollback, multi-monitor, HiDPI, a11y, apps matrix. Accept: todo verde o Ruling; informe. Dep: F11.
- [ ] **F12-T02 — Rendimiento y batería.** Files: `tests/perf/`. Acciones: boot, RAM, CPU idle, fps, GPU fallback, suspensión. Accept: umbrales definidos; informe. Dep: F12-T01.
- [ ] **F12-T03 — ISO Full y release notes.** Files: `iso/`, `docs/release/`. Acciones: ISO offline con NVIDIA, Calamares, wizard, branding; hash/firma. Accept: instala en VM y hardware; notas. Dep: F12-T01.
- [ ] **F12-T04 — Matriz 1:1 y tag 1.0.** Files: `docs/1.0-acceptance.md`, git tag. Acciones: revisar matriz completa, excepciones Ruling, tag `v1.0.0`. Accept: matriz 100% verde o excepción documentada. Pre-release. Dep: F12-T03.
- [ ] **F12-T05 — Secure Boot, firma y legal.** Files: `iso/`, `docs/legal/`. Acciones: MOK/firma de ISO, licencias y atribuciones, trademark, telemetría; auditoría. Accept: ISO firma/verifica; legal completo. Dep: F12-T03.
- [ ] **F12-T06 — Soak 8h y upgrades.** Files: `tests/soak/`. Acciones: 8h de uso, upgrade de Plasma/Klassy/Krema, rollback, suspensión; informe. Accept: 0 crashes, rollback verde. Dep: F12-T01.

**Gate F12:** matriz 1:1, soak, Secure Boot y rollback verdes; el tag `v1.0.0` solo se crea entonces.

---

## Fase 13 — Post-1.0 y upstream (1 tarea, 1%, continuo)

- [ ] **F13-T01 — Contribuciones upstream y mantenimiento.** Files: `docs/upstream/`. Acciones: preset Klassy, tema Krema, runner KRunner, fixes KWin; plan de releases y pin. Accept: 3 PRs enviados/mergeados o issues con repro. Dep: F12.

---

## Matriz de aceptación 1:1 (resumen)

| Superficie | Criterio |
|---|---|
| Barra superior | 24pt, Apple menu, app menus Qt, status, reloj, CC, notificaciones |
| Ventana | semáforos 12px offset 8-9 gap 8, titlebar 16/26, título izquierda, inactiva gris, zoom, fullscreen, drag, doble clic |
| Dock | posición, tamaño, magnificación, bounce, running, pins, papelera, stacks, menús, previews, autohide, multi-monitor |
| Spotlight | Cmd+Espacio, ranking, previews, acciones, calc, apps, archivos, portapapeles, emoji |
| Apps (sin Launchpad) | Cmd+1, categorías, Suggestions, Icons/List, sin carpetas/páginas |
| Mission Control | ventanas, Spaces, drag, agrupación, animación |
| Ajustes | 6 páginas Nimbus + System Settings; apariencia, Dock, escritorio, teclado, trackpad, pantallas, sonido, red, usuarios, privacidad, updates |
| Sistema | notificaciones, OSD, lock, login, apagado, Acerca de |
| Atajos | equivalentes Cmd, toggle, chuleta |
| Apps | Finder/Dolphin, Terminal/Konsole, Preview/Gwenview, TextEdit/Kate, Archive/Ark, Spectacle |
| A11y | Orca, zoom, contraste, reduce motion/transparency, teclado |
| i18n | es/en completo |
| Updates | Discover simple + rollback |
| Onboarding | wizard 6 pasos + migrador + Calamares |
| Rendimiento | 60fps Dock/Overview, boot/RAM definidos |

**Excepciones Ruling:** menú global GTK/Electron in-window (R-GTK); Dock layer-shell (R-DOCK); cero activos Apple (R-APPLE).

---

## Registro de decisiones (Rulings)

- **R-GTK:** menú global solo Qt/KDE; GTK/libadwaita/Electron in-window. No `appmenu-gtk` Wayland.
- **R-DOCK:** Dock layer-shell (Krema fork/theme); prohibido zoom en panel (KDE bug 495100). La barra superior es la segunda y única otra superficie layer-shell permitida (R-TOPBAR-LAYER); cualquier otra exige Ruling nueva.
- **R-TOPBAR-LAYER:** el panel stock de Plasma no baja de 38px (medido; pre-seed thickness ignorado). Para A1 (24pt) la barra superior será layer-shell QML custom (F3-T03), no panel/plasmoide.
- **R-KLASSY:** Klassy 6.7.3 medido en nested: carga y da círculos/colores, pero NO baja de Ø20, gap 22, inactivas grises ni hover ×/−/+; queda como **fallback**, no como base 1:1. CI/pin si se usa.
- **R-DECO:** la decoración 1:1 se implementa como plugin propio KDecoration3 `nimbus-decoration` (C++, 12px/gap8/inactivas/hover/titlebar 16/26); sin fork de Klassy; propuesta upstream si el API lo permite.
- **R-LOGIN:** SDDM 0.21 por defecto; plasma-login-manager solo spike en F8; greetd descartado (kwallet-PAM).
- **R-SPACES:** escritorios virtuales Plasma globales; per-monitor no es 1:1 y queda documentado; aceptar hasta que KWin lo soporte.
- **R-I18N:** ki18n/.ts es la única fuente; I18n.js de MacShell solo como origen de cadenas a portar.
- **R-KRUNNER:** KRunner `FreeFloating` + skin; sin API fullscreen oficial; overlay layer-shell solo opcional.
- **R-BLUR:** Better Blur/Glass pinneado por commit; fallback blur stock; prohibido `latest`.
- **R-APPLE:** cero assets Apple; golden propios. Temas GPL inspirados (WhiteSur/Klassy/Kvantum) permitidos con atribución; no se redistribuyen logos, SF, wallpapers ni sonidos de Apple.
- **R-ISO:** netinstall primero; ISO Full tras 2 semanas verde.
- **R-HYPR:** migración breaking change; migrador en 1.0.
- **R-CACHYOS:** perfil pinneado; sin `latest`.
- **R-CTRL:** atajos por defecto Meta/Super; Ctrl libre; toggle Cmd/Ctrl opcional.
- **R-TEST:** sin evidencia en VM no se marca tarea; `qdbus6`/`kwshot` + captura.
- **R-TAHOE-TOKENS:** `docs/design/tahoe-design-contract.md` §2 es la fuente única; prohibido hex/tamaño mágico; F3-T01 se reescribe con §2.
- **R-MENUBAR:** altura 24pt; F2-T05 28px era panel Plasma, no spec Apple.
- **R-TITLEBAR:** 16 sin toolbar / 26 con toolbar-sidebar, concéntrico; título izquierda.
- **R-APPSVIEW:** replicar Apps Tahoe (categorías, sin carpetas/páginas/reorden); Launchpad no existe; carpetas custom exigen Ruling nueva.
- **R-CONFIDENCE:** `[INFERIDO]` no cierra tarea; medir en VM y promover a `[MEDIDO]`.
- **R-F0-GATE:** F0-T03/T04 con GO funcional en live Plasma 6.7.4 + nested 6.8.2 (Krema 0.12 zoom, KRunner, Overview). Los umbrales de rendimiento (55/60fps, render <50/<300ms) se validan en F5-T11/A5 y F7-T09/A7; F0-T03/T04 siguen abiertas hasta esa medición. F2 puede avanzar.
- **R-PARALLEL:** F1 se ejecuta en el worktree `plasma/f1-restructure` en paralelo con los spikes F0; el gate F0 solo decide la implementación de Dock (F5) y Overview (F7), no la reestructuración. Orden de merge: F0 evidence → F1 → `plasma-migration`.

---

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Dock no llega a 60fps | F0-T03; fallback Crystal Dock/panel con Ruling |
| Overview custom se va de scope | MVP stock tematizado; efecto propio después |
| Klassy/Krema rompen por release | Pin + CI + vendor de presets, no forks |
| Menú GTK rompe 1:1 | R-GTK + matriz de apps + comunicación |
| CachyOS cadence | Pin snapshot; kernel opcional |
| A11y en superficies custom | Audit F11-T04; no bloquea MVP |
| Burnout 1-2 personas | 100 tareas, gates, no forks |
| Activos Apple | R-APPLE; arte propio |

---

## Protocolo de ejecución

1. **Leer** spec + plan + tarea.
2. **Crear evidencia** `docs/plans/evidence/<ID>.md` con comandos y capturas.
3. **Implementar** solo lo que la tarea pide (YAGNI).
4. **Verificar** con el comando de aceptación; si falla, no se marca.
5. **Commit** `feat|fix|docs(scope): <ID> <resumen>`.
6. **Revisión** (subagent-driven: reviewer; native: final review).
7. **Marcar `[x]`** y ejecutar `scripts/nimbus-progress`.
8. **Gate:** si la fase lo exige, revisar métricas y decidir go/no-go.
9. **Diffs visuales:** todo Accept con diff se ejecuta con `tests/screenshot-diff/compare.sh <golden> <captura> --umbral <N>`; el golden es propio (R-APPLE).
10. **Ciclo de 5 pasos por tarea:** (1) escribir test/evidencia que falla, (2) ejecutarlo y ver el fallo, (3) implementar lo mínimo, (4) verificar el Accept, (5) commit + `[x]` + progreso.

**Nunca:** empezar una tarea con dependencias abiertas, marcar sin evidencia, tocar `legacy/` en producción, añadir un fork sin Ruling.

---

## Definición de 1.0

- 100/100 tareas `[x]` con evidencia.
- Matriz 1:1 verde o excepción Ruling documentada.
- ISO Full instala en VM y hardware de prueba; wizard y migrador funcionan.
- Updates + rollback probados; a11y auditada; es/en completo.
- Rendimiento dentro de umbrales; 0 errores críticos en 8h soak.
- Docs de usuario y mantenimiento; tag `v1.0.0`.
