# sounds-nimbus (F10-T05) — tema de sonido propio NPS

Sonidos 100% sintetizados (`generate_sounds.py`, stdlib `wave` + ffmpeg):
ninguna muestra de Apple (R-APPLE). Nombres estándar KDE verificados en
`/usr/share/sounds/{ocean,freedesktop}/stereo` (Plasma 6.8).

| evento NPS | fichero estándar | duración |
|---|---|---|
| arranque | `service-login.oga` | 300ms |
| notificación | `message.oga` (+ alias `message-new-instant.oga`) | 220ms |
| diálogo | `bell.oga` | 200ms |
| error | `dialog-error.oga` | 250ms |
| papelera | `trash-empty.oga` | 200ms |
| volumen (OSD) | `audio-volume-change.oga` | 120ms |
| captura | `screen-capture.oga` (+ alias `camera-shutter.oga`) | 180ms |

Contrato Tahoe §2.5: todos ≤300ms + cue visual redundante (banner/OSD ya
existen, F3-T09/T10). `index.theme` hereda `freedesktop` como fallback.

## Enganche

- Instalación: copiar a `$XDG_DATA_HOME/sounds/Nimbus/` (o
  `/usr/share/sounds/Nimbus`). `install.sh` lo despliega a
  `~/.local/share/sounds/Nimbus`.
- Activación: `kdeglobals [Sounds] Theme=Nimbus`, `Enable=true`
  (dotfile `dotfiles/.config/plasma/kdeglobals`). Plasma lo resuelve vía
  libcanberra (`XDG_DATA_DIRS/sounds/<Theme>/stereo/<nombre>.oga`).
- Notificaciones/OSD (F3-T09/T10) ya emiten los eventos `message`,
  `audio-volume-change` y `bell`; este tema solo aporta los samples.
