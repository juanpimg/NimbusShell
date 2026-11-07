# Handoff — Sesión Limpia 2026-11-04 (Plasma 6.8.2 & Tahoe Liquid Glass)

> **Empieza por este documento.** Resume el estado real del proyecto tras la renovación estética **macOS Tahoe 1:1** y la integración de **Liquid Glass**, qué componentes están activos, cómo está estructurado el repositorio, cómo verificar la calidad y los pasos para continuar sin fricción.

---

## 0. TL;DR & Resumen Ejecutivo

- **Fecha:** 4 de noviembre de 2026.
- **Entorno del Host:** Arch Linux, KDE Plasma 6.8.2 (Wayland nativo), KWin 6.8.2, Qt 6.12, GCC 15, Python 3.14.
- **Rama de Trabajo:** `plasma-migration` (y `main`, ambas sincronizadas con `origin`).
- **Ledger de Progreso:** **103/112 tareas completadas (93.0%)**.
  - **Fases F1 a F11 completadas al 100%:** Base Plasma, barra NimbusBar, semáforos y decoraciones Aurorae, Dock Liquid Glass, Spotlight, Apps Launchpad, Mission Control, KCM Settings, Asistente Welcome, widgets/sistema y pulido visual/a11y.
  - **Fases pendientes:** F12 (Hardening final y release 1.0), F13 (Upstream) y
    los dos spikes históricos F0-T03/T04 (sus resultados viven en F5/F7; se
    mantienen sin marcar para no inflar el ledger).
- **Estado de CI:** `./scripts/ci.sh` está **100% VERDE** (44 grupos de checks
  sin warnings ni fallos; las suites internas suman 58+ comprobaciones).
- **Demostración en Video:**
  - Video MP4: `out/videos/nimbus-tahoe-ui-ux-demo.mp4` (2.74 MB, 1440×900, 25 fps, 59s).
  - Previsualización GIF: `out/videos/nimbus-tahoe-ui-ux-demo.gif` (3.43 MB).
  - 11 fotogramas clave en `out/videos/frames/`.
  - Grabador aislado vía Wayland virtual: `scripts/record-nimbus-demo.py`.

---

## 1. Arquitectura Óptica Liquid Glass & Estética macOS Tahoe 1:1

El sistema reproduce con precisión matemática la física de luz y geometría del diseño Tahoe sin utilizar activos de propiedad intelectual de Apple:

