# F9-T09-nested — Migrador legacy Hyprland→Plasma

Fixture `tests/migrate/fixtures/hypr-home/`: hyprland.conf/.lua,
10-shortcuts.conf (5 binds), hyprpaper.conf, macdock/settings.json
(3 pins), gtk-3.0/settings.ini (claro), quickshell/MacShell/Dock.qml.
Mapa: wallpaper→plasma-appletsrc Image=; gaps/borde/rounding→kwinrc
[NimbusMigrated]; binds Meta→kglobalshortcutsrc [kwin]; dark→kdeglobals
ColorScheme; monitor/pins→nota (KWin sin gaps nativos).
Tests `tests/migrate/test_hyprland_migrate.sh` (HOME temporal): 9/9
(dry-run no escribe, apply 4 tipos, informe, backup, idempotente,
rollback restaura, ajenos intactos, --json); `bash -n`+shellcheck cero.
Script `apps/nimbus-migrate/nimbus-migrate-hyprland`: dry-run defecto,
--apply con backup `nimbusshell-backup-*`, --rollback, sin root.
Límites: NO migrable Quickshell QML/hyprbars/blur/gestures/exec-once;
pins/monitor solo informe; rollback cubre 4 ficheros Plasma.
