# F3-T08 nested — reloj y calendario en barra

Fecha: 2026-10-31. Harness `tests/vm/nested-bar.sh` (sin modificar) con
wrapper a `nimbus-bar --demo-calendar` (abre el calendario al arrancar).

## Resultado: popup derecha anclado, mes/día/navegación OK

- Captura `spikes/nested/f3-calendar.png`: popup 280x320 arriba-derecha
  (cabecera "octubre 2026", grid L M X J V S D, día 31 resaltado azul,
  puntos placeholder en 1/15, ‹ ›); barra 24 intacta, cero errores QML.
- Medición PIL: barra oscura 75/80; 614 px azules en zona popup.
- Lógica JS Date simulada (`qmltestrunner`, 5 pass): oct-2026 31 días con
  3 blancos (jueves), wrap ene→dic2025 y dic→ene2027, feb bisiesto 29/28.
- `qmllint` limpio en `Calendar.qml` y `Bar.qml`.

## Implementación

`Calendar.qml` (scrim+popup patrón Menu/CC, `open/close/toggle/prev/next`);
`Bar.qml` (clic en reloj → `cal.toggle()`, `objectName: clock`); `main.cpp`
(`--demo-calendar`); `bar.qrc` (+`Calendar.qml`).

## Gaps

- Sin `Calendar.qml` en `bar.qrc` la barra moría en silencio (este Qt no
  imprime `qWarning` sin handler; hallazgo ya documentado en F3-T05).
- `x/y` del popup ignorados en layer-shell; anclaje real vía
  `anchors: Top|Right` (igual que CC en F3-T05).
- Sin clic/Esc reales en nested; eventos solo placeholder (días 1/15).

## Test qmltestrunner (`tests/qml/tst_calendar.qml`, Qt 6.12 offscreen)

Instancia el `Calendar.qml` real. Salida íntegra:
`8 passed, 0 failed` (`test_daysIn`, `test_header`, `test_leadBlanks`,
`test_leap`, `test_open_close`, `test_wrap` + init/cleanup).

## Cierre Esc / clic-fuera

Ambos llaman al mismo `root.close()` unit-testeado (`test_open_close`):
`Shortcut { sequence: "Escape" ... onActivated: root.close() }` (línea 42)
y scrim `MouseArea ... onClicked: root.close()` (línea 41), mismo patrón
que `Menu.qml` (líneas 45/48). Gap aceptado: sin inyección de tecla/clic
real en nested (el harness no la soporta); el camino `close()` sí verificado.
