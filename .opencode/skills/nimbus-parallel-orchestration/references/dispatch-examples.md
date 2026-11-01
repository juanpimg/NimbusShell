# Ejemplos de dispatch (OpenCode V2)

## Un implementer por unidad
```text
subagent({
  agent: "nimbus-implementer",
  description: "F3 barra autostart",
  background: true,
  model: "opencode-go/deepseek-v4.1-flash",
  prompt: "<brief completo con worktree exclusiva, ficheros, done y evidencia>"
})
```

## Fan-out correcto (mismo mensaje)
```text
subagent({ agent: "nimbus-implementer", ... A })
subagent({ agent: "nimbus-implementer", ... B })
subagent({ agent: "nimbus-reviewer",    ... C })
```
Los tres corren en paralelo. En mensajes separados, no.

## Review adversarial
```text
subagent({
  agent: "nimbus-reviewer",
  description: "review F3 autostart",
  background: true,
  prompt: "Revisa <commit> en <worktree>. Re-ejecuta <checks>. Veredicto..."
})
```

## Verificación VM (una sola)
```text
subagent({
  agent: "nimbus-verifier",
  description: "E2E instalado out8",
  prompt: "En la VM instalada ... captura ... evidencia ..."
})
```
Nunca lances dos verifiers: comparten VM/share.
