# Evidencia — loop live sin SSH (`scripts/dev-vm`)

Fecha: 2026-11-02. Worktree `NimbusShell-devvm`, rama `feat/dev-vm`.
Host: QEMU/KVM, ISO live `nimbusos.iso`, guest root en tty1 con
`startplasma-wayland`. **Sin sshd** (2228 solo hostfwd), 9p montado en `/mnt`.

> Nota de continuidad: la VM indicada (PID 409174) murió al reiniciarse el
> proceso del agente; `scripts/dev-vm reset` levantó una nueva (PID 16587) y
> el loop completo se validó desde cero. out15 (PID 299775) ya no estaba
> corriendo; **no se tocó** en ningún momento (5907/2227/target.sock intactos
> por contrato).

## 1. Sintaxis y lint

```bash
$ bash -n scripts/dev-vm
exit=0
$ shellcheck -S warning scripts/dev-vm
exit=0
$ sh -n ~/.cache/nimbusshell-vm/share/dev/agent.sh
exit=0
```

## 2. Cold boot: reset + agente + Plasma (PASS)

```bash
$ scripts/dev-vm reset
[dev-vm] reset: parando VM propia y arrancando de nuevo (ISO/$SHARE intactos)
[dev-vm] parando nimbus-dev (PID 14407) por HMP
[dev-vm] dev-vm parada
[dev-vm] arrancando nimbus-dev: ISO=.../nimbusos.iso VNC=:5908 SSH=2228 HMP=.../dev-vm.sock
[dev-vm] HMP listo; esperando 15s a que el live llegue a tty1
[dev-vm] 9p montado en /mnt; lanzando agente y Plasma
[dev-vm] agente vivo: 161fb37db6382ce01cf9b4d1715e57cb
[dev-vm] dev-vm lista (PID 16587). VNC 127.0.0.1:5908 · HMP .../dev-vm.sock · 9p /mnt
exit=0
```

`start` teclea por HMP en tty1; antes de los símbolos ejecuta `loadkeys us`
(el keymap del live era es/latam y corrompía `/`, `-`, `=`, `|`). Sin ese paso
el comando de montaje quedaba como
`mountpoint 'q -mnt CC mount 't 9p ...` y no aparecía el centinela.

```bash
$ cat ~/.cache/nimbusshell-vm/share/dev/agent.log
2026-11-02T14:24:44+00:00 agent: inicio (pid 953)
2026-11-02T14:24:50+00:00 agent: wayland listo: /run/user/0/wayland-1
2026-11-02T14:24:51+00:00 agent: bar lanzada pid=1692 args=[--open-cc] md5=161fb37...
```

## 3. Deploy real del binario actual (PASS)

```bash
$ scripts/dev-vm deploy --open-cc
[dev-vm] compilando nimbus-bar
[100%] Built target nimbus-bar
[dev-vm] artefacto: ~/.cache/nimbusshell-vm/share/dev/nimbus-bar (md5 161fb37db6382ce01cf9b4d1715e57cb)
[dev-vm] args:      [--open-cc]
[dev-vm] DEPLOY OK 9p: deployed.md5=161fb37db6382ce01cf9b4d1715e57cb, bar.pid=1692, args=[--open-cc]
exit=0
```

Verificación cruzada:

```bash
$ md5sum ~/.cache/nimbusshell-vm/share/dev/nimbus-bar
161fb37db6382ce01cf9b4d1715e57cb  .../share/dev/nimbus-bar
$ cat ~/.cache/nimbusshell-vm/share/dev/deployed.md5
161fb37db6382ce01cf9b4d1715e57cb
$ cat ~/.cache/nimbusshell-vm/share/dev/args
--open-cc
$ cat ~/.cache/nimbusshell-vm/share/dev/bar.pid
1692
```

En el primer deploy (antes del reset), el agente sí detectó el cambio y
relanzó: `cambio de binario/args; reinicio` → `bar lanzada pid=3261
args=[--open-cc] md5=161fb37...`. El binario del verifier (`7e9eba...`) fue
sustituido por el build actual (`161fb37...`).

## 4. Captura real

```bash
$ scripts/dev-vm capture docs/plans/evidence/DEV-VM-LOOP.png
[dev-vm] captura HMP: .../docs/plans/evidence/DEV-VM-LOOP.png (776239 bytes)
$ file docs/plans/evidence/DEV-VM-LOOP.png
PNG image data, 1280 x 800, 8-bit/color RGB, non-interlaced
```

La imagen muestra la barra superior Nimbus y el **Control Center abierto**
(`--open-cc`) sobre Plasma. `bar.log` registra `nimbus-cc geom=304x450`,
`nimbus-menu geom=248x299`, etc.; el log también dice
`blur compositor activo=0` (Glass/blur no está activo en esta VM; no es un
fallo del loop).

## 5. `doctor` y `status` (PASS)

```bash
$ scripts/dev-vm doctor
...
[live root / 9p / SSH]
  [OK]   live root: autologin tty1 + startplasma-wayland (sin systemd user)
  [OK]   9p montado en /mnt (agente vivo, deployed.md5 161fb37...)
  [OK]   sin sshd en :2228 (live: loop 9p+HMP, no es fallo)
[RAM]
  [OK]   VM dev-vm ya arrancada (PID 16587); 3G ya reservados
[puertos y sockets]
  [OK]   VNC :5908 en uso por dev-vm (PID 16587)
  [OK]   SSH hostfwd :2228 en uso por dev-vm (PID 16587)
  [OK]   HMP vivo y pertenece a dev-vm (PID 16587)
[out15 — no se toca]
  [OK]   out15 (PID 299775) no está corriendo; dev-vm no la toca
[resultado]
  PASS: 0 aviso(s); start puede arrancar/adoptar la VM
exit=0

$ scripts/dev-vm status
VM: nimbus-dev (sí) PID 16587
SSH: 127.0.0.1:2228 (hostfwd)   sshd guest: ausente (live: 9p+HMP)
agente: vivo (heartbeat) md5 161fb37...
bar.pid: 1692
deployed: 161fb37...
exit=0
```

## Límites honestos

- No se instaló Glass en esta VM: la captura prueba barra + CC, no refracción;
  `bar.log` confirma `blur compositor activo=0`. La receta de Glass queda en
  `docs/DEV-VM-WORKFLOW.md` (una vez por arranque; el snapshot la descarta).
- El tecleo HMP funciona cuando el foco está en tty1 (cold boot) o en un
  Konsole de la sesión. Si Plasma ya corre sin agente y el foco está en otra
  ventana, `start` no puede garantizar el foco; imprime el comando manual
  exacto para tty1/Konsole.
- La primera prueba con OVMF cayó en el setup de firmware (las teclas durante
  el boot lo abrieron). El default pasó a SeaBIOS, que es el camino validado;
  OVMF queda opt-in con `NIMBUS_DEV_OVMF=1`.
- `reset` se probó completo (stop + arranque + agente + Plasma). No se probó
  el fallback SSH (el live no tiene sshd); queda para una VM instalada.
- out15 no se señalizó en ningún momento; su PID ya no existía al terminar,
  pero el script solo habla con el PID de su propio `dev-vm-state/pid`.
