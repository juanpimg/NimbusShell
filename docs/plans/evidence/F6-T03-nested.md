# F6-T03 — Ranking, previews y acciones · evidencia nested

## Cambios
- `nimbusindex.cpp`: `fuzzyScore` con folding de acentos (NFD − marcas):
  `Música~musica`, `Ratón~raton`, insensible a mayúsculas (ya existía).
- `scanFilesAsync`: guarda `QPointer` — el worker no toca `this` si el
  índice murió (cierre de race que tumbaba `tst_index` con SIGSEGV).
- `tests/tst_index.cpp`: `accentFolding`, `tenQueriesRanking` (10 consultas
  con fixtures aislados `tests/fixtures/applications/` + HOME temporal),
  `localActions` (Abrir/Copiar/Revelar sin lanzar procesos).
- `CMakeLists.txt`: `NIMBUS_FIXTURES` para el test.

## Tabla de 10 (esperado vs obtenido, `tst_index`, offscreen)

| # | Consulta | Tab | Esperado top | Obtenido top (kind, n) |
|---|----------|-----|--------------|------------------------|
| 1 | `Kate` | — | Kate (app) | Kate (app, n=5) |
| 2 | `kat` | — | Kate (app) | Kate (app, n=6) |
| 3 | `kte` | — | Kate (app, fuzzy) | Kate (app, n=6) |
| 4 | `informe` | files | informe-nimbus.odt (file) | informe-nimbus.odt (file, n=1) |
| 5 | `wifi` | actions | Red e Internet (setting) | Red e Internet (setting, n=2) |
| 6 | `2+2` | — | = 4 (calc) | = 4 (calc, n=2) |
| 7 | `clima manana` | — | acción web presente | web presente (n=1) |
| 8 | `zzzzzsinmatch` | — | solo web (n=1) | solo web (n=1) |
| 9 | `KATE` | — | Kate (app) | Kate (app, n=5) |
| 10 | `musica` | — | Música (app) | Música (app, n=2) |

10/10 coinciden. Preview verificado en cada resultado: `text`, `category`,
`localKind/Id/Exec` no vacíos y primer `quickKey=A`.

## Acciones (lógica, sin abrir apps reales)
- `activateLocal(-1|999|vacío)` → `false` (nunca lanza nada).
- Calc `2+2` + `copy` → `true`, portapapeles `4`.
- App `Kate` + `reveal` → `false` (no es fichero, sin proceso).
- `recordUse(kate.desktop)` → aparece en sugerencias de consulta vacía.

## Tests
`tests/spotlight/test_index.py` → `tst_index`: **16/16 pasan**
(fuzzy, calc, desktop, web, perf 10k <50 ms, tabs, settings, files,
clipboard, acentos, 10 consultas, acciones). Latencias `searchLocal` 0–1 ms.

## Límites
- Folding solo latino NFD; sin transliteración (ñ, cirílico) ni typo-swap.
- `open` real (xdg-open/QProcess) no se ejecuta en tests por diseño.
- Frecuencia en `$XDG_STATE_HOME/nimbus-spotlight/frecuencia.json`, sin pruning.
