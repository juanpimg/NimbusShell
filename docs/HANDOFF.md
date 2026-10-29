# HANDOFF — continuar NimbusShell en otra sesión/agente

Lee en este orden: `AGENTS.md` (reglas) → `ESTADO.md` (foto) →
`.agent_roadmap.md` (backlog vivo, manda lo último) →
`docs/superpowers/plans/2026-10-28-tahoe-11.md` (plan M1-M7 + pointer lab).

## Estado al pausar (2026-10-28 noche)

- Rama `main`, ~133 commits por delante de `origin/main`. **Sin push**
  (requiere orden explícita). `git status` limpio tras el commit de pausa.
- Hitos completados y verificados con evidencia visual en VM y `./install.sh --check` CHECK VERDE:
  * **M1 Overlay WindowBar**: vivo por defecto con semáforos limpios al hover y hyprbars como tira nativa (R6, R7).
  * **M2 Radios**: unificación total de radios (M2.1 placa 15px R8, M2.2 AboutApp 12px R9, M2.4 paneles 24px R11, M2.3 widgets de escritorio 24px R8).
  * **M3 Animación Minimizar & Genie Shader**: hojas de animación `specialWorkspace slidevert` y `windowsMove slide` a 60fps con curva nimbus; instanciado `MinimizeFx.qml` en `shell.qml` y `sharedHub.minimizeFx`, shader `genie.vert.qsb` GridMesh 6x64; minimización en `WindowBar.qml` con `no_anim: 1` durante el vuelo y supresión de doble imagen; cálculo analítico `targetRectForToplevel()` y restauración inversa fluida desde el shelf en `MacDock.qml`; IPCs `window.minimize` y `dock.restoreFirst`; script `nimbus-minimize-toggle` integrado; evidencias `m3_genie_midflight.png`, `m3_genie_minimized.png`, `m3_genie_restored.png` y `m3_genie_comparison.png` (R12).
  * **M4 Transparencia Barra**: `barBgOpacity: 0.10` canónico macOS Tahoe 1:1 y slider `Bar background` en MacDock.qml:1719 (R11).
  * **M5 Semáforos**: unificación a 12px nativo sin escala 0.93 + gris inactivo Apple SystemGray 35% #598E8E93 en toda la shell (R9).
  * **M6 Integración/NTP**: start-hyprland en TTY, OSD brillo -c backlight R10, `timedatectl set-ntp true` en install.sh y VM (CHECK VERDE 100%).
- Upstream: fork `juanpimg/MacShell`. Estado PRs en `0-ss/MacShell`:
  * PRs **#36, #38, #39, #40 MERGED** aguas arriba (es.js, ru, clockApp, IPC).
  * PR **#35 OPEN** (sleep-notify fallback).
  * PR **#37 rebaseado localmente** en `~/.cache/nimbusshell-vm/upstream-patches/windowbar-hover-symbols-rebased.patch`
    (validado con `git apply --check` sobre `main` 0.4.3; listo para push cuando se ordene).
  Parches + cuerpos EN respaldados en `~/.cache/nimbusshell-vm/upstream-patches/`
  (`/tmp` es tmpfs: NO usar `/tmp` para nada que deba sobrevivir un reinicio).
- Port a NimbusOS: COMPLETADO 100% CONVERGENTE (Ciclo 15 2026-10-29). Sincronizados 27 ficheros
  en `dotfiles/` hacia `NimbusOS/nimbus-overlay/etc/skel/` y `/usr/bin/`; `diff -rq` produce exactamente
  las 4 líneas canónicas documentadas en `README.md:53` (las 3 herramientas de `.local/bin` y `Desktop/`).
  `NimbusOS/scripts/verify-macshell.sh` actualizado a R6-R12 y verificado con PASS=298 FAIL=0.
  Commit atómico `a4b2ef7` en NimbusOS (sin push).

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

## Ciclo 16: Paridad 1:1 Titlebar macOS y Semáforos Incrustados
- **Geometría 1:1:** `WindowBar.qml` reposicionado en `x: w.wx + 13`, `y: w.wy - 28` y `height: 28`. Semáforos de 12px centrados verticalmente con 8px de margen superior e inferior dentro de la barra de `hyprbars`.
- **Canvas 100% despejado:** El contenido de la ventana (prompt de Kitty, etc.) no sufre solapamiento alguno.
- **Píldora artificial eliminada:** `Rectangle` contenedor de fondo fijado a `visible: false` (preservando `radius: 15` para compatibilidad de suite), descansando los semáforos directamente sobre el vidrio esmerilado.
- **Máscara estricta:** `mask: Region { item: lights }` permite que los clics y el arrastre en el resto de la barra sean procesados por `hyprbars` para el arrastre y doble-click de maximizado nativos.
- **Feed de Geometría Activado:** Resuelto el bug histórico de `winBarWantsGeo` en `shell.qml`, permitiendo que el poller `ipcPoll()` suministre `clients` a `WindowBar` incluso con la barra Tahoe opaca.
- **Exclusión CSD:** Omitidas ventanas con CSD nativo (`Nautilus`, `Firefox`, `Pamac`, modales).
- **Vídeo iOS (Ciclo 16):** [https://gofile.io/d/JTcK5rUs](https://gofile.io/d/JTcK5rUs) (`yuv420p`, `+faststart`, H.264 High 4.1).
- **Test suite NimbusOS:** `PASS=298 FAIL=0 SKIP=7`.

