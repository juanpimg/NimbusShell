# nimbus-lockscreen — look-and-feel `org.nimbus.desktop` (F10-T04)

Tema de bloqueo kscreenlocker estilo login macOS, arte propio (R-APPLE).
En Plasma 6.8 el greeter (`/usr/lib/kscreenlocker_greet`) carga
`contents/lockscreen/LockScreen.qml` del look-and-feel indicado en
`kscreenlockerrc [Greeter] Theme=` (verificado contra el tema
`CachyOS-Nord` en `/usr/share/plasma/look-and-feel`).

## Estructura

- `metadata.json`: `KPackageStructure Plasma/LookAndFeel`, Id
  `org.nimbus.desktop`.
- `contents/defaults`: valores mínimos (cursor breeze, `ColorScheme`
  BreezeDark, iconos breeze-dark, deco breeze). Solo se aplican al crear
  usuario; el `kdeglobals` canónico NO apunta aquí (ver abajo).
- `contents/lockscreen/`:
  - `LockScreen.qml`: raíz con la API mágica del greeter (`viewVisible`,
    `notification`, `clearPassword`, señales de suspensión) + Esc/teclas.
  - `NimbusLockUi.qml`: fondo wallpaper+velo, tarjeta glass (avatar
    circular, usuario, `PasswordField`, botón Desbloquear, errores +
    aviso Bloq Mayús, acciones suspender/hibernar/cambiar/reiniciar/
    apagar vía `SessionManagement`), pie con teclado virtual/layout.
  - `NimbusLockClock.qml`: reloj grande tabular + fecha en español.
  - `NimbusTokens.qml`: copia md5-idéntica de `packages/themes/nimbus-tokens`
    (mismo espejo que `sddm-nimbus`; re-copiar si cambian los tokens).
  - `qmldir`: singleton + componentes.

## Config (dotfiles canónicos)

- `dotfiles/.config/plasma/kscreenlockerrc`: `[Greeter] Theme=org.nimbus.desktop`,
  `[Daemon] Autolock=true Timeout=300 LockOnResume=true`.
- `kglobalshortcutsrc [ksmserver] Lock Session=Meta+Ctrl+Q` (≈Cmd+Ctrl+Q
  macOS; única excepción Ctrl, documentada aquí).
- `kdeglobals [KDE] LookAndFeelPackage` se mantiene en
  `org.kde.breezedark.desktop` a propósito: este paquete es solo lockscreen
  (+defaults) y apuntar el escritorio completo a él rompería el tema
  Plasma/colores. Separación documentada, no gap.

## Instalación en sesión

```bash
cp -r packages/themes/nimbus-lockscreen \
  ~/.local/share/plasma/look-and-feel/org.nimbus.desktop
# kscreenlockerrc ya fija Theme=org.nimbus.desktop
loginctl lock-session   # NUNCA en el host de desarrollo sin orden explícita
```

## Validación

- `qmlformat -i` + `qmllint` (rc=0, Plasma 6.8 / Qt 6.8).
- `tests/vm/nested-lock.sh`: greeter real en modo `--testing` dentro de
  sesión anidada + captura `spikes/nested/f10-lock.png`.
- Evidencia: `docs/plans/evidence/F10-T04-nested.md`.
