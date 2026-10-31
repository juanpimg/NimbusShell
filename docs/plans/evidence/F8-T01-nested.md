# F8-T01 — Evidencia nested (KCM Nimbus esqueleto, 6 páginas)

## Patrón vigente medido (Plasma 6.8.2 / KF6 6.31)
- Clase base: `KQuickConfigModule` (`KCMUtilsQuick`). El brief `F8-kcm.md §1`
  propone `KQuickAddons::ManagedConfigModule`, que **no existe** en KF6
  instalado (`/usr/include/KF6` no trae `KQuickAddons`) → Ruling F8-T01-API.
- Sin `kconfig_compiler_kf6` en el host → sin `.kcfgc`; persistencia manual
  con `KConfigGroup` + `load()/save()/defaults()` (Ruling F8-T01-NOKCFGC).
- Sin `extra-cmake-modules` (no instalable: prohibido tocar el host) →
  `CMakeLists.txt` autocontenido con `GNUInstallDirs` que replica el layout
  de `kcmutils_add_qml_kcm` (Ruling F8-T01-NOECM).
- QML embebido en qrc con prefijo `:/kcm/kcm_nimbus/` y **alias sin `ui/`**
  (medido: el cargador pide `main.qml`, no `ui/main.qml`; el primer nested
  falló con «No se ha podido encontrar el recurso /kcm/kcm_nimbus/main.qml»).
- Instalación: `.so → lib/qt6/plugins/plasma/kcms/systemsettings/`
  (namespace canónico, como `kcm_access.so`), `.desktop → share/applications`,
  fallback KPackage en `share/kpackage/kcms/kcm_nimbus/`.

## Ficheros (`packages/kcm/kcm_nimbus/`)
- `CMakeLists.txt`, `kcm_nimbus.qrc`, `kcm_nimbus.desktop`,
  `package-metadata.json` (fallback KPackage).
- `src/nimbusmodule.{h,cpp}` + `src/metadata.json`
  (`K_PLUGIN_CLASS_WITH_JSON`, `KPlugin Id=kcm_nimbus`,
  `X-KDE-System-Settings-Parent-Category=appearance`).
  Propiedades reales: `darkMode`/`accentColor` (kdeglobals `[General]`
  ColorScheme + `[KDE]` LookAndFeelPackage); `openKcm()`/`openApp()` para
  salto a KCMs existentes; `save()` invoca `scripts/nimbus-theme` si existe.
- `ui/main.qml` (cabecera Nimbus + `SearchField` que filtra + sidebar 240px
  con las 6 páginas + `StackLayout`), `ui/AppearancePage.qml` (radios
  Claro/Oscuro + acento con `ColorDialog`, control real),
  `ui/NimbusPlaceholder.qml` + 5 páginas (`Network/Shortcuts/Accessibility/
  System/Updates`) con botones de salto y mensaje si el destino no existe.
- i18n: `i18n()` global en todos los QML (patrón de `kcm_networkmanagement`
  stock), títulos centralizados en `pageDefs` de `main.qml`; `.ts` en F11-T05.

## Build / instalación / tests
- `cmake -B /tmp/nimbus-kcm-build` + `cmake --build`: OK, **0 warnings**.
- `DESTDIR=/tmp/nimbus-kcm-prefix cmake --install`: `.so` + `.desktop` +
  KPackage OK.
- `qmllint` (8/8 ficheros): **0 errores**. `desktop-file-validate`: OK.
- `kcmshell6 --list | grep nimbus` → `kcm_nimbus - Ajustes Nimbus…` ✓.
- `kcmshell6 --smoke-test kcm_nimbus` → rc=0, sin errores.
- Nested (`tests/kcm/nested-kcm.sh`, kwin virtual `--no-lockscreen`,
  HOME/XDG temporales, overlay por `QT_PLUGIN_PATH`+`XDG_DATA_DIRS`):
  `spikes/nested/f8-kcm.png` muestra el KCM abierto con las **6 páginas
  visibles** en el sidebar, página Apariencia con Oscuro marcado y
  `#0A84FF`; **0 errores QML** en `spikes/nested/f8-kcm.log` (no se commitea).

## Trampas cazadas (para F8-T02…T08)
1. `QQC2.StackLayout` no existe: `StackLayout` está en `QtQuick.Layouts`.
2. `ComboBox.onActivated` dispara al asignar el modelo y corrompe el estado
   antes de input del usuario → radios con `checked` derivado de `kcm`.
3. `XDG_CONFIG_DIRS` heredado del host mete `kdedefaults/kdeglobals`
   (`Sweet`, sin «Dark») por cascada KConfig y el KCM arrancaba en claro:
   el harness fija `XDG_CONFIG_DIRS` a un dir temporal vacío.
4. `kwin_wayland --virtual` bloquea la sesión solo (`--immediateLock`):
   usar `--no-lockscreen` en harnesses.
5. `pkill -f kscreenlocker_greet` se mata a sí mismo (coincide con su propia
   línea): usar patrón `[k]screenlocker_greet`.
6. El stderr del loader del KCM no llega al log del harness (proceso hijo);
   el `QML_ERRORS=0` del harness solo cubre el proceso padre: los errores
   QML visibles salen en la propia ventana (foto) — aquí, ninguno.
