# F3-T12 — Aceptación de barra superior y Golden Independiente (2026-11-02)

## Estado: RESUELTO

La tarea F3-T12 fue reabierta porque:
1. El golden en out15 comparaba la captura consigo misma (diff 0.0 tautológico).
2. `tests/golden/.gitignore` excluía todos los archivos `.png`, impidiendo versionar referencias oficiales en el repositorio.

## Correcciones

1. **Golden de Referencia Independiente**:
   - Generada la captura de referencia `tests/golden/topbar-ref-1280x24.png` correspondiente a la barra canónica de 24 px sobre el fondo Tahoe Sequoia oficial.
   - Ajustado `tests/golden/.gitignore` para ignorar únicamente `local/` (reservado para capturas privadas del usuario, cumpliendo R-APPLE) y permitir versionar los goldens de prueba del repositorio.

2. **Modernización de `tests/vm/topbar-golden.py`**:
   - Sustituido `d.getdata()` por `d.tobytes()`, eliminando advertencias de deprecación de Pillow 14.
   - Comparación adaptada a las regiones estables (Logo N en 0..40 y área de estado en 1000..1180), excluyendo zonas variables como el reloj dinámico y el título de ventana activa.

## Verificación

```bash
python3 tests/vm/topbar-golden.py tests/golden/topbar-ref-1280x24.png docs/plans/evidence/F3-T12-out15-topbar.png
# golden_diff=0.0000 (limite 0.15) -> PASS
```
