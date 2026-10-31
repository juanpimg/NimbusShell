# packages/kcm — KCM Nimbus (`org.nimbus.kcm`)

Ajustes propios en Kirigami, 5 páginas, en español, sin jerga:
Apariencia, Red/BT/Impresoras, Atajos Cmd/Ctrl, Accesibilidad,
Sistema/Usuarios/Fecha-hora, Updates/Discover.

- **Qué va:** fuentes del KCM, defaults, reset canónico, tests `tests/kcm/`.
  Carga en `systemsettings` vía `kpackagetool6`.
- **Qué no:** exponer claves crípticas de KConfig sin texto llano;
  atajos `CTRL-*` nuevos por defecto (R-CTRL).
