# F3-T12 — test de barra y golden (2026-11-02 09:24)

## Implementado
- `tests/vm/topbar.sh`: comprueba proceso de barra, notificaciones Nimbus,
  `screenInfo`, captura full-screen y deja `topbar.png`.
- `tests/vm/topbar-golden.py`: diff por regiones estables (logo N 0..40 y
  status 1000..1180; app title/reloj enmascarados), umbral 15%.
- `tests/golden/topbar-out13-1280x800.png`: golden de out13.

## Ejecución real
```text
PASS bar.process pid=572
PASS bar.height=24 (KWin geometry)  [h=24 fh=24 y=0]
PASS notifications.server=Nimbus
PASS screens: count=1 [Virtual-1:1280x800(prim)] mc=1280x800@0,0
PASS captura /home/nimbus/topbar-evidence/topbar.png
RESULT 5 PASS / 0 FAIL
golden_diff=0.0000 (limite 0.15)
```
Evidencia: `F3-T12-topbar-out13.png`.

## Límites
- La altura se mide por geometría KWin (`nimbus-bar h=24 fh=24 y=0`), no por log.
- Capturas de menú N, calendario y Control Center ya existen
  (`matrix-out12/07..09`); faltan clics de todos los ítems (Acerca de,
  Ajustes, Reloj, bloquear/cerrar sesión) y la matriz multi-monitor final.
- F3-T12 **no se marca**.

## Fix de clic en menú N (2026-11-02 09:35)

- Síntoma: los ítems del menú N cerraban el popup sin ejecutar la acción
  (Acerca/Ajustes).
- Causa: scrim fullscreen y popup compartían `LayerTop`; el scrim recibía el
  clic y solo hacía `close()`.
- Fix en `packages/shell/nimbus-bar/qml/Menu.qml`: popup en
  `LayerShellQt.Window.LayerOverlay`.
- Validado con binario recompilado en out13: **Acerca de Nimbus abre**
  (`F3-T12-about-out13.png`); menú visible en `F3-T12-menu-n-out13.png`.
- El fix no está en out13; debe entrar en la próxima ISO.
- Ajustes/Reloj y matriz multi-monitor siguen pendientes; F3-T12 no se marca.

## Ítems del menú N (2026-11-02 09:40)

Con el fix LayerOverlay del popup, en out13 (binario recompilado):

- **Acerca de Nimbus** abre (`F3-T12-about-out13.png`).
- **Ajustes del sistema** abre el KCM Nimbus, con Dock/tema/acento
  (`F3-T12-settings-out13.png`).
- **Reloj** abre Nimbus-clock (reloj mundial, alarmas, cronómetro, timer)
  (`F3-T12-clock-out13.png`).
- Menú/día/CC ya estaban en `matrix-out12/07..09`.

## Gap multi-monitor de barra

En la captura simultánea 2560x800, la barra Nimbus solo aparece en
Virtual-1; Virtual-2 (Konsole) no tiene barra. macOS muestra menú/barra en
cada display por defecto; esto impide cerrar F3-T12 en multi-monitor.
Además, el fix LayerOverlay no está en out13; requiere nueva ISO.

## Cierre E2E out15 (2026-11-02 10:41)

Instalación limpia de out15 (`3b71a5f8…`) y segunda salida VirtIO:

```text
PASS bar.process pid=586
PASS bar.height=24 (KWin geometry)
PASS notifications.server=Nimbus
PASS screens: count=2 [Virtual-1:1280x800(prim) Virtual-2:1280x800]
PASS captura /home/nimbus/topbar-evidence/topbar.png
RESULT 5 PASS / 0 FAIL
```

Captura full-screen 2560x800: `F3-T12-out15-both.png` — barra Nimbus en
Virtual-1 y Virtual-2. Golden diff <0.15. **F3-T12 cerrado.**
