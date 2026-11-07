# F3-T04 — Menú Apple: cableado de acciones reales y confirmación (2026-11-02)

## Estado: RESUELTO

La tarea F3-T04 fue reabierta porque las acciones destructivas (dormir, bloquear, cerrar sesión, reiniciar, apagar) solo se trazaban en log pero no ejecutaban los comandos reales ni protegían "Cerrar sesión" con confirmación.

## Implementación

1. **Comandos reales de escritorio KDE Plasma 6 y fallback systemd/logind**:
   - **Dormir**: `qdbus6 org.freedesktop.PowerManagement /PowerManagement Suspend || systemctl suspend`
   - **Bloquear**: `qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock || loginctl lock-session`
   - **Cerrar sesión**: `qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout || loginctl terminate-session ""`
   - **Reiniciar…**: `qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndReboot || systemctl reboot`
   - **Apagar…**: `qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logoutAndShutdown || systemctl poweroff`

2. **Soporte de comandos compuestos en `CommandRunner` (`commandrunner.h`)**:
   - `CommandRunner::run` delegaba en `QProcess::splitCommand`, rompiendo operadores de shell (`||`, `&&`, `;`, comillas y variables).
   - Ahora detecta metacaracteres de shell (`|`, `;`, `&`, `$`, `"`, `'`) y ejecuta transparentemente vía `/bin/sh -c`.

3. **Confirmación en `Menu.qml`**:
   - Paridad macOS: "Cerrar sesión" exige confirmación al igual que "Reiniciar…" y "Apagar…".
   - Diálogo `confirmBox` muestra la pregunta limpia sin puntos suspensivos: "¿Cerrar sesión?", "¿Reiniciar?", "¿Apagar?".
   - Señal `actionTriggered(cmd, label)` para testabilidad y trazabilidad.

## Verificación

- Test unitario automatizado `tests/qml/tst_menu.qml` con `qmltestrunner`:
  - 6 PASS / 0 FAIL.
  - Verifica modelo de 9 acciones con flag `destructive: true`, iconos, comandos DBus/systemd, emisión de señales con etiqueta correcta (`actionTriggered`), confirmación y reseteo de `pendingLabel` al cerrar.
- Linting y formateo:
  - `qmllint packages/shell/nimbus-bar/qml/Menu.qml` → 0 errores.
  - `qmlformat` verificado e idempotente en `scripts/ci.sh`.
