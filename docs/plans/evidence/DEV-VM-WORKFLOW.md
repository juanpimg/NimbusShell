# Evidencia — workflow de VM de desarrollo (`scripts/dev-vm`)

Fecha: 2026-11-02. Worktree: `NimbusShell-devvm` (rama `feat/dev-vm`).
Entorno: host con QEMU/KVM; **otra VM live** (agente concurrente) ocupando
VNC 5908 / SSH 2228 / `dev-vm.sock` durante la verificación. Por orden
explícita **no se arrancó ninguna VM** y no se ejecutó `start`/`reset` reales.
La VM out15 (PID 299775, VNC 5907, SSH 2227) estaba viva y no se tocó.

## 1. Sintaxis y lint

```bash
$ bash -n scripts/dev-vm
exit=0

$ shellcheck -S warning scripts/dev-vm
exit=0
```

## 2. `doctor` en seco (no arranca la VM)

```bash
$ scripts/dev-vm doctor
== dev-vm doctor (solo lectura; no arranca la VM) ==
Contrato: VNC :5908 · SSH :2228 · HMP ~/.cache/nimbusshell-vm/dev-vm.sock · ISO .../nimbusos.iso

[host]
  [OK]   usuario no root
  [OK]   no usa VNC 5907, SSH 2227 ni target.sock (out15 intacta por contrato)

[dependencias]
  [OK]   QEMU: qemu-system-x86_64
  [OK]   Python (sondas/HMP): python3
  [OK]   CMake (deploy host): cmake
  [OK]   md5sum (deploy): md5sum
  [OK]   SSH (deploy/captura alternativa): ssh
  [OK]   setsid (SSH askpass): setsid
  [OK]   timeout (evita SSH colgado): timeout
  [OK]   /dev/kvm accesible

[activos]
  [OK]   ISO live: .../nimbusos.iso (2,3G)
  [OK]   share 9p: .../share
  [OK]   share escribible (deploy)
  [AVISO] sin artefacto previo en .../share/dev/nimbus-bar (normal antes del primer deploy)
  [OK]   helpers HMP: .../hmp.py + .../ppm2png.py
  [OK]   fuente nimbus-bar presente

[RAM]
  [BLOQ] RAM disponible insuficiente: 2.8 GiB; libera memoria o para otra VM (la VM pide 3G)

[puertos y sockets]
  [BLOQ] VNC :5908 OCUPADO por PID 409174 (otra VM/agente); dev-vm no lo mata. Espera o cambia el puerto
  [BLOQ] SSH :2228 OCUPADO por PID 409174 (otra VM/agente); dev-vm no lo mata. Espera o cambia el puerto
  [BLOQ] HMP .../dev-vm.sock vivo sin PIDFILE propio (otra VM/agente); dev-vm no lo toca
  [OK]   sin VM dev-vm propia arrancada
  [AVISO] serial .../dev-vm-serial.sock existe (viejo o en uso); start fallará si hay otra VM viva

[out15 — no se toca]
  [OK]   out15 viva (PID 299775, nimbus-target); dev-vm no la señala
  [OK]   out15 conserva VNC :5907 y SSH :2227

[resultado]
  FAIL: 1 faltante(s), 2 aviso(s), 3 bloqueo(s)
exit=1
```

El `[FALTA]` era la RAM (2.8 GiB < 3G) por la VM del otro agente. Tras
reclasificarla como bloqueo (no es una dependencia ausente), el mismo doctor
sale 2 con acción clara, sin arrancar ni tocar nada:

```bash
$ scripts/dev-vm doctor   # (tras ajuste)
[RAM]
  [BLOQ] RAM disponible insuficiente: 2.8 GiB; libera memoria o para otra VM (la VM pide 3G)
...
[resultado]
  LISTO con BLOQUEOS: 1 aviso(s), 1 bloqueo(s); start esperará a que se liberen
exit=2
```

Prueba del camino libre (puertos/socket alternativos, mismos defaults en el
contrato): `VNC :5918`, `SSH :2238`, HMP `/tmp/opencode/devvm-verify/dev-vm.sock`
→ todos `[OK]`, `HMP libre`, `sin VM dev-vm propia`; solo RAM bloquea (2.8 GiB).

## 3. `deploy`: build real en host + fallback sin SSH

