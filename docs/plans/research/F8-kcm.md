# F8 — Brief técnico KCM Nimbus (research, no implementa)

> Fase 8 del plan Plasma (`docs/superpowers/plans/2026-10-31-plasma-migration.md`):
> F8-T01…T08. KCM Kirigami en español, 7 páginas, `systemsettings` lo carga.
> Gate F8: 5 páginas verdes + reset canónico. Prohibido tocar código: este doc
> solo fija ficheros, comandos y decisiones para el implementador.

## 1. Estructura mínima de un KCM Kirigami (KF6 / Plasma 6)

Opción elegida: **A. C++ `ManagedConfigModule` + QML por página** (robusta,
con autosave/defaults). Opción B (KCM solo-QML vía KPackage) se descarta:
sin `KConfigSkeleton` la escritura es manual y frágil; documentar como Ruling
si alguien la propone.

```
packages/kcm/kcm_nimbus/
  CMakeLists.txt
  metadata.json                 # KPlugin metadata (Id, Name, Category…)
  kcm_nimbus.desktop            # lanzador Service para systemsettings
  src/nimbusmodule.h            # class NimbusModule : KQuickAddons::ManagedConfigModule
  src/nimbusmodule.cpp          # K_PLUGIN_CLASS + KPluginFactory
  src/nimbussettings.kcfg       # KConfigSkeleton: claves propias org.nimbus.*
  src/nimbussettings.kcfgc      # generación Settings object
  qml/kcm_nimbus/main.qml       # Kirigami.PageRow + buscador + 7 páginas
  qml/kcm_nimbus/AppearancePage.qml
  qml/kcm_nimbus/NetworkPage.qml
  qml/kcm_nimbus/ShortcutsPage.qml
  qml/kcm_nimbus/AccessibilityPage.qml
  qml/kcm_nimbus/SystemPage.qml
  qml/kcm_nimbus/UpdatesPage.qml
```

`metadata.json` mínimo:

```json
{
  "KPlugin": {
    "Authors": [{ "Name": "NimbusShell" }],
    "Description": "Ajustes Nimbus (español, lenguaje llano)",
    "Description[es]": "Ajustes Nimbus (español, lenguaje llano)",
    "EnabledByDefault": true,
    "Id": "kcm_nimbus",
    "License": "GPL-3.0-or-later",
    "Name": "Nimbus",
    "Version": "0.1"
  },
  "X-KDE-System-Settings-Parent-Category": "appearance"
}
```

`src/nimbusmodule.h` (esqueleto):

```cpp
#include <KQuickAddons/ManagedConfigModule>
class NimbusModule : public KQuickAddons::ManagedConfigModule {
    Q_OBJECT
public:
    explicit NimbusModule(QObject *parent, const KPluginMetaData &data);
};
```

```cpp
// nimbusmodule.cpp
#include "nimbusmodule.h"
#include "nimbussettings.h"
K_PLUGIN_CLASS_WITH_JSON(NimbusModule, "metadata.json")
#include "nimbusmodule.moc"
NimbusModule::NimbusModule(QObject *p, const KPluginMetaData &d)
    : ManagedConfigModule(p, d) {
    setButtons(Apply | Reset | Defaults);
}
```

`kcm_nimbus.desktop` (descubrimiento por `systemsettings` vía KService):

```ini
[Desktop Entry]
Type=Application
Name=Nimbus
Name[es]=Nimbus
Exec=kcmshell6 kcm_nimbus
Icon=nimbus-settings
Categories=Qt;KDE;SystemSettings;
X-KDE-System-Settings-Parent-Category=appearance
X-KDE-PluginInfo-Name=kcm_nimbus
```

`CMakeLists.txt` mínimo (CMake + ECM + KF6):

```cmake
cmake_minimum_required(VERSION 3.29)
project(kcm_nimbus)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs KF6Defaults)
find_package(Qt6 REQUIRED Quick Qml DBus)
find_package(KF6 REQUIRED ConfigWidgets KCMUtils I18n QuickAddons Config)
kconfig_add_kcfg_files(NIMBUS_SRCS src/nimbussettings.kcfgc)
kcmutils_add_qml_kcm(kcm_nimbus SOURCES src/nimbusmodule.cpp ${NIMBUS_SRCS}
    INSTALL_NAMESPACE "plasma/kcms")
install(FILES kcm_nimbus.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(DIRECTORY qml/kcm_nimbus DESTINATION ${KDE_INSTALL_QMLDIR}/org/nimbus/kcm)
```

