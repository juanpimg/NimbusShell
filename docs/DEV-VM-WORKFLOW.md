# DEV-VM-WORKFLOW — iterar la UI sin reconstruir la ISO

Fecha: 2026-11-02. Herramienta: `scripts/dev-vm` (bash, sin root en el host).
Objetivo: cambiar QML/C++ de `nimbus-bar`, verlo en una VM **live** en segundos,
y reservar la ISO completa solo para lo que de verdad la necesita.

## Contrato de la VM (no cambiar sin Ruling)

| Recurso | Valor |
|---|---|
| ISO live | `~/.cache/nimbusshell-vm/share/nimbusos.iso` |
| Disco destino | **ninguno** (`-snapshot`, el guest se descarta al parar) |
| RAM / CPU | 3G / 4 vCPU, `-machine q35,accel=kvm -cpu host` |
| Pantalla | VNC `127.0.0.1:5908` (`-display none`) |
| Monitor | HMP unix `~/.cache/nimbusshell-vm/dev-vm.sock` |
| SSH | `nimbus@127.0.0.1:2228` (solo loopback) |
| 9p | `hostshare` = `~/.cache/nimbusshell-vm/share` |
| Nombre QEMU | `nimbus-dev` |
| Estado propio | `~/.cache/nimbusshell-vm/dev-vm-state/pid` |

La VM `out15` (PID 299775, VNC 5907, SSH 2227, `target.sock`) es **intocable**.
`dev-vm` solo señaliza el PID de su `dev-vm-state/pid`, comprobado contra
`/proc/<pid>/cmdline` (`-name nimbus-dev` + su socket HMP). Nunca usa
`pkill -f`. Si el puerto o el socket están ocupados por otro proceso, se
detiene con un mensaje accionable; no mata nada ajeno.

Credenciales del live: `nimbus` / `nimbus` (solo live; el instalado no las
hereda). `deploy` usa SSH con `SSH_ASKPASS` (no exige `sshpass`); se puede
sobrescribir con `NIMBUS_DEV_SSH_PASS` / `NIMBUS_DEV_SSH_USER`.

## Bucle rápido (segundos) vs. lento (ISO)

**Rápido — no reconstruye ISO:**

```bash
scripts/dev-vm start                  # VM live con -snapshot (idempotente)
scripts/dev-vm deploy                 # build host + 9p + install/restart guest
scripts/dev-vm capture                # out/dev-<ts>.png por HMP screendump
scripts/dev-vm status                 # PIDs/puertos (no modifica nada)
scripts/dev-vm reset                  # stop + start: snapshot limpio
scripts/dev-vm stop
```

`deploy` hace, en este orden:

1. `cmake -S packages/shell/nimbus-bar -B /tmp/nimbus-dev-build` + build.
2. Copia el binario a `~/.cache/nimbusshell-vm/share/dev/nimbus-bar`.
3. Genera `~/.cache/nimbusshell-vm/share/dev/deploy.sh` con el md5 esperado.
4. Si SSH :2228 responde, monta el 9p en `/mnt/hostshare`, instala en
   `/usr/local/bin/nimbus-bar` y hace `systemctl --user restart nimbus-bar`.
5. **Solo declara éxito** si el guest imprime `DEPLOY_OK md5=<host>` y el
   md5 de `/usr/local/bin/nimbus-bar` coincide con el del host. Copiar no es
   desplegar.

`deploy` solo escribe por SSH si la VM propia está viva en su PIDFILE; si el
puerto :2228 responde pero no hay `start` de este script, se niega para no
desplegar en la VM de otro agente. Si SSH no está disponible, deja el artefacto
y el script y sale con código 3 (no desplegado). En el guest (consola/VNC):

```bash
sudo mkdir -p /mnt/hostshare
sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt/hostshare
sh /mnt/hostshare/dev/deploy.sh      # exige md5 y reinicia nimbus-bar
```

**Lento — ISO completa** (solo cuando el cambio no se puede probar en live):

- instalador Calamares, particionado, `greetd`/SDDM, drivers, `mkarchiso`,
  paquetes del sistema, servicios de arranque, o cualquier cosa que deba
  sobrevivir a un reinicio. Para eso: `iso/build-iso.sh` y el flujo de
  aceptación instalada; no es este documento.

## Captura y evidencia

`capture` usa el HMP y los helpers del harness
(`~/.cache/nimbusshell-vm/hmp.py` y `ppm2png.py`). Salida por defecto:
`out/dev-<YYYYmmddTHHMMSS>.png` (en la worktree; `out/` no se commitea).

```bash
scripts/dev-vm capture                       # out/dev-....png
scripts/dev-vm capture docs/plans/evidence/mi-captura.png
```

Si el HMP no responde pero SSH :2228 está arriba, intenta la alternativa
`spectacle -b -n -o` dentro del guest y copia el PNG por el 9p. Si tampoco,
falla con la pista de `doctor` (no genera una captura vacía "de mentira").

