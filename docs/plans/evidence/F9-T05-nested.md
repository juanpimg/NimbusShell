# F9-T05-nested — Migrador Windows/Mac

Script `apps/nimbus-migrate/nimbus-migrate-desktop --source DIR`:
dry-run por defecto, `--apply` con backup `nimbusshell-backup-*`,
`--rollback`, sin root, idempotente, sin red, nunca sobrescribe.
Importa 5 tipos: documentos (Documents/Desktop/Downloads, salvo
.exe/.msi/.dmg/.pkg) → `~/...`; marcadores Chrome/Edge (JSON),
Firefox (HTML), Safari (plist) → `bookmarks.html`; fondo (Themes /
`com.apple.desktop.plist`+Pictures) → `Pictures/fondo-importado.*`;
apps (.lnk/.app → Office→LibreOffice, Explorer/Finder→Dolphin...) →
`equivalencias.txt`; tema oscuro (registro/GlobalPreferences) →
kdeglobals. Informe de NO migrable + `--json`.
Fixtures `tests/migrate/fixtures/{win,mac}-home/` (docs, 4 urls,
fondo, 3 apps, oscuro cada una). Test `test_desktop_migrate.sh`
(HOME temporal): 28/28 (dry-run limpio, apply 5 tipos, backup,
excluye ejecutables, no sobrescribe, idempotente, rollback restaura
PREVIO/borra importados/respeta no-importados, ajenos, --json);
`bash -n`+shellcheck cero. Hyprland sigue 9/9.
Límites: NO migrable ejecutables, registro (salvo tema), PST/OST,
llaveros, drivers; rollback cubre imports+3 ficheros generados.
