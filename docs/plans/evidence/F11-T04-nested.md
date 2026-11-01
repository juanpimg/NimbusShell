# F11-T04 — Evidencia (accesibilidad por script + contraste medido)

## 1. `scripts/nimbus-a11y` (nuevo)
Bash, `set -u`, sin root, idempotente, backup `nimbusshell-backup-a11y-*`
(pila: cada `--apply` guarda, cada `--revert` restaura y consume).
`--list` / `--check` (8 features) solo lectura; solo `--apply`/`--revert`
escriben; todo redirigible con `--home DIR` (tests en HOME temporal).
Canales reales (mismos que el KCM F8-T05, `nimbusmodule.cpp`):
- `orca`: `kaccessrc [ScreenReader] Enabled` + gsettings
  `screen-reader-enabled` (best-effort) + `orca.service` si existe.
  Sin Orca instalado avisa y guarda igual (verificado en tests).
- `zoom`: `kwinrc [Plugins] zoomEnabled=true`; documenta Meta+= / Meta+-
  del efecto Zoom si existen en `kglobalshortcutsrc`.
- `contrast`: instala `NimbusHighContrast.colors` en
  `~/.local/share/color-schemes/` + `kdeglobals ColorScheme` (§3).
- `stickykeys`/`bouncekeys`/`slowkeys`: `kaccessrc [Keyboard]`
  (retardos 500 ms en bounce/slow).
- `reduce-motion`: `AnimationSpeed=0` + `magiclampEnabled=false` +
  fade 150 ms (contrato §2.5).
- `reduce-transparency`: `blurEnabled=false` + `translucencyEnabled=false`
  (contrato §2.4; la barra glass queda opaca).

## 2. Dotfiles
- Nuevo `dotfiles/.config/kaccessrc`: sticky/slow/bounce off, aviso
  visible (`[Bell] VisibleBell`), lector off. Se despliega a
  `~/.config/kaccessrc` (raíz, como `kwinrulesrc`).
- `kwinrc` canónico **no tocado** (propiedad de F11-T01): los cambios de
  kwinrc viven solo en `--apply` + backup, nunca en defaults.

## 3. Contraste WCAG AA medido (fórmula WCAG sobre el .colors)
- texto/fondo (View): **21.00:1** ✓ · acento/fondo: **9.46:1** ✓
- selección/fondo: **6.33:1** ✓ · botón y ventana: **21.00:1** ✓
- Umbral AA 4.5:1 (contrato §2.5/A4): **5/5 pares pasan**.

## 4. Tests `tests/a11y/test_a11y.sh`: **58/58 PASS**
Apply/check/revert por feature en HOME temporal, claves vía
`kreadconfig6`, idempotencia (re-apply), `--check` no escribe, feature
desconocido falla accionable, Orca ausente (aviso + guarda),
`--apply all` (8/8 on), `bash -n` + shellcheck cero warnings.

## 5. Captura
`spikes/nested/f11-a11y-contrast.png`: preview **offscreen** del esquema
(PIL, sin sesión). Gap: aplicar `plasma-apply-colorscheme` en nested/VM
y capturar ventana real (pendiente de harness con sesión viva).

## 6. Auditoría teclado
`F11-T04-audit.md`: **6/10 PASS estático**; gaps G1 (F6 Spotlight/Apps),
G2 (F7 nimbus-mc), G3 (F10 NC/CC por teclado) + repetición en VM.

## Límites
Orca no instalado en este host (aviso verificado, no lector real);
sin VM en esta tarea (contraste offscreen, audit estático).
