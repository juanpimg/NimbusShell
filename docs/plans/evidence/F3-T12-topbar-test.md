# F3-T12 — test de barra y golden (2026-11-02 09:24)

## Implementado
- `tests/vm/topbar.sh`: comprueba proceso de barra, notificaciones Nimbus,
  `screenInfo`, captura full-screen y deja `topbar.png`.
- `tests/vm/topbar-golden.py`: diff por regiones estables (logo N 0..40 y
  status 1000..1180; app title/reloj enmascarados), umbral 15%.
- `tests/golden/topbar-out13-1280x800.png`: golden de out13.

## Ejecución real
```text
PASS bar.process pid=572
PASS bar.height=24 (KWin geometry)  [h=24 fh=24 y=0]
PASS notifications.server=Nimbus
PASS screens: count=1 [Virtual-1:1280x800(prim)] mc=1280x800@0,0
PASS captura /home/nimbus/topbar-evidence/topbar.png
RESULT 5 PASS / 0 FAIL
golden_diff=0.0000 (limite 0.15)
```
Evidencia: `F3-T12-topbar-out13.png`.

## Límites
- La altura se mide por geometría KWin (`nimbus-bar h=24 fh=24 y=0`), no por log.
- Capturas de menú N, calendario y Control Center ya existen
  (`matrix-out12/07..09`); faltan clics de todos los ítems (Acerca de,
  Ajustes, Reloj, bloquear/cerrar sesión) y la matriz multi-monitor final.
- F3-T12 **no se marca**.
