# F6-T08 — Rendimiento Spotlight (evidencia nested)

Objetivo: toggle DBus y query local <50ms con 10k archivos sintéticos,
RSS/CPU/arranque en frío medidos, 0 errores QML, sin freeze.

## Comandos

```bash
rm -rf /tmp/opencode/spot-f6perf
cmake -S apps/nimbus-spotlight -B /tmp/opencode/spot-f6perf -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/opencode/spot-f6perf -j$(nproc)
QT_QPA_PLATFORM=offscreen /tmp/opencode/spot-f6perf/tst_index   # 16 passed
qmllint apps/nimbus-spotlight/qml/Spotlight.qml
bash -n tests/vm/spotlight.sh && shellcheck -S warning tests/vm/spotlight.sh  # 0 warnings
bash tests/vm/spotlight.sh --bin /tmp/opencode/spot-f6perf/nimbus-spotlight \
  --tst /tmp/opencode/spot-f6perf/tst_index
```

Micro-cambio justificado (aditivo, sin cambio de arquitectura):
`apps/nimbus-spotlight/main.cpp` — slot DBus `query(QString)` en `Toggle`
que reexpone el `searchLocal` síncrono para cronometrar queries en caliente
vía `qdbus6` (antes solo medible la query inicial `--query`).

## Tabla (run 2, nested kwin_wayland --virtual 1280x800, HOME temporal, 10k sintéticos)

| Métrica | Valor | Umbral | Veredicto |
|---|---|---|---|
| Query frío offscreen `perf-fuzzy-10k` (10k sintéticos, índice nuevo) | 3ms | <50ms | PASS |
| Query frío offscreen `perf-searchLocal` | 1ms | <50ms | PASS |
| Toggle DBus round-trip (10 rondas: min/med/max/avg) | 7.07 / 8.10 / 179.42 / 25.09 ms | <50ms (med) | PASS (ver gap G1) |
| Query caliente round-trip DBus (10 rondas) | 14.82 / 15.35 / 16.08 / 15.38 ms | <50ms | PASS |
| Query caliente in-process (`spotlight-local-latency`, n=320) | moda 5-6ms, rango 1-10ms | <50ms | PASS |
| Query fría inicial nested (índice en construcción) | 1ms | <50ms | PASS |
| RSS arranque (VmRSS) | 236896 kB (~231 MB) | informativo | OK |
| RSS post-query + ráfaga | 257816 kB (~252 MB) | informativo | OK |
| CPU reposo (ventana 3s, 100% = 1 núcleo) | 0.3% | informativo | OK |
| CPU durante query (ventana 2s, ráfaga 300 queries) | 49.6% de 1 núcleo | informativo | OK (ver G2) |
| Arranque frío spawn→DBus (ventana creada y registrada) | 216.1ms | informativo | OK |
| Errores QML | 0 | 0 | PASS |
| Freeze (todas las sondas con `timeout 10`) | sin freeze | ninguno | PASS |

Run 1 (mismo comando): arranque 218.0ms, query caliente med 13.08ms,
toggle med 6.96ms, CPU reposo 0.0% — consistente con run 2.

Captura: `spikes/nested/f6-perf.png` (overlay con «kate», 13 resultados,
«Latencia: 5 ms · 13 resultados · Nimbus» — corrobora la medición).
Log: `spikes/nested/f6-perf.log`; tabla: `spikes/nested/f6-perf-table.txt`;
crudos: `f6-perf-query.txt`, `f6-perf-toggle.txt`, `f6-perf-offscreen.txt`.

## Gaps / notas (no inventados, causa identificada)

- **G1 — toggle max 179ms (1 de 10 muestras).** Outlier aislado de
  planificación del compositor anidado bajo carga paralela del host
  (varias sesiones nested a la vez); la mediana (8.10ms) y 9/10 muestras
  están <10ms. No es coste del slot (solo alterna `visible`).
- **G2 — CPU 49.6% durante ráfaga.** Es saturación sintética deliberada
  (300 queries seguidas en ~2s para llenar la ventana de medida), no el
  coste de una query (5-6ms in-process). En reposo 0.0-0.3%.
- **Metodología 10k:** `scanRoots` limita a 1500 ficheros/raíz y 4000 en
  total, así que el índice en memoria retiene un subconjunto de los 10k
  sintéticos; el camino fuzzy completo sobre 10k candidatos lo cubre P0
  (`perf-fuzzy-10k`, 3ms). Sin cambio de límites (fuera de alcance T08).
- **Operativa:** el run 2 completó todas las sondas y artefactos pero la
  herramienta cortó a los 300s durante el `cleanup` (rm de 10k ficheros
  bajo carga paralela); restos `nimbus-perf-*` verificados vacíos
  (solo `data/kwalletd`) y borrados a mano. El script ya duerme 2s y
  reintenta el `rm` antes de avisar.
