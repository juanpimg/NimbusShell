# F10-T02 nested — Dolphin estilo Finder

Fecha: 2026-10-31. Host Plasma 6.8.2 Wayland, Dolphin 26.08.2.
Harness `tests/vm/nested-f10apps.sh` (patrón `nested-plasma.sh`: HOME/XDG
temporales, `dbus-run-session`, `kwin_wayland --virtual --no-lockscreen`
1280×800; NUNCA `--replace`, `~/.config` del host, root ni red).

```
bash tests/vm/nested-f10apps.sh --out spikes/nested --timeout 120
```

## Ficheros

- `dotfiles/.config/dolphinrc` — `[General]` SortingChoice=0 (natural),
  GlobalViewProps, ConfirmTrash=false (a papelera sin preguntar),
  ConfirmDelete/ConfirmEmptyTrash=true (lo destructivo sí confirma),
  ConfirmClosingMultipleTabs=false, EnlargeSmallPreviews, 1100x700 en
  `[MainWindow]` (best-effort).
- `dotfiles/.local/share/dolphin/view_properties/global/.directory` —
  defaults globales de vista: ViewMode=2 + PreviewsShown + SortRole=text +
  Timestamp (obligatorio, ver hallazgo 2).

## Hallazgos verificados (binario + fuente upstream)

1. **Columnas Miller eliminadas**: el binario solo expone acciones
   `iconsModeAction`, `compactModeAction`, `detailsModeAction`
   (`nm -D libdolphinprivate.so.26.08.2`); no existe modo columna.
   Ruling: "vista columnas" = **Compacta** (ViewMode=2), que "lists the
   folders and files in columns" (tooltip propio del binario).
   Probado: ViewMode=1→detalles, 2/3→compacta (capturas probe10/V2/V3).
2. **`[Dolphin]` en dolphinrc se ignora** con GlobalViewProps=true: los
   defaults globales se leen de
   `~/.local/share/dolphin/view_properties/global/.directory`
   (`ViewProperties::defaultProperties`/`destinationDir("global")` en
   `src/views/viewproperties.cpp`; `destinationDir`+`global/` confirmados
   en el binario por desensamblado; `strace` ausente, verificado con
   inotify: Dolphin abre el `.directory`).
3. **Sin `Timestamp` no hay props**: Dolphin 26 descarta view props sin
   Timestamp vengan de `.directory`, global o xattr (8 sondas:
   ViewMode=1/2/3 ignorados sin Timestamp; con Timestamp se aplican).
   La vía xattr (`kde.fm.viewproperties`) ya no existe en este build
   (sin rastro en el binario). `ViewPropsTimestamp` de dolphinrc no es
   necesario; vale un Timestamp estático (Dolphin lo refresca al cambiar
   el usuario; probado: no reescribe el fichero al salir).
4. **Tamaño inicial lo impone KWin**: `[MainWindow]` Width/Height los ignora
   Dolphin 26 al arrancar (probado: 700x500 sin efecto). Rige la regla
   Nimbus existente en `dotfiles/.config/kwinrulesrc` (Dolphin 1100x700
   centrada, sizerule Apply-inicial). Geometría medida en la captura final
   (detección de píxeles del titlebar con PIL): x=90..1189 (w=1099),
   y=50.., es decir 1100x700 centrada en 1280x800: la regla aplica.

## Resultados

| Test | Resultado |
|---|---|
| `shellcheck -S warning nested-f10apps.sh` | 0 warnings |
| `kreadconfig6` (HOME temporal): SortingChoice=0, GlobalViewProps=true, GlobalViewMode=2, GlobalPreviews=true, ConfirmTrash=false, Width=1100, Height=700 | todos OK |
| `spikes/nested/f10-dolphin.png` | SÍ: vista compacta multicolumna, sidebar Lugares (Carpeta personal, Papelera), panel info con preview grande, orden natural a1,a2,a10,a20, previews de texto (doc.txt) |
| 10 ops archivo (touch×3, mkdir, cp, mv, ls, ls -v, trash KIO, en-papelera, restaurar, limpieza) | 10/10 OK |
| Diálogos de confirmación al enviar a papelera | GUI-only: no inyectamos clics en nested (sin wtype/ydotool); las claves las lee el binario (símbolos ConfirmTrash/ConfirmDelete/ConfirmEmptyTrash presentes) |
| Cleanup | 0 procesos resto, tmp borrado por trap |

## Límites

- Sin Miller columns (upstream). Sin previsualización del cambio de modo
  por clic (GUI-only). Tamaño exacto depende de la regla KWin, no de dolphinrc.
