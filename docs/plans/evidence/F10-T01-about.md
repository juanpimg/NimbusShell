# F10-T01 (About) — evidencia nested

## Qué
`apps/nimbus-about/` (Qt6 Quick, CMake, sin KF): ventana 520x420, logo N
propio, versión `2026.11`, núcleo/Plasma/Qt/KWin reales (`/proc`,
`plasmashell --version`, `qmake6 -query QT_VERSION`, `kwin_wayland
--version`), CPU/RAM/GPU (`/proc`, `lspci`), créditos (NPS, Inter,
Klassy, Krema, Plasma), botones Guía/Atajos (abren `nimbus-help --tab`)
y Copiar información (portapapeles). `--demo`/`--shot` aceptados.
`.desktop` (System/Settings) + `assets/nimbus-about.svg` propio.
Menú N: «Acerca de Nimbus» → `cmd: "nimbus-about"` (antes `""`, solo
cerraba); Esc/scrim intactos (`sequence: "Escape"` presente).

## Prueba
`bash tests/vm/nested-about.sh` → RC=0. KWin virtual 1280x800, HOME/XDG
temporales (nada del host). Log `spikes/nested/f10-about.log`:
`about VIVO`, `help VIVO`, `SHOT_OK` x2, `spectacle OK` x2,
`0 errores QML` (`f10-qmlerr.txt` 0 bytes). Capturas:
`f10-about.png` (fullscreen, ambas ventanas reales),
`f10-about-grab.png` (520x420, ventana sola: kernel 7.3.0-4-cachyos,
Plasma 6.8.2, Qt 6.12.0, KWin 6.8.2, i7-12700H, 15.2 GB, Intel ADL-P).
Build CMake + `qmllint` limpios (About.qml, Help.qml, Menu.qml).

## Límites
- Menú verificado estático (grep 1/1/1 en log): el popup layer-shell no
  se ejecuta en nested; el lanzamiento real por `runner.run()` queda para VM.
- Clics Guía/Atajos/Copiar no ejercitados en nested (solo apertura).
- `iso/build-iso.sh --check` falla en rama base por `branding.desc`
  (preexistente, no de este cambio); staging extendido a
  nimbus-about/nimbus-help pendiente de validar con `--stage-only` en VM.
- Portal warnings en nested (`Failed to register with host portal`)
  benignos, sin efecto en ventanas/capturas.
