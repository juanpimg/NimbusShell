# AGENTS.md — NimbusShell (reglas para sesiones de IA)

Lee esto antes de tocar nada. Proyecto en español; responde y documenta en español.

## Fuente de verdad (Ruling, no bifurcar)

1. **Los dotfiles canónicos viven AQUÍ** (`dotfiles/`). `nimbus-overlay/etc/skel`
   de NimbusOS se genera DESDE este repo en el futuro (una sola dirección:
   NimbusShell → NimbusOS), nunca al revés a mano. Si cambias un dotfile aquí,
   abre el port correspondiente en NimbusOS; si viene de NimbusOS, porta aquí
   primero y genera hacia allí.
2. **Excepciones documentadas, no silenciosas:** `diff -rq` entre `dotfiles/` y
   el skel de NimbusOS debe dar cero salvo la lista del README (launcher ISO,
   wrappers a `.local/bin`, fondo en `assets/`). Toda divergencia nueva exige
   Ruling de 1 línea en el README.
3. **QML MacShell vendoreado intacto** (filosofía anti-fork): no reescribir
   upstream; parches mínimos documentados como `NimbusOS Ruling` con propuesta
   aguas arriba.

## Comandos (memorízalos)

4. `bash -n install.sh` + `shellcheck -S warning install.sh` (cero warnings)
   antes de cualquier commit que toque el instalador.
5. `./install.sh --check` en seco: solo lectura, sin sudo, sin red. Nunca
   instales paquetes "para probar" en el host de desarrollo salvo orden
   explícita; el `--check` es la verificación por defecto.
6. `diff -rq` dotfiles vs skel NimbusOS tras cada cambio de dotfiles.

## Reglas duras

7. **`set -u`, sin `set -e` ciego:** cada fallo con mensaje accionable; exit 1
   con contexto (qué faltó, cómo reintentarlo). Idempotencia real: re-ejecutar
   no duplica, no borra, no pregunta dos veces.
8. **Nunca root, nunca borrar a ciegas:** el instalador aborta como root (el
   AUR no compila como root); todo lo sobrescrito va a
   `~/.config/nimbusshell-backup-*` y nada borra backups ajenos. Sin binds
   `CTRL-*` nuevos en configs Hyprland (Ctrl intacto para el usuario) y sintaxis
   Hyprland 0.56 vigente (`--verify-config`, sesión Lua canónica).