Build + install + descubrimiento:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build        # .so → lib/qt6/plugins/plasma/kcms/, qml → share
kbuildsycoca6 --noincremental     # refrescar KService
kcmshell6 kcm_nimbus              # test módulo aislado
systemsettings                    # debe listar "Nimbus" bajo Apariencia
```

NOTA: `kpackagetool6 -i` es para **plasmoides**, NO para KCMs C++.
El KCM se instala con `cmake --install`, nunca con `kpackagetool6`.

`main.qml`: `Kirigami.ApplicationHeaderStyle`, `Kirigami.PageRow` +
`Kirigami.SearchField` que filtra por `page.title`; cada página
`Kirigami.ScrollablePage` con `title`/`icon.name`; botones heredados del
`ManagedConfigModule` (Aplicar/Restablecer/Defaults) — no reinventar barra.

## 2. Páginas: embeber vs reescribir

Regla: **embeber KCMs/daemons existentes; reescribir solo la UI Nimbus**
(1:1 lenguaje llano + toggles propios). Embeber = botón
`kcmshell6 <kcm>` o `KCModuleProxy` embebido; nunca duplicar el backend.

| Página F8 | Estrategia | KCMs existentes reutilizados | Qué reescribe Nimbus |
|---|---|---|---|
| Apariencia (T02) | Reescribir | ninguno (lee `kdeglobals`, `kwinrc`, `plasmarc`); preview propio | tema claro/oscuro, acento, fondo NPS, Dock/barra, animaciones; llama a `scripts/apply-theme` vía KAuth/helper |
| Red/BT/Impresoras (T03) | **Embeber** | `kcm_wifi`/`kcm_networkmanagement`, `kcm_bluetooth`, `kcm_printer` (CUPS) | wrapper con estados llanos ("Conectado a…") + botones que abren cada KCM; prohibido reescribir NetworkManager/BlueZ/CUPS |
| Atajos Cmd/Ctrl (T04) | Reescribir UI, delegar daemon | `KGlobalAccel` + `kglobalshortcutsrc` (NO copiar su lógica) | toggle Meta=Cmd, cheat-sheet, reset; 20 atajos vía `kwriteconfig6`; sin binds `CTRL-*` nuevos (R-CTRL) |
| Accesibilidad (T05) | Mixta | `kcm_access` (lector Orca, sticky keys), `kcm_bell` | toggles propios: zoom KWin, contraste, reduce motion/transparency (`kwinrc`, `kdeglobals`); tests Orca |
| Sistema/Usuarios/Fecha-hora (T06) | **Embeber** | `kcm_users`, `kcm_clock` (NTP), `kcm_locale`, `kcm_energy`/`powerdevil` | wrapper llano + mensajes de error sin jerga; cambios vía KAuth (fecha/usuarios exigen root) |
| Updates/Discover (T07) | Reescribir UI, delegar backend | `PackageKit` (`org.freedesktop.PackageKit`) + app `plasma-discover` | estado, programar, botón "Abrir Discover", enlace rollback snapper; prohibido reescribir el gestor de paquetes |

Embed mecánico (QML): `KCMUtils.KCModuleProxy moduleId: "kcm_bluetooth"` si se
quiere inline, o `Qt.openUrlExternally("kcmshell6 kcm_wifi")` / `KIO::ApplicationLauncherJob`
si basta con salto. Preferir salto en MVP (menos acoples binarios), inline
solo si la página queda vacía sin ello. Documentar cada `moduleId` usado y su
paquete proveedor (si el KCM no está instalado, mostrar placeholder llano,
nunca crash).

## 3. Persistencia: KConfig, JSON, defaults, reset, backup

- **Claves propias** (tema Nimbus, layout, toggles Cmd/Ctrl, prefs Dock):
  `src/nimbussettings.kcfg` → `KConfigSkeleton`; `ManagedConfigModule`
  da gratis load/save/indicador "modificado"/Defaults. Ejemplo:

```xml
<kcfg><group name="Appearance">
  <entry name="AccentColor" type="Color" default="#0A84FF"/>
  <entry name="DarkMode" type="Bool" default="false"/>
