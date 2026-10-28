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

## Cola conocida (backlog vivo en `.agent_roadmap.md`)

1. M2 sistema único de radios: M2.1 placa WindowBar a 15px ✅ (paridad Tahoe R8 con píldora perfecta). M2.2/M5.1 AboutApp.qml ✅ (radio diálogo 12px + semáforos 12px estándar comunitario R9). Siguiente: M6 OSD brillo / NTP reloj.
2. Genie al minimizar (hoy corte brusco al shelf + SUPER+M).
3. Transparencia de barra Tahoe (hoy blur 0.45) + tintes del Dock.
4. Mission Control real (switcher actual es fallback; hyprexpo rechazado).
5. Menú global D-Bus (descartado V1; entradas falsas eliminadas).
6. Nits: M6 start-hyprland completado (aviso watchdog resuelto en TTY), reloj VM, OSD brillo.
7. Upstream: vigilar PR #35; push de PR #37 rebaseado cuando se ordene.

## Dependencias de NimbusOS (NO hacer aquí)

Instalador Calamares, greetd/login, drivers, kernel, repo `[nimbus]`, temas
GRUB/Plymouth. Van en la ISO; aquí solo se documenta el contrato.
