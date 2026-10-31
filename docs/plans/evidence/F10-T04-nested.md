# F10-T04 nested — lockscreen Nimbus (kscreenlocker)

Fecha: 2026-10-31. Host Plasma 6.8.2 Wayland. Harness nuevo
`tests/vm/nested-lock.sh` (patrón `nested-plasma.sh`: HOME/XDG temporales,
`dbus-run-session`, `kwin_wayland --virtual` 1280×800, `plasmashell`,
cleanup por trap; NUNCA `--replace`, ni `~/.config`, ni root, ni red).
Comando canónico:

```
bash tests/vm/nested-lock.sh --out spikes/nested --timeout 60
```

## Mecanismo real verificado (Plasma 6.8)

- `kscreenlocker_greet` (`/usr/lib/kscreenlocker_greet --help`) carga
  `contents/lockscreen/LockScreen.qml` del look-and-feel de
  `kscreenlockerrc [Greeter] Theme=` (confirmado contra el tema
  `CachyOS-Nord`; `org.kde.breeze.desktop` NO trae lockscreen propio: el
  fallback vive en `plasma/shells/org.kde.plasma.desktop`).
- API mágica replicada: `viewVisible`, `notification`, `clearPassword`,
  señales `suspendToDisk/suspendToRam`; contexto `authenticator`
  (`startAuthenticating/respond/stopAuthenticating`, `graceLocked`,
  `pamTimeout`, señales `failed/succeeded/...Changed` verificadas en
  `kscreenlocker_greet.qmltypes`) + `wallpaper`, `kscreenlocker_userName`,
  `kscreenlocker_userImage`; acciones vía `SessionManagement`
  (`suspend/hibernate/switchUser/requestReboot/requestShutdown`,
  `sessionsprivateplugin.qmltypes`).

## Resultados

| Test | Resultado |
|---|---|
| `qmlformat -i` + `qmllint` (4 QML) | rc=0, 0 warnings |
| `metadata.json` | JSON válido, Id `org.nimbus.desktop` |
| `shellcheck -S warning nested-lock.sh` | 0 warnings |
| Greeter real `--testing --immediateLock` en nested | VIVO (pid verificado), 0 errores QML en log |
| `spikes/nested/f10-lock.png` (spectacle, greeter real) | SÍ: fondo + reloj `23:12` + fecha ES renderizados por nuestro QML |
| `spikes/nested/f10-lock-card.png` (preview offscreen `qmlscene6` + stub auth, `uiVisible=true`) | SÍ: tarjeta glass (avatar N, usuario, contraseña, Desbloquear, Suspender/Cambiar/Reiniciar/Apagar en 2 filas sin recorte, pie Esc) |
| Cleanup | 0 procesos resto; 1 dir temp huérfano del run abortado por timeout limpiado a mano |

## Bloqueo real (PAM unlock): NO

- El greeter `--testing` usa autenticador ficticio: prueba carga+render,
  NO desbloqueo PAM. `loginctl lock-session` NO se usó: en nested no hay
  sesión logind y en el host bloquearía la pantalla real del usuario
  (prohibido por AGENTS.md). Desbloqueo real pendiente de VM con usuario
  de pruebas (puerta F10-T04→VM).
- La tarjeta arranca oculta (`uiVisible=false`, como upstream: cualquier
  tecla la muestra, Esc la oculta); por eso `f10-lock.png` solo muestra
  reloj+fecha. Sin inyector de teclas en el host (`wtype/ydotool`
  ausentes, prohibido instalar), la tarjeta se valida en el preview
  offscreen, que ejecuta el MISMO `NimbusLockUi.qml` (copia byte-idéntica
  al momento del render; revalidar si cambia).

## Estructura entregada

`packages/themes/nimbus-lockscreen/` (`metadata.json`,
`contents/defaults`, `contents/lockscreen/`: `LockScreen.qml`,
`NimbusLockUi.qml`, `NimbusLockClock.qml`, `NimbusTokens.qml` copia
md5-idéntica de `nimbus-tokens`, `qmldir`, `README.md`).
Config: `kscreenlockerrc` (`Theme=org.nimbus.desktop`, `Autolock=true`,
`Timeout=300`, `LockOnResume=true`), `kglobalshortcutsrc [ksmserver]
Lock Session=Meta+Ctrl+Q` (única excepción Ctrl, ≈Cmd+Ctrl+Q macOS).
`kdeglobals LookAndFeelPackage` se mantiene en breezedark a propósito:
el paquete es solo lockscreen y apuntar el escritorio a él rompería el
tema (separación documentada en el README del tema).

## Límites

- Iconos de acciones y estilo Breeze del campo: en offscreen no cargan
  tema de iconos; en greeter real cargan Breeze (sin captura con tarjeta
  en greeter por falta de inyector de teclas).
- Sin `contents/previews`, `splash`, `logout`, `osd`: fuera del alcance
  F10-T04 (solo kscreenlocker).
