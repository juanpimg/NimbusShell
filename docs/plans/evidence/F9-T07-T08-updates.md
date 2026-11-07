# Evidencia F9-T07 / F9-T08 — Discover simple y Rollback Btrfs / snapper

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- **Actualizaciones en lenguaje llano (`scripts/nimbus-updates`)**:
  - Modo `--check` (por defecto): inspección no destructiva de paquetes desactualizados mediante `checkupdates` o `pacman -Qu`. Solo lectura, sin root, sin modificar el sistema.
  - Modo `--apply`: crea una instantánea de seguridad Btrfs mediante `snapper create` con descripción identificativa antes de aplicar actualizaciones vía `pacman -Syu`.
- **Retorno seguro (`--rollback-list` y `--rollback N`)**:
  - Lista instantáneas disponibles con identificador y fecha.
  - Reversión atómica y limpia invocando `snapper undochange` o instrucciones detalladas en caso de ausencia de configuración de snapper.
  - Fallo accionable ante argumentos faltantes o no numéricos.
- **Configuración de Discover (`dotfiles/.config/discoverrc`)**:
  - `CompactMode=true` para simplificar la vista y evitar descripciones técnicas abrumadoras.
- **Suite de pruebas (`tests/updates/test_updates.sh`)**:
  - 19/19 tests PASS utilizando fakes en PATH para simular `checkupdates`, `pacman` y `snapper` en entornos aislados sin permisos de superusuario, validando rechazo estricto de parámetros no numéricos o inválidos en `--rollback`.

## Verificación
```bash
bash tests/updates/test_updates.sh
# Resultado: 19 ok, 0 fallos
```
