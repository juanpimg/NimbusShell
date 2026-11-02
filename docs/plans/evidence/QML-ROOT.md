# Evidencia — `nimbus-bar --qml-root DIR`

Fecha: 2026-11-02. Worktree `NimbusShell-qmlroot` (rama `feat/qml-root`).
Objetivo: cargar `Bar.qml` desde disco (iterar QML sin rebuild) manteniendo
`qrc:/Bar.qml` cuando el flag no se pasa.

## Cambios

- `packages/shell/nimbus-bar/main.cpp`: flag `--qml-root DIR`/`--qml-root=DIR`,
  validación de `DIR/Bar.qml` (existe y legible; si no, stderr + exit 1),
  `QUrl::fromLocalFile()` para `engine.load` y el `QQmlComponent` de barras
  extra, log `nimbus-bar: qml-root=<abs>` y aviso si falta `qmldir`.
- `tests/bar/test_qml_root.sh` (nuevo): build + offscreen + copia del dir QML.
- `docs/DEV-QML-ROOT.md` (nuevo): uso, límites, rsync a VM/PC.

## Test unitario (offscreen, sin red/sudo)

```bash
bash -n tests/bar/test_qml_root.sh && shellcheck -S warning tests/bar/test_qml_root.sh
bash tests/bar/test_qml_root.sh
```

Salida (`docs/plans/evidence/qml-root/test_qml_root.log`):

```
== qml-root: build ==
  [OK] build nimbus-bar
  [OK] copia con NimbusTokens.qml + qmldir
== qml-root: carga desde disco ==
  [OK] sin flag sigue en qrc (--dump-preset)
  [OK] --qml-root .../packages/shell/nimbus-bar/qml (--dump-preset)
  [OK] log qml-root=<dir>
  [OK] --qml-root=DIR (copia: import "." resuelve NimbusTokens)
== qml-root: negativos ==
  [OK] DIR inexistente → exit != 0 con mensaje (1)
  [OK] --qml-root sin valor → exit != 0 con uso (1)
== qml-root: resultado ==
  [OK] 0 fallos
```

`bash -n` y `shellcheck -S warning`: 0 warnings. `qmllint`/`qmlformat`: no se
tocó ningún `.qml` (sin cambios que revalidar).

## Nested real (KWin virtual)

```bash
bash tests/vm/nested-bar.sh \
  --bin /tmp/opencode/qmlroot-build/nimbus-bar \
  --out spikes/qml-root \
  --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-qmlroot \
  --bar-args "--qml-root $PWD/packages/shell/nimbus-bar/qml --open-cc"
```

`dbus-run-session exit=0`; extracto (`nested-bar-excerpt.log`):

```
nimbus-bar: qml-root=/home/jp/Escritorio/Proyectos/NimbusShell-qmlroot/packages/shell/nimbus-bar/qml
[bar] nimbus-bar VIVO pid=13301
[bar] f3-bar-24.png OK
   string "NIMBUS win caption= class=nimbus-bar type=0 layer=3 geom=0,0,1280,24"
   string "NIMBUS win caption= class=nimbus-bar type=0 layer=3 geom=976,24,304,450"
```

Ventana layer-shell de 24px en `0,0,1280,24` (barra) y panel CC en
`976,24,304,450`; `--open-cc` visible en la captura. No se distingue del
arranque `qrc:` (mismo `Bar.qml`).

Captura: `docs/plans/evidence/qml-root/f3-bar-24.png` (barra arriba + CC
abierto sobre KWin/plasmashell nested).

## No verificado / límites

- C++ y `.qrc` siguen requiriendo build; el flag solo sustituye el root QML.
- Sin recarga en caliente: reinicio manual de la barra.
- No se ejecutó en la VM out15 ni en la live (fuera de alcance); nested es la
  verificación de esta tarea.
- `scripts/ci.sh` no se tocó (evitar conflicto); el comando es
  `bash tests/bar/test_qml_root.sh`.
