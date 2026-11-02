# DEV-QML-ROOT — iterar QML de la barra sin rebuild

`nimbus-bar --qml-root DIR` carga `DIR/Bar.qml` desde disco en vez de
`qrc:/Bar.qml`. Sirve para editar QML, reiniciar la barra y ver el cambio en
segundos, sin `cmake` ni reinstalar el binario.

```bash
# build una vez (C++ no cambia)
cmake -S packages/shell/nimbus-bar -B /tmp/nimbus-build -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/nimbus-build -j"$(nproc)"

# ejecutar con el árbol QML real
/tmp/nimbus-build/nimbus-bar --qml-root "$PWD/packages/shell/nimbus-bar/qml"
```

Tras editar un `.qml`, mata y relanza la barra (no hay recarga en caliente):

```bash
pkill -x nimbus-bar
/tmp/nimbus-build/nimbus-bar --qml-root "$PWD/packages/shell/nimbus-bar/qml" &
```

## Contrato

- Acepta `--qml-root DIR` y `--qml-root=DIR`. El directorio debe contener
  `Bar.qml` legible; si no, error accionable y exit 1.
- Se loguea `nimbus-bar: qml-root=<dir absoluto>` por stderr.
- La ventana primaria **y** las barras multi-monitor (`QQmlComponent`) usan el
  mismo `QUrl::fromLocalFile(DIR/Bar.qml)`.
- El `import "."` de `Bar.qml` resuelve `NimbusTokens.qml` y `qmldir` **del
  mismo DIR**: copia el directorio completo (`qml/`), no solo `Bar.qml`.
- Sin el flag, el comportamiento es el de siempre (`qrc:/Bar.qml`).

## Límites (honestos)

- **Solo QML.** Cualquier cambio en `main.cpp`, modelos o `.qrc` exige build
  de CMake. `bar.qrc` no se relee con el flag.
- Los recursos empaquetados en Qt (`qrc:/...`) no vienen del DIR; hoy la barra
  no referencia recursos así (todo son QML + tema del sistema), pero si se
  añaden habrá que servirlos también desde disco.
- No hay watch/recarga automática: reinicia la barra para cada iteración.
- `nimbus-bar.service` arranca sin el flag. Para uso persistente en una VM o
  PC físico, añade un drop-in `ExecStart=/usr/local/bin/nimbus-bar
  --qml-root /ruta/al/qml` (no lo hace este repo).

## Copiar a una VM o PC físico

El binario sigue siendo el instalado; solo cambia el directorio QML. Ejemplo
con la VM de desarrollo (`docs/DEV-VM-WORKFLOW.md`, SSH del guest):

```bash
rsync -a --delete packages/shell/nimbus-bar/qml/ jp@127.0.0.1:/tmp/nimbus-qml/
ssh jp@127.0.0.1 'pkill -x nimbus-bar; \
  nohup nimbus-bar --qml-root /tmp/nimbus-qml >/tmp/nimbus-bar.log 2>&1 &'
```

`--delete` mantiene el espejo: el DIR remoto debe ser exclusivo para QML.
En el PC físico, igual con `rsync` a `~/.local/share/nimbus/qml` y el flag al
relanzar (o el drop-in del servicio). El binario debe ser uno con soporte del
flag (`nimbus-bar --qml-root`).

## Verificación

- `tests/bar/test_qml_root.sh`: build + `--dump-preset` offscreen con el flag
  (incluida una copia del dir para probar `import "."`), forma `=DIR`, sin
  flag, y negativos.
- Nested real (`tests/vm/nested-bar.sh --bar-args "--qml-root … --open-cc"`):
  captura en `docs/plans/evidence/qml-root/`.