Se ejecutó con `SHARE/BUILD/STATE` temporales y `SSH :2299` cerrado, para no
tocar la VM del otro agente ni el share compartido:

```bash
$ NIMBUS_DEV_SHARE=/tmp/opencode/devvm-verify/share \
  NIMBUS_DEV_ISO=~/.cache/nimbusshell-vm/share/nimbusos.iso \
  NIMBUS_DEV_BUILD=/tmp/opencode/devvm-verify/build \
  NIMBUS_DEV_STATE_DIR=/tmp/opencode/devvm-verify/state \
  NIMBUS_DEV_SSH_PORT=2299 scripts/dev-vm deploy

[dev-vm] configurando build host en /tmp/opencode/devvm-verify/build
[dev-vm] compilando nimbus-bar
[100%] Built target nimbus-bar
[dev-vm] artefacto listo: /tmp/opencode/devvm-verify/share/dev/nimbus-bar (md5 161fb37...)
[dev-vm] script guest:    /tmp/opencode/devvm-verify/share/dev/deploy.sh
[dev-vm] AVISO: SSH no escucha en 127.0.0.1:2299: NO se ha desplegado en el guest.
...
exit=3
```

Comprobaciones del artefacto y del script guest:

```bash
$ ls -l /tmp/opencode/devvm-verify/share/dev/
-rwxr-xr-x ... deploy.sh
-rwxr-xr-x ... nimbus-bar
$ md5sum /tmp/opencode/devvm-verify/share/dev/nimbus-bar
161fb37...  .../nimbus-bar
$ bash -n /tmp/opencode/devvm-verify/share/dev/deploy.sh && echo OK
OK
$ shellcheck -s sh -S warning /tmp/opencode/devvm-verify/share/dev/deploy.sh
exit=0
```

El `deploy.sh` generado exige `md5` del 9p contra el del host, instala con
`sudo -n`, verifica el md5 destino y hace `systemctl --user restart
nimbus-bar`; solo entonces imprime `DEPLOY_OK md5=<host>`. `deploy` exige ese
eco **y** el md5 para devolver 0. El código 3 del ensayo es el esperado
(sin SSH no se declara desplegado).

## 4. Guardrails (sin arrancar QEMU)

```bash
# HMP "ajeno" simulado con socat; puertos alternativos libres
$ scripts/dev-vm start
[dev-vm] ERROR: HMP /tmp/.../fake.sock está vivo pero no es de este PIDFILE
         (otra VM/agente). No se toca...
exit=1
PIDFILE_NO_CREADO=OK

# PIDFILE apuntando a PID 1: se niega en vez de señalizar
$ printf '1\n' > .../state/pid && scripts/dev-vm stop
[dev-vm] ERROR: el PID 1 del PIDFILE no es nimbus-dev en .../dev-vm.sock;
         no se señala...
exit=1

# stop idempotente sin VM propia
$ scripts/dev-vm stop
[dev-vm] no hay VM dev-vm arrancada por este script; nada que parar
exit=0
```

`status` con la VM ajena viva la marca explícitamente y no la toca:

```bash
$ scripts/dev-vm status
VM:          nimbus-dev (no)
VNC:         127.0.0.1:5908 (PID 409174, AJENA: no se toca)
SSH:         127.0.0.1:2228 (PID 409174, AJENA: no se toca)
HMP:         .../dev-vm.sock [vivo, AJENO: no se toca]
exit=3
```

## Límites de esta evidencia

- No se ejecutó `start`/`reset` reales ni se arrancó QEMU: la VM del agente
  concurrente estaba usando 5908/2228/`dev-vm.sock` y el encargo lo prohíbe.
- No hay captura `out/dev-*.png` porque implicaría leer la VM ajena o
  arrancar una propia; el camino HMP/`spectacle` queda implementado y
  `doctor` valida sus dependencias.
- No se ejecutó `deploy` contra un guest real (mismo motivo); sí se validó el
  build CMake real, la publicación del artefacto, el `deploy.sh` guest y el
  fallback sin SSH.
- La verificación con VM live (arranque, VNC, 9p, `DEPLOY_OK` real, captura)
  queda pendiente para cuando 5908/2228/`dev-vm.sock` estén libres y haya
  RAM suficiente; es el siguiente paso natural, no algo declarado aquí.
