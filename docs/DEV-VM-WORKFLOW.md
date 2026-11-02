# DEV-VM-WORKFLOW — loop live sin SSH (9p + HMP)

Fecha: 2026-11-02. Herramienta: `scripts/dev-vm` (bash, sin root en el host).
Objetivo: cambiar QML/C++ de `nimbus-bar` y verlo en la VM **live** en segundos,
sin reconstruir la ISO. La ISO completa se reserva para instalador, `greetd`/
SDDM, drivers, servicios de arranque y cualquier cosa que deba persistir.

> **Validado 2026-11-02:** `reset` (cold boot + Plasma + agente), `deploy
> --open-cc` y `capture` PASS; binario host/guest md5 `161fb37…`; captura
> `docs/plans/evidence/DEV-VM-LOOP.png`. La VM se paró después. No hay sshd
> en el live: el deploy va por 9p+agente+HMP. `--qml-root` y `dev-remote`
> complementan el loop para QML y PC instalado.

## Contrato de la VM (no cambiar sin Ruling)

| Recurso | Valor |
|---|---|
| ISO live | `~/.cache/nimbusshell-vm/share/nimbusos.iso` |
| Disco destino | **ninguno** (`-snapshot`; el guest se descarta al parar) |
| RAM / CPU | 3G / 4 vCPU, `q35,accel=kvm`, SeaBIOS (OVMF opcional con `NIMBUS_DEV_OVMF=1`) |
| Pantalla | VNC `127.0.0.1:5908` (`-display none`) |
| Monitor | HMP unix `~/.cache/nimbusshell-vm/dev-vm.sock` |
| SSH hostfwd | `127.0.0.1:2228` (solo hostfwd; el live **no trae sshd**) |
| 9p | `hostshare` = `~/.cache/nimbusshell-vm/share`, montado en el guest en **`/mnt`** |
| Nombre QEMU | `nimbus-dev` |
| Estado host | `~/.cache/nimbusshell-vm/dev-vm-state/pid` |

El live arranca a **tty1 como root (autologin)**. Plasma 6.8.2 se lanza con
`startplasma-wayland` (sin systemd user service). No hay Quickshell: la barra
es el binario `nimbus-bar`.

`out15` (PID 299775, VNC 5907, SSH 2227, `target.sock`) es **intocable**.
`dev-vm` solo señaliza el PID de su VM, verificado en `/proc` (`-name
nimbus-dev` + su socket HMP), o adopta una VM ya viva cuyo dueño de VNC 5908
sea exactamente esa combinación. Nunca usa `pkill -f` ni mata puertos ajenos.

## Bucle rápido (segundos)

```bash
scripts/dev-vm start                 # arranca/adopta, monta 9p /mnt, agente + Plasma
scripts/dev-vm deploy --open-cc      # build host + 9p + args; espera deployed.md5
scripts/dev-vm capture docs/plans/evidence/mi.png
scripts/dev-vm status
scripts/dev-vm stop
scripts/dev-vm reset                 # stop + start (snapshot limpio)
```

`start`:

1. Arranca QEMU (o adopta el PID 5908 si ya está viva).
2. Espera HMP y teclea en tty1 cada segundo hasta que el shell root responde.
3. Ejecuta `loadkeys us` (el keymap por defecto del live puede ser es/latam),
   monta `hostshare` en `/mnt` y escribe un centinela `share/dev/tty.ready`.
4. Lanza `setsid sh /mnt/dev/agent.sh` y, si no corre, `startplasma-wayland`.
5. Espera heartbeat del agente y `bar.pid`.

`agent.sh` (lo genera `scripts/dev-vm` en el 9p):

- Espera `/run/user/0/bus` y `/run/user/0/wayland-*`.
- Lee `share/dev/args` y lanza `nimbus-bar` con esos flags.
- Vigila el md5 del binario **y el contenido de `args`**; al cambiar, mata su
  barra (solo PID/cmdline exactos) y relanza.
- Escribe `share/dev/deployed.md5`, `bar.pid`, `agent.heartbeat`, `agent.log`
  y `bar.log`. Sin systemctl (live root, sin servicio).

`deploy`:

1. `cmake -S packages/shell/nimbus-bar -B /tmp/nimbus-dev-build` + build.
2. Copia el binario a `~/.cache/nimbusshell-vm/share/dev/nimbus-bar`.
3. Escribe los flags recibidos en `share/dev/args` (p. ej. `--open-cc`).
4. Espera (timeout 60 s) a que `agent.heartbeat` esté fresco y
   `deployed.md5` coincida con el md5 host; exige `bar.pid` y `bar lanzada`
   en `agent.log`. **Copiar no es desplegar:** sin `deployed.md5` no hay OK.

Si el agente no está vivo, `deploy` avisa y espera; ejecuta antes `start`.
Con `NIMBUS_DEV_TRANSPORT=ssh` (VM instalada con sshd) se usa el fallback
`install` + `systemctl --user restart nimbus-bar`; en el live no aplica.

## Captura

