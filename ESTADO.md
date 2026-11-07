# Estado — NimbusShell

Actualizado: **2026-11-07**. Rama de trabajo: `plasma-migration` / `main`.
Documento maestro para continuar: **[`docs/SESSION-2026-11-04-HANDOFF.md`](docs/SESSION-2026-11-04-HANDOFF.md)**.
Reparaciones de coherencia de esta sesión: **[`docs/SESSION-2026-11-07-FIXES.md`](docs/SESSION-2026-11-07-FIXES.md)**.

## Objetivo

Experiencia **1:1 con macOS Tahoe** sobre KDE Plasma 6.8.2 Wayland, con pruebas
reales (virtual Wayland/VM/PC) y capturas. Sin activos propietarios de Apple. Ledger
real: **103/112 (93.0%)**; fases F1 a F11 completadas al 100%.

## Estado en una frase

NimbusShell cuenta con estética integral **macOS Tahoe 1:1** y motor **Liquid Glass**
(óptica de Snell, Dual Kawase blur, squircles SDF continuos y bisel especular), Dock
con reflejos invertidos, barra superior translúcida con Global Menu, conjunto
completo de aplicaciones propias, módulo KCM con 6 páginas y demostración en vídeo;
`./scripts/ci.sh` pasa al 100% VERDE.

## Qué está verde

- `./scripts/ci.sh` **100% VERDE**: 44 grupos de checks (lint, QML, i18n,
  ledger, tema, apps, docs, KWin, seguridad, HW, aceptación VM y packaging).
- Ledger en **103/112 (93.0%)**, fases F1 a F11 al 100%.
- **Dock Liquid Glass:** cápsula continua de 66 px, reflejos individuales de
  suelo por icono, gradiente especular vertical y magnificación parabólica suave.
- **Barra Superior 24 px:** translúcida con hairline de 1 px, Menú Global
  sincronizado, Menú Nimbus/Apple, Centro de Control con cápsulas 140×64 px y
  sliders estilo pastilla.
- **Calendario & Reloj:** Popover esmerilado de 300×368 px con rejilla 6×7 y
  selector de meses.
- **OSD In-Situ & Notificaciones:** barra de volumen bajo panel superior y
  banners flotantes Tahoe.
- **Efecto Compositor KWin:** plugin `liquidglass.so` cargado por D-Bus,
  `BlurDecorations=false` en `kwinrc`.
- **Tema Tahoe aplicado por el instalador:** color schemes NimbusTahoe/Light,
  Kvantum, decoración Aurorae `MacTahoeLiquidKde-Dark/Light` y fondo NPS.
- **Instalador:** despliega paquetes, dotfiles, tema, scripts/efectos KWin,
  preset del Dock, apps de script (`nimbus-hw`, migradores, backup,
  bug-report) y herramientas de usuario (`nimbus-theme`, `nimbus-dock`,
  `nimbus-updates`…) en `~/.local/bin`, con sus recursos en
  `~/.local/share/nimbus/`.
- **Ajustes del Sistema (KCM):** 6 páginas integradas en System Settings.
- **Traducciones:** 367 cadenas en español e inglés sin pendientes.
- **Demostración en Vídeo:** MP4 H.264, GIF y 11 fotogramas en `out/videos/`.

## Qué queda pendiente

- **F0-T03/T04 (históricos):** spikes de Dock layer-shell y KRunner/Overview.
  Sus resultados se materializaron en F5 y F7; siguen sin marcar para no inflar
  el ledger. No bloquean F12.
- **F12-T01 a F12-T06:** hardening, multimonitor/HiDPI, rendimiento y batería,
  ISO offline final, auditoría de licencias/Secure Boot y soak test de 8 h.
- **F13-T01:** contribuciones upstream (Klassy, Krema, KWin effects).
- **Skel de NimbusOS:** port aplicado en la rama `plasma-skel-sync`
  (`917cc0f`, 59 ficheros) con 9 extras legacy/ISO; pendiente de revisión,
  merge y push en NimbusOS. Ver [`docs/SKEL-SYNC.md`](docs/SKEL-SYNC.md).
- **Binarios GUI + KCM:** `scripts/build-components` los compila e instala en
  `~/.local` (9 GUI + KCM verificado); `install.sh` no instala el toolchain y
  `--check` los marca `[PENDIENTE]` hasta que se compilen (F12-T03).

## Dónde mirar

- `docs/SESSION-2026-11-04-HANDOFF.md` — handoff maestro.
- `docs/SESSION-2026-11-07-FIXES.md` — reparaciones y evidencia de esta sesión.
- `docs/SKEL-SYNC.md` — divergencia dotfiles ↔ skel.
- `docs/superpowers/plans/2026-10-31-plasma-migration.md` — ledger detallado.
- `docs/plans/evidence/` — evidencias de pruebas y auditorías de paridad.
- `scripts/record-nimbus-demo.py` — grabador de vídeo en Wayland virtual.
- `out/videos/nimbus-tahoe-ui-ux-demo.mp4` — grabación maestra.

## Reglas invariables

`AGENTS.md` sigue mandando: sin privilegios de root, sin activos de Apple
(Inter, logo N y dominio público), pruebas con evidencia real, backups
automáticos y Rulings documentadas.
