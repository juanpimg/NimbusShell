# Evidencia F3-T12-notif-server — servidor FDO en nimbus-bar

Fecha: 2026-11-01. Rama `plasma/f3-notif2` (base `plasma-migration`).
Harness `tests/vm/nested-notifications.sh` (plantilla
`tests/vm/nested-bar.sh`: HOME/XDG temporales, `--no-lockscreen`,
cleanup por trap). KWin 6.8.2 virtual 1280x800 + nimbus-bar **SIN
plasmashell** (nombre `org.freedesktop.Notifications` libre) +
`notify-send` real. Resultado: **PASS=12 FAIL=0, exit=0**
(`spikes/nested/nested-notifications.log`).

## Protocolo (spec 1.2, `notificationserver.h/.cpp`)

- `GetServerInformation` → `Nimbus / NimbusOS / 1.0 / 1.2` ✓ (qdbus6).
- `GetCapabilities` → `body, actions, icon-static, persistence,
  body-markup` ✓.
- `Notify` devuelve IDs incrementales (1, 2, 3…); `replaces_id` (-r)
  actualiza en su sitio y conserva el id (3→3) ✓.
- Señales verificadas con suscriptor python3-dbus (AddMatch) +
  `InvokeAction`/`CloseNotification` por `gdbus`:
  `SIG ActionInvoked 2 open`, `SIG NotificationClosed 2 2` (tras la
  acción el banner se descarta), `SIG NotificationClosed 1 3`
  (`CloseNotification` → reason 3) ✓ (`spikes/nested/sig-actions.log`,
  `sig-close.log`).
- Cierres: timeout (reason 1), usuario ×/clic/Esc (reason 2),
  `CloseNotification` (reason 3), expulsión por límite (reason 4).
- Hints: `urgency` byte 0/1/2 (clamp), `category`, `desktop-entry`,
  `image-path`/`app_icon` ruta → `file://`, `image-data`
  (iiibiiay) validado por viabilidad (sin caché a disco: QML dibuja
  badge con inicial); `iconName` expuesto como rol para uso futuro.
- Extensiones Nimbus (documentadas en cabecera, fuera de spec, solo
  verificación): propiedad `HistoryCount` y método `InvokeAction(id,key)`
  (el clic real no es inyectable en nested sin wtype/ydotool/uinput —
  mismo gap que F3-T09 §2).

## Capturas (`spikes/nested/`)

- `f3-notif2-banner.png`: banner glass arriba-derecha bajo la barra
  (y=28), ~360px, badge «N», «Nimbus · HH:mm», summary/body, × ✓.
- `f3-notif2-actions.png`: pila de 2 banners + botón «Abrir»
  (`-A "open=Abrir"`) ✓. A diferencia del applet Plasma (F3-T09: sin
  botón si el emisor ya salió), el servidor propio pinta acciones
  siempre.
- `f3-notif2-dnd.png`: con `Inhibited=true`, **sin banner** ✓.
- `f3-notif2-timeout-before/after.png`: visible / ausente.
- QMLERR=0 (grep TypeError/ReferenceError/assign/file-qml-error) ✓.

## DND

`Inhibited` (bool) + `InhibitedBy` (string) como propiedades
lectura/escritura sobre la misma interfaz (`org.freedesktop.DBus.
Properties.Set`). Con DND: `hcount 0→1` (historial guardado con rol
`inhibited=true`, sin banner); al desactivar, la pendiente NO reaparece
(flag por notificación en la llegada) ✓.

## Timeout

`-t 2000`: `hcount base=0 antes=1 después=0` (T0→T1 ≈ 5.25s con
sleeps del harness) ✓. Mapeo: `<0` → 5000 (default), `0` =
persistente (banners de la evidencia usan `-t 0`), `>0` = tal cual.

## Conflicto con el servidor stock

2ª instancia de nimbus-bar con el nombre tomado: **sigue VIVA** y
loguea `org.freedesktop.Notifications ya registrado (plasmashell
stock?) — sigo SIN servidor de notificaciones` (fprintf: qWarning se
suprime en este Qt, F3-T05-fix); la 1ª (dueña) sigue viva ✓. Flags:
`--notifications` (defecto, intenta), `--no-notifications` (omite),
`--demo-notification` (siembra una local a los 2.5s, con o sin bus).

## Gap de posición (medido y corregido en este run)

Con solo `AnchorTop`, layer-shell centra la superficie en horizontal
(banner al centro en el primer run). Fix: `AnchorTop | AnchorRight`
(patrón `Calendar.qml:92`) + `x = Screen.width - width - 12` como
margen. Verificado en `f3-notif2-actions.png` (pila arriba-derecha).
Sin gap pendiente en layer-shell.

## Límites

- Modelo `QAbstractListModel` (roles nid/app/summary/body/iconSource/
  iconName/actions/urgency/category/timeStr/timestamp/inhibited),
  la más nueva primera, **límite 50** (expulsa la más antigua con
  reason 4); QML muestra `banners` (no-inhibidas) con **stack máximo 4
  + contador «+N más»**; agrupación por app vía rol `app` (sección QML;
  historial agrupado completo = NC futuro, igual que F3-T09 §3).
- `bash -n` + `shellcheck -S warning` cero; `qmllint` cero (QML nuevo +
  `Bar.qml`); build CMake cero warnings nuevos.
- Trampas del harness documentadas en el script: `-A` implica `--wait`
  (background + id por fichero, run1 colgado sin esto); `gdbus`
  rechaza el prefijo `uint32:` en métodos con introspección (valores
  pelados, run3); `dbus-monitor`/BecomeMonitor sin eavesdrop y `gdbus
  monitor` sin `--dest` no ven las señales (suscriptor python3-dbus,
  run4/run5).
