# Evidencia F9-T03 — layouts Mac/Win/Nimbus (`apps/nimbus-welcome` + `scripts/nimbus-layout`)

## Qué se implementó
- Wizard 6→7 pasos: nuevo paso 6/7 «Diseño» (`qml/Welcome.qml`) con 3
  tarjetas (Mac por defecto, Windows, Nimbus), preview mock (barra +
  semáforos izq/der + Dock con acento) y descripción; clic =
  `setLayout` (persiste), «Aplicar diseño» = `applyLayout()`.
- Backend (`welcomebackend.{h,cpp}`): propiedad `layout` (mac por
  defecto, valida mac|windows|nimbus), persiste `layout/name` en
  `~/.config/nimbus-welcome.ini` + espejo `[Layout] name=` en
  `~/.config/nimbus-layout.ini`; `applyLayout()` ejecuta
  `scripts/nimbus-layout <layout> --apply` (repo o PATH), en sim solo inis.
- `scripts/nimbus-layout` (`set -u`, sin root, idempotente, backup en
  `~/.config/nimbusshell-backup-layout`, `--apply/--check/--revert`,
  `--home DIR`): botones XIA izq (mac/nimbus) o IAX der (windows),
  atajos vía `nimbus-keys` (meta/ctrl), Dock Krema abajo tile 48,
  barra 24, doble-clic maximizar (≈zoom; KWin no tiene zoom de ventana).
- `main.cpp`: flag `--layout <mac|windows|nimbus>` (preselección/test).
- `I18n.js`: 7 claves nuevas es→en.

## Verificación (HOME/XDG temporales, host intacto)
- `qmllint qml/Welcome.qml` → 0 avisos.
- `shellcheck -S warning scripts/nimbus-layout` → 0 warnings.
- `ctest` (HOME temporal, `NIMBUS_WELCOME_SIM=1`) → 5/5 PASS, incl.
  `layoutDefaultAndPersist` (defecto mac, rechazo de inválido, espejo en
  ambos inis, reanudación).
- Offscreen: `--layout windows --page layout` → `STEP=5`, reanuda, 0 QML.
- Nested (`kwin_wayland --virtual` + `dbus-run-session`, script
  `/tmp/opencode/f9t03-nested.sh`, log `spikes/nested/f9-layout-nested.log`):
  `QML_WARN/ERROR=0` en ambos shots; `SHELL --check` mac OK (7/7);
  `kreadconfig6`: mac `ButtonsOnLeft=XIA/IconSize=48/Window Close=Meta+Q`,
  windows `ButtonsOnRight=IAX/Window Close=Ctrl+Q`, nimbus
  `nimbus-layout.ini name=nimbus`; `--revert` restaura el backup.

## Capturas
- `spikes/nested/f9-layout-mac.png` (Diseño, Mac elegido, semáforos izq).
- `spikes/nested/f9-layout-win.png` (Diseño, Windows elegido, der).

## Límites
- Mac y Nimbus comparten keymap KWin (meta) y botones; difieren en el
  marcador `nimbus-layout.ini` (documentado en el script).
- Modo Windows reescribe Meta+<tecla simple> a Ctrl+<tecla> solo dentro
  de `kglobalshortcutsrc` (opt-in por elección, revertible); no toca
  binds Ctrl fuera de ese fichero ni configs Hyprland.
- `build/` no se commitea.
