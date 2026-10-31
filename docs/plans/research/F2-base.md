# F2 Base Plasma/ISO — brief técnico (research, 2026-10-31)

Fuentes: ArchWiki (KDE, SDDM, NVIDIA, greetd) verificado 2026-10-31;
`pacman -Si` en host CachyOS (extra/cachyos-extra-v3); AUR klassy;
upstream archiso (profiledef.sh, packages.$arch) y docs Calamares
(packages.conf, settings.conf). Pins propuestos = snapshot CachyOS
2026-10; **validar en VM F2-T01** antes de congelar en `packages/plasma.list`.

## 1. Paquetes Plasma 6 (Arch/CachyOS) — F2-T01

Baseline medido en host: **Plasma 6.8.2, Frameworks/krunner 6.31.0,
SDDM 0.21.0, Kvantum 1.1.8, PPD 0.30, plasma-meta 6.8-1**.

| Paquete | Repo | Versión pin propuesta | Notas |
|---|---|---|---|
| `plasma-meta` | extra | 6.8-1 | Meta-paquete canónico (recomendación ArchWiki + upstream KDE packaging recommendations). Alternativa mínima: `plasma-desktop` solo. El grupo `plasma` equivale pero el meta es versionable → preferir meta. |
| `kwin` | extra | 6.8.2 | Compositor Wayland. Parte de plasma-meta. |
| `krunner` | extra | 6.31.0 | Paquete separado (versión Frameworks). Parte de plasma-meta vía `milou`/workspace; listar explícito para F6. |
| `plasma-login-manager` | extra | 6.8.2 | **Nuevo DM por defecto de KDE** (fork de SDDM, greeter + KCM). Parte de plasma-meta 6.8. Decisión F2-T02: evaluar vs `sddm`. |
| `sddm` | extra | 0.21.0 | Alternativa estable y documentada. Greeter X11 por defecto; Wayland experimental. |
| `sddm-kcm` | extra | 6.8.2 | KCM login screen (aplica settings Plasma a SDDM). |
| `kde-gtk-config` | extra | 6.8.2 | Sincroniza KDE→GTK (breeze-gtk). Ojo: sobrescribe `~/.config/gtk-3.0/settings.ini` en cada arranque. |
| `kvantum` (+ `kvantum-qt5` si se necesita Qt5) | extra | 1.1.8 | Motor de temas Qt. Solo `kvantum` Qt6 basta (Qt5 fuera de repos principales). |
| `klassy` | **AUR** | **6.7.3** (para Plasma ≥6.6.1; KDecoration3, Qt6-only) | NO está en repos. `klassy-bin` (binario OBS home:/paulmcauley) como fallback si el build AUR falla. Requiere `kdecoration ≥6.3`. Riesgo: el binario OBS y el AUR han divergido en checksum alguna vez (feb-2026) → pin por commit + hash propio. `klassy-qt5` innecesario (Qt5 fuera). |
| `layer-shell-qt` | extra | 6.8.2 | Requerido por Dock (F5) y por greeter SDDM-Wayland. (`layer-shell-qt5` solo AUR, no usar.) |
| `power-profiles-daemon` | extra/cachyos | 0.30 | Dependencia opcional de `powerdevil` (incluido en plasma-meta) para perfiles de energía. CachyOS puede traer `tuned-cachy-ppd` como sustituto → **fijar uno solo** (PPD upstream) para evitar conflicto. |
| `powerdevil` | extra | 6.8.2 | Gestión energía Plasma (en plasma-meta). |
| Extras ISO/live | extra | — | `calamares`, `archiso`, `mkinitcpio-archiso` (obligatorio en packages), `firewalld`, `networkmanager`, `plasma-nm`, `konsole`, `dolphin`, `spectacle`, `mesa`, `vulkan-radeon/intel`, `nvidia-open-dkms` (solo perfil NVIDIA/offline). Sin AUR no fijado en ISO (R-CACHYOS). |

Comandos aceptación F2-T01:
`plasmashell --version` → 6.8.2; `kwin_wayland --version` → 6.8.2;
`pacman -Q plasma-meta kwin krunner sddm kde-gtk-config kvantum klassy layer-shell-qt power-profiles-daemon`.

## 2. Sesión Wayland: SDDM vs greetd vs plasma-login-manager — F2-T02

