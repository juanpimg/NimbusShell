# F5-T06 — 20 ciclos de Dock (parcial, 2026-11-02 08:36)

Sistema instalado out13, una salida, Dolphin fijado en el Dock.

- 20 clicks reales en el icono del Dock (x=537,y=748), captura por ciclo.
- Ciclo 1: Dolphin abre (`F5-T06-dock-launch.png`).
- Ciclos 2-20: Dolphin sigue abierto/enfocado, sin crash ni pérdida de
  ventana (`F5-T06-dock-focus-20.png`); 19 capturas idénticas + 1 de apertura.
- Menú contextual y previews ya capturados en `matrix-out12/04` y `06`.

## No acreditado
- Minimizar con animación genie: los clics en el botón amarillo (122,84) no
  minimizan en esta sesión VNC; falta validarlo con puntero real o shortcut.
- Restaurar desde minimizado y 20 ciclos alternando launch/minimize.

F5-T06 **no se marca** hasta completar minimize/restore.

## Minimize/restore por one-shot KWin (2026-11-02 08:44)

- `window.minimized=true` vía script KWin (`Script.run`) **minimiza Dolphin**
  (`F5-T06-minimized-kwin.png`): el escritorio queda libre y el Dock conserva
  el punto de running.
- `window.minimized=false` + `workspace.activeWindow` **restaura y enfoca**
  Dolphin (`F5-T06-restored-kwin.png`).
- Causa raíz del atajo/botón: `kglobalshortcutsrc` solo existía en
  `dotfiles/.config/plasma/`; KDE lee `~/.config/kglobalshortcutsrc`.
  Añadido efectivo + copia en setup + `cmp` en build/CI. Tras desplegarlo y
  reiniciar `kglobalaccel`, Meta+M aún no se validó en esta sesión; requiere
  re-login. F5-T06 sigue abierto (minimize por botón/shortcut sin PASS).

## KGlobalAccel y kglobalshortcutsrc (2026-11-02 08:57)

Tras añadir `~/.config/kglobalshortcutsrc` efectivo y reiniciar sesión:

- `qdbus6 org.kde.kglobalaccel /component/kwin \
   org.kde.kglobalaccel.Component.invokeShortcut "Window Minimize"`
  **minimiza Dolphin** (`F5-T06-minimized-kgaccel.png`).
- Click en el icono del Dock **restaura y enfoca** Dolphin
  (`F5-T06-restored-dock.png`).
- El botón amarillo y la tecla Meta+M por VNC no se pudieron inyectar de
  forma fiable; la **acción global** de minimizar sí funciona. F5-T06 sigue
  abierto hasta validar el botón/tecla física y la animación genie.
