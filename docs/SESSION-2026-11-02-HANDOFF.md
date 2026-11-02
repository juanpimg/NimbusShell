# Handoff — sesión limpia 2026-11-02 (Plasma)

> **Empieza por este documento.** Resume el estado real, lo que funciona, lo
> que no, el entorno y los siguientes pasos. El resto de documentos son
> evidencia o historia; este manda para continuar.

## 0. TL;DR

- Rama de trabajo: **`plasma-migration`** (incluye `main`; 402 commits).
  `main` local es ancestro y se puede fast-forward antes de publicar.
- Remoto: `https://github.com/juanpimg/NimbusShell.git`.
- Ledger real: **60/112 (54,3 %)**; **no inflar**. Ver
  `docs/superpowers/plans/2026-10-31-plasma-migration.md`.
- `scripts/ci.sh` **VERDE**; `tests/bar/test_presets.sh` **VERDE**;
  `qmltestrunner` calendario **9/9**; `test_qml_root.sh` **7/7**.
- ISO **out16 construida y con SHA verificado**:
  `~/.cache/nimbusshell-vm/share/out16/nimbusos-2026.11.01-x86_64.iso`
  (2,3 GB, `de12c6d9…789b3`). Arranca en UEFI hasta SDDM/Plasma; **Calamares
  no se dibujó en QEMU** (proceso vivo, ventana no visible). No está validada
  en el PC físico.
- Glass real: **spike nested** (blur + refracción Snell) en barra/CC/menú;
  **no empaquetado en la ISO** ni validado en GPU real.
- PC secundario: Windows, sin teclado; no instalado. PXE por Wi-Fi **falló**
  (el AP no entrega DHCP a `wlan0`); SD **no arrancó**; queda GRUB2Win.
- out15 (VM del usuario, PID 299775) **ya no estaba corriendo**; no se tocó.
  La VM dev se paró para liberar RAM. No hay VMs de Nimbus arrancadas ahora.

## 1. Qué es el proyecto ahora

Migración de NimbusShell (histórico Hyprland/MacShell) a **KDE Plasma 6.8.2
Wayland** con barra propia layer-shell (`nimbus-bar`), tema NimbusTahoe,
Klassy, Krema (Dock) e ISO NimbusOS. El objetivo sigue siendo **1:1 con macOS
Tahoe**, sin activos Apple. La documentación anterior de Hyprland se conserva
como historia en `docs/legacy/` y en `docs/HANDOFF.md`.

## 2. Entorno de trabajo

- Host: Arch/Plasma 6.8.2, KWin 6.8.2, Qt 6.12, 20 CPU, 15 GiB RAM.
- Repo: `/home/jp/Escritorio/Proyectos/NimbusShell-migration`.
- QEMU/KVM cache: `~/.cache/nimbusshell-vm/`:
  - `share/nimbusos.iso` → ISO out8; `share/out16/` ISO nueva.
  - `target-disk.qcow2` (out15 instalada, no tocar), `target.sock`,
    VNC 5907/SSH 2227 (out15).
  - `dev-vm` live: VNC 5908, HMP `dev-vm.sock`, SSH 2228 (sshd ausente).
  - `build-disk.qcow2` (VM de build de ISO), `build.sock`, VNC 5906.
  - `install-test.qcow2` + `install-test-OVMF_VARS.fd` (test de instalación).
- Clave SSH de control: `~/.ssh/nimbus_control` (privada, **no commitear**);
  pública embebida en `scripts/nimbus-control`.
- **No hay contraseñas en el repo.** Las credenciales de laboratorio históricas
  están en `docs/HANDOFF.md`; no reutilizar en producción.

## 3. Lo que funciona (con evidencia)

| Área | Estado | Evidencia |
|---|---|---|
| Barra 24 px, multi-monitor, orden/Spotlight | Funciona en nested/live | `docs/plans/evidence/F3-T12-*`, `F3-T03-bar-transparency.md` |
| Barra translúcida Tahoe | 0.18 / hairline 0.25, Glass si está | `F3-T03-bar-transparency/before-after.png` |
| Menú Apple | 248×299, Glass, iconos de línea, separadores, altura dinámica; overlay corregido | `F3-T04-menu-glass.md` + capturas |
| Control Center | 304/292 px, cápsulas 140×64, badges blancos, círculos 64, sliders con etiqueta | `F3-T05-tahoe-cc.md` |
| Calendario | 300×368, 6×7, hoy círculo, sin puntos falsos, tiempo pie | `F3-T08-calendar-tahoe.md`; `qmltestrunner 9/9` |
| Notificaciones | Banner 360, icono 38, radio 18, acciones; demo + Glass | `F3-T09-notifications-tahoe.md` |
| Blur real de compositor | Barra + CC (`ext-background-effect`) | `F11-T02-blur.md` (laplaciano 15,27 vs 81,15) |
| Glass (refracción) | Spike nested KWin 6.8.2; bar/CC/menú | `F11-T02-glass-spike.md`, `F11-T02-glass/` |
| Loop dev sin ISO | `scripts/dev-vm` live 9p+HMP+agente; deploy/capture PASS | `DEV-VM-LOOP.png`, md5 `161fb37…` |
| QML sin rebuild | `--qml-root` + test 7/7 | `docs/DEV-QML-ROOT.md`, `QML-ROOT.md` |
| Deploy a PC instalado | `scripts/dev-remote` (SSH) | `docs/INSTALL-SECONDARY-PC.md` |
| ISO out16 | Build + SHA + arranque UEFI hasta SDDM/Plasma | `out16/SHA256SUMS`; captura abajo |
| CI | Verde | `scripts/ci.sh` |

