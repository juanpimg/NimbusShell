# apps/nimbus-welcome (`org.nimbus.welcome`)

Wizard de primer arranque en 6 pasos (bienvenida, idioma, Wi-Fi,
cuenta/avatar, apariencia, apps, tour) + elección de layout Mac/Win/Nimbus
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
