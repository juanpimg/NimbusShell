# F3-T12 — barra en Virtual-1 y Virtual-2 (2026-11-02 10:09)

Implementado en `nimbus-bar` un solo proceso que crea **una ventana
layer-shell por QScreen**:

- `Bar.qml` nace `visible:false` (sin `visibility`, que provocaba conflicto).
- C++ crea la ventana primaria + una `QQmlComponent` por cada pantalla
  adicional, fija `QWindow::setScreen` y `LayerShellQt::Window::setScreen`
  antes de mostrarla.
- Un único `NotificationServer`/bus `org.nimbus.Bar`.

Validación en out13 con `virtio-gpu-pci` (Virtual-1 + Virtual-2):

```text
nimbus-bar: barra secundaria en Virtual-2
nimbus-bar: servidor org.freedesktop.Notifications activo
```

Captura full-screen 2560x800: `F3-T12-multiwindow-both.png` — barra Nimbus
arriba en ambas salidas (N Konsole/reloj/estado).

Pendiente para cerrar F3-T12: incluir en ISO (out15), instalar/E2E y repetir
la matriz de menús/multi-monitor sobre el sistema instalado.