</group></kcfg>
```

- **Claves ajenas** (KDE existentes: `kdeglobals`, `kwinrc`, `plasmarc`,
  `kglobalshortcutsrc`, `krunnerrc`): NO meterlas en el skeleton propio;
  leer/escribir con `KConfigGroup` en C++ o `kwriteconfig6`/`kreadconfig6`
  en helpers. Ejemplos:

```bash
kreadconfig6 --file kdeglobals --group General --key AccentColor
kwriteconfig6 --file kwinrc --group Effect-Overview --key Duration 250
qdbus6 org.kde.KWin /KWin reconfigure   # aplicar kwinrc en vivo
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '...'
```

- **JSON** solo para lo que KConfig no modela: pins del Dock, layout
  Launchpad (`~/.config/nimbus/dock.json`); validado con esquema + `jq empty`
  en CI; reset = borrar + regenerar defaults.
- **Defaults/Reset**: botón Defaults del módulo → `skeleton->setDefaults()`
  + re-aplicar `scripts/apply-theme`; F8-T08 exige test "reset deja estado
  canónico" (comparar `kreadconfig6` dump contra fixture).
- **Backup** (obligatorio antes de Aplicar, coherente con `install.sh`):
  copiar `~/.config/{kdeglobals,kwinrc,plasmarc,kglobalshortcutsrc,krunnerrc,nimbus/}`
  a `~/.config/nimbusshell-backup-<timestamp>/`; nunca sobrescribir backups
  ajenos; botón "Restaurar" = copiar de vuelta + `reconfigure`.
- **Privilegiados** (usuarios, NTP, impresora): vía `KAuth` action
  (`org.nimbus.kcm.save`), nunca ejecutar el KCM como root.

## 4. Tests, comandos y riesgos API KF6

```bash
# módulo aislado + suite completa
kcmshell6 kcm_nimbus
systemsettings kcm_nimbus
# smoke D-Bus y config
qdbus6 org.kde.KWin /KWin org.kde.KWin.showDebugConsole  # KWin vivo
kreadconfig6 --file kdeglobals --group General --key AccentColor
# lint QML/i18n en CI
qmllint qml/kcm_nimbus/*.qml
qmlformat -i qml/kcm_nimbus/*.qml
desktop-file-validate kcm_nimbus.desktop
# capturas VM (R-TEST: sin captura no hay verde)
kwshot --window "Ajustes Nimbus" --out /tmp/kcm-appearance.png
tests/screenshot-diff/compare.sh tests/golden/kcm-appearance.png /tmp/kcm-appearance.png --umbral 15
```

Matriz F8-T08 (`tests/kcm/`): un script por página que (1) abre la página,
(2) cambia un valor, (3) verifica con `kreadconfig6`/`qdbus6`, (4) pulsa
Reset y compara con fixture canónico. Gate F8 = 5 páginas verdes en VM.

Riesgos API KF6 (pin + CI, R-CACHYOS/R-KLASSY):

1. `KQuickAddons::ManagedConfigModule` y `kcmutils_add_qml_kcm` cambian de
   firma entre releases Plasma → pinnear Plasma/ECM, rebuild en CI por snapshot.
2. Módulos QML `org.kde.kcmutils`/`org.kde.kirigami` versionados: importar sin
   versión fija (`import org.kde.kirigami as Kirigami`) para no romper.
3. `KCModuleProxy` inline acopla ABI del KCM embebido → preferir salto
   `kcmshell6` en MVP; inline solo tras soak.
4. `systemsettings --test` no existe como flag estable: test real =
   `kcmshell6 kcm_nimbus` + `systemsettings` manual en VM con captura.
5. KAuth policies cambian de path (`/usr/share/polkit-1/actions/`) →
   instalar el `.policy` desde CMake y verificar con `pkaction --action-id`.

## 5. Mapa F8-T01…T08 → ficheros de este brief

T01 esqueleto (§1) · T02 Apariencia (§2 fila 1 + §3 apply-theme) ·
T03 Red (§2 fila 2, embeber) · T04 Atajos (§2 fila 4, R-CTRL) ·
T05 A11y (§2 fila 5) · T06 Sistema (§2 fila 6, KAuth) ·
T07 Updates (§2 fila 7, PackageKit/Discover) · T08 reset/tests (§3+§4).
