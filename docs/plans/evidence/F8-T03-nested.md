# F8-T03 — Evidencia nested (Red real)

## Controles (estado en vivo vía `load()` + botones; cambios al momento)
- Wifi: interruptor (`nmcli radio wifi on/off`), SSID actual, botón
  «Buscar redes» (`rescan` + `nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY`),
  lista con icono de señal y candado; clic en red → diálogo de contraseña
  (`connectWifi`: la clave viaja solo en memoria a `nmcli`, jamás se guarda).
  Parseo con `:` escapados. Sin `nmcli` → mensaje «sin wifi».
- Bluetooth: interruptor (`bluetoothctl power`), vinculados
  (`bluetoothctl devices` + `info` por MAC → nombre|mac|conectado).
  Emparejar nuevos pide agente: se indica con «sin aparatos vinculados».
- Impresoras: `lpstat -p` si existe; aquí no hay CUPS → mensaje honesto
  «Sin soporte de impresión (falta CUPS)».
- Saltos a `kcm_networkmanagement`/`kcm_bluetooth` como avanzados.
- Sin root en ningún control.

## Tests (dentro de `test-pages.sh`, 41/41 PASS total)
Escenario `network` (solo lectura, sin tocar radios del host):
`wifiAvailable=true`, `wifiEnabled=true`, `wifiCount=21`,
`bluetoothAvailable=true`, `printingAvailable=false`.
Conexión real (`connectWifi`) deliberadamente sin test (cambiaría la red
del host); el parseo de red/SSID queda cubierto por el listado.

## Captura
`spikes/nested/f8-kcm-network.png`: KCM en Red con 9 redes reales del
NetworkManager del host, candados e iconos de señal; `QML_ERRORS=0`.
Trampa: el `rcc` no re-embebía `ui/*.qml` cambiados (el `.so` mostraba la
página vieja) → `OBJECT_DEPENDS` en `CMakeLists.txt` + reinstalación
forzada (el `cmake --install` dijo «Up-to-date» con binario rancio).

## Review: vincular/conectar e imprimir (sin root)
- `pairBluetooth/connectBluetooth/disconnectBluetooth(mac)` Q_INVOKABLE:
  validan MAC, usan `bluetoothctl pair/connect/disconnect`, éxito =
  «…uccessful…» sin «Failed»; refrescan y ponen estado en UI.
- `scanBluetooth()`: descubrimiento 10 s (`--timeout 10 scan on`),
  fusiona no vinculados como `paired=0`; la lista muestra Vincular /
  Conectar / Desconectar según estado (modelo `nombre|mac|conectado|
  vinculado`).
- `printTestPage(printer)`: página temporal propia en `$TMPDIR`
  + `lp -d`; sin CUPS (`lpstat` ausente) avisa y no hace nada.
- Tests con fakes en PATH (`tests/kcm/fakes/`: `bluetoothctl` con
  estado enlatado + `FAKE_BT_FAIL`, `lp`/`lpstat`, `pkexec`, `pamac`):
  pair/connect/disconnect OK + log invocado, pair-fallo honesto,
  print OK (fake `lp` invocado) y sin-CUPS honesto.
- Trampa: los fakes con shebang `#!/usr/bin/env bash` mueren con PATH
  mínimo (`env: bash no existe`) → shebang `#!/bin/bash`.
