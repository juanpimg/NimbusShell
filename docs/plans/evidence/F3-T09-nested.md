# F3-T09 nested — notificaciones estilo macOS

Fecha: 2026-10-31. Rama `plasma/f3-notif`. Harness
`tests/vm/nested-notif.sh` (plantilla `nested-plasma.sh`: HOME/XDG
temporales, `--no-lockscreen`, cleanup por trap). KWin 6.8.2 virtual
1280x800 + plasmashell + applet `org.kde.plasma.notifications`.

## Claves (verificadas en host: headers libnotificationmanager + servicio real)

- Servidor FDO = `org.freedesktop.Notifications`, registrado por
  **plasmashell** (dueño en host: `/usr/bin/plasmashell --no-respawn`).
  Sin el applet en el panel no hay servidor (`notif-ready` vacío en
  run1) → R-NOTIF-SERVER: applet añadido al panel en el appletsrc.
- `plasmanotifyrc [Notifications]`: `PopupPosition=TopRight` (enum
  `CloseToWidget..BottomRight`, `Settings::PopupPosition`),
  `PopupTimeout=5000`, `LowPriorityHistory=true`,
  `LowPriorityPopups=false`. `kreadconfig6` en nested → `TopRight`/`5000` ✓.
- DND por DBus: `Inhibit(app,razón,a{sv})` → cookie; `Inhibited`
  `b true` con holder vivo → `b false` tras matarlo ✓. La inhibición
  muere con el proceso que la pide (dbus-send solo = `false` siempre).
- Fondo popup: desktop theme `dialogs/background.svg` (9-slice propio,
  `packages/themes/nimbus-notifications/`); resto hereda breeze/default.

## Evidencia (`spikes/nested/`)

- `f3-notif.png`: banner **arriba-derecha**, glass oscuro propio
  (hairline+sheen+radio 14, sin costuras tras solape 1px), «Nimbus /
  Reunión / En 5 minutos», barra de timeout, ×. Campana en panel.
- `f3-notif-actions.png`: botón «Abrir» (`-A "open=Abrir"`) ✓.
- `f3-notif-dnd.png`: **sin banner** con inhibición activa + campana
  tachada en panel ✓.
- `nested-notif.log`: `notif-ready=yes`, `notify rc=0`, `QMLERR=0`.

## Gaps (F2-T08: solo nested, sin VM)

1. Agrupación: `GroupApplicationsFlat` es el modo del modelo; historial
   agrupado por app **no verificado visualmente** `[INFERIDO]`.
2. `PopupTimeout=5000` desplegado pero **no cronometrado** `[INFERIDO]`.
3. Campana en panel stock diverge de macOS (sin icono) → F3-T12.
4. Solo variante dark; blur KWin bajo popup no medido aquí.
