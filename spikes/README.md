# spikes/ — pruebas de viabilidad (desechables)

Spikes de gate F0: `dock/` (Krema fork mínimo, ≥55fps en VM),
`krunner/` (skin fullscreen, <50ms), `overview/` (efecto KWin mínimo,
<300ms, sin crash). Cada spike genera su evidencia
(`docs/plans/evidence/F0-T0*.md`) y el veredicto go/no-go.

- **Qué no:** código de producción (si el spike se adopta, se reescribe
  en `packages/` con tests y pin).
