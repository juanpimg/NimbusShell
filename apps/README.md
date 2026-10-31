# apps/ — aplicaciones Nimbus (`org.nimbus.*`)

Apps propias de sistema: `nimbus-welcome` (wizard primer arranque),
`nimbus-migrate` (migradores Win/Mac/legacy), `nimbus-hw` (detección
hardware), `backup` (backup/restore Konsave, `nimbus-bug-report`).

- **Convención:** IDs `org.nimbus.<app>`, UI en español + i18n en,
  sin terminal obligatoria (F9).
- **Qué va:** fuentes, `.desktop`, tests por app. **Qué no:** lógica de
  plasmoids, efectos o temas (van en `packages/`).
