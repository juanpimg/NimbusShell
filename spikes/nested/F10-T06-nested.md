# F10-T06 — Evidencia nested: XWayland y apps legacy

## Variables (dotfiles/.config/environment.d/90-nimbus.conf)
- `QT_QPA_PLATFORM=wayland;xcb`, `ELECTRON_OZONE_PLATFORM_HINT=auto`,
  `MOZ_ENABLE_WAYLAND=1`, `GDK_BACKEND=wayland,x11`,
  `CLUTTER_BACKEND=wayland`, `SDL_VIDEODRIVER=wayland,x11` — Wayland
  nativo primero, X11/XCB solo fallback vía XWayland. Cada variable
  documentada con su riesgo en el propio fichero (reléase con relogin;
  en nested se exportan las mismas 6). Despliegue automático: `copy_dotfiles`
  copia todo el árbol (sin cambios en install.sh).

## CSD (dotfiles/.config/plasma/kwinrc + kwinrulesrc)
- KWin no fuerza decoración SSD sobre CSD (sin clave DecorationPolicy a
  propósito); sombras/bordes Breeze solo para SSD/XWayland legacy que la
  pide; foco ClickToFocus (paridad macOS). Excepciones: XWayland sin marco
  recibe sombra SSD; Firefox CSD conserva botones a la derecha (excepción
  a XIA); diálogos/utilidades sin maximizar (regla 5).

## Matriz 8 apps (tests/vm/nested-f10xway.sh, log f10-xway-nested.log)
- kate/konsole/dolphin/kcalc/gwenview/systemsettings/firefox: VIVO;
  spectacle 6.8.2 OK (herramienta de captura = 8.º verificado).
- XWayland activo (`HAVE_X11_XCB: yes`, DISPLAY exportado por kwin);
  Qt/Firefox en Wayland nativo por las 6 vars (verificadas en log).
- Captura `spikes/nested/f10-xway-matrix.png` (mosaico 4x2 vía KWin
  scripting): 7 ventanas con contenido, 0 negras (black_frac 0.10 =
  fondo oscuro fish + tema dark Firefox, esperado).

## Límites / gaps
- Electron/GTK puros no disponibles en host/ISO (sin code/chromium/gimp/
  inkscape): su rama del fallback queda sin probar en nested → pendiente VM.
- Firefox primer arranque lento (~60s); teardown nested ~3.5 min total.
- Audio/PipeWire ausente en nested (igual que F10-T05); HiDPI real pendiente VM.
