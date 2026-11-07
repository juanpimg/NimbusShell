# F5-T08 — Dock: configuración, persistencia y test suite (2026-11-02)

## Estado: RESUELTO

La tarea F5-T08 fue reabierta por falta de suite de tests en `tests/dock` y verificación de persistencia INI.

## Implementación

1. **Suite de pruebas `tests/dock/test_dock_config.sh`**:
   - Verifica claves requeridas para paridad macOS Tahoe 1:1 en `packages/dock/kremarc-nimbus`:
     - `IconSize=48` (tile macOS)
     - `MaxZoomFactor=1.6` (zoom parabólico)
     - `Edge=1` (dock en borde inferior)
     - `Floating=true`, `FloatingMargin=8`, `CornerRadius=12`
     - `BackgroundStyle=3` (acrílico Tahoe), `BackgroundOpacity=0.6`
     - `VisibilityMode=0` (fijo) y variante `kremarc-nimbus-autohide` (`VisibilityMode=1`)
     - `PreviewEnabled=true`, `PreviewThumbnailSize=200`, `PreviewHoverDelay=500`
   - Prueba ciclo completo de persistencia: lectura inicial de pins, desanclado (unpin) de aplicación, re-anclado (re-pin), reordenación de lista y restablecimiento al preset canónico.

2. **Integración en `lib/dock.sh`**:
   - `dock_deploy`: inicializa `~/.config/kremarc` copiando `packages/dock/kremarc-nimbus` de forma idempotente.
   - `dock_check`: comprueba presencia del preset en el repo y dependencias de layer-shell-qt.

3. **Integración en CI**:
   - `tests/dock/test_dock_config.sh` añadido a `scripts/ci.sh` (validación de sintaxis, shellcheck y ejecución).

## Verificación

```bash
./tests/dock/test_dock_config.sh
# DOCK VERDE (todos los checks pasan).
```
