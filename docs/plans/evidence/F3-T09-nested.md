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

## Gaps medidos (fix review F3-T09, 2026-10-31)

Harness nuevo `tests/vm/nested-notif-measure.sh` (+ sonda wire
`tests/vm/nested-notif-wire.sh`, `spikes/nested/f3-wire.dump`).

1. **Timeout 5s MEDIDO** (sin ajuste): `T0=…050.31 send-rc=0`,
   `T1=+2.03s` (`f3-timeout-before.png`, banner visible),
   `T2=+7.42s` (`f3-timeout-after.png`, ausente). `PopupTimeout=5000` OK.
2. **Acción MEDIDA a nivel protocolo+render**: `GetCapabilities`
   incluye `actions`/`inhibitions`; `Notify` con `["open","Abrir"]`
   devuelve `id=4/5`. Sonda wire: `notify-send` añade hints
   `urgency byte 1` + `sender-pid` (el `gdbus` pelado mandaba `{}`).
   A/B con hints idénticos: (a) `expire -1` + cliente efímero →
   **sin botón** (`f3-notify-a.png`); (b) `expire 30000` + emisor
   vivo (hold) → **botón «Abrir» visible** (`f3-notify-b.png`).
   El applet solo pinta acciones con el emisor en el bus.
   Gap exacto restante: el **clic** → `ActionInvoked` no es emitable
   en nested (sin `wtype`/`ydotool`/`uinput` sin root; KWin scripting
   sin inyección de entrada; el applet no expone invoke por DBus).
3. **Agrupación MEDIDA (popups)**: 2 notifs misma app → **pila de 2
   banners, no fusiona** (`f3-group.png`). Gap exacto: historial
   agrupado sin verificar (abrirlo exige clic; scripting sin
   `panels()`/`expanded`; `plasmawindowed` no ve el servidor del
   panel: «no disponible… proporcionado por KDE Plasma»).

## Gaps previos (siguen)

- Campana en panel stock diverge de macOS → F3-T12.
- Solo variante dark; blur KWin bajo popup no medido aquí.
