# Estado — NimbusShell

Actualizado: **2026-11-02**. Rama de trabajo: `plasma-migration`.
Documento maestro para continuar: **`docs/SESSION-2026-11-02-HANDOFF.md`**.

## Objetivo

UI/UX **1:1 con macOS Tahoe** sobre KDE Plasma 6.8.2 Wayland, con pruebas
reales (nested/VM/PC) y capturas. Sin activos propietarios de Apple. Ledger
real: **60/112 (54,3 %)**; no inflar cierres sin evidencia.

## Estado en una frase

La barra, menú, Control Center, calendario y notificaciones están rediseñados
con blur/Glass en nested; la ISO out16 se construyó y arranca hasta SDDM/
Plasma, pero **Calamares no se dibuja en QEMU** y **Glass no está empaquetado**
en la ISO. El PC secundario (Windows) aún no está instalado; PXE por Wi-Fi y
SD fallaron; queda GRUB2Win. Nada está aceptado en hardware real.

## Qué está verde

- `scripts/ci.sh` VERDE, `test_presets.sh` VERDE, calendario 9/9, qml-root 7/7.
- Barra 24 px multi-monitor; barra translúcida 0.18/0.25.
- Menú 248×299 con Glass, iconos de línea, separadores y overlay corregido.
- CC 304/292 px, cápsulas 140×64, badges blancos, círculos 64, sliders.
- Calendario 300×368 sin eventos falsos.
- Notificaciones 360 px, icono 38, radio 18, acciones.
- Blur real de compositor en barra/CC; Glass (refracción) en spike nested.
- Loop dev sin ISO (`scripts/dev-vm`), `--qml-root`, `scripts/dev-remote`.
- ISO out16 con SHA256 verificado y arranque UEFI hasta SDDM/Plasma.

## Qué falta / duele

- Calamares de la ISO no renderiza en QEMU; no validar instalación aún.
- Glass no empaquetado ni validado en GPU/PC.
- PC secundario sin instalar; GRUB2Win pendiente.
- Dock/Krema, notificaciones FDO reales, acciones reales del menú y toggles CC.
- F3-T12 golden tautológico; F5-T06/T08/F7-T10 sin 1:1.
- fps, Reduce Transparency, accesibilidad y aceptación en VM/PC.

## Dónde mirar

- `docs/SESSION-2026-11-02-HANDOFF.md` — **handoff maestro**.
- `docs/superpowers/plans/2026-10-31-plasma-migration.md` — ledger y tareas.
- `docs/plans/evidence/` — evidencia canónica (226 ficheros).
- `docs/INSTALL-SECONDARY-PC.md` — instalación y control SSH.
- `docs/BOOT-WITHOUT-USB.md` — ISO/GRUB2Win/PXE (qué falló).
- `docs/DEV-VM-WORKFLOW.md`, `docs/DEV-QML-ROOT.md` — loops de desarrollo.
- `docs/design/liquid-glass-research.md` — Glass y arquitectura.
- Histórico Hyprland: `docs/legacy/ESTADO-2026-10-29.md` y `docs/HANDOFF.md`.

## Reglas que no cambian

`AGENTS.md` sigue mandando (sin root, sin activos Apple, evidencia real,
backup, sin `CTRL-*` nuevos, Rulings de una línea). La pila actual es Plasma;
los comandos Hyprland de `AGENTS.md`/`HANDOFF.md` son **históricos**.
