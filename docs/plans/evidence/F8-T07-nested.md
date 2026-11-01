# F8-T07 — Evidencia nested (Updates real)

## Controles
- «Comprobar ahora» → `checkupdates` async (sin root; fallback
  `pacman -Qu` si falta; mensaje si no hay gestor). Cuenta + top-15
  («…y N más»). No auto-escanea al abrir (tarda ~1 min): seam de test
  `NIMBUS_KCM_AUTOCHECK` para la captura.
- «Aviso diario» → timer de usuario `nimbus-updates-check.{service,timer}`
  en `~/.config/systemd/user` (sin root) + `daemon-reload/enable`
  best-effort; se guarda/borra con «Aplicar» (verificado en HOME temporal).
- Discover: botón si existe `plasma-discover` (aquí no → texto honesto
  con `pacman`); copias: nota snapper si `list-configs` no vacío.

## Tests (dentro de `test-pages.sh`, 41/41 PASS total)
Escenario `updates`: `updatesAvailable=true`, `updatesCount=17`,
`shown=15`. Programación: timer+service escritos en HOME temporal,
`dailyCheck` releído `true`, borrados al desactivar.

## Captura
`spikes/nested/f8-kcm-updates.png`: KCM en Actualizaciones con las 17
pendientes reales («…y 2 más»); `QML_ERRORS=0` (espera 90 s al scan).
