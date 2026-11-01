# apps/nimbus-welcome (`org.nimbus.welcome`)

Wizard de primer arranque en 7 pasos (bienvenida, idioma, Wi-Fi,
cuenta/avatar, apariencia, diseño, apps, tour) + elección de layout Mac/Win/Nimbus
+ apps recomendadas + toggle Cmd/Ctrl y chuleta.

- **Qué va:** wizard reanudable/omisible (<5 min), presets de layout,
  instalador Flatpak/PackageKit no bloqueante.
- **Qué no:** migración de datos (es `nimbus-migrate`) ni ajustes
  persistentes (es el KCM).

## F9-T02 (implementado)
- Build: `cmake -S . -B build && cmake --build build && ctest`.
- Abrir: `./build/nimbus-welcome --demo` (`--page <n|nombre>`, `--shot`,
  `--reset`; `NIMBUS_WELCOME_SIM=1` en test: simula wifi/apariencia).
- Estado: `~/.config/nimbus-welcome.ini` (reanuda paso; completado + sin
  `--demo` = sale con 0). Evidencia: `docs/plans/evidence/F9-T02-nested.md`.

## F9-T03 (implementado)
- Paso 6/7 «Diseño»: tarjetas Mac (defecto) / Windows / Nimbus con
  preview mock (semáforos izq/der + Dock) y descripción; «Aplicar diseño»
  llama a `backend.applyLayout()`.
- Estado: `layout/name` en `nimbus-welcome.ini` + espejo en
  `~/.config/nimbus-layout.ini` (`[Layout] name=`).
- `scripts/nimbus-layout [mac|windows|nimbus] [--apply|--check|--revert]
  [--home DIR]` (`set -u`, sin root, idempotente, backup en
  `~/.config/nimbusshell-backup-layout`): botones XIA izq (Mac/Nimbus) o
  IAX der (Windows), atajos vía `nimbus-keys` (meta/ctrl), Dock Krema
  abajo tile 48 (`kremarc`), barra 24 (`plasmashellrc`), doble-clic =
  maximizar (≈zoom; KWin no tiene zoom). El modo Windows reescribe
  Meta+<tecla> a Ctrl+<tecla> solo en `kglobalshortcutsrc` (opt-in por
  elección, revertible; no toca binds Ctrl fuera de ese fichero).
- Flag `--layout <nombre>` para preseleccionar (test/capturas).
- Evidencia: `docs/plans/evidence/F9-T03-nested.md`.
