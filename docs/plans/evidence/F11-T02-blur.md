# F11-T02 — Blur real de compositor en la barra (spike nested, 2026-11-02)

## Qué se ha demostrado

La barra `nimbus-bar` pide **blur real** al compositor con
`KWindowEffects::enableBlurBehind()` sobre su superficie layer-shell. En KWin
6.8 Wayland se usa `ext-background-effect-v1` (el global está anunciado:
`ext_background_effect_manager_v1`, versión 1). El fondo del escritorio se
desenfoca de verdad detrás de la barra; el QML solo pinta el tinte oscuro, el
hairline y el contenido.

**Esto NO es todavía Liquid Glass completo**: hay blur de fondo, pero no hay
refracción/lensing, dispersión, rim/specular ni tinte adaptativo. F11-T02
sigue abierto hasta integrar Glass (o un efecto equivalente) y validarlo en la
VM instalada.

## Entorno y comando

- Host: Plasma/KWin **6.8.2**, backend virtual 1280×800, sesión nested aislada
  (`dbus-run-session`, HOME/XDG temporales). No se tocó la VM del usuario.
- Fondo de prueba: damero de 16 px (`/tmp/opencode/checker-1280x800.png`)
  aplicado con `plasma-apply-wallpaperimage`. Sin un fondo de alto contraste el
  blur es invisible (un degradado suave no demuestra nada).
- Comando:

```bash
bash tests/vm/nested-bar.sh \
  --bin /tmp/barblur2/nimbus-bar \
  --out spikes/f11-blur --timeout 30 \
  --wallpaper /tmp/opencode/checker-1280x800.png \
  --socket nimbus-blur-final
```

- Log clave: `nimbus-bar: blur compositor activo=1` (a los 500 ms, cuando el
  binding Wayland ya está activo).

## Evidencia

| Fichero | Qué muestra |
| --- | --- |
| `F11-T02-blur/before-after.png` | Arriba: barra con blur (damero promediado). Abajo: el mismo fondo sin barra (damero nítido). |
| `F11-T02-blur/bar-with-blur.png` | Recorte de la franja superior con barra. |
| `F11-T02-blur/bar-without-bar.png` | Recorte equivalente sin barra (referencia enfocada). |
| `F11-T02-blur/zoom-4x.png` | Zoom 4× del extremo izquierdo: el damero bajo la barra queda convertido en una media uniforme. |
| `F11-T02-blur/metrics.txt` | Métrica objetiva. |

Nitidez (varianza del laplaciano en la franja `x=300..900`, `y=0..24`):

- **Con blur**: media 7,20 / desviación 15,27.
- **Sin barra**: media 33,78 / desviación 81,15.

La caída de alta frecuencia es la firma del blur; no es solo un tinte, porque
el damero deja de verse y pasa a un promedio de color.

## Hallazgo técnico (importante)

`KWindowEffects::isEffectAvailable(BlurBehind)` devuelve **false en el primer
frame** aunque el protocolo exista: el binding del global y la capability
`blur` llegan de forma asíncrona. Si se usa esa guardia para no llamar a
`enableBlurBehind`, el blur nunca se activa (era el bug del primer prototipo).

Secuencia que funciona:

1. Llamar a `enableBlurBehind(win, true)` **sin** condicionar a
   `isEffectAvailable`; la región queda registrada.
2. Tras ~500 ms (binding activo), reaplicar `false` + `true` y pedir
   `requestUpdate()`.
3. El protocolo es double-buffered: la región solo se aplica en el siguiente
   `wl_surface.commit`. Sin repintado, el efecto queda pendiente y no se ve.

## Límites y siguientes pasos

- Probado solo en nested; falta la **VM instalada** (out15/out16) y medir fps
  con `QSG_RENDER_TIMING=1` (llvmpipe y GPU).
- Falta **Reduce Transparency** (A9): con blur desactivado la superficie debe
  quedar opaca y legible.
- Falta **refracción real**: integrar `4v3ngR/kwin-effects-glass` para Plasma
  6.8 o un efecto equivalente; el blur stock por sí solo no reproduce Liquid
  Glass.
- El harness `tests/vm/nested-bar.sh` ahora acepta `--wallpaper` y `--socket`
  y limpia solo sus propios PID (antes mataba por patrón y dos ejecuciones
  concurrentes se tumbaban entre sí).
