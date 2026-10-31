# Goldens de referencia (R-APPLE)

**R-APPLE:** cero activos de Apple en este repo. No se distribuyen capturas
de macOS ni logos, fuentes SF, wallpapers o sonidos suyos. Los goldens son
**referencias propias**: capturas de NimbusShell en VM o fotos aportadas por
el usuario. Nada de `tests/golden/` contiene material de Apple.

## Superficies (manifiesto)

| Fichero (`tests/golden/local/`) | Superficie | Recorte sugerido |
|---|---|---|
| `barra.png` | Barra superior (menu, estado, reloj, CC) | `0,0,1920,28` en 1080p |
| `ventana-activa.png` | Ventana con semaforos activos | ventana 1100x700 centrada |
| `ventana-inactiva.png` | Ventana inactiva (semaforos grises) | misma geometria |
| `dock.png` | Dock (pins, running, papelera) | banda inferior |
| `spotlight.png` | KRunner fullscreen (Spotlight) | pantalla completa |
| `mission-control.png` | Overview/Spaces | pantalla completa |
| `settings.png` | KCM Nimbus (Ajustes) | ventana completa |

Ajusta los recortes a tu resolucion con `--crop x,y,w,h` de
`tests/screenshot-diff/compare.sh`.

## Como aportar tus capturas de macOS Tahoe (opcional, no se commitean)

1. En tu Mac, captura cada superficie (Cmd+Mayus+3/4) y copialas a
   `tests/golden/local/` con los nombres de la tabla.
2. Nunca hagas `git add` de ese directorio: esta ignorado (ver
   `tests/golden/.gitignore`). Son solo referencia visual local para
   comparar a ojo con NimbusShell; el diff automatico usa goldens
   generados por `capture.sh` en la VM.
3. No subas esas capturas a issues/PRs publicos si muestran datos
   personales; recortalas antes.

## Flujo reproducible

```bash
tests/screenshot-diff/capture.sh barra          # VM -> tests/golden/local/barra.png
tests/screenshot-diff/compare.sh tests/golden/local/barra.png /tmp/ahora.png --threshold 15
```