**Recomendación: SDDM (X11-greeter por defecto) para F2; evaluar
`plasma-login-manager` en paralelo; descartar greetd salvo Ruling.**
Motivos: SDDM es lo documentado y estable; su greeter Wayland sigue
"experimental" (ArchWiki); greetd+`startplasma-wayland` funciona pero
salta el stack `auth` PAM → **kwallet no se desbloquea en autologin**
(requiere `pam_fde_boot_pw`, AUR) y pierde el KCM de login;
plasma-login-manager es el futuro upstream pero joven (llega con
plasma-meta 6.8) → spike comparativo, no apuesta ciega.

Arranque sesión (común a los tres):
`/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland`
(desktop file `/usr/share/wayland-sessions/plasma.desktop`).

Archivos exactos:

- SDDM: defaults en `/usr/lib/sddm/sddm.conf.d/default.conf` (NO tocar);
  overrides en `/etc/sddm.conf.d/*.conf`. Autologin VM:
  `/etc/sddm.conf.d/autologin.conf` con `[Autologin] User=nimbus
  Session=plasma`. Tema: `[Theme] Current=nimbus`. Sincronizar
  monitores/input del greeter: copiar `kwinoutputconfig.json` y
  `kcminputrc` a `/var/lib/sddm/.config/` (chown sddm:sddm), o botón
  "Apply Plasma Settings" del KCM. Preview tema:
  `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/breeze`.
- SDDM-Wayland (solo si el spike lo pide): `/etc/sddm.conf.d/10-wayland.conf`
  con `[General] DisplayServer=wayland` +
  `GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell` +
  `[Wayland] CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1`.
  Requiere `layer-shell-qt`. Layout teclado vía `XKB_DEFAULT_LAYOUT`.
- greetd (alternativa): `/etc/greetd/config.toml` con `[initial_session]
  command="startplasma-wayland" user="nimbus"` (autologin) y
  `[default_session] command="/usr/lib/plasma-dbus-run-session-if-needed
  /usr/bin/startplasma-wayland" user="greeter"`. Servicio
  `greetd.service` en vez de `sddm.service`.
- plasma-login-manager: `/etc/plasmalogin.conf.d/autologin.conf` con
  `[Autologin] User=nimbus Session=plasma.desktop`. Desactivar
  `sddm.service` antes; el usuario `sddm` puede eliminarse tras migrar.

Aceptación F2-T02: boot → greeter → Plasma en <20 s en VM; captura;
`loginctl show-session $(loginctl | awk '/nimbus/{print $1}') -p Type`
→ `Type=wayland`.

## 3. Configs base Plasma — F2-T03

Viven en `~/.config/` (sistema: `/etc/xdg/` como default global).
**Regla: escribir solo vía `kwriteconfig6`, nunca heredocs**, para no
romper tipos KConfig:

```
kwriteconfig6 --file kdeglobals --group General --key ColorScheme NimbusDark
kwriteconfig6 --file kwinrc --group Windows --key BorderlessMaximizedWindows true
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false   # VM
```

Claves por fichero (defaults Nimbus propuestos; validar cada una con
`kreadconfig6` tras aplicar en VM):

- `kdeglobals`: `[General] ColorScheme`, `Name`; `[KDE] SingleClick`
  (=false, doble clic macOS), `LookAndFeelPackage`; `[Fonts] font=Inter,11,-1,5,50,0,0,0,0,0`
  (formato Qt: familia,tamaño,...); `[Icons] Theme`.
- `kwinrc`: `[Windows] BorderlessMaximizedWindows=true` (eficiencia),
  `FocusPolicy=ClickToFocus`, `Placement=Centered` (F4-T07 pedirá
  1100x700+centrar vía `kwinrulesrc`, no aquí); `[Compositing]
  Enabled=true`, `GLCore=true`; `[Effect-Overview] BorderActivate=9`
  (solo si se usa); `[NightColor] Active=false` (default off).
- `kglobalshortcutsrc`: NO escribir a mano de inicio — se genera con
  `kglobalaccel`; F2 solo fija que el componente `kwin` use Meta
  (Cmd) y reserva que no haya binds `CTRL-*` nuevos (R-CTRL). Fijar en
  F4-T08.
- `plasmashellrc`: `[PlasmaViews][Panel...] floating=true` (panel
  flotante F2-T05); el layout de applets vive en
  `plasma-org.kde.plasma.desktop-appletsrc` (F2-T05).
