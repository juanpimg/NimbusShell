# F6-T02 — Runners Nimbus (fast-path local) · evidencia nested

## Arquitectura

`apps/nimbus-spotlight/nimbusindex.{h,cpp}` (Qt Core/Gui/DBus, sin KF):
`NimbusIndex` expone `searchLocal(term, tab)` síncrona en memoria y
`localMatches` a QML como contexto `nimbus`. `Spotlight.qml` muestra
locales primero (`krunnerMode=false`); Tab o botón "Buscar en KRunner"
activan `requestKRunner()` + `backend.search()` (KRunner intacto como
fallback). Preview con Abrir/Copiar/Revelar → `activateLocal(i, acción)`.
Ficheros indexados en worker `std::thread` (no bloquea UI); debounce QML
200 ms ya existente; cada tecla vuelve al fast-path.

Fuentes: Apps (.desktop, parser propio + 15 KCMs conocidos), Archivos
(`Desktop/Documents/Downloads`+`~`, profundidad ≤3, tope 4000 + recientes
de `recently-used.xbel`), Calculadora (shunting-yard `+ - * / % ^`,
sin eval), Web (`?`/texto → DuckDuckGo, sin red), Portapapeles (solo
klipper DBus, <16 kB). Ranking exacto>prefijo>subcadena>fuzzy + frecuencia
en `$XDG_STATE_HOME/nimbus-spotlight/frecuencia.json`. Quick Keys A–L.

## Latencias (A6 exige <50 ms)

Nested `tests/vm/nested-spotlight.sh --query kate` (KWin virtual,
HOME/XDG temporales):
`spotlight-local-latency: query=0ms mode=nimbus results=20 tab=apps`
(KRunner ~236 ms solo se usa en fallback). Footer QML confirma:
"Latencia: 0 ms · 20 resultados · Nimbus". Captura:
`spikes/nested/f6-runners.png` (query "kate", Kate primera, Motor: Nimbus,
0 errores QML en log).

Tests: `tests/spotlight/test_index.py` → `tst_index` (QtTest): 13/13 pasan —
fuzzy (exacto<prefijo<subcadena<fuzzy), calculadora (precedencia
`2+3*4=14`, `(2+3)*4=20`, `2^3=8`, errores `1/0`, `2++2`, `(2+3`),
parser .desktop (`%U` limpio, NoDisplay/sin-Exec rechazados),
perf fuzzy 10 k sintéticos: 0 ms (<50 ms), `searchLocal("kate")`: 0 ms.
El wrapper configura siempre en dir temporal fresco (`TST_BUILD_DIR` o
`mkdtemp`; nunca `build/` del repo: evita CMakeCache rancio).
`qmllint qml/Spotlight.qml`: limpio. Build `nimbus-spotlight` + `tst_index`: OK.

## Latencias por runner (test en vivo, `tst_index`, host)

- `tab=apps` ("kate"): 0 ms, 20 resultados, todos categoría `apps`.
- Settings ("wifi", tab actions): 0 ms, 5 resultados, KCM Red presente.
- Files: `scanRoots` sobre fixture (`Documents/proyectos/
  informe-fixture-nimbus.odt`): 0 ms, indexado=1; query tab=files: 0 ms.
- Clipboard: klipper vivo en host con 20 entradas; parser verificado
  (título ≤80, cuerpo <16384); sin klipper → vacío + fallback KRunner.
- Calc ("2+2", tab actions): 0 ms, resultado inline `= 4`.

## Límites

- Archivos: tope 4000 + 1500/dir, sin inotify (re-escaneo manual `rescan()`).
- Ajustes: 15 KCMs fijos + .desktop Settings (no detecta KCMs de terceros).
- Calc: sin funciones (sin/cos), `^` es potencia, `,` = `.`.
- Web siempre 1 acción (relevancia 0,1); motor fijo DuckDuckGo.
- Clipboard: requiere klipper activo; si no, pestaña vacía (fallback KRunner).
- Frecuencia JSON sin prunning; sin telemetría/red.
