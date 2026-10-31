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

## Fix --log-actions (evidencia de las 7 acciones)

`--log-actions` invoca `Menu.logAllActions()` desde C++ (recorre el
modelo QML real); `runner.logAction` escribe `MENU_ACTION <id> <cmd>` a
stderr. `runner.run` inhibido en demo → destructivos nunca se ejecutan.
Log nested (`nested-bar.log`, `nimbus-bar: demoMenu=1 logActions=1`):

```text
MENU_ACTION 0 -
MENU_ACTION 1 systemsettings
MENU_ACTION 2 systemctl suspend
MENU_ACTION 3 loginctl lock-session
MENU_ACTION 4 loginctl terminate-session
MENU_ACTION 5 systemctl reboot
MENU_ACTION 6 systemctl poweroff
```

Trampa: con `JOURNAL_STREAM` heredado, Qt 6 manda qInfo/console.log al
journal y el log nested queda vacío; el wrapper usa `env -u
JOURNAL_STREAM QT_FORCE_STDERR_LOGGING=1` (verificado: 0 líneas sin el
fix, 7 con él; `strings` no sirve: el qrc va comprimido).
Acciones reales (clic) se prueban en sesión instalada; reboot/poweroff
con confirmación Sí/No. Whitelist de comandos en `CommandRunner`
pendiente para endurecer (no bloquea F3-T04).

## Limitaciones vigentes

- Esc: scrim `OnDemand` solo con menú abierto (cerrado → invisible →
  cero robo de teclado). Sin test de tecla real en nested.
- Popup en x=8/y=26 fijos (no anclaje geométrico al logo); en 1280x800
  coincide con el logo. Sin iconos externos (arte propio).
