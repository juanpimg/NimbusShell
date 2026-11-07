# Evidencia F9-T04 — Apps recomendadas en nimbus-welcome

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- Módulo de selección de aplicaciones recomendadas ampliado en `apps/nimbus-welcome/`.
- Propiedades reactivas integradas en `WelcomeBackend`:
  - `isInstalling`: estado booleano de instalación en segundo plano sin bloqueo de UI.
  - `installProgress`: porcentaje entero (0 a 100) del progreso.
  - `installStatus`: mensaje explicativo en lenguaje llano del estado actual.
  - Métodos `installApps()` y `cancelInstall()` con soporte para Flatpak/PackageKit o simulación determinista (`NIMBUS_WELCOME_SIM=1`).
- Interfaz gráfica en `Welcome.qml` (Paso 6):
  - Checkboxes accesibles para apps esenciales (Firefox, VLC, GIMP, LibreOffice).
  - Botón "Instalar apps seleccionadas" con `Accessible.name`.
  - Barra de progreso interactiva estilo Tahoe y botón "Cancelar".
  - Flujo no bloqueante: el usuario puede avanzar a "Terminar" o realizar otras tareas sin congelar el asistente.
- Cobertura de pruebas unitarias (`apps/nimbus-welcome/tests/tst_welcome.cpp` y `tests/welcome/test_welcome.sh`):
  - Nuevo caso de prueba `appSelectionAndInstall()` que comprueba la selección de 3 aplicaciones, disparo de instalación, progreso hasta el 100%, verificación de estado y cancelación activa en segundo plano con terminación segura del proceso `m_installProcess`.
  - Nueva suite automatizada `tests/welcome/test_welcome.sh` integrada en CI local (`scripts/ci.sh`).
  - Suite de pruebas de `nimbus-welcome`: 100% verde.

## Verificación
```bash
bash tests/welcome/test_welcome.sh
# Resultado: 4 ok, 0 fallos
```
