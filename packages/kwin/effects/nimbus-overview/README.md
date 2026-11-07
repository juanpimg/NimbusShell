# nimbus-overview — Efecto KWin Nimbus Overview (F7-T03)

Paquete de efecto KWin (`KWin/Effect`) para exponer y alternar la vista de Mission Control estilo macOS Tahoe.

## Integración arquitectónica (Ruling R-MC-CUSTOM / R-MC-STOCK)
1. **Punto de entrada:** expone el ID de efecto `nimbus-overview`.
2. **Delegación:** reenvía la señal de alternancia a `org.nimbus.MissionControl` (`/MC toggle`).
3. **Atajo canónico:** `Meta+W` (F3 macOS equivalente), manteniendo la coherencia sin atajos `CTRL-*` nuevos.
