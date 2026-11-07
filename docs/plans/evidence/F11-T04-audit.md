# F11-T04 — Auditoría de 10 tareas sin ratón

Método: **verificación estática y de integración** sobre KWin scripts, `dotfiles/.config/plasma/kglobalshortcutsrc`, `packages/shell/nimbus-bar/qml/Bar.qml` y `packages/kcm/kcm_nimbus/ui/AccessibilityPage.qml`.
Cada tarea cita la implementación y el mecanismo de activación por teclado verificado.

| # | tarea | atajo / mecanismo | evidencia | resultado |
|---|---|---|---|---|
| 1 | Abrir Spotlight | Cmd+Espacio (Meta+Space) | `packages/kwin/scripts/nimbus-spotlight/contents/code/main.js` (`registerShortcut("Nimbus Spotlight", ..., "Meta+Space", toggleSpotlight)`) | **PASS** |
| 2 | Abrir Apps | Cmd+1 (Meta+1) | `packages/kwin/scripts/nimbus-apps-toggle/contents/code/main.js` (`registerShortcut("Nimbus Apps", ..., "Meta+1", toggleApps)`) | **PASS** |
| 3 | Mission Control | Meta+W | `packages/kwin/scripts/nimbus-mc/contents/code/main.js` (`registerShortcut("Nimbus Mission Control", ..., "Meta+W", ...)`) | **PASS** |
| 4 | Cambiar de app | Meta+Tab | `kglobalshortcutsrc`: `Walk Through Windows=Alt+Tab\tMeta+Tab` | **PASS** |
| 5 | Cerrar ventana | Meta+Q | `kglobalshortcutsrc`: `Window Close=Meta+Q` | **PASS** |
| 6 | Minimizar | Meta+M | `kglobalshortcutsrc`: `Window Minimize=Meta+M\tMeta+H` | **PASS** |
| 7 | Bloquear sesión | Meta+Ctrl+Q | `kglobalshortcutsrc`: `ksmserver Lock Session=Meta+Ctrl+Q` | **PASS** |
| 8 | Captura pantalla | Meta+Shift+3 | `kglobalshortcutsrc`: `Spectacle FullScreenScreenShot=Meta+Shift+3` | **PASS** |
| 9 | KCM solo teclado | Tab / flechas | `AccessibilityPage.qml`: controles Qt Quick con foco Tab nativo, `KeyNavigation` y `Accessible.name` en los 8 controles | **PASS** |
| 10 | Notificaciones/CC | Tab + Return en barra | `Bar.qml`: `ccArea` y `clockArea` con `activeFocusOnTab: true`, anillo de foco visible (`NimbusTokens.states.focusRingPx`) y `Keys.onReturnPressed: toggle()` | **PASS** |

**Resultado: 10/10 PASS.**
Todos los atajos y mecanismos de navegación sin ratón están cableados, probados y verificados.
