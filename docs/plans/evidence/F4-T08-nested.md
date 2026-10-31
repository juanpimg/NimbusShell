# F4-T08 nested — atajos Meta como Cmd (Meta=⌘, cero Ctrl nuevos)
Fecha: 2026-10-31. Rama `plasma/f4-keys`. KWin 6.8 anidado (`--virtual`
1280x800, bus D-Bus privado, HOME/XDG temporales; `~/.config` del host
intacto —mtime 15:26—, sin root, sin red).
## Tabla macOS→Plasma (`scripts/nimbus-keys` genera con `kwriteconfig6`)
| macOS | Plasma (acción real) | Atajo Nimbus |
|---|---|---|
| Cerrar ⌘Q | kwin `Window Close` | Meta+Q |
| Minimizar ⌘M / Ocultar ⌘H | kwin `Window Minimize` (alias; KDE sin hide-app) | Meta+M / Meta+H |
| Spotlight ⌘Espacio | krunner `_launch` (+Alt+F2) | Meta+Espacio |
| Finder ⌥⌘Espacio | krunner `RunClipboard` (portapapeles) | Meta+Alt+Espacio |
| Mission Control | kwin `Overview` | Meta+W |
| Exposé / Desktop | kwin `Expose` / `Show Desktop` | Meta+E / Meta+D |
| Cambiar app ⌘Tab | kwin `Walk Through Windows` (+Rev.; alias Alt+Tab) | Meta+Tab |
| Ciclo ventanas ⌘` | kwin `…of Current Application` | Meta+` |
| Spaces ⌃←→↑↓ | kwin `Switch One Desktop *` (únicos Ctrl) | Meta+Ctrl+flecha |
| Mover a Space | kwin `Window One Desktop *` | Meta+Alt+Shift+flecha |
| Media ventana ⌘←→↑↓ | kwin `Window Quick Tile *` | Meta+flecha |
| Captura ⌘⇧3/4/5 | spectacle Full/Rect/Active | Meta+Shift+3/4/5 |
| Fullscreen / Zoom | scripts Nimbus F4-T03/T04 (delegados) | Meta+F / Meta+Z |
## Colisiones (resueltas en el fichero)
Meta+1..4→`none` en plasmashell (reserva Apps F6-T04); Meta+Espacio→KRunner
(layout switcher a `none`); Meta+F/Z→scripts (`Window Fullscreen`=`none`);
Alt+F4 liberado (Close=Meta+Q); Meta+Z global tapa deshacer en apps;
Ctrl+Alt+Del del sistema intacto (ksmserver no se toca).
## Pruebas (`spikes/nested/f4-keys-nested.log`; `.png` muestra KRunner)
`kreadconfig6` 8/8 binds OK; `grep -ri ctrl`=4 líneas (solo Meta+Ctrl+
flechas); `invokeShortcut` 14/14 rc=0 en 11 acciones KWin; krunner anidado
fusiona `_launch=Search Alt+F2 Meta+Space` ✓. Requiere RELOGIN
(kglobalacceld lee al iniciar); scripts KWin aplican sin relogin.
