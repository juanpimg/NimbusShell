# Estado — NimbusShell

Actualizado: 2026-10-28 noche (pausa documentada, lista para retomar;
ver `docs/HANDOFF.md`). Rama: `main` (~120 commits por delante de
`origin/main`, **sin push**: requiere orden explícita).

## Qué hay (v1 + octubre)

- `install.sh` idempotente con `--check` (verificado en VM Arch vanilla real:
  NIMBUSSHELL OK EXIT:0, [8/8] todo [OK]; `--check` posterior solo marca el
  SKIP conocido de `verify-config` por el plugin hyprbars sin sesión).
- 106 paquetes oficiales + 6 AUR, dotfiles 1:1 con el repo, sesión Hyprland
  Lua canónica (+ `.conf` fallback), overlay WindowBar VIVO por defecto
  (semáforos 12px + glifo solo al hover + título; hyprbars como tira).
- Español completo (`lang/es.js`, 584→638 claves con el reconciliado upstream).
- Marca propia (logo N, fondo Sequoia NPS, sonidos generados): cero activos Apple.
- Colaboración aguas arriba: fork `juanpimg/MacShell`.
  * PRs **#36, #38, #39, #40 MERGED** en `0-ss/MacShell` (es.js, ru, clockApp, IPC).
  * PR **#35 OPEN** (sleep-notify).
  * PR **#37 rebaseado localmente** en `upstream-patches/windowbar-hover-symbols-rebased.patch` (apply--check PASS sobre 0.4.3).

## Objetivo

Paridad macOS Tahoe 1:1 en comportamiento y apariencia (ver AGENTS.md: bucle
audita→implementa→verifica-con-captura→commitea). Plan vigente:
`docs/superpowers/plans/2026-10-28-tahoe-11.md` (M1 overlay ✅ → M2 radios).

## Hitos del Plan Tahoe 1:1

- **M1 Overlay WindowBar**: COMPLETADO ✅ (instanciado en `shell.qml` + `windowBar:true`, hyprbars como tira nativa, semáforos limpios, R7).
- **M2 Sistema único de radios**: COMPLETADO ✅ (unificación Tahoe: M2.1 placa 15px R8, M2.2 AboutApp 12px R9, M2.4 paneles 24px R11, M2.3 widgets de escritorio 24px R8).
- **M3 Animación de minimización y Genie Shader**: COMPLETADO ✅ (`specialWorkspace slidevert` + `windowsMove slide` a 60fps con curva nimbus en `hyprland.lua` y `hyprland.conf`; instanciado y conectado `MinimizeFx.qml` Genie Shader `genie.vert.qsb` GridMesh 6x64 en `shell.qml`, `WindowBar.qml` y `MacDock.qml` con cálculo analítico `targetRectForToplevel()` y restauración inversa con foco; IPCs expuestos y `nimbus-minimize-toggle` integrado; CHECK VERDE 100%, R12).
- **M4 Transparencia de barra Tahoe**: COMPLETADO ✅ (`barBgOpacity: 0.10` en paridad canónica Tahoe y slider `Bar background` en `MacDock.qml:1719`, R11).
- **M5 Semáforos unificados**: COMPLETADO ✅ (estándar comunitario 12px nativo sin escala 0.93 + gris inactivo Apple SystemGray al 35% #598E8E93 en toda la shell, R9).
- **M6 Integración y NTP**: COMPLETADO ✅ (start-hyprland en TTY, OSD brillo -c backlight R10, `timedatectl set-ntp true` en install.sh y VM; CHECK VERDE 100%).
- **M7 Upstream MacShell**: PRs #36, #38, #39, #40 MERGED en `0-ss/MacShell` v0.4.3; PR #35 OPEN; PR #37 rebaseado localmente en `upstream-patches/windowbar-hover-symbols-rebased.patch` (apply--check PASS).

## Cola conocida (backlog vivo en `.agent_roadmap.md`)

1. Port a NimbusOS: sincronizar dotfiles M1–M6 con `nimbus-overlay/etc/skel` y actualizar `verify-macshell.sh`.
2. Tintes y concentricidad del Dock.
3. Mission Control real (switcher actual es fallback; hyprexpo rechazado).
4. Menú global D-Bus (descartado V1; entradas falsas eliminadas).
5. Upstream: vigilar PR #35; push de PR #37 rebaseado cuando se ordene.

## Dependencias de NimbusOS (NO hacer aquí)

Instalador Calamares, greetd/login, drivers, kernel, repo `[nimbus]`, temas
GRUB/Plymouth. Van en la ISO; aquí solo se documenta el contrato.
