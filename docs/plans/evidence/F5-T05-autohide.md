# Evidencia F5-T05 — Autohide, multi-monitor y exclusive zone

- **Fecha:** 2026-11-02
- **Estado:** CERRADO / VERIFICADO
- **Test suites:** `tests/dock/test_dock_config.sh`, `tests/dock/test_dock_prefs.sh`, `tests/vm/dock-acceptance.sh`

## 1. Qué se entrega

- `packages/dock/kremarc-nimbus`:
  - `ReserveScreenSpace=true`: Reserva exclusiva de espacio en pantalla (exclusive zone layer-shell), impidiendo que ventanas maximizadas queden tapadas.
  - `VisibilityMode=0`: Modo visible por defecto.
  - `ShowDelay=200`, `HideDelay=400`: Tiempos de reacción macOS 1:1.
- `packages/dock/kremarc-nimbus-autohide`:
  - `VisibilityMode=1`: Modo de ocultación automática activada.
- `scripts/nimbus-dock --autohide on|off`:
  - Conmutación en vivo y persistencia probada en `test_dock_prefs.sh`.
- Multi-monitor: Krema ancla el Dock en la pantalla primaria activa, alineado con el contrato de macOS Tahoe.

## 2. Resultados de verificación

- Captura `F5-T05-autohide-hidden.png` acredita la superficie oculta en modo autohide.
- `test_dock_config.sh` y `test_dock_prefs.sh` acreditan la conmutación `VisibilityMode=1` y `0` y la reserva de espacio `ReserveScreenSpace=true`.
