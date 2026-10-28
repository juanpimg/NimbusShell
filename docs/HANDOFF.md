# HANDOFF — continuar NimbusShell en otra sesión/agente

Lee en este orden: `AGENTS.md` (reglas) → `ESTADO.md` (foto) →
`.agent_roadmap.md` (backlog vivo, manda lo último) →
`docs/superpowers/plans/2026-10-28-tahoe-11.md` (plan M1-M7 + pointer lab).

## Estado al pausar (2026-10-28 noche)

- Rama `main`, ~127 commits por delante de `origin/main`. **Sin push**
  (requiere orden explícita). `git status` limpio tras el commit de pausa.
- Último trabajo: M1 overlay WindowBar vivo (`d35f436` + docs) + fix verify-config hyprbars (`3619703`). SIGUIENTE: M2.
- Upstream: fork `juanpimg/MacShell`. Estado PRs en `0-ss/MacShell`:
  * PRs **#36, #38, #39, #40 MERGED** aguas arriba (es.js, ru, clockApp, IPC).
  * PR **#35 OPEN** (sleep-notify fallback).
  * PR **#37 rebaseado localmente** en `~/.cache/nimbusshell-vm/upstream-patches/windowbar-hover-symbols-rebased.patch`
    (validado con `git apply --check` sobre `main` 0.4.3; listo para push cuando se ordene).
  Parches + cuerpos EN respaldados en `~/.cache/nimbusshell-vm/upstream-patches/`
  (`/tmp` es tmpfs: NO usar `/tmp` para nada que deba sobrevivir un reinicio).
- Port pendiente a NimbusOS: 18 ficheros en `dotfiles/` (M1/Tahoe/ES) pendientes de sincronizar
  con `NimbusOS/nimbus-overlay/etc/skel/`. Exige actualizar `NimbusOS/scripts/verify-macshell.sh`
  (reemplazar aserciones obsoletas de "cero QML" por las Rulings R6/R7).

## VM de pruebas (disco persiste, todo lo demás es volátil)

- Disco: `~/.cache/nimbusshell-vm/disk-arch.qcow2` (sistema convergido).
- Lanzar: `~/.cache/nimbusshell-vm/run-arch-gtk.sh` (ventana nativa en el
  escritorio del usuario; la VM **muere al cerrar su ventana**, es normal).
- Credenciales guest: usuario `nimbus`, clave `nimbus2026`; entrar con
  `start-hyprland` tras login en TTY (evita el aviso de watchdog de Hyprland). Red SLIRP (guest→host `10.0.2.2:18088`).
- Servidor de staging: `bash ~/.cache/nimbusshell-vm/stage.sh` → imprime
  `TOKEN=…` nuevo (cada ejecución ROTA el token y el tarball). Último token
  conocido al pausar: `472b15e93fb23fe4` (si falla, re-stagear).
- Harness: `hmp.py` (screendump/sendkey/`info status`), `sendstr.py`
  (teclear), `ppm2png.py`. Atajos guest: `meta_l-t` = terminal (SUPER+T).

## Pointer lab (receta por arranque del guest)

1. `echo nimbus2026 | sudo -S pacman -S --noconfirm ydotool` (ya instalado
   en disco; solo si falta) + `sudo pkill ydotoold; sudo ydotoold … &`
   + `sudo chmod 666 /tmp/.ydotool_socket`.
2. Prefijo obligatorio: `YDOTOOL_SOCKET=/tmp/.ydotool_socket`.
3. Mover: aparcar `mousemove -x -2000 -y -2000`, luego
   `mousemove -x X/2 -y Y/2` (factor ×2.0 exacto), verificar SIEMPRE con
   `hyprctl cursorpos`. Clics NO actúan (solo movimiento+hover);
   workaround: `hyprctl dispatch …` / IPC para las acciones.

## Trampas que ya mordimos (no repetir)

- `sendstr`: escribe comandos SIMPLES (sin `|`, líneas <200 chars, eco de
  confirmación). `$?` lo expande el bash del HOST: medir exits en fichero.
- Despliegue a VM: exigir eco (`DEPLOY_OK`) + `md5sum` guest==host.
- Verificar la CARGA, no los bytes: `qs -c MacShell log` tras reiniciar
  (`pkill -9 -f 'qs -c MacShell'`, lo relanza `macshell-start`).
- Sesión Lua: `hyprctl reload` PIERDE los `add_button` (reinicio completo),
  `hyprctl keyword` no existe (solo fichero+reinicio).
- Duplicar un `property` QML rompe la carga en silencio (mirar `qs log`).
- Medir coordenadas SIEMPRE en la captura actual (detección de píxeles
  rojos puros); las ventanas se recolocan entre sesiones.
- `grep -c FALTA` cuenta también la línea resumen "ver [FALTA] arriba".

## Mapa rápido del repo

- `install.sh` + `packages.*` + `dotfiles/` (canónicos) + `assets/`.
- QML vendoreado en `dotfiles/.config/quickshell/MacShell/` (parches con
  `NimbusOS Ruling`, R1-R7 en README). Sesión Lua canónica + `.conf`.
- Rulings README: R6 glifos hover, R7 overlay ON + hyprbars como tira.
