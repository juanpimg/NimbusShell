# nimbus-notifications — notificaciones estilo macOS (F3-T09)

Banner arriba-derecha, glass oscuro, auto-ocultar 5s (contrato §3:
Banner ~5s `[INFERIDO]`), agrupación por app (defecto del applet),
DND por DBus. Sin activos Apple: arte SVG propio (CC0).

## Instalación

```bash
# 1. Tema de escritorio (solo dialogs/background.svg; el resto hereda breeze/default)
mkdir -p ~/.local/share/plasma/desktoptheme
cp -r packages/themes/nimbus-notifications/desktoptheme/nimbus-notifications \
  ~/.local/share/plasma/desktoptheme/
kwriteconfig6 --file plasmarc --group Theme --key name nimbus-notifications
# 2. Posición/timeout/DND (fuente: dotfiles/.config/plasma/plasmanotifyrc)
cp packages/themes/nimbus-notifications/plasmanotifyrc ~/.config/plasmanotifyrc
plasmashell --replace &  # o re-login
```

## Rutas/claves exactas (Plasma 6.8, host)

- Popup: applet binario `org.kde.plasma.notifications`
  (`/usr/lib/qt6/plugins/plasma/applets/…so`, sin QML parcheable).
- Fondo popup: desktop theme `dialogs/background.svg(z)`
  (`/usr/share/plasma/desktoptheme/default|breeze-*/dialogs/`); este
  paquete solo overridea ese fichero.
- `plasmanotifyrc [Notifications]`: `PopupPosition=TopRight`
  (enum `CloseToWidget..BottomRight`, `Settings::PopupPosition`),
  `PopupTimeout=5000` (ms), `LowPriorityHistory/Popups`.
- `plasmanotifyrc [DoNotDisturb]`: `WhenFullscreen/ScreenSharing/ScreensMirrored`.
- DND manual (canal DBus, sin clave en fichero):
  `qdbus6 org.freedesktop.Notifications /org/freedesktop/Notifications
  org.freedesktop.Notifications.Inhibit <app> <razón> {}` → cookie;
  `UnInhibit <cookie>`; propiedad `Inhibited` (`server.h`).
- Agrupación: `GroupApplicationsFlat` es el modo por defecto del
  modelo (`NotificationsModel.groupMode`); sin clave global.

## Atribución

- Formato 9-slice compatible con Breeze (KDE VDG, LGPL); arte 100%
  original, sin copiar paths de Breeze. SVG + tokens propios: CC0.

## Límites

- El SVG no hace blur (imposible en SVG); el blur lo pone KWin bajo
  el popup translúcido. Sin blur de KWin = gris sólido.
- Solo variante dark (contrato: cada token exige light+dark → F3-T11).
- Si el tema no se lista, `kbuildsycache6` + re-login.