- `plasmarc`: `[KUserFeedback] statisticsEnabled=false` como primera
  aproximación de telemetría off — **verificar en VM** con
  `grep -ri feedback ~/.config | head` porque KDE ha movido esta clave
  entre releases; lo que vale es el Accept de F2-T09 (UI muestra
  "no enviar"), no el nombre de la clave.
- `krunnerrc`: `[General] FreeFloating=true` (base del skin
  fullscreen F6-T01); plugins se activan en F6.
- `kscreenlockerrc`: `[Daemon] Autolock=false LockOnResume=false
  LockOnStart=false` en VM (seguridad real se prueba en F10-T04);
  tema Nimbus en F10.
- `startkderc`: `[General] systemdBoot=true` (default Plasma ≥5.25;
  NO poner false — rompería el arranque systemd-user).

Aceptación F2-T03: usuario nuevo (`useradd` + skel de `dotfiles/`)
hereda defaults tras primer login; `install.sh --check` valida cada
clave con `kreadconfig6`.

## 4. ISO netinstall — F2-T06/T07 (perfil archiso + Calamares)

### 4a. Perfil archiso (`iso/profile/`)

Variables `profiledef.sh` vigentes (archiso ≥v86: bootmodes unificados,
sin sufijos de arquitectura):

```
iso_name="nimbusos"; iso_label="NIMBUS_$(date +%Y%m)"; iso_publisher="NimbusOS"
iso_application="NimbusOS Plasma netinstall"; iso_version="2026.11.01"
install_dir="nimbus"; buildmodes=('iso'); arch="x86_64"
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"; airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M' '-Xcompression-level' '19')
file_permissions=(["/etc/shadow"]="0:0:400" ["/root"]="0:0:750")
```

`packages.x86_64`: un paquete por línea, `#` comentarios; obligatorios
`mkinitcpio mkinitcpio-archiso`; base + `plasma-meta calamares
networkmanager firewalld power-profiles-daemon powerdevil sddm
layer-shell-qt kvantum kde-gtk-config konsole dolphin spectacle`.
NVIDIA **fuera** del netinstall (se instala post-detección, F2-T10);
solo en ISO Full F12. `pacman.conf`: repos CachyOS pinneados a snapshot
+ `multilib` para lib32. Build: `mkarchiso -w /tmp/work -o out
iso/profile/`; reproducibilidad vía `SOURCE_DATE_EPOCH` (el
`iso_version` deriva de ella).

### 4b. Calamares (`iso/calamares/`)

`settings.conf`: secuencia mínima
`[welcome, locale, keyboard, partition, users, displaymanager,
packages, fstab?, grub?, umount, finished]` + `netinstall` (grupo
`packagechooser`/`netinstall.conf` con la lista Plasma). `branding.desc`:
`componentName: nimbus`, `welcomeStyleCalamares: true`,
strings es/en, sin activos Apple (R-APPLE). Módulos:

- `partition.conf`: particionado guiado + **LUKS opcional/recomendado**
  (`enableLuks` / passphrase en el paso partition; documentar que el
  cifrado se ofrece, no se impone — F2-T09).
- `users.conf`: usuario + autologin opcional (`doAutologin`).
- `displaymanager.conf`: `displaymanagers: [sddm]`,
  `basicSetup: true`, `sysconfigSetup` para autologin post-instalación.
- `packages.conf`: operaciones `install` (lista netinstall descargada)
  / `try_install` para opcionales; `remove` de paquetes solo-live.
- `locale.conf` + `keyboard.conf`: es-ES por defecto, selector visible.

Aceptación F2-T06: `mkarchiso` produce ISO booteable (hash registrado).
F2-T07: instalación completa Calamares en VM. F2-T08: VM limpia →
Calamares → primer boot Plasma <20 min instalación, 0 errores críticos
(`journalctl -p 3 -b`).

## 5. Seguridad, NVIDIA, energía — F2-T09/T10

- **LUKS**: vía módulo `partition` de Calamares (paso "Cifrar sistema").
  Verificar post-instalación: `lsblk -f | grep crypto_LUKS`.
- **Telemetría off**: `kwriteconfig6` (clave §3, a validar) + comprobar
  en System Settings → User Feedback que figura desactivado; evidencia:
  captura + `grep -ri "feedback\|telemetry" ~/.config | head`.
