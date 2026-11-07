# Evidencia F9-T01 — Calamares pulido

Fecha: 2026-11-02 · NimbusOS Plasma 6.8.2

## Resumen
- Módulos Calamares unificados y validados: `settings.conf`, `branding.desc`, y todos los ficheros en `iso/calamares/modules/*.conf`.
- Diapositivas de instalación `slideshow.qml` pulidas (4 diapositivas estructuradas con tipografía Inter, tokens Tahoe y contenidos sobre Ventanas/Spaces, Dock/Barra, Btrfs/snapper y Cero telemetría).
- Grupo `input` añadido a `users.conf` para garantizar funcionamiento out-of-the-box de `ydotool` para atajos sintéticos sin intervención manual.
- Suite de pruebas automatizada `tests/calamares/test_calamares_config.sh` (15/15 OK): validación YAML, ejecutabilidad y sintaxis de scripts de shellprocess (`nimbus-assets.sh`, `nimbus-efi-fallback.sh`, `nimbus-kernel.sh`, `nimbus-pacstrap-patch.sh`), `qmllint` sobre slideshow.

## Verificación
```bash
bash tests/calamares/test_calamares_config.sh
# Resultado: 15 ok, 0 fallos
```
