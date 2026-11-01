# F2-T02 — tema SDDM Nimbus renderiza (fix pantalla negra)

## Causa raíz (doble, verificada con evidencia)

1. **`metadata.desktop` sin `QtVersion=6`** (hallazgo researcher, confirmado en
   fuente SDDM v0.21.0 `src/common/ThemeMetadata.cpp:64`:
   `settings.value("SddmGreeterTheme/QtVersion", 5)`). Sin la clave, SDDM
   arranca `/usr/bin/sddm-greeter` (Qt5), inexistente en imagen solo-Qt6 →
   greeter muerto, negro sin fallback. Breeze funciona porque la declara.
2. **`import SddmComponents 2.0` en `Main.qml` abortaba la carga del QML.**
   El módulo exporta su propio `Button` (Rectangle-based, sin `contentItem`)
   que gana la resolución de nombre frente a `QtQuick.Controls` →
   `Main.qml:158: Cannot assign to non-existent property "contentItem"` →
   `QQuickView::Error`, sin rootObject (en el greeter real: fallback al tema
   embebido o negro). Reproducido con harness Qt6 que replica el entorno del
   greeter (`GreeterApp.cpp`: `SizeRootObjectToView` + context properties
   `config/sddm/userModel/sessionModel/keyboard/screenModel`).

Secundarios (mismo síntoma parcial): roles `UserModel` mal
(`UserRole+2/+3` = RealName/HomeDir; correcto `+1/+2` según
`UserModel.h` v0.21.0), avatar leía `userList.count` inexistente (siempre
`?`), `SessionBar` en una fila desbordaba la tarjeta (botones cortados).

No tocado: raíz fija 1920×1080 (el greeter usa `SizeRootObjectToView`, la
reescala; igual que Breeze 1600×900), `nimbus-installed-setup` (el orquestador
activará `SDDM_THEME=nimbus` solo si esto pasa).

## Fix (mantiene diseño Nimbus, sin activos Apple)

- `metadata.desktop`: `QtVersion=6`.
- `Main.qml`: eliminado `import SddmComponents 2.0` (documentado como
  NimbusOS Ruling en el propio fichero); roles `+1/+2` en selector y
  `sddm.login`; avatar/`userName` leen `users.length`.
- `components/SessionBar.qml`: dos filas (selectores / energía).
- `NimbusTokens.qml` intacto. Nota: el README afirma copia md5-idéntica de
  `nimbus-tokens`, pero ya divergía en HEAD (e8b8… vs 2ad9…); no se introduce
  divergencia nueva.

## Salida de verificación (host, sin root, sin SDDM)

- Harness Qt6.12 offscreen (contexto = `GreeterApp.cpp` real, roles =
  `UserModel.h`/`SessionModel.h` v0.21.0):
  - Antes: `status=Error`, 1 error (`contentItem`), sin rootObject.
  - Después: `status=Ready`, 0 errores, 996011/1024000 px no negros.
- `qmllint` (Main + tokens + components): exit 0.
- `qmlformat` aplicado a Main.qml y SessionBar.qml.
- `tests/sddm/test_theme.sh`: PASS (test-mode SKIP: sin `sddm-greeter` ni
  Xvfb en el host).
- `bash -n` + `shellcheck -S warning`: cero warnings.

## Fix v2 — greeter real sin Controls (commit encima de 738f82f)

La VM (out8, SDDM 0.21, `sddm-greeter-qt6 --test-mode`) con el tema
desplegado cayó al fallback Breeze con:

`Main.qml:158:17: Cannot assign to non-existent property "contentItem"`

Nota: línea 158 = `contentItem` del fichero **pre-fix** (tras el fix v1 está
en la 185); el despliegue en VM pudo ser anterior. En cualquier caso, se
elimina la clase entera de fallo: el tema ya **no usa `QtQuick.Controls`
ni `SddmComponents`** (solo QtQuick + QtQuick.Layouts + tipos propios):

- `Main.qml`: `TextField` → `Item` + `TextInput` (placeholder propio,
  `onAccepted`, `Keys.onEscapePressed` intactos); `Button` login →
  `NimbusButton` (nuevo `components/NimbusButton.qml`: Rectangle +
  MouseArea + Text, foco teclado con Return/Espacio).
- `UserSelector.qml`: delegado `Button` → `Rectangle` + `MouseArea`
  (mismo look: seleccionado `#0A84FF`, resto con borde).
- `SessionBar.qml`: `ComboBox` → selector cíclico propio (clic =
  siguiente sesión; teclado oculto si no hay layouts); `Button` →
  `NimbusButton` flat.
- `LoginClock.qml`: quitado import Controls sin uso. `qmldir`: registra
  `NimbusButton`.
- `tests/sddm/test_theme.sh`: nuevo check "sin contentItem/background de
  Controls" (ignora comentarios) + check de imports.

Verificación host: harness Qt6 offscreen `status=Ready`, 0 errores,
996143/1024000 px no negros; `qmllint` 0; `test_theme.sh` PASS (test-mode
SKIP). Captura `spikes/nested/sddm-nimbus-greeter.png` regenerada sin
Controls (placeholder, botón, selector cíclico `plasma`, energía OK).

## Captura / límite

- `spikes/nested/sddm-nimbus-greeter.png` (1280×800, offscreen Qt6 +
  software): fondo Sequoia NPS, reloj 24h + fecha ES, tarjeta glass con
  avatar `N`, usuario, contraseña, botón `#0A84FF`, sesión `plasma`,
  Reiniciar/Apagar. Nota: lista 2 usuarios = artefacto del modelo fake del
  harness; en VM habrá 1.
- LÍMITE: sin `sddm-greeter-qt6 --test-mode` ni Xvfb en el host; pendiente
  validación real en VM (F2-T08): `[Theme] Current=nimbus` + foto de
  pantalla del greeter.