## 4. Lo que NO está hecho / falla

1. **Calamares en la ISO live**: en QEMU el proceso arranca pero su ventana
   no se dibuja (Wayland/virtio). Se probó activar/mover la ventana con KWin;
   sigue sin renderizar. **No dar la ISO por instalable hasta validarlo.**
   Posible fix: lanzar Calamares con `QT_QPA_PLATFORM=xcb`/XWayland; requiere
   rebuild out17.
2. **Glass no está en la ISO**: la receta `packaging/glass/PKGBUILD` está
   lista, pero no se instaló en el perfil/staging ni se activó en kwinrc por
   defecto. En nested se usó `/tmp/glass-prefix`.
3. **PC secundario**: no instalado; Windows, sin teclado. PXE por Wi-Fi falló
   (tcpdump ve el DHCP del portátil, dnsmasq no lo recibe: aislamiento AP);
   SD no arranca; GRUB2Win pendiente. El ISO está en el escritorio del host y
   en out16.
4. **Dock real (Krema)** no validado con Glass; en el live de la ISO aparece
   el panel stock de Plasma, no Krema.
5. **Notificaciones**: acciones reales por FDO, DND y pila de 2 no repetidas
   en VM/PC; el demo local sí.
6. **Menú**: acciones destructivas (dormir/bloquear/reiniciar/apagar) no
   ejecutadas; solo UI/log. F3-T04 sigue abierto.
7. **CC**: toggles reales Wi-Fi/BT/tema/DND no validados en instalado;
   F3-T05 abierto. Falta AirDrop/Stage Manager reales (adaptación funcional).
8. **F3-T12**: golden tautológico (captura propia); falta golden independiente
   y clics reales.
9. **F5-T06/F5-T08/F7-T10**: genie, reorder del Dock y drag de miniaturas
   siguen sin evidencia 1:1.
10. **FPS, Reduce Transparency, accesibilidad**: sin medir en GPU real.

## 5. Flujo de trabajo recomendado (tres velocidades)

### 5.1 Nested (segundos, sin VM)
```bash
bash tests/vm/nested-bar.sh --bin /tmp/nimbus-bar-dev/nimbus-bar \
  --out spikes/nested --wallpaper packages/themes/nimbus-tahoe/wallpapers/sequoia-dark.jpg \
  --socket nimbus-dev-$$ --bar-args "--open-cc"
```
- Captura `spikes/nested/f3-bar-24.png`; log `nested-bar.log`.
- Para Glass: `--kwinrc /tmp/opencode/glass-kwinrc-subtle
  --plugin-path /tmp/glass-prefix/lib/plugins`.
- `/tmp/glass-prefix` y `/tmp/opencode/glass-kwinrc-subtle` son **volátiles**:
  recompilar con `packaging/glass/README.md` si no existen.
- `--wallpaper` y `--socket` son opcionales; el socket único evita que dos
  harness se maten (el cleanup ya solo mata sus PID).

### 5.2 VM live dev (`scripts/dev-vm`)
```bash
scripts/dev-vm start          # ISO live, -snapshot, VNC 5908
scripts/dev-vm deploy --open-cc
scripts/dev-vm capture docs/plans/evidence/dev.png
scripts/dev-vm stop
```
- Sin SSH en el live: 9p `/mnt` + agente + HMP. `doctor`/`status`/`deploy`
  verifican md5 y `deployed.md5`; `capture` usa HMP.
- No usar 5907/2227/target.sock (out15). El script solo mata su PIDFILE.
- La VM no arranca Plasma sola en todos los casos: `start` teclea
  `startplasma-wayland` + agente; si ya hay Plasma, imprime el comando manual.

### 5.3 PC físico (cuando esté)
```bash
scripts/dev-remote doctor
scripts/dev-remote deploy
scripts/dev-remote capture
```
- Requiere `nimbus-control` ejecutado en el PC (sshd, clave, sudo, autologin).
- Para QML sin rebuild: `--qml-root` + rsync del directorio `qml/`, luego
  reiniciar la barra (el servicio actual no pasa el flag; usar ejecución
  manual o un drop-in, documentado en `DEV-QML-ROOT.md`).

### 5.4 ISO (solo release)
- `iso/build-iso.sh --check`; build real en la VM de build (CachyOS live +
  `share/iso-bootstrap16.sh`); salida `share/out16`.
