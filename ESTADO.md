# Estado — NimbusShell

Actualizado: **2026-11-04**. Rama de trabajo: `plasma-migration` / `main`.
Documento maestro para continuar: **[`docs/SESSION-2026-11-04-HANDOFF.md`](docs/SESSION-2026-11-04-HANDOFF.md)**.

## Objetivo

Experiencia **1:1 con macOS Tahoe** sobre KDE Plasma 6.8.2 Wayland, con pruebas
reales (virtual Wayland/VM/PC) y capturas. Sin activos propietarios de Apple. Ledger
real: **103/112 (93.0%)**; 100% de fases F1 a F11 completadas.

## Estado en una frase

NimbusShell cuenta con estética integral **macOS Tahoe 1:1** y motor **Liquid Glass**
(óptica de Snell, Dual Kawase blur, squircles SDF continuos y bisel especular), Dock con
reflejos invertidos, barra superior translúcida con Global Menu, conjunto completo de
aplicaciones propias (`nimbus-about`, `apps`, `spotlight`, `missioncontrol`, `welcome`),
módulo KCM con 6 páginas y demostración en video generada; `./scripts/ci.sh` pasando al 100% VERDE.

## Qué está verde

- `./scripts/ci.sh` **100% VERDE** (58 suites de pruebas sin warnings ni fallos).
- Ledger en **103/112 (93.0%)**, fases F1 a F11 al 100%.
- **Dock Liquid Glass:** cápsula continua de 66 px ($r=22\text{ px}$), reflejos individuales de suelo por icono, gradiente especular vertical y magnificación parabólica suave.
- **Barra Superior 24 px:** translúcida con hairline de 1 px (#FFFFFF a 45%), Menú Global sincronizado, Menú Nimbus/Apple, Centro de Control con cápsulas 140×64 px y sliders estilo pastilla.
- **Calendario & Reloj:** Popover esmerilado de 300×368 px con rejilla 6×7 y selector de meses.
- **OSD In-Situ & Notificaciones:** Barra de volumen bajo panel superior y banners flotantes Tahoe ($r=18\text{ px}$).
- **Efecto Compositor KWin:** Plugin C++ `liquidglass.so` cargado dinámicamente vía D-Bus (`loadEffect("liquidglass")`), `BlurDecorations=false` en `kwinrc` eliminando halos perimetrales.
- **Aplicaciones de Usuario:** `nimbus-about`, `nimbus-apps` (Launchpad), `nimbus-spotlight` (búsqueda con motor de cálculo), `nimbus-missioncontrol` (Spaces y ventanas), `nimbus-welcome` (wizard 7 pasos), `nimbus-clock`, `nimbus-bug-report`, `nimbus-wallpaper`.
- **Ajustes del Sistema (KCM):** 6 páginas configurables integradas en System Settings de Plasma (Apariencia, Sistema, Atajos, Red, Accesibilidad, Actualizaciones).
- **Traducciones:** 367 cadenas en español e inglés sin cadenas pendientes.
- **Demostración en Video:** Video MP4 H.264 (2.74 MB, 1440×900, 25 fps, 59s), previsualización GIF (3.43 MB) y 11 fotogramas clave en `out/videos/`.

## Qué queda pendiente (Fases F12 y F13)

- **F12-T01 a F12-T06:** Hardening, pruebas en multimonitor y escalas HiDPI, medición de consumo de batería/CPU idle (< 1%), construcción de ISO offline final, auditoría de licencias/Secure Boot y soak test de 8h.
- **F13-T01:** Propuestas y contribuciones upstream a proyectos de la comunidad (Klassy, Krema, KWin effects).

## Dónde mirar

- `docs/SESSION-2026-11-04-HANDOFF.md` — **Handoff maestro actual**.
- `docs/superpowers/plans/2026-10-31-plasma-migration.md` — Ledger detallado de tareas.
- `docs/plans/evidence/` — Evidencias de pruebas y auditorías de paridad.
- `scripts/record-nimbus-demo.py` — Grabador automatizado de video para pruebas visuales en Wayland virtual.
- `out/videos/nimbus-tahoe-ui-ux-demo.mp4` — Grabación master de la experiencia de usuario.

## Reglas invariables

`AGENTS.md` sigue mandando: sin privilegios de root, sin activos de Apple (Inter, logo N y dominio público), pruebas con evidencia real, backups automáticos y Rulings documentadas.
