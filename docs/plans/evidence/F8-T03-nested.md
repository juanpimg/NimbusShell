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
