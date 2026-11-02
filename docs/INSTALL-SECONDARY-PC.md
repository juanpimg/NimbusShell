# Instalar el PC secundario y dejarlo controlable por SSH

Objetivo: instalar la ISO de NimbusOS en el PC de pruebas y dejarlo accesible
para desplegar/capturar sin reconstruir la ISO.

## 1. ISO

Cuando termine el build estará en el host:

```
~/.cache/nimbusshell-vm/share/out16/nimbusos-*.iso
~/.cache/nimbusshell-vm/share/out16/SHA256SUMS
```

Verifica el checksum antes de copiarla:

```bash
cd ~/.cache/nimbusshell-vm/share/out16
sha256sum -c SHA256SUMS
```

Copia a un USB con Ventoy (recomendado) o `dd` (borra el USB):

```bash
# Sustituye /dev/sdX por el USB, NO por el disco del PC
sudo dd if=nimbusos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## 2. Instalación en el PC secundario

1. Conecta **Ethernet** (mejor que Wi-Fi para SSH) y el USB.
2. Arranca el PC desde el USB (F12/F11/ESC según firmware; si es UEFI,
   desactiva Secure Boot).
3. Calamares: idioma, teclado, disco **dedicado** (borra ese disco, no el de
   tu uso diario), usuario y contraseña, hostname `nimbus-test`.
4. Instala el grupo Nimbus por defecto (red necesaria para los paquetes).
5. Reinicia y arranca del disco.

La ISO instala Plasma 6.8, SDDM, NetworkManager, barra Nimbus, CC, menú,
calendario, aplicaciones y `nimbus-control`.

## 3. Dejarlo controlable (una vez)

En el PC, abre Konsole y ejecuta:

```bash
sudo nimbus-control
```

Hace, de forma idempotente:

- activa `sshd` y abre SSH en firewalld;
- añade la clave pública `nimbus-control` a tu usuario;
- concede `sudo` sin contraseña a ese usuario (máquina de pruebas);
- configura autologin de SDDM a Plasma (la barra/CC necesitan sesión);
- imprime la IP y el comando SSH.

Apunta la IP (o búscala con `ip -4 addr`). Si el PC usa Wi-Fi, conéctalo antes
desde Plasma.

## 4. Desde el host

```bash
ssh -i ~/.ssh/nimbus_control <usuario>@<IP>
```

Si funciona, añade el alias:

```bash
cat >>~/.ssh/config <<'EOF'
Host nimbus-test
  HostName <IP>
  User <usuario>
  IdentityFile ~/.ssh/nimbus_control
  StrictHostKeyChecking accept-new
EOF
ssh nimbus-test 'hostnamectl; nimbus-bar --version 2>/dev/null; echo OK'
```

La clave privada se queda en el host (`~/.ssh/nimbus_control`, modo 600).
La pública está embebida en la ISO; no hay contraseña que compartir.

## 5. Instalar el toolchain de iteración (una vez, por SSH)

```bash
ssh nimbus-test 'sudo pacman -S --needed --noconfirm \
  git cmake ninja extra-cmake-modules qt6-tools qt6-base qt6-declarative \
  kwin kdecoration rsync grim spectacle ydotool vulkan-headers'
```

Con eso puedo:

- compilar `nimbus-bar` en el PC o en el host y desplegar por `rsync`;
- reiniciar el servicio user `nimbus-bar`;
- capturar con `grim`/`spectacle` y traer el PNG;
- mover el puntero con `ydotool` para clics reales (Wayland);
- compilar/instalar Glass para la GPU real.

## 6. Primer despliegue y captura

Desde el host:

```bash
scripts/dev-remote deploy      # build + rsync + restart + md5
scripts/dev-remote capture     # grim + scp a docs/plans/evidence/
```

`scripts/dev-remote doctor` comprueba SSH, servicio, `grim` y `rsync`.
Los comandos manuales equivalentes son:

```bash
rsync -av /tmp/nimbus-remote-build/nimbus-bar nimbus-test:/tmp/nimbus-bar.new
ssh nimbus-test 'sudo install -m755 /tmp/nimbus-bar.new /usr/local/bin/nimbus-bar && \
  systemctl --user restart nimbus-bar && md5sum /usr/local/bin/nimbus-bar'
ssh nimbus-test 'grim /tmp/nimbus-shot.png'
scp nimbus-test:/tmp/nimbus-shot.png docs/plans/evidence/
```

## 7. Energía y recuperación

- Déjalo encendido; para reiniciar usa `ssh nimbus-test 'sudo reboot'`.
- Para apagarlo y volver a encenderlo remotamente necesitas **Wake-on-LAN**
  (BIOS + `ethtool -s <iface> wol g`) o un enchufe inteligente. Sin eso, evita
  `poweroff` remoto.
- Si algo rompe la sesión gráfica, entra por SSH y reinicia SDDM:
  `sudo systemctl restart sddm`.
- Si rompes SSH, usa el teclado/consola física del PC.

## 8. Glass (GPU real)

La ISO lleva el blur stock de KWin; para la refracción Liquid Glass, una vez
con SSH:

```bash
# En el host, con la receta de packaging/glass/README.md, publica glass.so
# y kwin_glass_config.so; luego en el PC:
sudo install -Dm755 glass.so /usr/lib/qt6/plugins/kwin/effects/plugins/glass.so
sudo install -Dm755 kwin_glass_config.so \
  /usr/lib/qt6/plugins/kwin/effects/configs/kwin_glass_config.so
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key glassEnabled true
```

Reinicia la sesión (`sudo systemctl restart sddm`) y verifica que la barra/CC
refractan sobre un fondo de alto contraste. Los fps y la refracción se miden
en este PC, no en la VM.