```bash
scripts/dev-vm capture                                  # out/dev-<ts>.png
scripts/dev-vm capture docs/plans/evidence/DEV-VM-LOOP.png
```

Usa HMP `screendump` + `hmp.py`/`ppm2png.py`. Si HMP no responde, falla con
mensaje accionable; no genera una captura vacía. La ruta con `/` se interpreta
relativa al repo; un nombre suelto va a `out/`.

## Glass una vez por arranque

Glass es un plugin binario de KWin (no va dentro de `nimbus-bar`) y el snapshot
lo descarta al parar. En el host, con la receta/pin de
`docs/plans/evidence/F11-T02-glass-spike.md`:

```bash
git clone --depth 1 https://invent.kde.org/frameworks/extra-cmake-modules /tmp/ecm-src
cmake -S /tmp/ecm-src -B /tmp/ecm-src/build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/tmp/ecm-prefix -DBUILD_TESTING=OFF
cmake --build /tmp/ecm-src/build && cmake --install /tmp/ecm-src/build

git clone --depth 1 https://github.com/4v3ngR/kwin-effects-glass /tmp/kwin-glass
cmake -S /tmp/kwin-glass -B /tmp/kwin-glass/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/tmp/glass-prefix \
  -DCMAKE_PREFIX_PATH=/tmp/ecm-prefix
cmake --build /tmp/kwin-glass/build -j"$(nproc)"
cmake --install /tmp/kwin-glass/build
mkdir -p ~/.cache/nimbusshell-vm/share/dev/glass
cp -a /tmp/glass-prefix/lib/plugins/kwin/effects/plugins/glass.so \
      /tmp/glass-prefix/lib/plugins/kwin/effects/configs/kwin_glass_config.so \
      ~/.cache/nimbusshell-vm/share/dev/glass/
```

En tty1/Konsole del guest (root):

```bash
sudo install -Dm755 /mnt/dev/glass/glass.so \
  /usr/lib/qt6/plugins/kwin/effects/plugins/glass.so
sudo install -Dm755 /mnt/dev/glass/kwin_glass_config.so \
  /usr/lib/qt6/plugins/kwin/effects/configs/kwin_glass_config.so
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key glassEnabled true
kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength 6.0
kwriteconfig6 --file kwinrc --group Effect-blurplus --key PhysicallyBasedRefraction true
qdbus6 org.kde.KWin /Effects reconfigureEffect glass 2>/dev/null || true
```

Si el efecto no aparece, reinicia la sesión/VM (snapshot): KWin solo carga
plugins nuevos al arrancar. Verifica `journalctl --user -u plasma-kwin_wayland`
y `kwinrc` (`glassEnabled=true`).

## Paralelismo sin pisarse

- **Host build + guest capture**: el build CMake corre en el host y `capture`
  habla con QEMU por HMP; pueden solaparse. No lances dos `deploy` a la vez
  sobre el mismo `share/dev` (artefacto/args únicos).
- **Dos agentes**: los defaults 5908/2228/dev-vm.sock son de **una** VM. Para
  una segunda usa overrides y `NIMBUS_DEV_STATE_DIR` distinto; nunca 5907/2227
  ni `target.sock`.
- `doctor` es de solo lectura y se puede correr en paralelo.

## Riesgos conocidos (y cómo los trata el script)

- **Snapshot**: binario, plugin Glass y configuración del guest se pierden al
  `stop`/`reset`. `share/dev` persiste; el agente reaplica el binario y Glass
  se reinstala una vez por arranque.
- **9p y root**: el guest monta `hostshare` en `/mnt` (root). Los ficheros del
  share se escriben como el usuario del host; el binario debe ser ejecutable.
- **Sin SSH**: el live no trae sshd; el loop es 9p + HMP. `doctor` lo detecta
  y **no lo trata como fallo**. SSH solo es fallback de una VM instalada.
- **Keymap de tty1**: el live puede arrancar en es/latam; `start` teclea
  `loadkeys us` antes de los símbolos (`/`, `-`, `=`, `|`). Sin eso, el
  comando de montaje se corrompe (ver evidencia).
- **Foco del teclado HMP**: `start` teclea en el shell de tty1 tras el boot.
  Si Plasma ya está corriendo y el agente murió, el foco puede estar en una
  ventana; en ese caso usa el comando manual que imprime el error.
- **Rendimiento**: la barra loguea `blur compositor activo=0` en esta VM
  (Glass/blur no activo); no es fallo del loop.
- **VNC/SSH solo loopback**: VNC 5908 y hostfwd 2228 en `127.0.0.1`.

## Diagnóstico

```bash
scripts/dev-vm doctor    # PASS / BLOQ / FALTA (no arranca nada)
scripts/dev-vm status    # 0 si la VM propia corre; 3 si está parada
scripts/dev-vm stop      # idempotente; solo toca su PID verificado
```

Códigos: `doctor` 0 = listo, 1 = falta algo, 2 = bloqueado por otra VM/
puertos; `deploy` 0 = verificado por `deployed.md5`, 3 = timeout/fallo.
