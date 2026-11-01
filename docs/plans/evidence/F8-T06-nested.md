# F8-T06 — Evidencia nested (Sistema real)

## Controles
- Personas: AccountsService por D-Bus (`ListCachedUsers` → nombre|real|tú);
  sin el servicio, `/etc/passwd` (uid≥1000 con shell válida + root;
  jamás contraseñas). «Eres tú» marca la sesión.
- Equipo (`QHostInfo`), zona (`timedatectl show -p Timezone`), idioma
  (`localectl status`) e interruptor NTP (`timedatectl set-ntp`,
  best-effort: sin permiso avisa «necesita administrador»).
- Energía: `powerprofilesctl list/get/set` (rendimiento/equilibrado/ahorro,
  sin root). Lo que exige root (renombrar, añadir usuarios, zona, idioma)
  solo se muestra + salto a `kcm_users`/`kcm_regionandlang`.

## Tests (dentro de `test-pages.sh`, 41/41 PASS total)
Escenario `system`: `userCount=2` (AccountsService), `currentUser=jp`,
`hostName`/`timeZone=Europe/Madrid`/`systemLocale` no vacíos,
`energyProfiles=performance,balanced,power-saver` y roundtrip reversible
 balanced→restaurado (único cambio de estado del host, revertido).

## Captura
`spikes/nested/f8-kcm-system.png`: KCM en Sistema (jp + builder,
Europe/Madrid, NTP activo); `QML_ERRORS=0`.
