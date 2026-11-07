# Índice de documentación — NimbusShell (2026-11-07)

## Para continuar en una sesión limpia

1. **`docs/SESSION-2026-11-04-HANDOFF.md`** — estado real, entorno, qué
   funciona, qué falla, siguientes pasos y trampas.
2. `ESTADO.md` — resumen corto y puntero al handoff.
3. `docs/superpowers/plans/2026-10-31-plasma-migration.md` — ledger y tareas
   (**103/112, 93.0%**; no inflar).
4. `AGENTS.md` — reglas duras (la nota superior aclara la pila Plasma).
5. `docs/SKEL-SYNC.md` — divergencia pendiente entre `dotfiles/` y el skel de
   NimbusOS (dirección única NimbusShell → NimbusOS).
6. `docs/SESSION-2026-11-07-FIXES.md` — reparaciones de coherencia, CI y
   despliegue de esta sesión.

## Diseño y decisiones

- `docs/design/tahoe-design-contract.md` — contrato visual/medidas.
- `docs/design/liquid-glass-research.md` — Glass, blur, refracción y
  arquitectura.
- `docs/design/agent-desktop-eval.md` — por qué no se integra agent-desktop.
- `docs/legacy/ESTADO-2026-10-29.md` — estado histórico Hyprland.

## Evidencia

- `docs/plans/evidence/` — evidencia canónica por fase (F0–F11).
- `docs/plans/evidence/README.md` — política y nomenclatura.
- `docs/plans/evidence/AUDIT-2026-11-02.md` — auditoría y cierre de sesión.
- `docs/plans/evidence/F11-T02-blur.md` — blur real de compositor.
- `docs/plans/evidence/F11-T02-glass-spike.md` — refracción Glass.
- `docs/plans/evidence/F3-T03-bar-transparency.md` — barra translúcida.
- `docs/plans/evidence/F3-T04-menu-glass.md` — menú Glass + overlay.
- `docs/plans/evidence/F3-T05-tahoe-cc.md` — Control Center 292.
- `docs/plans/evidence/F3-T08-calendar-tahoe.md` — calendario 300×368.
- `docs/plans/evidence/F3-T09-notifications-tahoe.md` — banner.
- `docs/plans/evidence/DEV-VM-LOOP.png` — loop dev-vm.

## Entornos y despliegue

- `docs/DEV-VM-WORKFLOW.md` — loop live sin ISO (9p+HMP+agente).
- `docs/DEV-QML-ROOT.md` — QML desde disco sin rebuild.
- `docs/INSTALL-SECONDARY-PC.md` — instalación y control SSH del PC.
- `docs/BOOT-WITHOUT-USB.md` — ISO, PXE, SD y GRUB2Win (qué falló).
- `packaging/glass/README.md` — receta Glass GPL y kwinrc.
- `docs/i18n.md` — traducciones.
- `docs/HANDOFF.md` — histórico Hyprland/MacShell (no aplica a Plasma).
- `docs/SESSION-2026-11-02-HANDOFF.md` — handoff anterior (histórico).

## Scripts clave

- `scripts/ci.sh` — gate (lint, tests, i18n, packaging).
- `scripts/apply-theme` — tema Tahoe (color scheme, Kvantum, Aurorae).
- `scripts/nimbus-bar-preset` — presets de barra.
- `scripts/nimbus-dock` — preferencias del Dock Krema.
- `scripts/dev-vm` — VM live dev (VNC 5908/9p/HMP).
- `scripts/dev-remote` — deploy/captura por SSH en PC instalado.
- `scripts/nimbus-control` — deja el PC controlable (sshd/clave/autologin).
- `scripts/nimbus-pxe` — proxy DHCP/PXE (solo con Ethernet en el host).
- `scripts/nimbus-i18n` — extract/check de cadenas.

## Tests

- `tests/bar/test_presets.sh` — presets/binding/orden.
- `tests/bar/test_qml_root.sh` — `--qml-root`.
- `tests/theme/test_apply_theme.sh` — tema, variantes, Aurorae y revert.
- `tests/theme/test_themes_deploy.sh` — `themes_deploy`/`themes_check` con HOME temporal.
- `tests/theme/test_nimbus_theme.sh` — cambio claro/oscuro con decoración Aurorae.
- `tests/apps/test_apps_deploy.sh` — apps de script 1:1 en `~/.local/bin`.
- `tests/install/test_deploy_home.sh` — despliegue completo en HOME aislado.
- `tests/docs/test_docs_consistency.sh` — handoff y ledger sin drift.
- `tests/qml/tst_calendar.qml` — calendario (9/9).
- `tests/vm/nested-bar.sh` — harness nested (barra/CC/menú/calendario/OSD).
- `tests/vm/*` — aceptación VM/ISO histórica.
