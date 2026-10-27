# Estado — NimbusShell

Actualizado: 2026-10-27. Rama: `main`.

## Qué hay (v1)

- `install.sh` idempotente con `--check` (en host sin desplegar el drift es total; ref. VM CachyOS: CHECK ROJO con 64 oficiales + 5 AUR + 111 dotfiles + 12 binarios FALTA).
- 106 paquetes oficiales + 5 AUR, dotfiles 1:1 con NimbusOS (cero drift salvo excepciones documentadas en README).
- Sesión Hyprland Lua canónica, hyprbars nativo, no_bar pamac/nautilus/firefox/MacShell (solo sesión Lua; fallback `.conf` con doble barra documentada), verde=maximizar, Spaces, Launchpad, switcher unificado.

## Objetivo

Paridad macOS 1:1 en comportamiento y apariencia (ver AGENTS.md: bucle audita→implementa→verifica-con-captura→commitea).

## Cola conocida (de las auditorías NimbusOS, validar aquí)

1. Mission Control real (switcher actual es fallback; hyprexpo rechazado).
2. Menú global D-Bus (descartado V1; entradas falsas eliminadas).
3. Minimizar con retorno genie al icono (hoy: shelf + SUPER+M).
4. Reloj en español (requiere locale + `lang/es.js` upstream).
5. Exposé/Show-desktop por gesto, Hide (`SUPER+H` existe), mosaico por arrastre.
6. Capturas estilo Mac (HECHO `nimbus-screenshot` + binds `SUPER+SHIFT+3/4/5` (R4); PENDIENTE solo panel con temporizador estilo Mac).
7. Spotlight con ficheros/calculadora/diccionario por defecto.

## Dependencias de NimbusOS (NO hacer aquí)

Instalador Calamares, greetd/login, drivers, kernel, repo `[nimbus]`, temas GRUB/Plymouth. Van en la ISO; aquí solo se documenta el contrato (qué espera el escritorio del sistema).
