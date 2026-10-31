# F3-T07 nested — system tray SNI en barra

Fecha: 2026-10-31. Harness `tests/sni/nested-tray.sh` (plantilla de
`tests/vm/nested-bar.sh`): KWin virtual + plasmashell (watcher SNI
real) + 2 fake-sni (items A/B con IconPixmap y menú dbusmenu) +
`nimbus-bar --tray-open-menu` (abre el menú del item 0 para la captura).

## Resultado

Captura `spikes/nested/f3-tray.png` (1280x800, `--no-lockscreen` en el
harness: kwin bloqueaba la sesión anidada a los ~12s sin ese flag):

- Barra 24 intacta (logo N + Nimbus izq; Wi-Fi/BT/CC/batería/reloj
  der) + **2 iconos tray 16px antes del reloj**: B verde x∈[1182,1197]
  y A azul x∈[1204,1219] (medición PIL; orden = registro en watcher).
- Popup dbusmenu anclado arriba-derecha con las 3 entradas reales del
  item B (`Nimbus B info / Nimbus B acerca / Quit`) — `fetchMenu`
  (libdbus `GetLayout`) funcionando en QML.
- El panel Plasma inferior muestra también A/B: los fakes son items
  SNI reales para cualquier host.
- Cero errores QML en log; `qmllint` limpio (Bar/StatusArea).
- Métodos verificados en el fake: `Activate Nimbus A 0 0` y
  `Event id=1 clicked Nimbus A` (llamadas directas; el clic real
  izq/der no es inyectable en nested — misma limitación que F3-T04).

## Protocolo SNI (investigado en el host real, solo lectura)

Watcher `org.kde.StatusNotifierWatcher`, objeto
`/StatusNotifierWatcher` (verificado con `qdbus6` en la sesión del
usuario; 4 items reales: zapfast, warp-taskbar ayatana, cachy-update,
shelly):

- Prop `RegisteredStatusNotifierItems: QStringList` con entradas
  `"servicio/ruta"` (el servicio puede ser nombre único, p.ej.
  `:1.42/org/ayatana/...`). Señales `StatusNotifierItemRegistered` /
  `StatusNotifierItemUnregistered(QString)`. Método
  `RegisterStatusNotifierItem(service)` (lo llama el item, no el host).
- Item `org.kde.StatusNotifierItem`: props `Id/Category/Title/Status/
  IconName/IconThemePath(nuevo)/ItemIsMenu/WindowId`,
  `IconPixmap a(iiay)` (bytes ARGB big-endian por píxel),
  `ToolTip (sa(iiay)ss)` = (icon-name, pixmaps, title, text),
  `Menu` (object path a `com.canonical.dbusmenu`, vacío si no hay
  menú — los 4 items del host lo tienen vacío). Métodos
  `Activate(x,y)`, `ContextMenu(x,y)`, `SecondaryActivate`,
  `Scroll`; señales `NewIcon/NewTitle/NewStatus/NewToolTip` (+
  `PropertiesChanged` genérico).
- Menú `com.canonical.dbusmenu`: `GetLayout(parent,depth,props) →
  (u revision, layout)`, `AboutToShow(id)`, `Event(id,event,data,ts)`;
  nodo = struct(int32 id, `a{sv}` props, array hijos).

## Implementación (`packages/shell/nimbus-bar/`)

- `statusnotifiermodel.h/.cpp`: `StatusNotifierModel`
  (QAbstractListModel, orden estable de registro) con watcher + items
  dinámicos; iconos: pixmap SNI (mayor resolución) → `QIcon::fromTheme`
  (+ IconThemePath) → badge generado (inicial, sin activos externos);
  `image://sni/<uid>` vía provider en `main.cpp`. Clic izq
  `activate()` / der `contextMenu()`; `fetchMenu()` (lista
  [{id,label,enabled}] vía GetLayout) y `triggerMenuAction()` (Event).
- `qml/StatusArea.qml`: iconos 16px a la derecha antes del reloj,
  tooltip (Title — texto), popup dbusmenu (scrim+ventana, patrón
  Menu.qml), `autoOpenRow` (flag `--tray-open-menu`, solo captura).
- `Bar.qml` (StatusArea antes del reloj), `bar.qrc`, `main.cpp`
  (`--demo-tray`: siembra 2 items demo si el watcher sigue vacío a los
  2.5s; `--tray-open-menu`), `CMakeLists.txt` (Qt6 DBus + dbus-1).
- Fake service `tests/sni/fake-sni.cpp` (+CMake): item SNI propio con
  IconPixmap dibujado (A azul / B verde), Title/Status/ToolTip y menú
  dbusmenu (info/acerca/Quit; Quit cierra el fake). Uso:
  `fake-sni --service ... --title ... --letter ... [--stay]`.

## Hallazgos Qt 6.12 (vinculantes para futuros F3)

1. El descenso manual de `QDBusArgument` sobre copias user-side está
   roto: `atEnd()` inmediato en arrays no vacíos, lecturas a defaults
   en structs locales, abort (`struct not basic`) en mensajes del bus.
   SÍ funciona: `QDBusReply<T>`/`qdbus_cast<T>` con tipos registrados y
   libdbus-1 directo (probes en `/tmp/dbusprobe`: cli9/cli10/rt/cli14).
2. Los adaptadores Qt no firman retornos struct custom anidados
   (`<arg type="" direction="out"/>`, respuesta vacía) y Qt no firma
   tipos recursivos (cuelgue en `typeToSignature`). Por eso el fake
   sirve props fijas con structs registrados y `GetLayout` (dos
   out-args, forma real) vía `QDBusVirtualObject` + respuesta manual
   con `operator<<`.
3. Límite del fake: hijos de hoja como `as` vacío (no `a(iai{sv}av)`
   recursivo); arrays vacíos no leen elementos — el parser genérico no
   lo nota. Menús reales con submenús → VM (F2-T08).
4. `QFont` exige `QGuiApplication` (el fake con `QCoreApplication`
   abortaba en `findFont`); `qInfo`/`qWarning` no vuelcan en este Qt
   sin handler (el fake loguea con `fprintf`, patrón F3-T05).
5. `commandrunner.h` traía un bug preexistente (split con salto de
   línea literal, no compilaba); fix mínimo propio (`'\n'`,
   equivalente al `QLatin1Char('\n')` de `plasma-migration`).

## Límites

- Sin clic real izq/der en nested (el harness no inyecta puntero);
  `Activate`/`ContextMenu`/`Event` verificados por llamada directa y
  por el popup abierto vía modelo (`fetchMenu` real en QML).
- Iconos de apps reales (IconName de tema, menús profundos) → VM F2-T08.
- `fetchMenu` bloquea el hilo GUI (llamada con timeout 2-3s en bus
  local; aceptable para interacción de tray).
