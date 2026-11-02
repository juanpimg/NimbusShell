# F3-T09 — Banner de notificaciones Tahoe (2026-11-02)

## Cambio

`NotificationCenter.qml` acerca el banner a macOS Tahoe:

- Ancho 360 px; radio 18 (antes 12); padding 12.
- Icono 38 px (antes 28), badge de inicial 18 px si no hay `iconSource`.
- Cabecera app · hora en 11, título 13 semibold, cuerpo 12, acciones.
- Acciones visibles (`Abrir`, `Posponer`) con foco/teclado; × de descarte.
- Ventana 368 px con margen 4; scope `nimbus-notifications` sigue en la
  allowlist Glass (blur/refracción si el plugin está activo).
- El demo local (`--demo-notification`) siembra ahora una notificación con
  acciones y timeout 60 s para poder capturarla; el servidor real sigue usando
  el `expire_timeout` FDO.

## Evidencia

- `F3-T09-notifications-tahoe.png` (1280×800) y `-crop.png` (365×131).
- Nested con wallpaper Nimbus + Glass sutil:
  `tests/vm/nested-bar.sh --bin /tmp/nimbus-bar-dev/nimbus-bar
  --wallpaper sequoia-dark.jpg --kwinrc /tmp/opencode/glass-kwinrc-subtle
  --plugin-path /tmp/glass-prefix/lib/plugins --bar-args "--demo-notification"`.
- Log: `nimbus-notifications` scope, `glass scope=nimbus-notifications`,
  `nimbus-bar VIVO`; sin TypeError QML.
- Geometría efectiva de la ventana: ancho 368 (banner 360 + 8); el banner
  crece con el contenido y las acciones.
- `qmllint` y build CMake PASS.

## Límites

- La captura usa el **demo local**; no se ha repetido el `ActionInvoked` por
  un cliente FDO real ni la pila de 2 notificaciones en la VM instalada.
- DND (`Inhibit`) y timeout FDO ya estaban cubiertos por F3-T09; no se
  reabren aquí.
- Las acciones se muestran siempre; macOS las revela al hover. Es una
  aproximación visual, no un fallo funcional.
- Sin validación en VM/PC instalada.
