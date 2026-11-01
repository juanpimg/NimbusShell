# F10-T05 — Evidencia nested: sonidos Nimbus + Spectacle

## Ficheros
- `packages/themes/sounds-nimbus/`: `generate_sounds.py` (síntesis propia
  stdlib `wave`, semilla fija), `index.theme` (`Name=Nimbus`,
  `Inherits=freedesktop`), `stereo/` (7 eventos + 2 alias, .wav masters +
  .oga vorbis). Nombres estándar verificados en
  `/usr/share/sounds/{ocean,freedesktop}/stereo` (Plasma 6.8). Sin muestras
  Apple (R-APPLE).
- `dotfiles/.config/plasma/kdeglobals`: `[Sounds] Theme=Nimbus, Enable=true`.
- `dotfiles/.config/plasma/spectaclerc`: `autoSaveImage=true`,
  `clipboardGroup=PostScreenshotCopyImage` (claves reales del host).
- `kglobalshortcutsrc`: ya tenía Meta+Shift+3/4/5 (sin duplicar).
- `lib/themes.sh`: despliega a `$XDG_DATA_HOME/sounds/Nimbus` (sin sudo).
- `tests/vm/nested-f10-sounds.sh`: harness propio (kwin `--no-lockscreen`).

## Test nested (`spikes/nested/f10-nested.log`)
- `find`: 9 .oga + 9 .wav + index.theme en `XDG_DATA_HOME/sounds/Nimbus`.
- `ffprobe`: service-login 0.30s, message 0.22s, bell 0.20s, dialog-error
  0.25s, trash-empty 0.20s, audio-volume-change 0.12s, screen-capture 0.18s
  (+ alias message-new-instant, camera-shutter). Todos ≤300ms (§2.5).
- `kreadconfig6`: Sounds=Nimbus/Enable=true; spectaclerc autoSave=true,
  clipboard=PostScreenshotCopyImage.
- Capturas: `f10-sounds.png` (escritorio + banner notify-send arriba-der),
  `f10-spectacle.png` (fullscreen vía Spectacle, autoguardado OK).

## Enganche notif/OSD (F3-T09/T10)
Banner 5s arriba-der + OSD ya existen; emiten eventos `message`,
`audio-volume-change`, `bell` vía libcanberra, que resuelve
`$XDG_DATA_HOME/sounds/Nimbus/stereo/*.oga`. Este tema solo aporta samples.

## Límites / gaps (VM)
- Audio real no reproducible en nested (sin PipeWire: "Failed to connect to
  PipeWire" en log) → timbre/calidad pendientes de oído en VM (QEMU/KVM).
- El locker anidado bloquea al arrancar (`greet --immediateLock`; también el
  harness principal `nested-plasma.sh` sale bloqueado hoy): el test usa
  `--no-lockscreen` solo en su sesión. No se tocó el harness compartido.
- `bash -n` + `shellcheck -S warning` OK; `./install.sh --check` en seco OK.
