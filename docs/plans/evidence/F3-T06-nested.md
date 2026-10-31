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

- `appmenu: activa pid=245426 app=Kate` → `menu org.kde.kate-245426
  /MenuBar/2` → `GetLayout /MenuBar/2 tops=11`. Captura
  `f3-appmenu-kate.png`: barra `Kate Archivo Editar Selección Ver Ir
  Proyectos Cliente LSP Sesiones Herramientas Preferencias Ayuda` (11
  tops visibles).
- `appmenu: activa pid=245505 app=Dolphin` → `menu
  org.kde.dolphin-245505 /MenuBar/2` → `GetLayout tops=7`. Captura
  `f3-appmenu-dolphin.png`: barra `Dolphin Archivo Editar Ver Ir
  Herramientas Preferencias Ayuda` (7 tops).
- `appmenu: activa pid=245713 app=Nautilus` → `pid 245713 sin dbusmenu
  (GTK/in-window?)`; `nimbus-bar VIVO` + `barra VIVA tras nautilus`.
  Captura `f3-appmenu-gtk.png`: barra muestra solo `Nautilus` en negrita
  (sin menú), Nautilus conserva su headerbar in-window. Cero aborts, cero
  errores QML.

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