- **No reconstruir ISO para iterar UI**; solo instalador/greetd/drivers/
  release. El build tarda ~15-20 min y formatea `build-disk.qcow2`.

## 6. Mapa del repo (lo importante)

- `packages/shell/nimbus-bar/`: C++ (`main.cpp`) + QML (`Bar`, `Menu`,
  `ControlCenter`, `Calendar`, `NotificationCenter`, `OSD`, `StatusArea`) +
  presets + tokens.
- `packages/themes/nimbus-tahoe/`, `nimbus-tokens/`, `klassy-preset/`,
  `sddm-nimbus/`.
- `packages/kwin/`, `packaging/glass/` (Glass GPL), `packaging/krema/`,
  `packaging/klassy/`.
- `iso/`: perfil archiso, Calamares, `build-iso.sh`; `scripts/nimbus-control`.
- `scripts/`: `ci.sh`, `nimbus-i18n`, `nimbus-bar-preset`, `nimbus-control`,
  `nimbus-pxe`, `dev-vm`, `dev-remote`.
- `tests/vm/nested-bar.sh`, `tests/bar/test_presets.sh`,
  `test_qml_root.sh`, `tests/qml/tst_calendar.qml`.
- `docs/plans/evidence/`: evidencia canónica (226 ficheros). `spikes/` es
  **local/transitorio** (ignorado en git).
- `docs/design/tahoe-design-contract.md`, `liquid-glass-research.md`,
  `docs/INSTALL-SECONDARY-PC.md`, `docs/DEV-VM-WORKFLOW.md`,
  `docs/DEV-QML-ROOT.md`, `docs/BOOT-WITHOUT-USB.md`.

## 7. Trampas ya mordidas (no repetir)

- `KWindowEffects::isEffectAvailable(BlurBehind)` es **false en el primer
  frame**: registrar siempre, reaplicar a ~500 ms y `requestUpdate()`
  (double-buffered).
- El **scrim full-screen** no debe llevar blur; se descarta por scope/título
  y por geometría ≥90 % de pantalla.
- El **menú** sin `LayerShellQt.Window.anchors` recibía 1280×730 y su fondo
  0.94 tapaba el escritorio; con `AnchorTop|AnchorLeft` + márgenes 8,26 queda
  248×299.
- Glass `Rim*/EdgeLighting` se aplica al **borde de la ventana**, no por
  cápsula; con el CC de una sola ventana hay que bajar el rim.
- `qmlformat` del CI es **`/usr/lib/qt6/bin/qmlformat` (6.12)**, no
  `/usr/bin/qmlformat` (1.0); usar el binario del CI.
- i18n: tras cambiar textos, `scripts/nimbus-i18n --extract` y `--check`.
- `spikes/` no se versiona; las evidencias nuevas van a `docs/plans/evidence/`.
- El harness nested debe usar **socket único** y cleanup por PID; nunca
  `pkill -f` global.
- PXE por **Wi-Fi** en esta red no funciona: los DHCP del portátil se ven en
  `tcpdump` pero no llegan a `dnsmasq` (aislamiento AP). Sin cable al host o
  al router, no insistir.
- La ISO out16 arranca, pero **Calamares no renderiza en QEMU**; no declarar
  instalable sin probarlo en hardware o arreglar X11.

## 8. Siguiente plan (ordenado)

1. **PC secundario**: terminar la vía GRUB2Win (ISO en `C:\nimbus.iso`,
   `grub-nimbus.txt`, Secure Boot off, BitLocker off) o cable Ethernet; al
   entrar, `sudo nimbus-control`, y desde el host `scripts/dev-remote doctor`.
2. **Calamares ISO**: arreglar render (XWayland/xcb) y reconstruir out17;
   instalar en QEMU y validar barra/CC/menú/calendario con capturas.
3. **Glass en ISO**: compilar/instalar `packaging/glass`, kwinrc por defecto,
   licencia GPL, y captura de refracción en GPU real; fps.
4. **Cerrar UI**: notificaciones FDO reales (ActionInvoked/DND/pila), menú con
   acciones reales, Dock/Krema, toggles CC, eventos reales de calendario.
5. **Ledger**: reabrir/cerrar con evidencia; F3-T12 golden independiente;
   F5-T06/T08; F7-T10; F11-T02.
6. **Accesibilidad/perf**: Reduce Transparency, contraste, fps llvmpipe/GPU.

## 9. Comandos de arranque de una sesión limpia

```bash
cd /home/jp/Escritorio/Proyectos/NimbusShell-migration
git status --short
git log --oneline -5
scripts/ci.sh
bash tests/bar/test_presets.sh
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_calendar.qml
```

Si hay que reconstruir la barra:
```bash
cmake -S packages/shell/nimbus-bar -B /tmp/nimbus-bar-dev -G Ninja \
  -DCMAKE_BUILD_TYPE=Release && cmake --build /tmp/nimbus-bar-dev -j8
```

No hay secretos en el repo. La ISO y las VMs viven en `~/.cache/nimbusshell-vm`
y en el escritorio; no se commitean.
