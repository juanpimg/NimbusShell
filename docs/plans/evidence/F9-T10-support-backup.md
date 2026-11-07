# Evidencia F9-T10 — Soporte, diagnóstico y backup

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- Implementada herramienta de diagnóstico y reporte de soporte `apps/nimbus-bug-report/nimbus-bug-report`:
  - Recopila información del sistema (/etc/os-release, kernel, uptime).
  - Diagnóstico de hardware (CPU, memoria, GPU PCI / lspci).
  - Estado de sesión Plasma 6 y Wayland (variables XDG, versiones de plasmashell y kwin_wayland).
  - Servicios DBus activos registrados por Nimbus y KDE (`qdbus6`).
  - Filtrado de incidencias y avisos de usuario vía `journalctl`.
  - Recopilación de configuraciones Nimbus (`kwinrc`, `kdeglobals`, `nimbus-welcome.ini`, `nimbus-layout.ini`, etc.) con anonimización estricta de contraseñas, secretos, PSKs y tokens.
  - Generación de tarball `.tar.gz` autocontenido.
  - Modo `--dry-run` / `--check` de solo lectura sin escritura en disco.
- Integración de escritorio:
  - Fichero `apps/nimbus-bug-report/org.nimbus.bugreport.desktop` válido según freedesktop.
- Herramienta de copias de seguridad de configuraciones:
  - `apps/backup/nimbus-backup` (estilo Konsave): `save`, `restore`, `list`, respaldos incrementales y restauración idempotente.
- Suite de pruebas completa:
  - `tests/support/test_bug_report.sh` (13/13 OK):
    - `bash -n` y `shellcheck -S warning` sin advertencias.
    - `desktop-file-validate` limpio.
    - Verificación de `--dry-run`.
    - Generación y comprobación de contenido del tarball de diagnóstico en HOME temporal.
    - Comprobación de seguridad: anonimización probada de contraseñas y tokens.
    - Ciclo completo de save y restore con `nimbus-backup`.

## Verificación
```bash
bash tests/support/test_bug_report.sh
# Resultado: 13 ok, 0 fallos
```
