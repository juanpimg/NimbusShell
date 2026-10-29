# AGENTS.md — NimbusShell (reglas para sesiones de IA)

Lee esto antes de tocar nada. Proyecto en español; responde y documenta en español.

## Objetivo (no negociable)

Clonar la experiencia macOS **Tahoe 1:1** en comportamiento y apariencia:
ventanas con semáforos nativos, Spaces, Mission Control, Spotlight, Launchpad,
Dock, menús globales, atajos universales. Todo lo que se vea o se comporte
distinto de un Mac real es un bug con nombre y prioridad. **Todas las
pruebas son reales en VM** (QEMU/KVM + capturas + pointer lab, ver
`docs/HANDOFF.md`): sin evidencia de la VM no hay "listo". Sin activos
propietarios de Apple (nada de logos, SF, wallpapers o sonidos suyos):
equivalencia con arte propio y libre (Inter, logo N, Sequoia NPS).

## Bucle de iteración (siempre igual)

1. **Audita** contra macOS real (cita fuente: Apple Support/HIG o captura).
2. **Implementa** lo mínimo que cierre el gap (preferencia: config > script >
   parche QML documentado; nunca reescribir upstream).
3. **Verifica con evidencia**: `--check` en seco + `hyprland --verify-config`
   con HOME temporal + **captura de pantalla** del antes/después (VM o
   sesión anidada). Sin captura no hay "listo".
4. **Commitea** (`feat|fix|docs(scope): ...`) y documenta la Ruling si diverge.
5. Si algo exige ISO (Calamares, greetd, drivers), NO lo hagas aquí: abre el
   port en NimbusOS y documenta la dependencia.

## Fuente de verdad (Ruling, no bifurcar)

1. **Los dotfiles canónicos viven AQUÍ** (`dotfiles/`). `nimbus-overlay/etc/skel`
   de NimbusOS se genera DESDE este repo en el futuro (una sola dirección:
   NimbusShell → NimbusOS), nunca al revés a mano. Si cambias un dotfile aquí,
   abre el port correspondiente en NimbusOS; si viene de NimbusOS, porta aquí
   primero y genera hacia allí.
2. **Excepciones documentadas, no silenciosas:** `diff -rq` entre `dotfiles/` y
   el skel de NimbusOS debe dar cero salvo la lista del README (launcher ISO,
   wrappers `macshell*`/`nimbus-*` en `.local/bin`, fondo y logo en `assets/`
   — R1-R5 del README). Toda divergencia nueva exige
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

## Lecciones operativas M1 (2026-10-28, vinculantes)

9. **Verificar la CARGA, no los bytes:** tras desplegar QML al guest,
   `pkill -9 -f 'qs -c MacShell'` (lo relanza `macshell-start`) y confirmar
   en `qs -c MacShell log` (un `property` duplicado rompe la carga en
   silencio; el md5 igual no prueba nada).
10. **Despliegue con eco + md5:** `curl` con `-s` oculta 404 (exit 0 igual);
    exigir eco textual (`DEPLOY_OK`) y `md5sum` guest==host. Detalle en
    `docs/HANDOFF.md` (trampas de `sendstr`, `$?`, `hyprctl reload` que
    pierde `add_button`, `keyword` inexistente en Lua, calibración ×2.0).
11. **Evidencia posicional cerrada:** medir coordenadas SIEMPRE en la captura
    actual (detección de píxeles, `hyprctl cursorpos`); las ventanas se
    recolocan entre sesiones y el ojo falla por 30px.