1. **Motor de Shaders KWin (`liquidglass.so`):**
   - **Refracción de Snell (`distort.glsl`):** Deformación no lineal de los contenidos situados detrás de los bordes redondeados orgánicos.
   - **Dual Kawase Blur (`downsample.frag` / `upsample.frag`):** Difuminado multicapa de 4 pasadas ejecutado en GPU sin carga apreciable de CPU.
   - **Curvatura Squircle Continua (`sdf.glsl`):** Funciones de distancia con signo (SDF) superelípticas (orden cuadrático continuo) aplicadas al Dock ($r=22\text{ px}$), Popovers ($r=18\text{ px}$) y ventanas ($r=16\text{ px}$).
   - **Resplandor Especular (`highlight.glsl`):** Hairline superior blanco translúcido de 1 px (#FFFFFF al 45% de opacidad) simulando iluminación cenital natural.
   - **Carga en KWin:** Configurado en `dotfiles/.config/kwinrc` (`[Plugins] liquidglassEnabled=true`) y cargado dinámicamente mediante la interfaz D-Bus de KWin (`loadEffect("liquidglass")`).
   - **Corrección de Scrims:** `BlurDecorations=false` en `kwinrc` para evitar que las superficies de captura de eventos a pantalla completa dibujen bordes espurios en Wayland.

2. **Componentes del Entorno de Escritorio:**
   - **Dock (`packages/dock/qml/Dock.qml`):** Cápsula continua de 66 px con fondo de cristal esmerilado, doble gradiente especular vertical, reflejos de suelo individuales invertidos bajo cada icono, magnificación parabólica suave en hover y puntos de ejecución.
   - **Barra Superior (`packages/shell/nimbus-bar/qml/Bar.qml`):** Translúcida (altura 24 px) con Menú Global sincronizado con la ventana en foco (**N** | **Kate** | Archivo...).
   - **Centro de Control (`ControlCenter.qml`):** Cuadrícula con 4 cápsulas de conectividad (140×64 px) y sliders horizontales estilo pastilla.
   - **Calendario y Reloj (`Calendar.qml`):** Popover de 300×368 px con rejilla mensual 6×7 y selector de meses.
   - **OSD In-Situ (`OSD.qml`):** Píldora de volumen/brillo bajo la barra superior.
   - **Notificaciones (`NotificationCenter.qml`):** Banners flotantes translúcidos con radio de 18 px, iconos y botones de acción.
   - **Semáforos Nativos (Aurorae):** Diámetro 12 px, separación 8 px, centros en x=25, 45, 65 con glifos interactivos solo al posar el cursor (+, -, x).

---

## 2. Organización del Repositorio

El proyecto sigue una estructura modular y limpia:

```
NimbusShell/
├── apps/                         # Aplicaciones independientes en C++/Qt6 y QML
│   ├── nimbus-about/             # Diálogo "Acerca de este equipo" translúcido
│   ├── nimbus-apps/              # Lanzador Launchpad (10 categorías fijas y teclado)
│   ├── nimbus-bug-report/        # Diagnósticos del sistema y reporte de incidencias
│   ├── nimbus-clock/             # Reloj mundial y cronómetro
│   ├── nimbus-help/              # Centro de ayuda y manual de atajos de teclado
│   ├── nimbus-hw/                # Detección y configuración de GPU / energía
│   ├── nimbus-migrate/           # Scripts de migración de escritorio e histórico Hyprland
│   ├── nimbus-missioncontrol/    # Mission Control, Spaces y expositor de ventanas
│   ├── nimbus-spotlight/         # Búsqueda universal con evaluación matemática en vivo
│   ├── nimbus-wallpaper/         # Gestor de fondo de pantalla y soporte LayerShell
│   ├── nimbus-welcome/           # Asistente de configuración inicial (7 pasos)
│   └── backup/                   # Utilidad de copia de seguridad nimbus-backup
├── dotfiles/                     # Dotfiles canónicos del sistema
│   ├── .config/                  # kwinrc, kdeglobals, nimbus-bar, etc.
│   └── .local/share/aurorae/     # Temas de decoración de ventanas Aurorae Tahoe
├── packages/                     # Componentes modulares del entorno
│   ├── dock/                     # Dock Liquid Glass (Dock.qml, lanzadores, iconos)
│   ├── kcm/kcm_nimbus/           # Módulo de System Settings (6 páginas de configuración)
│   ├── kwin/effects/             # Efectos adicionales de KWin (nimbus-overview)
│   ├── shell/nimbus-bar/         # Barra superior propia en C++ y QML
│   └── themes/                   # Temas de color NimbusTahoe, wallpapers y tokens
├── packaging/                    # Recetas de empaquetado para Arch Linux
│   ├── glass/                    # PKGBUILD para kwin-effects-glass / liquidglass
│   ├── klassy/                   # PKGBUILD para decoraciones Klassy
│   └── krema/                    # PKGBUILD para Krema dock
├── scripts/                      # Herramientas de desarrollo, verificación y automatización
│   ├── ci.sh                     # Suite de integración continua (58 verificaciones)
│   ├── record-nimbus-demo.py     # Grabador automatizado de video y fotogramas en KWin virtual
│   ├── nimbus-progress           # Herramienta del ledger de progreso ponderado
│   ├── nimbus-theme              # Conmutador de temas claro/oscuro
│   ├── nimbus-dock               # Lanzador y controlador del dock
│   ├── nimbus-trash              # Gestor de papelera
│   ├── nimbus-updates            # Gestor de actualizaciones y snapshots
│   └── nimbus-i18n               # Herramienta de sincronización de traducciones (es/en)
├── tests/                        # Pruebas unitarias, de integración, a11y y de aceptación
├── iso/                          # Perfil de construcción de la imagen ISO NimbusOS
├── i18n/                         # Archivos de traducción Qt Linguist (nimbus_es.ts, nimbus_en.ts)
├── assets/                       # Logotipos propios (N) y arte libre
├── docs/                         # Documentación de arquitectura, planes, evidencia y handoffs
└── out/                          # Binarios compilados y videos generados (ignorado en git)
```

---

## 3. Comandos Rápidos para Iniciar una Nueva Sesión

Copia y pega estos comandos para arrancar y verificar el estado inmediatamente:

```bash
# 1. Comprobar estado de git
git status

# 2. Correr la suite de verificación completa (debe ser 100% VERDE)
./scripts/ci.sh

# 3. Comprobar el ledger de progreso (debe indicar 93.0%, 103/112)
scripts/nimbus-progress

# 4. Formatear archivos QML si se modifican (usar siempre la ruta Qt6 de Plasma 6.8)
/usr/lib/qt6/bin/qmlformat -i <archivo.qml>

# 5. Grabar o actualizar el video de demostración UI/UX (ejecución sin monitor físico ni root)
python3 scripts/record-nimbus-demo.py
```

---

## 4. Estado de las Tareas Pendientes (Para Continuar)

El desarrollo principal de la UI, la barra, el dock, los shaders y todas las aplicaciones de usuario (Fases F1 a F11) está terminado y verificado. Para llevar el proyecto a la versión 1.0 definitiva, las tareas pendientes del ledger son:

### Fase 0 — Spikes históricos (2 tareas sin marcar)
1. **F0-T03 — Spike Dock layer-shell (Krema).** Superado por F5: el Dock real
   está implementado y verificado. Se deja sin marcar para no inflar el ledger.
2. **F0-T04 — Spike KRunner fullscreen + KWin Overview.** Superado por F6/F7:
   Spotlight y Mission Control están implementados. Se deja sin marcar.

### Fase 12 — Hardening y Release 1.0 (6 tareas restantes)
1. **F12-T01 — Suite de pruebas completa:** Pruebas combinadas en hardware/VM multimonitor, diferentes escalas HiDPI (1x, 1.25x, 2x) y matrices completas de accesibilidad.
2. **F12-T02 — Rendimiento y batería:** Medición de uso de memoria RAM en reposo, CPU idle (< 1%), tasa de refresco a 60/120 fps y comportamiento en suspensión (`systemd-suspend`).
3. **F12-T03 — ISO Full y Release Notes:** Ensamblaje final de la ISO offline de NimbusOS incorporando los binarios actualizados, branding unificado y notas de lanzamiento.
4. **F12-T04 — Matriz 1:1 y Tag 1.0:** Auditoría de la matriz de paridad contra macOS Tahoe y etiquetado `v1.0.0` en git.
5. **F12-T05 — Secure Boot, firma y verificación legal:** Certificación de licencias de activos (GPL-3.0, MIT, Creative Commons / Dominio Público) y firma de la ISO.
6. **F12-T06 — Soak test de 8h:** Verificación de estabilidad continua durante 8 horas sin fugas de memoria en KWin o NimbusBar.

### Fase 13 — Upstream y Mantenimiento (1 tarea)
- **F13-T01 — Contribuciones upstream:** Envío de parches a proyectos de la comunidad (Klassy, Krema, KWin effects) documentando las soluciones encontradas en NimbusShell.

---

## 5. Reglas Inviolables (`AGENTS.md`)

- **Idioma:** Documentación y respuestas siempre en **español**. Identificadores de código en inglés.
- **Sin activos de Apple:** Prohibido el uso de tipografías San Francisco, logos de Apple o fondos propietarios. Se utiliza **Inter**, logo propio **N** y fotografías de dominio público (US NPS Sequoia).
- **Sin privilegios de root:** Todo el desarrollo, compilación y pruebas debe ejecutarse en espacio de usuario.
- **Entorno de pruebas:** Preferir sesiones Wayland virtuales (`kwin_wayland --virtual`) antes que construir imágenes ISO repetitivamente.
- **Trazabilidad y evidencia:** Todo cambio debe acompañarse de su prueba correspondiente en `scripts/ci.sh` o evidencias en `docs/plans/evidence/`.

---

## 6. Actualización 2026-11-07 — reparaciones y deuda conocida

- Todo el trabajo del 4-nov quedó commiteado (app, temas, tests, evidencias y
  este handoff); `git status` limpio.
- `scripts/apply-theme` ya aplica la decoración **Aurorae** canónica
  (`MacTahoeLiquidKde-Dark/Light`), no Klassy. `install.sh` instala sus
  recursos con `--resources-only`; los dotfiles activan el tema y no se
  reescriben para no generar drift falso.
- `lib/apps.sh` despliega las apps de script y las herramientas de usuario
  (`nimbus-theme`, `nimbus-dock`, `nimbus-updates`…) en `~/.local/bin`, con sus
  recursos en `~/.local/share/nimbus/`, y verifica que sean 1:1; las apps GUI
  se compilan con `scripts/build-components` (9/9 verificado) o con la ISO.
- CI incorpora `tests/apps/test_apps_deploy.sh`,
  `tests/install/test_deploy_home.sh`, `tests/install/test_build_components.sh`
  y `tests/docs/test_docs_consistency.sh`.
- **Deuda conocida:** ISO final con los binarios/KCM ya compilables con
  `scripts/build-components` (F12-T03), skel de NimbusOS
  (`docs/SKEL-SYNC.md`), F12 completo y F13.
- Detalle de la sesión: [`docs/SESSION-2026-11-07-FIXES.md`](SESSION-2026-11-07-FIXES.md).
