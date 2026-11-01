# F11-T04 — Auditoría de 10 tareas sin ratón

Método: **estático** (grep sobre `dotfiles/.config/plasma/kglobalshortcutsrc`
canónico + `packages/kcm/kcm_nimbus/ui/AccessibilityPage.qml`). Sin sesión
nested/VM en esta tarea: la columna *resultado* cita la evidencia exacta y
los FAIL son gaps reales con su port. Nada se marca PASS sin cita.

| # | tarea | atajo esperado | evidencia | resultado |
|---|---|---|---|---|
| 1 | Abrir Spotlight | Cmd+Espacio | `_launch=none` reservado F6-T01 (sin trigger) | **FAIL** — gap G1 |
| 2 | Abrir Apps | Cmd+1 | `activate task manager entry 1=none` reservado F6-T04 | **FAIL** — gap G1 |
| 3 | Mission Control | Meta+W | `Overview=none` (R-MC-STOCK); `scripts/nimbus-mc` aún no existe | **FAIL** — gap G2 |
| 4 | Cambiar de app | Meta+Tab | `Walk Through Windows=Alt+Tab\tMeta+Tab` | **PASS** |
| 5 | Cerrar ventana | Meta+Q | `Window Close=Meta+Q` | **PASS** |
| 6 | Minimizar | Meta+M | `Window Minimize=Meta+M\tMeta+H` | **PASS** |
| 7 | Bloquear sesión | Meta+Ctrl+Q | `ksmserver Lock Session=Meta+Ctrl+Q` | **PASS** |
| 8 | Captura pantalla | Meta+Shift+3 | `Spectacle FullScreenScreenShot=Meta+Shift+3` | **PASS** |
| 9 | KCM solo teclado | Tab/flechas | `AccessibilityPage.qml`: controles Qt Quick (foco Tab nativo) + `Accessible.name` en los 8 controles | **PASS** (estático) |
| 10 | Notificaciones/CC | teclado | sin trigger de teclado (el reloj abre NC con clic) | **FAIL** — gap G3 |

**6/10 PASS.** Gaps (ports, no parte de F11-T04):
- G1 (F6): Spotlight/Apps reservados sin trigger → F6-T01/T04 deben asignar
  Cmd+Espacio / Cmd+1.
- G2 (F7): `nimbus-mc` con Meta+W → F7 (R-MC-CUSTOM).
- G3 (F10): trigger de teclado para NC/CC → proponer en F10 (p. ej. clic-reloj
  ya existe; falta atajo).
- Gap de método: repetir esta tabla en sesión nested/VM (teclado real) antes
  de dar F11-T04 por cerrada al 100 %.
