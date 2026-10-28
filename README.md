# NimbusShell

**Convierte cualquier Arch Linux instalado en el escritorio NimbusOS: Hyprland + MacShell con estética y flujo de trabajo estilo macOS.**

> **English:** NimbusShell turns any installed Arch system (vanilla or derivative) into the NimbusOS desktop. Documented primarily in Spanish.

> **Aviso importante — sin afiliación.** NimbusShell es un proyecto independiente y **no está afiliado, respaldado ni patrocinado** por CachyOS, Apple Inc. (macOS/Mac) ni por el proyecto MacShell. macOS y Mac son marcas de Apple Inc. Reutilizamos el trabajo de otros y los citamos: [CachyOS](https://cachyos.org) (base original del sistema), [MacShell](https://github.com/0-ss/MacShell) (capa visual, MIT), [Hyprland](https://hyprland.org) (compositor), [WhiteSur](https://github.com/vinceliuice/WhiteSur-gtk-theme) (temas GTK) y la tienda [pamac](https://github.com/manjaro/pamac) (instalador gráfico, GPL).

## Qué es

Un instalador (`install.sh`, idempotente y re-ejecutable) más los dotfiles canónicos del escritorio NimbusOS. Lo corres en tu Arch ya instalado y obtienes: sesión Hyprland flotante con semáforos nativos, barra y Dock MacShell, Spotlight, Mission Control, Nautilus estilo Finder, tienda pamac + Flathub y power-management de laptop — sin reinstalar nada.

NimbusShell es la mitad "escritorio" de [NimbusOS](https://github.com/juanpimg/NimbusOS): la ISO instalable vive allí; este repo vive aquí para que **cualquier** Arch lo aproveche.

## Instalación en 3 pasos

```bash
git clone https://github.com/juanpimg/NimbusShell.git && cd NimbusShell
./install.sh --check    # paso 1 (opcional): qué falta o cambiaría, sin tocar nada
./install.sh            # paso 2: instala (pide sudo una vez al inicio)
# paso 3: cierra sesión y entra en Hyprland (tu DM o `Hyprland` desde TTY)
```

Detalles: instala 106 paquetes oficiales vía pacman, 6 AUR vía paru (lo instala o compila si falta, **nunca como root**), despliega `dotfiles/` a `$HOME` con backup previo (`~/.config/nimbusshell-backup-*`), aplica fondo, fuentes, Nautilus estilo Finder, habilita `auto-cpufreq`/`thermald`/`bluetooth`, añade Flathub y verifica (`hyprland --verify-config` con HOME temporal).

## `--check`

Solo lectura: no instala, no escribe, no pide sudo. Informa qué paquetes faltan, qué dotfiles cambiarían, si los binarios/scripts/sonidos/fondo/logo están en su sitio, si el tema de iconos coincide en las 3 configs y si los servicios están habilitados. También comprueba `paru`, `hyprland --verify-config` con HOME temporal, Flathub y el conflicto `power-profiles-daemon`/`auto-cpufreq`. Exit `0` = sistema convergido, exit `1` = hay drift. Exit `2` = precondición (root, sin `pacman`, repo incompleto, argumento desconocido). Úsalo antes de instalar y para auditar después.

## Desinstalación / restaurar backup

No hay "desinstalador" con borrado a ciegas por diseño:

```bash
ls ~/.config/nimbusshell-backup-*   # cada run guarda aquí lo que sobrescribió
# restaura a mano lo que quieras: cp -a ~/.config/nimbusshell-backup-<fecha>/... $HOME/
sudo pacman -Rns $(grep -vE '^\s*(#|$)' packages.nimbus.conf) $(grep -vE '^\s*(#|$)' packages.nimbus-aur.txt)  # solo si quieres quitar los paquetes
```

Los backups no se borran solos: tú decides cuándo borrarlos.

## Alcance y límites honestos

- **Alcance:** cualquier Arch instalado (vanilla, CachyOS, EndeavourOS…): si hay `pacman`, hay NimbusShell. En Arch vanilla `paru` se compila desde el AUR automáticamente y los 2 paquetes `lib32-*` se omiten con AVISO (necesitan `[multilib]` en `/etc/pacman.conf`; actívalo y re-ejecuta para soporte 32-bit).
- **Calamares (instalador del sistema) NO incluido:** vive en la ISO de NimbusOS, aquí no pinta nada — ya tienes tu sistema instalado.
- **Login intacto:** no tocamos tu Display Manager ni tu greeter (`greetd` es ISO, R1). Entras a Hyprland desde lo que ya uses.
- **Tuning de sistema ISO no incluido:** `etc/` de NimbusOS (greetd, modprobe, udev, sysctl, dconf db del sistema, auto-cpufreq.conf…) no se despliega; los ajustes con efecto equivalente a nivel usuario (Nautilus Finder, fuentes) sí se aplican.
- **Plugin hyprbars:** `hyprland --verify-config` no carga plugins `.so` sin una sesión Hyprland activa; tanto `--check` como `[8/8]` inspeccionan el log del validador y distinguen este SKIP conocido de errores de sintaxis reales (permitiendo `CHECK VERDE` tras la instalación si no hay otro drift). Errores reales de configuración o sintaxis fallan de inmediato.
- **Wayland/Hyprland 0.56:** la sesión canónica es Lua; el `.conf` queda como fallback, igual que en NimbusOS.

## Exclusiones respecto a NimbusOS (Rulings)

Derivado de `packages.nimbus.x86_64.append` de NimbusOS. R1: `greetd` fuera (tu login no se toca). R2: `whitesur-gtk-theme whitesur-icon-theme pamac-aur hyprshell hyprland-plugin-hyprbars` fuera de la lista oficial porque son AUR (viven en `packages.nimbus-aur.txt`). R3: `plymouth`/Calamares ni siquiera están en el append aguas arriba (Ruling documentado allí); nada que excluir. Se **mantienen** a conciencia: power laptop + GPU híbrida (también sirven en escritorio instalado), `iptables qt6-multimedia-ffmpeg tesseract-data-eng` (fijan prompts interactivos) y las toolchains AUR (paru las pediría igual). Divergencia en dotfiles, documentada: se excluye `Desktop/Instalar NimbusOS.desktop` (lanza Calamares, ISO) y se añaden `~/.local/bin/macshell` + `~/.local/bin/macshell-start` + `~/.local/bin/nimbus-minimize-toggle` (equivalentes a nivel usuario de `/usr/bin` de la ISO) y `assets/sequoia-light.jpg` (fondo canónico, dominio público US NPS, idéntico al de la ISO). R4: `~/.local/bin/nimbus-screenshot` (script propio grim+slurp para SUPER+SHIFT+3/4/5; los binds lo exigían y no existía). R5: `assets/nimbus-logo.svg` → `/usr/share/nimbus/branding/` (marca N propia para barCustomLogoPath; sin ella la barra queda sin logo en modo custom). R6: `MacShell/WindowBar.qml` (glifos de semáforos solo al hover, como macOS; el ajuste `tlAlwaysSymbols` existía pero sin cablear; propuesta aguas arriba: cablearlo al `visible` del glifo). R7: overlay WindowBar ENCENDIDO (`MacBar windowBar:true` + instanciado en `shell.qml`; era código huérfano que nadie cargaba) con hyprbars como tira sin botones ni título (sin doble juego; arrastre y doble-click siguen nativos).

## Filosofía

Respeto y colaboración con los proyectos que nos sostienen: **no reinventamos** lo que ya existe (cero desarrollo desde cero pudiendo reutilizar) y **no opacamos** a nadie — citamos cada fuente con repo y licencia. Las mejoras reutilizables se proponen aguas arriba. Nuestro aporte: llevar esa experiencia a **tu Arch ya instalado** con un instalador honesto (informa antes de tocar, backup antes de sobrescribir, límites declarados).

## Licencia

Código propio (install.sh, listas, docs) bajo **GPL-3.0-or-later** (ver `LICENSE`). Dotfiles vendorean [MacShell](https://github.com/0-ss/MacShell) (MIT) con los parches NimbusOS; fondo Sequoia: dominio público (foto US National Park Service vía Wikimedia Commons). Componentes instalados conservan sus licencias.
