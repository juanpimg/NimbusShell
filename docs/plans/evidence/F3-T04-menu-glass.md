# F3-T04 — Menú Apple con Glass y overlay corregido (2026-11-02)

## Bug corregido: el menú oscurecía todo el escritorio

Causa raíz (medida con sonda KWin, no inferida): el `Window` del popup no
tenía `LayerShellQt.Window.anchors`, así que KWin le asignaba **toda el área
disponible** (1280×730) en vez de 248×372. Su `Rectangle` de fondo (alfa 0.94)
llenaba esa superficie y tapaba el escritorio; el scrim no era el culpable
(también ocurría con el scrim oculto y sin blur/Glass).

Fix en `main.cpp` para el scope `nimbus-menu`:

```cpp
ls->setAnchors({LayerShellQt::Window::AnchorTop,
                LayerShellQt::Window::AnchorLeft});
ls->setMargins(QMargins(8, 26, 0, 0));
```

Geometría KWin después del fix: `geom=8,50,248,299` (x=8, y=24 bar + 26,
248×299), y el fondo ya no cubre la pantalla.

## Acabado visual

- Vidrio real con Glass (blur + refracción) sobre `nimbus-menu`; tinte 0.64
  (el 0.94 del token tapaba el efecto).
- Filas de 28 px (antes 32), iconos de 16 px y texto de 13 px.
- Separadores entre grupos: Acerca / Ayuda / Reloj / Ajustes / sesión /
  apagado.
- Iconos de línea dibujados con Canvas (`MenuGlyph`): logo N, ayuda, reloj,
  engranaje, luna, candado, salir, reiniciar, apagar. Sin letras ni activos
  Apple.
- Altura dinámica: `height: menuColumn.implicitHeight + 12` (299 px); el
  diálogo de confirmación crece con el contenido.
- Hover/pressed/foco conservados; acciones y confirmación intactas.

## Evidencia

- `F3-T04-menu-glass/menu-glass-wallpaper.png` / `-crop.png`: menú sobre el
  wallpaper Nimbus con Glass.
- `F3-T04-menu-glass/menu-glass-checker.png` / `-crop.png`: menú + CC sobre
  damero; los bordes del menú refractan el damero y el exterior sigue nítido.
- Sonda KWin: menú `248,299` en `8,50`; scrim full-screen aparte.
- `qmllint Menu.qml` → 0; build CMake → PASS.

## Límites (F3-T04 sigue abierto)

- No se han ejecutado las acciones reales (dormir/bloquear/cerrar/reiniciar/
  apagar) ni el diálogo de confirmación con puntero; solo UI y log.
- Falta el acento/atajos reales en las filas y la validación en la VM
  instalada.
- El menú usa iconos de línea propios, no SF Symbols (correcto por licencia).
