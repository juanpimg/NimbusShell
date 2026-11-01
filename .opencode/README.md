# Orquestación NimbusShell (OpenCode V2)

- Agentes: `.opencode/agents/nimbus-{orchestrator,implementer,reviewer,verifier,researcher}.md`.
- Skill: `.opencode/skills/nimbus-parallel-orchestration/SKILL.md`.
- Config: `.opencode/opencode.jsonc` (modelo fijo permitido:
  `opencode-go/deepseek-v4.1-flash`).

## Uso

1. Elige el agente **Nimbus Orchestrator** en el selector de agentes (o pide
   `@nimbus-orchestrator`).
2. El orquestador inventaría, divide y lanza todos los subagentes independientes
   **en un solo mensaje** (`background: true`).
3. Cada implementer usa una worktree exclusiva y devuelve commit + tests + evidencia.
4. Reviewer re-ejecuta; verifier aporta captura/salida real; el orquestador mergea
   y actualiza el ledger solo con evidencia.

## Reglas duras

- Máx. 4 subagentes concurrentes; **una** VM/ISO a la vez.
- Nada de dos agentes en la misma worktree o fichero.
- Sin captura/salida real no se marca una tarea.
- `bash scripts/ci.sh` verde antes de cada merge.
