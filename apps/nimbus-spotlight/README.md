# nimbus-spotlight — Spotlight sobre KRunner (F6-T01, Plan B)

Overlay centrado estilo Spotlight (contrato Tahoe §3) con backend KRunner
real vía `libKF6Runner` (`RunnerManager::launchQuery`), NO skin QML.

## Por qué Plan B

KRunner 6.8 **no expone API oficial de skin/tema QML** (verificado en host):

- UI en C++ dentro de `plasma-workspace` (`/usr/bin/krunner`); no hay
  `org.kde.krunner` QML instalado ni KCM de temas (solo `kcm_plasmasearch`
  = on/off de plugins).
- Única key de presentación en `krunnerrc`: `[General] FreeFloating=true`
  (ya en `dotfiles/.config/plasma/krunnerrc`).
- DBus `org.kde.krunner.App` solo ofrece `display/toggleDisplay/
  displaySingleRunner/displayWithClipboardContents/query/querySingleRunner`
  (ver `/usr/share/dbus-1/interfaces/org.kde.krunner.App.xml`):
  **sin método de resultados ni `match`**. El `qdbus6 ... query` del
  enunciado abre el popup con el término, no devuelve matches.

Backend propio con la API oficial C++ `KF6Runner::RunnerManager`
(`launchQuery` + `matchesChanged`/`queryFinished` + `run`), misma que usa
el popup stock: mismos runners, mismo ranking.

## Contrato §3 cubierto

- Overlay centrado tercio superior, ~680px, glass oscuro, campo grande,
  resultados + preview lateral, footer Cmd+1..4 (Apps/Files/Actions/
  Clipboard), Quick Keys (primeros 12 resultados con letra), Esc cierra,
  cierra al perder foco, arriba/abajo/Enter, sin robar teclado oculto.
- Atajo Cmd+Espacio = `Meta+Space` vía KWin script
  `packages/kwin/scripts/nimbus-spotlight/` → DBus
  `org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle`.
- Sin activos Apple: Inter, sin logos/sonidos.

## Uso

```sh
cmake -B build -S . && cmake --build build
./build/nimbus-spotlight --demo              # datos falsos (test render)
./build/nimbus-spotlight --demo --query kate # demo + query inicial (nested)
./build/nimbus-spotlight --query kate        # backend KRunner real
qdbus6 org.nimbus.Spotlight /Spotlight org.nimbus.Spotlight.toggle
```

Latencia: `QElapsedTimer` query→`queryFinished` + render; se imprime como
`spotlight-latency: query=<ms>ms`. Objetivo A6 <50ms DBus+render (el tramo
DBus no aplica: in-process vía libKF6Runner; se mide query→render).

## Ficheros

- `main.cpp`, `krunnerbackend.{h,cpp}` — app + backend RunnerManager.
- `nimbusindex.{h,cpp}` (F6-T02) — fast-path local Qt Core: apps .desktop
  (parser propio), archivos (`~/Desktop|Documents|Downloads` + `~`,
  profundidad ≤3, caché, worker `std::thread`), ajustes (KCMs conocidos),
  calculadora (shunting-yard seguro, sin eval), web (`?` → DuckDuckGo,
  sin red), portapapeles (solo klipper DBus, <16k). Frecuencia en
  `$XDG_STATE_HOME/nimbus-spotlight/frecuencia.json`. Locales primero;
  KRunner (backend intacto) solo como fallback con Tab o botón.
- `qml/Spotlight.qml`, `spotlight.qrc` — overlay QML (tokens hardcodeados
  dark §2.1; `NimbusTokens` como import opcional si está instalado).
  Preview con acciones Abrir/Copiar/Revelar (`nimbus.activateLocal`).
- `tests/tst_index.cpp` + `tests/spotlight/test_index.py` — fuzzy,
  calculadora, .desktop, 10k sintéticos <50ms.
- `org.nimbus.spotlight.desktop` — lanzador.
- KWin script: `packages/kwin/scripts/nimbus-spotlight/`.
