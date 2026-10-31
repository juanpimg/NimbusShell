# packages/plasma — plasmoids Nimbus (`org.nimbus.*`)

Plasmoids propios: barra superior (`org.nimbus.bar`), menú Apple
(`org.nimbus.menu`), Control Center (`org.nimbus.controlcenter`), reloj,
tray.

- **Qué va:** un subdirectorio por plasmoid con `metadata.json`
  (`X-Plasma-API`, id `org.nimbus.*`), QML, i18n es/en.
  Instalación con `kpackagetool6 -i`.
- **Qué no:** lógica de Dock (vive en `packages/dock/`) ni efectos KWin
  (`packages/kwin/`). Sin activos Apple (R-APPLE).
