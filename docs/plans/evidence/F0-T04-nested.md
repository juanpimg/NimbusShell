# F0-T04 nested — KRunner + Expose/Overview (harness anidado)

Fecha: 2026-10-31. Host Plasma 6.8.2 Wayland. Harness
`tests/vm/nested-plasma.sh` con flags nuevos `--krunner <q>`,
`--expose`/`--overview`, `--home <dir>`, `--plasma-src <dir>`.
Comando canónico (configs de `plasma/f2-configs`, solo lectura):

```
bash tests/vm/nested-plasma.sh --out spikes/nested --timeout 60 \
  --krunner kate --expose \
  --home /tmp/opencode/nimbus-f2homeN \
  --plasma-src /home/jp/Escritorio/Proyectos/NimbusShell-f2cfg/dotfiles/.config/plasma
```

## Resultados

| Test | D-Bus | rc | Latencia D-Bus | Visual |
|---|---|---|---|---|
| `krunner.App.query("kate")` | `org.kde.krunner /App` | 0 | 7 ms | SÍ: popup con Kate, Ejecutar kate, sesiones, ventana (`f0-krunner.png`) |
| `invokeShortcut Expose` | `kglobalaccel /component/kwin` | 0 | 5–6 ms | NO: sin grid en 3/3 capturas (`f0-expose.png`) |
| `invokeShortcut Overview` | idem | 0 | 6 ms | SÍ: grid "Escritorio 1" + thumbs + Buscar (`f0-overview.png`) |

KWin no crashea en ningún caso; cleanup verificado (0 restos, 0 dirs temp).

## Gap exacto: Expose sin efecto

`supportInformation` → `Loaded Effects: overview` (único). El efecto
present-windows no está cargado en la sesión virtual, así que el atajo
responde rc=0 pero no hay nada que renderizar. Pendiente: cargar/habilitar
el efecto (kwinrc `[Effect-PresentWindows]` o `dbus /Effects loadEffect`) y
repetir. Overview descarta riesgo de compositor: el pipeline de efectos
renderiza bien en `--virtual`.

## Hallazgos del harness (fixeados)

- krunner abierto tapa el grid: Expose va ANTES que query; tras query se
  cierra con `toggleDisplay`; tras captura de efecto, toggle de cierre + `break`.
- `--overview` prueba Overview primero y captura a `f0-overview.png`.
- krunner se automuestra al arrancar en el nested (popup "Buscar..." vacío
  visible incluso sin query): documentado, no bloquea.

## Limitaciones

Latencias = solo ida/vuelta D-Bus, NO tiempo de render (falta instrumentar
primer-frame). GPU compartida con el host; perf real (<50 ms KRunner,
<300 ms Overview de F0-T04) pendiente de VM. Sin `ydotool`: Meta+W físico
no probado; el invokeShortcut es equivalente funcional.
