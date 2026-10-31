# F3-T06 nested — menú global Qt en barra

Fecha: 2026-10-31. Harness `tests/vm/nested-appmenu.sh` (kwin virtual +
fake registrar + kate + dolphin + nautilus + `nimbus-bar --demo-appmenu
--log-appmenu`; HOME/XDG temporales, sin `--replace`). Binario
`/tmp/nimbus-bar-f3menu-prefix/bin/nimbus-bar` (cmake, Qt 6.12);
`qmllint` limpio en `Bar.qml`/`GlobalMenu.qml`.

## Canal DBus exacto (verificado en `spikes/nested/nested-appmenu.log`)

1. **Registrar**: Qt6 (`QDBusMenuBar`, dentro de QtGui) solo exporta el
   menubar si existe el nombre bien conocido
   `com.canonical.AppMenu.Registrar`. En nested no hay registrar real:
   el harness levanta `tests/vm/fake-registrar.py` (ver su cabecera).
2. **Export**: cada app Qt publica su menú en su servicio propio, objeto
   `/MenuBar/N`, interfaz `com.canonical.dbusmenu`. Escaneo previo:
   `DBUSMENU org.kde.kate-… /MenuBar/2`,
   `DBUSMENU org.kde.dolphin-… /MenuBar/2`.
3. **Ventana activa**: KWin scripting (`workspace.activeWindow` →
   `caption|resourceClass|pid`), poll 1 s vía objeto propio
   `org.nimbus.bar /Bar` (`reportActive`). `queryWindowInfo()` es
   interactivo y no sirve.
4. **pid→servicio**: `org.freedesktop.DBus.GetConnectionUnixProcessID`
   (`servicePid`); introspección de `/MenuBar` para hallar el hijo con
   `com.canonical.dbusmenu`.
5. **Layout**: `GetLayout(0,-1,[])` recursivo (firma `(ia{sv}av)`);
   `AboutToShow(id)` antes de abrir un submenú; `Event(id,"clicked",…)` al
   activar. `LayoutUpdated` → refresco best-effort.

## Resultado: Kate sí, Dolphin sí, GTK no rompe

- `appmenu: activa pid=308699 app=Kate` → `menu org.kde.kate-308699
  /MenuBar/2` → `GetLayout /MenuBar/2 tops=11`. Captura
  `f3-appmenu-kate.png`: barra `Kate Archivo Editar Selección Ver Ir
  Proyectos Cliente LSP Sesiones Herramientas Preferencias Ayuda` (11
  tops visibles).
- `appmenu: activa pid=311583 app=Dolphin` → `menu
  org.kde.dolphin-311583 /MenuBar/2` → `GetLayout tops=7`. Captura
  `f3-appmenu-dolphin.png`: barra `Dolphin Archivo Editar Ver Ir
  Herramientas Preferencias Ayuda` (7 tops).
- `appmenu: activa pid=317427 app=Firefox cap=Mozilla Firefox` → `pid
  317427 sin dbusmenu (GTK/in-window?)`; `barra VIVA tras firefox`.
  Captura `f3-appmenu-firefox.png`: barra con solo `Firefox` en negrita,
  ventana con su UI propia. Firefox arranca en ~25 s con HOME temporal
  (creación de perfil); el harness espera 25 s + 5 s tras enfocar.
- Nautilus igual: `activa pid=316735 app=Nautilus` → `pid 316735 sin
  dbusmenu`, `barra VIVA tras nautilus`, captura `f3-appmenu-gtk.png`.
  Cero aborts, cero errores QML en ambos casos GTK.

## Fix de compilación/ejecución (cambios C++ mínimos)

- El run previo abortaba: `QDBusArgument: write from a read-only object`
  (core). Causa: Qt 6.12 tiene sobrecargas const (lectura) y no-const
  (escritura) de `beginStructure/beginArray/…`; el parseo usaba
  referencias no-const sobre datos recibidos. Fix: todo el parseo
  (`nodeFromArg`, `operator>>`, `formatShortcut`, puntero de
  `fetchTopLevel`) a `const QDBusArgument`.
- `onActiveReported` ignora el pid propio (`QCoreApplication::
  applicationPid`): las ventanas layer-shell propias aparecían como
  `activeWindow` y borraban el menú al abrir el popup.
- `discoverMenu` cierra el submenú al cambiar de app (como macOS);
  `Bar.qml` muestra `appMenu.appName` (defecto `Nimbus`) cuando no hay
  menú; `GlobalMenu.qml` cierra el popup ante `menusChanged` y en demo
  reabre el primer top-level (para la captura con menú visible).

## Popup abierto (Archivo de Kate, demo auto-open)

- `openSubmenu(1) 'Archivo' kids=20 (cache)`: el `GetLayout(1,1,[])` en
  vivo tras `AboutToShow` devuelve un nodo vacío en Kate (título `''`,
  0 hijos; `en-vivo vacio, uso cache` en el log), así que `openSubmenu`
  usa el subárbol del `GetLayout(0,-1,[])` raíz (verificado en pantalla).
  Lección: no fiarse del parse en vivo sin validar.
- Captura `f3-appmenu-popup.png`: dropdown 280×560 bajo la barra con los
  20 items de Archivo — `Nuevo` (Control+N), `Nueva ventana`
  (Control+Shift+N), `Abrir…` (Control+O), `Abrir carpeta…` (Control+T),
  `Guardar todo` (Control+L), `Cerrar` (Control+W), `Cerrar ventana`
  (Control+Shift+W), `Salir` (Control+Q), separadores y ▶ de drill-in
  (`Abrir reciente`, `Abrir con`, `Acciones de archivos`). Sin checks en
  este menú (Kate no marca nada en Archivo; el render ✓/disabled existe
  en `GlobalMenu.qml` vía `toggle-state`/`enabled`).
- Geometría: `globalmenu: popup 280x560 at 0,0` — sin anclas, layer-shell
  ignoraba tamaño/posición y el popup salía a pantalla completa; fix con
  `AnchorTop|AnchorLeft` (patrón F3-T05). `x: 64` se ignora (sale en
  x=0); gap menor documentado.

## Build y qmllint (salida literal)

```text
$ cmake --build /tmp/nimbus-bar-f3menu
[ 12%] Built target nimbus-bar_qmlimportscan
[ 12%] Built target nimbus-bar_autogen_timestamp_deps
[ 25%] Built target nimbus-bar_autogen
[ 37%] Automatic RCC for bar.qrc
[ 50%] Building CXX object CMakeFiles/nimbus-bar.dir/nimbus-bar_autogen/EWIEGA46WW/qrc_bar.cpp.o
[ 62%] Linking CXX executable nimbus-bar
[100%] Built target nimbus-bar
$ qmllint packages/shell/nimbus-bar/qml/GlobalMenu.qml packages/shell/nimbus-bar/qml/Bar.qml
(exit 0, sin avisos)
```

## Límites / gaps

- Solo Qt/KDE exportan dbusmenu. **R-GTK**: GTK (Nautilus/Firefox) no
  exporta → solo nombre de app en barra, menú in-window intacto (no se
  toca).
- Un solo objeto `/MenuBar/N` por app (multi-ventana resuelve al
  primero); sin iconos en el popup.
- Popup con drill-in en vez de submenú lateral macOS (gap documentado).
- Poll de activa cada 1 s (retardo máx. ~1 s + GetLayout tras enfocar;
  el harness espera 4-5 s tras cada foco).
- Las líneas del log salen duplicadas (cosmético: `tee -a` dentro de un
  bloque ya redirigido a `$LOG`).
