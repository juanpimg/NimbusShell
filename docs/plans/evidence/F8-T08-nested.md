# F8-T08 — Evidencia nested (Reset canónico, persistencia y tests)

## Reset por sección (`resetSection`, botón arriba en las 6 páginas)
- Cada página tiene «Restablecer esta sección»: backup `~/.config/
  nimbusshell-backup-YYYYMMDD-HHMMSS/` (solo ficheros existentes que toca;
  jamás borra nada) + valores canónicos + escritura del dominio + refresco
  UI por señales. No toca `needsSave` ajeno.
- Dominios: appearance (kdeglobals/kremarc/plasmashellrc/kwinrc-anim/
  nimbusrc), accessibility (kwinrc-plugins/anim, kcminputrc, kaccessrc,
  gsettings + `kscreenlockerrc` canónica: Autolock/LockOnResume/LockOnStart
  false, Timeout 10, Greeter breeze), shortcuts (`nimbus-keys meta --home`),
  system (energía→balanced + intento NTP con aviso), updates (borra timer),
  network (radios on + redescubrir; sin ficheros propios).
- `save()` refactorizado en `saveAppearance/Accessibility/Shortcuts/System/
  Updates` con backup previo (mismo comportamiento, verificado por los
  tests previos). `defaults()` global ahora incluye `dailyCheck=false`.

## Tests (`tests/kcm/test-pages.sh`, HOME por escenario, 68/68 PASS)
- Persistencia: save→load round-trip (dark/dock/zoom/delay + kdeglobals).
- Reset por dominio con antes/después: appearance (light/#FF0000/72 →
  dark/`#0A84FF`/48, kdeglobals+kremarc), a11y (zoom/invert/motion/delay200
  → todo off/delay500, kwinrc anim 3, kscreenlockerrc), shortcuts
  (ctrl→meta en fichero), system (energía→balanced, revertida), updates
  (timer escrito→borrado), network (wifi on).
- Backup: dir `nimbusshell-backup-*` con ficheros en HOME temporal.
- JSON/KConfig: `package-metadata.json` + `src/metadata.json` parsean;
  `desktop-file-validate` OK.
- Trampas: `AnimationSpeed` vivía solo en dominio Apariencia y el reset
  a11y dejaba 0 (ahora ambos dominios la escriben + canónico restaura 3);
  el probe enlaza fuentes: reconstruir `/tmp/nimbus-probe-build` tras
  cada cambio C++.

## Captura
`spikes/nested/f8-kcm-reset.png`: Updates con «Restablecer esta sección»
visible arriba; `QML_ERRORS=0`. Antes/después textual vía probe dumps
arriba. `qmllint` 8/8 (se eliminó `NimbusPlaceholder.qml`, sin uso),
build 0 warnings, `shellcheck` limpio. Sin root en ningún test.
