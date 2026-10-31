# packages/

Componentes propios de NimbusShell sobre Plasma 6.

- **Subdirectorios:** `plasma/` (plasmoids barra, menús, CC),
  `kwin/` (decoración Klassy, efectos, scripts), `themes/` (tokens, Kvantum,
  fondos, sonidos propios), `dock/` (fork/theme Krema), `kcm/` (KCM Nimbus).
- **Convención:** todo componente público se nombra `org.nimbus.*`
  (p. ej. `org.nimbus.bar`, `org.nimbus.controlcenter`).
- **Qué va:** fuentes QML/C++, presets versionados, `metadata.json`,
  licencias y atribuciones de terceros. **Qué no:** forks de Plasma/KWin
  (prohibido sin Ruling); binarios o tarballs.
