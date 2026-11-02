# F5-T05 — Autohide del Dock (parcial, 2026-11-02 10:44)

- `kremarc` `VisibilityMode=1` + reinicio de Krema: el Dock queda oculto
  (`F5-T05-autohide-hidden.png`).
- Revelación al llevar el puntero al borde inferior: **no observada** con
  `ydotool` absoluto ni con VNC; el Dock siguió oculto.
- `ReserveScreenSpace=true` en kremarc; no se midió reserva con ventana.
- Restaurado `VisibilityMode=0`; Dock visible de nuevo.
- Multi-monitor: el Dock aparece solo en Virtual-1 en las capturas full-screen.
- F5-T05 **no se marca**: falta reveal fiable, reserve y Dock en Virtual-2.