- **Firewall**: `firewalld` (default CachyOS) — `systemctl enable --now
  firewalld`, `firewall-cmd --state` → running, zona `public` por
  defecto. Alternativa `ufw` solo si el perfil la elige; **una sola**.
- **Flatpak**: `flatpak override --user --nofilesystem=home <app>`
  por app sensible (plantilla en dotfiles, no global).
- **NVIDIA** (F2-T10): driver según generación — `nvidia-open-dkms`
  (Turing/Ada/Blackwell; recomendado upstream, obligatorio en
  Blackwell) o `nvidia-580xx-dkms` (AUR, Maxwell/Pascal/Volta legacy).
  `modeset` y `fbdev` ya vienen `Y` por defecto desde nvidia-utils 560
  (verificar: `cat /sys/module/nvidia_drm/parameters/modeset`); si `N`,
  parámetro `nvidia_drm.modeset=1`. Early loading en initramfs si SDDM
  arranca antes que el driver (pantalla negra tras logout). Híbridos:
  `KWIN_DRM_DEVICES` o DRI_PRIME según ArchWiki. Suspensión: preservar
  VRAM (`nvidia-suspend` + `NVreg_PreserveVideoMemoryAllocations=1`).
- **Energía**: `power-profiles-daemon` + `powerdevil`; verificar
  `powerprofilesctl list` muestra balanced/performance/power-saver.

## 6. Tests de aceptación F2 y comandos

Por tarea: T01 `plasmashell --version && kwin_wayland --version` +
sesión arranca; T02 boot→Plasma <20 s + captura + `loginctl -p Type`;
T03 `kreadconfig6` valida claves + usuario nuevo hereda;
T04 `scripts/apply-theme` idempotente + `compare.sh golden captura
--umbral 20` + reversible; T05 panel 28 px flotante reserva espacio
(`qdbus6 org.kde.plasmashell /PlasmaShell
org.kde.PlasmaShell.evaluateScript '...'`) + captura; T06 ISO con hash;
T07 instalación Calamares completa en VM; T08 <20 min, 0 críticos en
journal; T09 LUKS + firewall running + telemetría off (captura);
T10 Wayland en NVIDIA + `powerprofilesctl list`. Gate F2 = todo lo
anterior verde o no se avanza a F3.

Utilidades comunes: `qdbus6 org.kde.KWin /KWin supportInformation`
(estado KWin), `kpackagetool6 -l --type=Plasma/Applet` (applets),
`systemsettings kcm_*` (KCMs), `journalctl -p 3 -b` (errores críticos),
`kinfo`/`plasmashell --version` (versiones para evidencia).

## 7. Riesgos (top 5)

1. **Klassy es AUR-only y sigue a Plasma de cerca** (hoy 6.7.3↔Plasma
   6.6.1+; Plasma local ya 6.8.2 → verificar compatibilidad en VM;
   si rompe, fallback `klassy-bin` OBS o KDecoration custom, R-KLASSY).
2. **plasma-login-manager inmaduro**: si su KCM/autologin falla en VM,
   quedarse en SDDM y re-evaluar en F8 (Ruling de 1 línea).
3. **Claves KConfig renombradas entre 6.6→6.8** (feedback, OSD):
   ninguna clave de este brief es definitiva hasta `kreadconfig6` en
   VM — el instalador debe tolerar clave ausente (warning, no fail).
4. **CachyOS cadence**: `cachyos-extra-v3` vs `extra` pueden llevar
   versiones distintas (hoy coinciden en 6.8.2 salvo PPD 0.30-3 vs
   -1) → pin por snapshot de repo, no por número suelto (R-CACHYOS).
5. **Greetd tienta por simplicidad pero pierde kwallet-PAM y KCM**;
   solo con Ruling explícita y solución kwallet documentada.

## 8. Pins propuestos (congelar en F2-T01 tras VM)

`plasma-meta 6.8-1`, `plasma 6.8.2` (kwin, plasma-desktop,
plasma-login-manager, sddm-kcm, kde-gtk-config, powerdevil…),
`krunner 6.31.0`, `sddm 0.21.0`, `kvantum 1.1.8`, `klassy 6.7.3`
(AUR, Qt6-only), `layer-shell-qt 6.8.2`, `power-profiles-daemon 0.30`,
`archiso` vigente + `calamares` repo, `firewalld`, CachyOS snapshot
2026-10. Nada usa `latest`.
