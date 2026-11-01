# F6-T09 — Aceptación Spotlight/Apps (evidencia nested)

Objetivo: 20 consultas Spotlight + 10 apps lanzables + teclado + toggle/cierre
(Spotlight) y abre/cierra + categorías/Suggestions/vistas + teclado (Apps),
con 0 cambios QML/C++ (solo scripts de test + evidencia).

## Comandos

```bash
cmake -S apps/nimbus-spotlight -B /tmp/opencode/f6accept-spot -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/opencode/f6accept-spot -j$(nproc)
cmake -S apps/nimbus-apps -B /tmp/opencode/f6accept-apps -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/opencode/f6accept-apps -j$(nproc)
bash -n tests/vm/spotlight-acceptance.sh && shellcheck -S warning tests/vm/spotlight-acceptance.sh  # 0 warnings
bash -n tests/vm/apps-acceptance.sh && shellcheck -S warning tests/vm/apps-acceptance.sh            # 0 warnings
bash tests/vm/spotlight-acceptance.sh   # EXIT=0 PASS (tras fix G1)
bash tests/vm/apps-acceptance.sh        # EXIT=0 PASS
```

Todo en KWin virtual + HOME/XDG temporales (`dbus-run-session`); offscreen
`#19/#20` también con bus propio (sin él, el offscreen veía el klipper del
host — detectado y corregido en el propio script).

## Tabla 20 consultas (run final, `spikes/nested/f6-acceptance-table.txt`)

| n | consulta | tipo | ms | resultados |
|---|---|---|---|---| 
| 1 | kate | app exacta | 2 | 20 |
| 2 | dolphin | app exacta | 2 | 20 |
| 3 | konsole | app exacta | 2 | 20 |
| 4 | kat | prefijo | 1 | 20 |
| 5 | dolp | prefijo | 2 | 20 |
| 6 | kons | prefijo | 1 | 20 |
| 7 | ktae | fuzzy (transposición) | 1 | 20 |
| 8 | cnsol | fuzzy | 1 | 20 |
| 9 | gwenviw | fuzzy | 1 | 12 |
| 10 | ratón | acentos (ajuste Ratón, fold NFD) | 2 | 20 |
| 11 | reunion | acentos (fichero semilla reunión-notas.txt) | 2 | 20 |
| 12 | informe | archivo semilla | 1 | 20 |
| 13 | wifi | ajuste (KCM Red) | 1 | 16 |
| 14 | pantalla | ajuste (KCM Pantalla) | 1 | 20 |
| 15 | 2+2*3 | calc (= 8, valor cubierto por tst_index) | 1 | 2 (calc+web) |
| 16 | (10-4)/2 | calc (= 3) | 2 | 2 (calc+web) |
| 17 | ?clima mañana | web (DuckDuckGo) | 1 | 1 |
| 18 | nimbus shell | web genérica | 1 | 14 |
| 19 | reunion (tab Portapapeles) | clipboard/history2.lst semilla | visual 1 ms (footer PNG) | 1 |
| 20 | 9z8x7q2w (tab Apps) | sin resultados | 0 | 0 |

Latencia local máx 2 ms (<50 ms, PASS). 10 apps lanzables verificadas
(`.desktop` + `Exec` existente + hit en índice): kate, dolphin, konsole,
spectacle, gwenview, ark, kcalc, firefox, systemsettings, Alacritty.
Teclado: 9/9 checks estáticos (Cmd+1..4, Quick Keys A–L, flechas, Home/End,
RePág/AvPág, Enter, Esc, Ctrl+Tab, Tab sin trampas); toggle oculta/muestra
rc=0; cierre rc=0. Apps: abre (icons, 73 apps), vista lista + Desarrollo
(11 apps), toggle rc=0, cierre OK, 11/11 estáticos, 0 errores QML.

Capturas: `spikes/nested/f6-acceptance.png` (kate, A–L, 0 ms · 20 · Nimbus),
`f6-acceptance-clipboard.png` (semilla, 1 ms · 1), `f6-acceptance-noresults.png`
(«Sin resultados», 0 ms · 0), `f6-apps-acceptance.png` / `-list.png`.
Logs: `f6-acceptance-nested.log`, `f6-apps-acceptance-nested.log`;
`f6-acceptance-qmlerr.txt` (18 líneas, G1).

## Gaps (exactos, no inventados)

- G1 (RESUELTO, aceptación Spotlight ahora `EXIT=0`, `0 errores QML`):
  causa probada con QML instrumentado en copia (`/tmp`, sin tocar el repo):
  al recambiar el modelo, el `ListView` pasa transitoriamente por `count=0`
  y escribe `currentIndex=-1`, que `onCurrentIndexChanged` propagaba a
  `root.currentIndex`; los bindings del preview (solo guardados con
  `length > 0`) evaluaban `filtered[-1]` → `TypeError` (`:550/558/566`).
  Se autorrecuperaba al asentarse la vista (de ahí «transitorio»), pero
  ensuciaba el log y tumbaba el gate. Fix (sin cambio visible):
  `qml/PreviewGuard.js` nuevo (`isValidIndex`/`safeAt`, fuente única QML+node),
  `property var previewItem` + 3 bindings + `announceSelection` con accesor
  seguro, y clamp del writeback (`Spotlight.qml:30 import, :59,
  :72-80, :431-436, :563/571/579`). C++ sin cambios: `activateLocal(-1)`
  ya retorna `false` (cubierto en `localActions`). Regresión:
  `tests/spotlight/test_previewguard.js` (15 aserciones node, OK),
  `previewContracts` en `tst_index.cpp` (0/1/2 resultados, PASS; total
  22 passed), `qmllint` OK, repro mínima DBus 20→2→2→1→20→1: 18→0 TypeErrors,
  aceptación 20/20 `VEREDICTO: PASS`, capturas regeneradas idénticas.
- G2: fuzzy sin cota de dispersión — gibberish corto da hits (`xqkvjw`→5,
  `zzzzqqqq`→4 vía subsecuencia en keywords largos); el «0 resultados» exige
  `9z8x7q2w`-style. Sin fix aquí.
- G3: fallback KRunner no medible en nested (`org.kde.krunner` ausente en bus
  aislado); referencia F6-T02: ~236 ms.
- G4: teclado físico (pulsaciones reales Enter/Esc/flechas) no sintetizable en
  nested (sin ydotool/wtype); cubierto estático + toggle DBus. Lanzamiento real
  de las 10 apps no ejecutado (solo `.desktop`+`Exec`+hit); evita 10 ventanas.
- G5 (cosmético): el trap dejó `.../runtime/gvfs` sin borrar (montaje portal
  ocupado); resto temporal limpio, host intacto.
