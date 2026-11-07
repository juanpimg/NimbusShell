# Evidencia F9-T09 — Migrador legacy Hyprland → Plasma

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- Herramienta de migración `apps/nimbus-migrate/nimbus-migrate-hyprland`:
  - Lee configuraciones históricas de Hyprland (`~/.config/hypr/hyprland.conf`, `10-shortcuts.conf`, `hyprpaper.conf`, `settings.json`, temas GTK).
  - Migra de forma no destructiva a configuraciones nativas de Plasma 6:
    - Fondo de pantalla -> `plasma-org.kde.plasma.desktop-appletsrc` (Image=...)
    - Gaps/bordes -> `kwinrc` (`[NimbusMigrated]`)
    - Atajos de teclado -> `kglobalshortcutsrc` (`[kwin] Walk Through Windows`, etc.)
    - Esquema de color (claro/oscuro) -> `kdeglobals` (`ColorScheme`)
  - Genera informe transparente de elementos no migrables (animaciones propietarias de Hyprland, efectos blur incompatibles o scripts exec-once).
  - Respaldo automático en `~/.config/nimbusshell-backup-*` antes de aplicar cambios.
  - Opciones completas `--dry-run`, `--apply`, `--rollback` y `--json`.
- Suite de pruebas (`tests/migrate/test_hyprland_migrate.sh`):
  - 9/9 checks OK en entornos de HOME temporal aislados.
  - Cobertura de idempotencia, rollback seguro y preservación estricta de ficheros ajenos.

## Verificación
```bash
bash tests/migrate/test_hyprland_migrate.sh
# Resultado: 9 ok, 0 fallos
```
