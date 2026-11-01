# F7-T08 nested — Multi-monitor: 2 salidas reales en doble anidado

Fecha: 2026-11-01. Rama `plasma/f7-mc`. Harness
`tests/vm/nested-f7mc-dual.sh` (+ outer/inner): kwin windowed
`--output-count 2` (2×1280×800) DENTRO de kwin virtual 2600×900, con
2ª sesión D-Bus para no colisionar `org.kde.KWin`. Host intacto
(la vía windowed directa abriría ventanas en la sesión del usuario:
prohibida). Captura `spikes/nested/f7-mc-dual.png`, log
`spikes/nested/f7mc-dual.log`.

## Resultado: SÍ, 2 pantallas; MC abre en la primaria y no rompe

- `screenInfo=count=2 [WL-0:1280x800(prim) WL-1:1280x800]
  mc=1280x800@0,0` ✓ (slot `/MC screenInfo`; geometría MC =
  primaria, añadido en este cambio junto a re-encuadre en
  `primaryScreenChanged`).
- `windowCount=3` (kate/konsole/dolphin del kwin interno),
  `desktopCount=4` (ensureSpaces también vale aquí), MC VIVO,
  grab OK, `open_ms=107`, **0 errores QML**.

## R-MC-DISPLAY (se mantiene, acotado)

Overlay solo en primaria; MC-por-display y salto al monitor con cursor
pendientes (F7-T10+). Sin HW multi-monitor real para medir más.
