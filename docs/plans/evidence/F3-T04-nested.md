# F3-T04 nested — menú Apple en barra

Fecha: 2026-10-31. Harness `tests/vm/nested-bar.sh` (sin modificar) con
`--bin` wrapper a `nimbus-bar --demo-menu` (abre el menú al arrancar;
`demo=true` inhibe `runner.run`, solo UI/log).

## Resultado: menú visible, 7 items, barra 24 intacta

- Captura: `spikes/nested/f3-menu.png` — popup bajo el logo N con los 7
  items (Acerca de Nimbus, Ajustes…, Dormir, Bloquear, Cerrar sesión,
  Reiniciar…, Apagar…); kate debajo sin solape; sin errores QML en log.
- Medición PIL (x=640 y x=100): transición en y=24/25 → **barra 24 px**,
  popup flotando en y=26 sin romper exclusiveZone.
- Acciones destructivas NO ejecutadas en el test (solo UI); reboot/poweroff
  piden confirmación Sí/No en QML. Comandos reales: `systemsettings`,
  `systemctl suspend`, `loginctl lock-session`, etc. vía `CommandRunner`.

## Implementación

`commandrunner.h` (QProcess, `run(QString)`, señal `finished`, como
`runner`); `qml/Menu.qml` (Item con scrim fullscreen + popup, Esc/scrim
cierran); `Bar.qml` (logo clicable); `main.cpp` (`--demo-menu`).

## Limitaciones

- Esc requiere foco: scrim usa `OnDemand` solo con menú abierto (cerrado
  → invisible → cero robo de teclado). Sin test de tecla real en nested.
- Popup posicionado x=8/y=26 fijos (no anclaje geométrico al logo); en
  1280x800 nested coincide con el logo. Sin iconos externos (arte propio).
