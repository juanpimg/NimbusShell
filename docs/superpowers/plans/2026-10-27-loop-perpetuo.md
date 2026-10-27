# Bucle perpetuo NimbusShell — Plan de mejora continua

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mantener NimbusShell convergiendo a paridad macOS 1:1 sin regresiones, en vueltas atómicas verificadas, hasta orden de parada.

**Architecture:** Orquestador (sesión principal) audita por oleadas con subagentes `explore` de solo lectura en dominios disjuntos; integra UN hallazgo por vuelta con rojo-verde y commit semántico; las puertas mecánicas (`bash -n`, `shellcheck -S warning`, `luac -p`, `./install.sh --check`, harness de stubs, VM CachyOS) deciden cada cierre.

**Tech Stack:** bash (`set -u`, sin `set -e` ciego), Hyprland 0.56 (.conf fallback + Lua canónica), QML MacShell vendoreado, QEMU/KVM + HMP para evidencia en VM.

**Spec:** `AGENTS.md` (bucle audita→implementa→verifica-con-captura→commitea; responde en español), `README.md` (Rulings R1+), `.agent_roadmap.md` (backlog vivo).

## Global Constraints

- Sintaxis Hyprland 0.56 vigente; sesión Lua canónica, `.conf` fallback.
- Cero binds `CTRL-*` nuevos en configs Hyprland.
- Instalador nunca como root; lo sobrescrito va a `~/.config/nimbusshell-backup-*`; nada borra backups ajenos.
- `bash -n` + `shellcheck -S warning` (cero warnings) antes de cada commit que toque el instalador.
- QML MacShell vendoreado intacto: parches mínimos marcados `NimbusOS Ruling`, nunca reescribir upstream.
- Sin captura (VM o sesión anidada) no hay "listo"; sin red ni sudo en `--check`.
- Nunca instalar paquetes en el host de desarrollo para probar.

## Review Focus

- Paquete del manifest que no resuelve en vanilla (transacción única aborta todo): lo esperable es detectar con `pacman -Si` por repo + mover a AUR si `paru` lo resuelve.
- Check verde + drift real (verificación laxa): lo esperable es re-verificar lo desplegado en `[8/8]`; pin con stubs que fallen.
- Bind/regla que diverge entre `.conf` y Lua: lo esperable es tabla de paridad + `verify-config`/`luac -p` tras cada toque.
- Referencia rota en QML (comando/path/IPC/tema inexistente): lo esperable es mapa contra dotfiles+manifests antes de añadir paquetes.
- Tests que viven fuera del repo (harness efímero): lo esperable es no afirmar "verificado" sin log o captura citable.

---

### Task 1: Oleada de auditoría G (lógica QML)

**Files:**
- Read-only: `dotfiles/.config/quickshell/MacShell/*.qml`, `*.js`
- Produce: informe P0/P1/P2/P3 con `fichero:línea` (el orquestador implementa)

**Interfaces:**
- Consumes: nada (dominio disjunto de H e I)
- Produces: lista de hallazgos con fix mínimo sugerido

- [ ] **Step 1:** Despachar `subagent` (`explore`, background) con brief: IPC huérfanos, null-refs en settings, `execDetached` sin guarda, persistencia de ajustes.
- [ ] **Step 2:** Recibir informe y triar (una atómica por vuelta).
- [ ] **Step 3:** Verificación según el hallazgo (`luac` n/a en QML: balanceo + revisión + captura VM si aplica).
- [ ] **Step 4:** Commit `fix(qml): ...` o `docs:` con Ruling si toca vendoreado.

### Task 2: Oleada de auditoría H (caminos no ejecutados + seguridad)

**Files:**
- Read-only: `install.sh` (rutas paru-compile/makepkg, `curl|bash` ausentes, patrones inseguros), `packages.*`
- Produce: informe como Task 1

- [ ] **Step 1:** Despachar `subagent` (`explore`, background): caminos jamás ejecutados en stubs (compilación paru, `mask --now`, `flatpak` sin red) + patrones inseguros (`eval`, `curl|sh`, `rm -rf` con variable).
- [ ] **Step 2:** Recibir y triar.
- [ ] **Step 3:** Verificación: stubs que fuercen la rama + `bash -n`/`shellcheck`.
- [ ] **Step 4:** Commit `fix(install): ...`.

### Task 3: Oleada de auditoría I (higiene y muertos)

**Files:**
- Read-only: `assets/`, `dotfiles/` completo, `~/.cache/nimbusshell-vm/` (fuera del repo)
- Produce: informe como Task 1

- [ ] **Step 1:** Despachar `subagent` (`explore`, background): ficheros muertos/duplicados, dotfiles sin referencia, assets huérfanos, nombres que mienten.
- [ ] **Step 2:** Recibir y triar (borrar solo con origen conocido y regenerable).
- [ ] **Step 3:** Verificación: `find`/conteos + `--check` verde-en-dev-igual (mismo rojo esperado).
- [ ] **Step 4:** Commit `chore: ...`.

### Task 4: Puertas del orquestador (cada vuelta)

**Files:** ninguno (solo ejecuta)

- [ ] **Step 1:** `bash -n install.sh` → OK esperado.
- [ ] **Step 2:** `shellcheck -S warning install.sh dotfiles/.local/bin/*` → cero warnings.
- [ ] **Step 3:** `luac -p` en `hypr/*.lua` → OK.
- [ ] **Step 4:** `./install.sh --check` → exit 1 en host dev (rojo esperado), exit 0 solo en sistema convergido.
- [ ] **Step 5:** Si la vuelta tocó install: suite stub completa (solo fondo+logo FALTA sin root).

### Task 6: Plan nocturno UI 1:1 (batch actual)

- [ ] **Step 1:** Terminar `lang/es.js` por tramos con paridad de claves node en cada commit.
- [ ] **Step 2:** Install completo en VM CachyOS live en background (log vía POST + capturas periódicas).
- [ ] **Step 3:** Sesión Hyprland en VM con screenshots (TTY + dotfiles desplegados).
- [ ] **Step 4:** Cerrar gaps visibles contra checklist macOS; roadmap + commits.

## Regla innegociable del bucle (2026-10-28)

El orquestador NO para ni pregunta: audita → implementa atómico → verifica con evidencia → commitea → relanza. Si la cola se vacía, nueva oleada sobre deltas. Subagentes en dominios disjuntos; integración inmediata al volver cada informe. Solo se interrumpe por orden explícita de parada.

- [ ] **Step 1:** Releer `.agent_roadmap.md` y marcar lo cerrado.
- [ ] **Step 2:** Despachar nueva oleada G/H/I sobre los deltas desde la anterior.
- [ ] **Step 3:** Volver a Task 1. Sin pausas hasta orden de parada.