## Desplegar Glass una vez en el guest

Glass es un plugin binario de KWin, no va dentro de `nimbus-bar`; se instala
una vez **por arranque del live** (el snapshot lo descarta). En el host, con
el pin/receta de `docs/plans/evidence/F11-T02-glass-spike.md`:

```bash
# ECM + plugin en prefijos temporales (no toca /usr del host)
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
```

Publica los `.so` en el 9p y instálalos en el guest:

```bash
mkdir -p ~/.cache/nimbusshell-vm/share/dev/glass
cp -a /tmp/glass-prefix/lib/plugins/kwin/effects/plugins/glass.so \
      /tmp/glass-prefix/lib/plugins/kwin/effects/configs/kwin_glass_config.so \
      ~/.cache/nimbusshell-vm/share/dev/glass/
```

En el guest (consola/VNC o SSH):

```bash
sudo install -Dm755 /mnt/hostshare/dev/glass/glass.so \
  /usr/lib/qt6/plugins/kwin/effects/plugins/glass.so
sudo install -Dm755 /mnt/hostshare/dev/glass/kwin_glass_config.so \
  /usr/lib/qt6/plugins/kwin/effects/configs/kwin_glass_config.so
# kwinrc: blur/translucency stock OFF, glass ON; grupo [Effect-blurplus]
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key glassEnabled true
# Refracción suave ya validada en el spike:
kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength 6.0
kwriteconfig6 --file kwinrc --group Effect-blurplus --key PhysicallyBasedRefraction true
qdbus6 org.kde.KWin /Effects reconfigureEffect glass 2>/dev/null || true
```

Si el efecto no aparece, reinicia la sesión/VM (snapshot): KWin solo carga
plugins nuevos al arrancar. Verifica en `journalctl --user -u
plasma-kwin_wayland` y en `kwinrc` que `glassEnabled=true`.

## Paralelismo sin pisarse

- **Host build + guest capture**: el build CMake corre en el host y la
  captura habla con QEMU por HMP; se pueden lanzar a la vez (CPU vs. VM).
  No ejecutes dos `deploy` a la vez sobre el mismo `share/dev/`: el artefacto
  y `deploy.sh` son únicos.
- **Dos agentes**: los valores por defecto (5908/2228/dev-vm.sock) son de
  **una** VM. Para una segunda, usa overrides y un `STATE_DIR` distinto:
  `NIMBUS_DEV_VNC_DISPLAY=18 NIMBUS_DEV_SSH_PORT=2238
  NIMBUS_DEV_HMP_SOCK=/tmp/opencode/dev-vm-b.sock
  NIMBUS_DEV_STATE_DIR=/tmp/opencode/dev-vm-b`. Nunca 5907/2227 ni
  `target.sock` (out15).
- `doctor` es de solo lectura y se puede correr en paralelo; informa
  `[BLOQ]` si otro agente tiene los puertos/socket y no toca nada.

## Riesgos conocidos (y cómo los trata el script)

- **Snapshot**: cualquier cambio del guest (binario en `/usr/local/bin`,
  plugins, configuración) se pierde al `stop`/`reset`. El 9p sí persiste;
  por eso `deploy` y Glass viven en `share/dev/` y se reaplican por arranque.
- **9p y permisos**: se monta con `security_model=none`; el guest escribe
  como el usuario del host. `sudo` en el guest para instalar en `/usr/local`
  es obligatorio. Si el share no es escribible o el montaje falla, `deploy`
  lo dice y no simula éxito.
- **SSH ausente**: el live puede no tener SSH listo (red/servicio). `deploy`
  publica igualmente el artefacto y `deploy.sh`, sale 3 y explica la orden
  manual; no hay `DEPLOY_OK` sin verificación real.
- **`sudo -n`**: el live trae NOPASSWD; en un sistema instalado puede pedir
  clave y el script guest falla con mensaje (no se queda colgado).
- **RAM**: la VM pide 3G. `doctor` avisa si `MemAvailable` es justo; con
  varias VMs/ISO a la vez puede no arrancar.
- **VNC/SSH solo loopback**: VNC en `127.0.0.1:5908` y hostfwd SSH en
  `127.0.0.1:2228`; no se expone en la LAN.
- **Nunca matar por patrón**: `stop` verifica `/proc/<pid>/cmdline`; si el
  PIDFILE no es de `nimbus-dev` con su socket, se niega. `doctor` informa de
  los PID ajenos sin señalizarlos.

## Diagnóstico

```bash
scripts/dev-vm doctor        # qemu, ISO, helpers, RAM, puertos, out15
scripts/dev-vm status        # 0 si corre; 3 si está parada
scripts/dev-vm stop          # idempotente: sin PIDFILE propio, no hace nada
```

Códigos: `doctor` 0 = listo, 1 = falta algo, 2 = listo pero bloqueado por
otra VM/agente (puertos/socket); `deploy` 0 = verificado, 3 = artefacto
publicado pero no desplegado/confirmado.
