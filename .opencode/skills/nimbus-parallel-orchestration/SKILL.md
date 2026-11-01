---
name: Nimbus Parallel Orchestration
description: Divide NimbusShell en unidades independientes, lanza subagentes en paralelo con worktrees exclusivas y verifica con evidencia antes de integrar. Úsala siempre que haya 2+ tareas independientes (código, tests, docs, UI) o cuando el usuario pida ir más rápido/paralelizar.
metadata:
  opencode/autoinvoke: true
---

# Nimbus Parallel Orchestration

Objetivo: reducir el tiempo de pared sin romper el contrato de evidencia de NimbusShell.
El orquestador no implementa: descompone, despacha, integra y verifica.

## Regla de oro

**Dos o más unidades independientes ⇒ todos los `subagent` en el MISMO mensaje.**
Si se lanzan en mensajes distintos, se ejecutan en serie y no hay ganancia.

## Cuándo paralelizar

| Paraleliza | No paralelices |
| --- | --- |
| Ficheros/módulos distintos sin solaparse | Misma worktree o mismo fichero |
| Docs/evidencia + código de otra área | Dos tareas de VM/ISO a la vez |
| Revisión de commits distintos | Una tarea depende del resultado de otra |
| Investigación externa + implementación local | Cambios en `scripts/ci.sh` o `install.sh` desde dos ramas |
| Tests de subsistemas distintos | Estado compartido (VM, disco, build, share 9p) |

Máximo 4 subagentes concurrentes. Solo **una** tarea de VM/ISO.

## Roles (modelo fijo: `opencode-go/deepseek-v4.1-flash`)

| Agente | Uso | Permisos |
| --- | --- | --- |
| `nimbus-implementer` | Una tarea acotada en worktree exclusiva | edita + shell |
| `nimbus-reviewer` | Revisión adversarial de un commit | read + shell, sin editar |
| `nimbus-verifier` | Aceptación VM/nested + capturas | read + shell + evidence/spikes |
| `nimbus-researcher` | Upstream/docs externas | read + web, sin editar |
| `nimbus-orchestrator` | Coordinación (primario) | sin editar código |

## Protocolo

1. **Inventario** (2 min): `git log -5`, `git status`, `scripts/nimbus-progress`,
   plan; identifica qué está abierto y qué ya está hecho. No dupliques.
2. **Descomposición**: una unidad = un objetivo verificable + ficheros/estado propios.
   Si comparten fichero, VM o worktree ⇒ fusiónalas o secuéncialas.
3. **Worktrees**: cada implementer con `git worktree add -b plasma/<tema> <dir> <base>`.
   Nunca dos agentes en la misma worktree.
4. **Brief autocontenido** (plantilla abajo): el subagente no ve esta conversación.
5. **Fan-out**: todos los `subagent` en un solo mensaje, `background: true` para no
   bloquear; el orquestador sigue con trabajo local no solapado.
6. **Recepción**: lee cada informe; exige commit, tests y evidencia. Un "hecho" sin
   salida no cuenta.
7. **Review**: un `nimbus-reviewer` por commit relevante, en paralelo si son
   independientes. Re-ejecuta checks.
8. **Integración**: merge en `plasma-migration` en orden; resuelve conflictos;
   `bash scripts/ci.sh`; después verifier/VM si aplica.
9. **Ledger**: marca `[x]` solo con aceptación real; nota gaps honestos.
10. **Reporte**: <15 líneas: lanzado, evidencia, merge, pendiente.

## Brief template

```text
Rol: implementer (NimbusShell). Worktree EXCLUSIVA `<dir>` (rama `<rama>`, base `<sha>`).
NO toques otras worktrees. Español.

Host = máquina del usuario: NO root/instalar/tocar su ~/.config ni su sesión;
nested/HOME temporales. Contrato: docs/design/tahoe-design-contract.md y AGENTS.md.

Tarea: <una frase>
Contexto mínimo: <ficheros, líneas, comandos, errores exactos>
Alcance: <qué tocar> — PROHIBIDO: <qué no tocar>
Criterio de done: <comprobable>
Evidencia: <tests/capturas/salida que debe quedar>
Commit: `feat|fix|docs(<scope>): ...` (NO checkbox, NO merge)
Reporta <25 líneas: ficheros, PASS/FAIL, evidencia, commit, límites.
```

## Mapa de paralelismo de NimbusShell

- **Código/QML independiente**: barra (`packages/shell/nimbus-bar`), apps
  (`apps/*`), KCM (`packages/kcm`), scripts (`scripts/*`), ISO (`iso/*`).
  Ojo: ISO/VM es secuencial y una sola a la vez.
- **Docs/evidencia/i18n**: pueden ir en paralelo con código, salvo que editen el
  mismo fichero del plan.
- **Revisiones**: cada rama/commit es independiente; lanza 2-3 reviewers a la vez.
- **VM/aceptación**: una sola; el verifier posee la VM y el share. Los demás no
  tocan `~/.cache/nimbusshell-vm`.

## Anti-patrones

- Lanzar 6 agentes para 2 unidades reales (coste de merge > ganancia).
- "Paralelo" con dispatches en mensajes distintos (es serie).
- Brief que dice "mira el repo" sin ficheros ni criterio de done.
- Aceptar el informe del worker sin re-ejecutar los checks.
- Mergear sin `scripts/ci.sh` ni evidencia de VM cuando el accept la exige.
- Dos agentes en la misma worktree o dos VMs a la vez.
- Marcar tareas por "compila" cuando el accept pide captura real.

## Verificación

Antes de decir "listo": `git log` con commits, `bash scripts/ci.sh` verde,
evidencia enlazada y, si es UI/VM, captura real. Si falta algo, se declara.
