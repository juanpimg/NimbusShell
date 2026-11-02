# F3-T03 — kwinrc efectivo, panel auto-hide e input (2026-11-02)

## Aceptación real en la VM instalada (antes del fix)

Salida de la aceptación 22 PASS / 3 FAIL, tal como la reportó la VM:

```
PASS 22
FAIL  3
- kwin.scripts: FAIL — nimbus-spotlight=vacío nimbus-apps-toggle=vacío
  nimbus-tabs=vacío nimbus-mc=vacío nimbus-zoom=vacío
- panel.stock: FAIL — plasmashell no devolvió paneles ()
  y el panel sigue visible tras nimbus-hide-panel; visibilityMode=1 no persiste
- ydotool.input-group: FAIL — usuario no está en el grupo input
```

Causas raíz verificadas:

1. **kwin.scripts**: `dotfiles/` solo instalaba `~/.config/plasma/kwinrc`;
   KWin 6.8 lee `~/.config/kwinrc`. El fichero efectivo no tenía las claves
   `nimbus-*Enabled`, así que ningún script Nimbus se cargaba. `kwriteconfig6
   --file kwinrc` de los tests escribía en el efectivo, pero el despliegue no.
2. **panel.stock**: el script terminaba en
   `panels().forEach(...)` (expresión `undefined`), `qdbus6` imprimía vacío
   con exit 0 y el bucle lo daba por bueno aunque `panels()` aún no existiera.
   Además solo esperaba 20 s y no dejaba rastro.
3. **ydotool.input-group**: `usermod -aG input` vivía dentro del bloque
   condicionado a `THEME_UNIT_DIR`, que no existe en todos los sistemas; en
   el target no se ejecutó.

## Fixes

- `dotfiles/.config/kwinrc` (nuevo, idéntico byte a byte a
  `dotfiles/.config/plasma/kwinrc`, con cabecera que explica que KWin lee el
  efectivo). `scripts/ci.sh` y `tests/bar/test_kwinrc.sh` fallan ante drift
  con `cmp`.
- `iso/build-iso.sh`: exige `dotfiles/.config/kwinrc`, lo verifica en el
  staging (`/etc/skel/.config/kwinrc`) y que el autostart tenga
  `Exec=/usr/local/bin/nimbus-hide-panel`.
- `nimbus-installed-setup`: copia `plasma/kwinrc` → `.config/kwinrc` en
  `/etc/skel` y en el home si falta (no pisa datos), y fija
  `library=org.kde.klassy` en ambos ficheros. `usermod -aG input` sube a
  0a-bis, se ejecuta siempre que exista el grupo, comprueba pertenencia
  (idempotente) y loguea OK/AVISO.
- `nimbus-hide-panel`: consulta `panels().length` antes de tocar nada,
  devuelve el número de paneles modificados (no `undefined`), reintenta
  hasta 30 s (`NIMBUS_HIDE_PANEL_TIMEOUT`), loguea en
  `$XDG_CACHE_HOME/nimbus/hide-panel.log` y devuelve exit 1 si la API falla.
  Autostart en `dotfiles/.config/autostart/nimbus-hide-panel.desktop` y en
  el skel de la ISO, con `X-KDE-autostart-after=plasmashell`.

## Verificación local (sin root, HOME temporal)

```
$ bash -n iso/profile/airootfs/usr/local/bin/nimbus-hide-panel \
         iso/profile/airootfs/usr/local/bin/nimbus-installed-setup \
         iso/build-iso.sh tests/bar/test_kwinrc.sh
(exit 0)

$ shellcheck -S warning <mismos ficheros + scripts/ci.sh>
(exit 0, cero warnings)

$ tests/bar/test_kwinrc.sh
  [OK] dotfiles/.config/kwinrc == plasma/kwinrc (cmp)
  [OK] kwinrc efectivo: nimbus-spotlightEnabled=true
  [OK] kwinrc efectivo: nimbus-apps-toggleEnabled=true
  [OK] kwinrc efectivo: nimbus-tabsEnabled=true
  [OK] kwinrc efectivo: nimbus-mcEnabled=true
  [OK] kwinrc efectivo: nimbus-zoomEnabled=true
  [OK] build-iso exige dotfiles/.config/kwinrc
  [OK] build-iso verifica kwinrc efectivo en el staging (cmp)
  [OK] autostart nimbus-hide-panel con Exec canónico
  [OK] setup copia plasma/kwinrc -> .config/kwinrc si falta
  [OK] setup fija Klassy en kwinrc efectivo y plasma
  [OK] usermod -aG input aparece una sola vez
  [OK] grupo input se aplica fuera/antes del bloque del timer de tema
  [OK] panel: reintenta hasta panels()>0 y aplica auto-hide
  [OK] panel: sin paneles tras timeout -> AVISO y exit 0
  [OK] panel: evaluateScript con error -> ERROR y exit 1
  KWINRC/PANEL VERDE.

$ scripts/ci.sh
  [OK] kwinrc efectivo == plasma/kwinrc (cmp)
  [OK] tests/bar/test_kwinrc.sh
  [OK] install.sh --check exit 1 (drift esperado en host)
  CI VERDE.

$ iso/build-iso.sh --check
  == --check OK ==
```

## Límite honesto (pendiente de VM)

- No se ha podido re-ejecutar la aceptación 22/3 dentro de la VM instalada en
  esta worktree: los fixes son de despliegue (skel → home → kwinrc efectivo)
  y de robustez del script. La captura/veredicto final exige reconstruir la
  ISO con estos cambios y repetir el E2E.
- `visibilityMode=1` se reaplica en cada login vía autostart; **no** se ha
  confirmado persistencia en `plasma-org.kde.plasma.desktop-appletsrc` en
  Plasma 6.8. Eliminación permanente (`panel.remove()`) queda pendiente
  hasta confirmar que la API de scripting 6.8 la soporta; borrar el panel de
  configuración del usuario sin esa confirmación sería destructivo.
- El grupo `input` requiere cerrar y reabrir sesión para que ydotool lo vea;
  el log del instalador solo confirma `usermod`, no la sesión ya abierta.
