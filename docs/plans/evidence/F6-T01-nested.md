# F6-T01 nested — Spotlight sobre KRunner (Plan B)

Fecha: 2026-10-31. Rama `plasma/f6-krunner`. KRunner 6.8.2 / Plasma 6.8.2.
Nested (`kwin_wayland --virtual --no-lockscreen`, bus D-Bus privado,
HOME/XDG temporales; `~/.config` del host intacto, sin root, sin instalar).

## 1. API skin/tema KRunner: NO existe (Plan B aplicado)

Verificado en host (solo lectura):

- Sin QML instalado `org.kde.krunner` (`find /usr -name RunCommand.qml`
  solo devuelve el del plasmoide Colorizer, no relacionado). UI de KRunner
  en C++ dentro de `plasma-workspace` (`/usr/bin/krunner`).
- Sin KCM de temas: solo `kcm_plasmasearch` (on/off de plugins).
- Única key de presentación en `krunnerrc`: `[General] FreeFloating=true`
  (ya en `dotfiles/.config/plasma/krunnerrc`; sin keys de tamaño/posición).
- DBus `org.kde.krunner.App` (`/usr/share/dbus-1/interfaces/
  org.kde.krunner.App.xml`): solo `display/toggleDisplay/
  displaySingleRunner/displayWithClipboardContents/query/querySingleRunner`.
  **Sin método de resultados ni `match`**: `qdbus6 … query "kate"` abre el
  popup con el término, no devuelve matches.

Backend propio con la API oficial C++ `KF6Runner::RunnerManager`
(`setupMatchSession` + `launchQuery` + `matchesChanged`/`queryFinished` +
`run`): mismos runners y ranking que el popup stock.

## 2. Ficheros

- `apps/nimbus-spotlight/` (`main.cpp`, `krunnerbackend.{h,cpp}`,
  `qml/Spotlight.qml`, `spotlight.qrc`, `CMakeLists.txt`,
  `org.nimbus.spotlight.desktop`, `README.md`): overlay 680x460 tercio
  superior, layer-shell Overlay sin zona exclusiva, teclado exclusivo solo
  visible; campo grande, resultados + preview, footer Cmd+1..4
  (Apps/Archivos/Acciones/Portapapeles vía klipper DBus), Quick Keys A–L
  por posición visible, debounce 200ms, arriba/abajo/Enter/Esc, cierra al
  perder foco; DBus `org.nimbus.Spotlight /Spotlight toggle`; `--demo`,
  `--query <t>`, `--shot <png>`.
- `packages/kwin/scripts/nimbus-spotlight/`: `registerShortcut Meta+Space
  → callDBus toggle` (sin binds CTRL, Meta como Cmd).
- `tests/vm/nested-spotlight.sh`: harness nested dedicado (plantilla
  `nested-plasma.sh`).

## 3. Evidencia nested (`--query kate`, backend KRunner real)

- Resultados reales: 6 matches (Kate vía runner Aplicaciones + sesiones +
  shell); pestaña Apps muestra 3. Capturas: `spikes/nested/f6-spotlight.png`
  (spectacle) y `f6-spotlight-grab.png` (grabWindow): campo "kate", lista con
  Quick Keys A/B/C, preview "Motor: Aplicaciones", footer ⌘1..4, línea
  "Latencia: 236 ms · 3 resultados".
- Latencia medida (`QElapsedTimer` query→render, log `spotlight-latency`):
  progresiva 235ms + final 236ms (nested, frío y caliente ~230ms en host).
- DBus toggle: `qdbus6 org.nimbus.Spotlight /Spotlight …toggle` rc=0
  (oculta y muestra).
- QML: 0 errores (`qmllint` limpio + `f6-qmlerr.txt` vacío).

## 4. Límites conocidos (no bloquean T01; van a F6-T08/F6-T02)

- **A6 <50ms NO alcanzado en query→render (~235ms)**: dominado por hilos de
  runners por `launchQuery` (medido también en caliente: 200ms; el popup
  stock comparte `RunnerManager`, misma clase de latencia). El toggle
  mostrar/ocultar sí es instantáneo. Optimización (caché, fast-path por
  runner) → F6-T08.
- Doble `launchQuery` encadenado deja a `RunnerManager` sin `queryFinished`:
  mitigado con debounce QML 200ms + guarda mismo-término en `search()`.
- Este Qt suprime `qInfo/qWarning` por defecto (verificado con binario
  mínimo; nimbus-bar ya lo documentó): handler propio a stderr.
- En nested sin tema de iconos los glyphs caen a letra/placholder; baloo/
  activities fallan sin demonios (benigno, servicios runner responden).
- `tests/vm/nested-spotlight.sh`: no pipear su stdout a `tail` (hijos
  heredan el pipe y cuelga); redirigir a fichero.

## Veredicto

Overlay funcional con backend KRunner real, captura con query real,
toggle DBus OK, 0 errores QML. T01 verde salvo sub-objetivo A6-latencia,
que se deriva a F6-T08 con números medidos.
