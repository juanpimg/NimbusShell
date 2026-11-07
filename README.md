# NimbusShell

> **Estado 2026-11-07 — rama `plasma-migration` / `main`.** Perfil activo:
> **KDE Plasma 6.8.2 (Wayland)** con estética **macOS Tahoe 1:1**, shaders
> **Liquid Glass** y ledger de progreso al **93.0%** (103/112). Handoff para
> sesiones limpias: [`docs/SESSION-2026-11-04-HANDOFF.md`](docs/SESSION-2026-11-04-HANDOFF.md).
> Demostración reproducible: `python3 scripts/record-nimbus-demo.py` genera
> `out/videos/` (MP4/GIF; `out/` no se versiona).

**Convierte cualquier Arch Linux instalado en el escritorio NimbusOS: Plasma 6.8.2 Wayland con flujo y estética macOS Tahoe.**

> **English:** NimbusShell turns any installed Arch system (vanilla or derivative) into the NimbusOS desktop. Documentation is primarily in Spanish.

> **Aviso importante — sin afiliación.** NimbusShell es un proyecto independiente y **no está afiliado, respaldado ni patrocinado** por CachyOS, Apple Inc. (macOS/Mac) ni por el proyecto MacShell. macOS y Mac son marcas de Apple Inc. Reutilizamos el trabajo de otros y lo citamos: [KDE Plasma](https://kde.org/plasma-desktop/) (GPL), [KWin effects Glass](https://github.com/taj-ny/kwin-effects-glass) (GPL-3.0), [Krema](https://github.com/iruzard/krema) (GPL), [MacShell](https://github.com/0-ss/MacShell) (MIT, perfil legacy), [WhiteSur](https://github.com/vinceliuice/WhiteSur-kde) (GPL-3.0) y el fondo Sequoia del US National Park Service (dominio público).

## Qué es

Un instalador (`install.sh`, idempotente y re-ejecutable) más los dotfiles
canónicos del escritorio NimbusOS. El perfil por defecto es **`plasma`**:
sesión Plasma 6.8 Wayland con barra superior propia, semáforos estilo macOS,
Dock Krema, Spotlight, Mission Control, ajustes Nimbus y tema Tahoe. El perfil
**`legacy-hypr`** queda congelado en [`legacy/hyprland/`](legacy/hyprland/)
solo como referencia histórica.

NimbusShell es la mitad "escritorio" de [NimbusOS](https://github.com/juanpimg/NimbusOS):
la ISO instalable vive allí; este repo vive aquí para que **cualquier** Arch lo aproveche.
La frontera entre ambos está en [`docs/architecture/PRODUCT-MODEL.md`](docs/architecture/PRODUCT-MODEL.md).

## Instalación en 3 pasos

```bash
git clone https://github.com/juanpimg/NimbusShell.git && cd NimbusShell
./install.sh --check    # paso 1 (opcional): qué falta o cambiaría, sin tocar nada
./install.sh            # paso 2: instala (pide sudo una vez para pacman)
# paso 3: cierra sesión y entra en Plasma (Wayland)
```

El perfil `plasma` instala **28 paquetes oficiales** de `packages/plasma.list`
(sin AUR), despliega `dotfiles/` a `$HOME` con backup previo en
`~/.config/nimbusshell-backup-*`, aplica el tema Tahoe, los scripts/efectos de
KWin, el preset del Dock y las apps de script. Nunca se ejecuta como root.

Para el perfil histórico Hyprland: `./install.sh --profile=legacy-hypr`.

## Qué despliega el perfil Plasma

- **Paquetes:** Plasma 6.8, KWin, KRunner, SDDM, Kvantum, LayerShellQt,
  power-profiles-daemon y apps base (Konsole, Dolphin, Spectacle, NetworkManager,
  firewalld). Lista fija en `packages/plasma.list`.
- **Dotfiles:** `kwinrc`, `kdeglobals`, `kwinrulesrc`, `plasmarc`, `plasma/`,
  `kglobalshortcutsrc`, presets de la barra y tema Aurorae
  `MacTahoeLiquidKde-Dark/Light`.
- **Tema Tahoe:** el instalador copia color schemes NimbusTahoe/NimbusTahoeLight,
  Kvantum, decoración Aurorae y fondos NPS (`apply-theme --resources-only`); los
  dotfiles canónicos ya activan `NimbusTahoe`/Aurorae. `scripts/apply-theme`
  completo queda para fusionar el tema en un `$HOME` existente. Los
  iconos/cursor WhiteSur se usan si están instalados; si no, Plasma cae a
  Breeze con aviso.
- **KWin:** scripts `nimbus-spotlight`, `nimbus-apps-toggle`, `nimbus-tabs`,
  `nimbus-mc`, `nimbus-zoom` y efecto `nimbus-overview`.
- **Dock:** preset `kremarc-nimbus` para Krema y launchers propios.
- **Apps de script** en `~/.local/bin`: `nimbus-hw`, `nimbus-gpu-detect`,
  `nimbus-gpu-setup`, `nimbus-migrate-desktop`, `nimbus-migrate-hyprland`,
  `nimbus-backup` y `nimbus-bug-report`.
- **Herramientas de usuario** en `~/.local/bin`: `nimbus-theme`, `apply-theme`,
  `nimbus-dock`, `nimbus-trash`, `nimbus-updates`, `nimbus-a11y`,
  `nimbus-layout`, `nimbus-keys`, `nimbus-privacy`, `nimbus-flatpak-perms`,
  `nimbus-bar-preset` y `nimbus-control`, con sus presets de barra/dock en
  `~/.local/share/nimbus/`.
- **Sonidos y marca:** tema de sonido Nimbus y logo propio N.

Los **binarios GUI** (`nimbus-bar`, `nimbus-about`, `nimbus-apps`, `nimbus-clock`,
`nimbus-help`, `nimbus-missioncontrol`, `nimbus-spotlight`, `nimbus-welcome`,
`nimbus-wallpaper`) y el módulo **KCM** se compilan con
`scripts/build-components` en `~/.local` (sin root), con `iso/build-iso.sh`
(DESTDIR a `/usr/local`) o con `scripts/dev-remote`. `install.sh` no instala el
toolchain de compilación: `--check` los marca `[PENDIENTE]` con la orden exacta,
no como fallo.

### Binarios GUI en un Arch ya instalado

```bash
./scripts/build-components --check    # qué falta y en qué prefijo
./scripts/build-components            # 9 binarios GUI + KCM en ~/.local
./scripts/build-components --filter nimbus-bar,nimbus-about
./scripts/build-components --check    # debe dar BUILD_COMPONENTS_CHECK_OK
```

El KCM se instala en `~/.local/lib/qt6/plugins/plasma/kcms/systemsettings/` y
`~/.local/share/kpackage/kcms/kcm_nimbus/`; Plasma puede requerir reiniciar
System Settings para descubrirlo. La ISO lo instala en la ruta de sistema.

Requiere `cmake`, un compilador, Qt6 y los Frameworks KF6/LayerShellQt que ya
trae el perfil Plasma. Si falta alguno, el script falla con el log en
`out/build/components/logs/`.

## `--check`

Solo lectura: no instala, no escribe, no pide sudo, no usa red. Informa qué
paquetes faltan, qué dotfiles cambiarían, si los comandos de sesión existen, si
el tema Tahoe está aplicado sin drift, si los scripts/efectos KWin y el preset
del Dock están en su sitio, y si las apps de script están desplegadas 1:1.

- Exit `0` = sistema convergido.
- Exit `1` = hay drift (con detalle `[FALTA]`).
- Exit `2` = precondición (root, sin `pacman`, repo incompleto o argumento desconocido).

Úsalo antes de instalar y para auditar después. Nota: `--check` compara contra
los dotfiles canónicos; tras personalizar tema/atajos o tras el cambio
automático de variante (`nimbus-theme`) puede mostrar drift en
`kdeglobals`/`kwinrc`. Es esperado: re-ejecutar el instalador hace backup y
restaura los canónicos.

## Desinstalación / restaurar backup

No hay "desinstalador" con borrado a ciegas por diseño:

```bash
ls ~/.config/nimbusshell-backup-*   # cada run guarda aquí lo que sobrescribió
# restaura a mano lo que quieras: cp -a ~/.config/nimbusshell-backup-<fecha>/... $HOME/
sudo pacman -Rns $(sed 's/#.*//' packages/plasma.list | grep -v '^[[:space:]]*$')  # solo si quieres quitar los paquetes
scripts/apply-theme --revert        # revierte color scheme, Kvantum y decoración
```

Los backups no se borran solos: tú decides cuándo borrarlos.

## Alcance y límites honestos

- **Alcance:** cualquier Arch instalado (vanilla, CachyOS, EndeavourOS…): si hay
  `pacman`, hay NimbusShell. El perfil Plasma no usa AUR.
- **Calamares/ISO:** el instalador del sistema y los binarios GUI viven en la ISO
  de NimbusOS (`iso/`, F12-T03); aquí no se particiona ni se compila la ISO.
- **Dock Krema:** el perfil plasma deja el preset `kremarc-nimbus` y los
  launchers, pero Krema se instala desde AUR/ISO; el perfil no usa AUR, así que
  sin Krema no hay Dock.
- **Barra superior:** `scripts/build-components` compila `nimbus-bar` en
  `~/.local/bin`; su unidad systemd/autostart se despliega desde la ISO. El
  instalador genérico prepara configuración y presets, no el binario.
- **Login intacto:** el instalador no activa ni cambia tu Display Manager. SDDM
  viene como paquete y su tema Nimbus se aplica desde la ISO.
- **Iconos WhiteSur:** si no están instalados, el tema avisa y usa Breeze como
  fallback; no se descargan activos de Apple.
- **Perfil legacy:** `legacy/hyprland/` está congelado; sus Rulings R1–R21 y
  detalles de Hyprland/Quickshell viven en
  [`legacy/hyprland/README.md`](legacy/hyprland/README.md).

## Filosofía

Respeto y colaboración con los proyectos que nos sostienen: **no reinventamos**
lo que ya existe (cero desarrollo desde cero pudiendo reutilizar) y **no
opacamos** a nadie — citamos cada fuente con repo y licencia. Las mejoras
reutilizables se proponen aguas arriba. Nuestro aporte: llevar esa experiencia a
**tu Arch ya instalado** con un instalador honesto (informa antes de tocar,
backup antes de sobrescribir, límites declarados).

## Licencia

Código propio (install.sh, lib/, scripts, apps y docs) bajo
**GPL-3.0-or-later** (ver `LICENSE`). El perfil legacy vendorea MacShell (MIT)
con los parches NimbusOS; el fondo Sequoia es dominio público (US National Park
Service vía Wikimedia Commons). Los componentes instalados conservan sus licencias.
