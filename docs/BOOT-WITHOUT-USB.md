# Arrancar NimbusOS sin USB — estado real (2026-11-02)

## ISO

```
~/.cache/nimbusshell-vm/share/out16/nimbusos-2026.11.01-x86_64.iso
SHA256 de12c6d90076283946ed6b20f219c76aa12e78ca4473cdf50e1e2a72805789b3
```

También copiada al escritorio del host:
`/home/jp/Escritorio/nimbusos-2026.11.01-x86_64.iso` (+ `.sha256`,
`grub-nimbus.txt`, `LEEME-NIMBUSOS.txt`).

Servir por red en el host:

```bash
cd ~/.cache/nimbusshell-vm/share/out16
python3 -m http.server 8081 --bind 0.0.0.0
# http://192.168.1.225:8081/nimbusos-2026.11.01-x86_64.iso
```

## Lo que se probó y NO funcionó

1. **PXE por Wi-Fi (proxy DHCP)**. El portátil (Ethernet al router) envía
   DHCP y el router responde; `tcpdump -i wlan0` lo ve, pero **`dnsmasq` no
   recibe ni una petición** en `wlan0`. Es aislamiento AP/VLAN, no config.
   `scripts/nimbus-pxe` queda como herramienta para cuando el host tenga
   Ethernet. Sin cable al host o al router, no insistir.
2. **Arranque desde tarjeta SD**: la SD se escribe, pero el lector del
   portátil no aparece en el menú de arranque. No es un fallo del ISO.
3. **Calamares en QEMU**: el proceso arranca (`/usr/bin/calamares`), pero su
   ventana no se dibuja en el live (Wayland/virtio). Se activó/movió con un
   script KWin; sigue sin renderizar. La ISO **no está validada como
   instalable** hasta probarla en hardware real o arreglar XWayland/xcb.

## GRUB2Win (vía pendiente, sin USB)

1. Copiar la ISO a `C:\nimbus.iso` (2,3 GB).
2. Instalar **GRUB2Win** (SourceForge).
3. Secure Boot **OFF**; BitLocker de C: **desactivado o suspendido**
   (`manage-bde -status C:`; `manage-bde -protectors -disable C: -rebootcount 1`).
4. `Manage Boot Menu → Add a New Entry → Custom` y pegar
   [`grub-nimbus.txt`](../../grub-nimbus.txt) (o
   `http://192.168.1.225:8081/grub-nimbus.txt`).
5. La entrada `NimbusOS ISO (UUID)` usa `search` + `probe -u` para pasar
   `img_dev=/dev/disk/by-uuid/$isouuid` e `img_loop=/nimbus.iso`; la segunda
   entrada asume etiqueta `Windows`.
6. El initramfs de la ISO incluye `ntfs3`/`vfat` (verificado con
   `lsinitcpio`), así que el ISO en NTFS debería montar.

Si GRUB2Win falla, anotar el error exacto (`file not found`,
`unknown filesystem`, `mount: wrong fs type`). No inventar un éxito sin
captura.

## Alternativas

- Cable Ethernet **al host** (no solo al router): PXE funciona; `scripts/nimbus-pxe`.
- SD/DVD/HDD externo que el firmware sí arranque.
- Instalar el ISO en el PC desde un lector USB o quitando el disco.
- **No** usar correo para 2,3 GB (límite típico 25 MB); usar WeTransfer,
  Drive, OneDrive, Syncthing o un medio físico.
