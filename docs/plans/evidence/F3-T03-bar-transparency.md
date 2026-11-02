# F3-T03 — Barra Tahoe translúcida (2026-11-02)

## Cambio

La barra pasa de un tinte negro **0.55** con hairline **0.60** a:

- `barBg` dark: **0.18** (light se mantiene 0.55).
- `hairline` dark: **0.25** (light 0.20).
- Presets: `default` 0.18/0.25, `compact` 0.16/0.22, `minimal` 0.14/0.22.
- Ambas copias de `NimbusTokens.qml` con md5 idéntico.

Con Glass activo, el fondo del escritorio se ve a través de la barra y el blur
mantiene la legibilidad; el hairline ya no marca una línea dura.

## Evidencia

- `F3-T03-bar-transparency/before-after.png`: franja superior antes (0.55) y
  después (0.18), mismo wallpaper y mismo estado de UI.
- `after-full.png`: captura completa 1280×800 con CC abierto.
- Comando nested: `tests/vm/nested-bar.sh --wallpaper sequoia-dark.jpg
  --kwinrc /tmp/opencode/glass-kwinrc-subtle --plugin-path /tmp/glass-prefix/lib/plugins
  --bar-args "--open-cc"`; log `nimbus-bar VIVO`, `blur compositor activo=1`.
- `test_presets.sh` VERDE y `scripts/ci.sh` VERDE.

## Límite

No es todavía el toggle **100 % transparente / Show menu bar background** de
macOS: el 0.18 es un tinte de vidrio para legibilidad sobre fondos claros.
Falta el control de usuario y el fallback **Reduce Transparency** (A9). No se
valida en la VM instalada todavía.
